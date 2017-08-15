#!/usr/bin/perl 
use CGI ':standard';
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 
use warnings;
use strict;
use utf8;
binmode(STDIN, ":encoding(UTF-8)");
use JSON::XS;
use LWP::Simple;
use Encode qw(encode from_to);
use URI::Escape qw(uri_unescape uri_escape);
use Data::Dumper;
use List::MoreUtils qw(uniq);
use List::Util qw(min max);
use Math::Trig;
use Encode;

print "Content-Type: application/json; charset=utf-8\r\n\r\n";

my $q = CGI->new;
my $data, my $db;
my $entries;
my $out;
$out->{error} = '';

#################################################
## Read and organize data
## reads data from JSON input
################################################# 
sub readData {
  my $input = shift @_;
   my $url = 'http://overpass-api.de/api/interpreter';
#  my $url = "http://localhost/destinationsign/$input.json";
  my $st = shift @_ || 0;
  my $json;
  
  if($input =~ /elements/) {
    from_to ($input,"iso-8859-1","utf-8");
    $json = uri_unescape($input);
    }
  elsif ($input =~ /^[0-9]+$/ ) {
    my $query = <<QUERY;
[out:json][timeout:25];
(
  node($input)->.start;
  rel(bn.start)[type=destination_sign]->.rels;
  node(r.rels)->.nodes;
  way(r.rels)->.ways;
  way(bn.nodes)[highway]->.wa;
  way(bn.start)[highway]->.wb;
);
out body;
node(w);
out skel;  
(rel(bw.wb);rel(bw.wa););
out body;  
QUERY
    my $ua      = LWP::UserAgent->new();
    my $request = $ua->post( $url, ['data' => encode('utf-8',$query)] ); 
       $json = $request->content();
    }
  else {
    $out->{error} .= "<h3>Can not parse input</h3>"; 
    return 0;
    }
    
  eval {
    $data = decode_json($json);
    1;
    } 
  or do {
    $out->{error} .=  "<h3>No valid data from Overpass</h3>". $json;
    return 0;
    };
  
  if (scalar @{$data->{elements}}) {
    foreach my $w (@{$data->{elements}}) {
      next if $db->{$w->{'type'}}{$w->{'id'}};
      $db->{$w->{'type'}}{$w->{'id'}} = $w;
      }
    }  
  else {
    $out->{error} .=  "<h3>No valid data from Overpass</h3>". "Object not found";
    return 0;
    }
  return 1;  
  }

#################################################
## Direction of X->A
#################################################
sub calcDirection {
  my ($x,$a) = @_;
  my $lat = $db->{node}{$x}{lat} * 0.01745;
  my $dxa = 111.3 * cos($lat) * ($db->{node}{$a}{lon} - $db->{node}{$x}{lon});
  my $dya = 111.3 * ($db->{node}{$a}{lat} - $db->{node}{$x}{lat});
  
  return 0 if($dxa == 0);
  my $anga = rad2deg(atan(abs($dya)/abs($dxa)));
  $anga = -$anga     if $dxa>=0 && $dya>=0;
  $anga = -180+$anga if $dxa<0 && $dya>=0;
  $anga = 180-$anga  if $dxa<0 && $dya<0;
  $anga = 0+$anga    if $dxa>=0 && $dya<0;
  
  return $anga;
  }     
  
#################################################
## Prepare direction calc for one end of way
#################################################  
sub getDirection {
  my ($s) = @_;
  my $o = -1000;
  my $p = -1000;
  #from from to to
  if(defined $q->param('fromarrow') && $s->{to} && $s->{from}) {
    my @ns = @{$db->{way}{$s->{to}}{nodes}};
    if ($ns[0] == $s->{intersection}) {
      $o = calcDirection($s->{intersection},$ns[min(scalar @ns-1, 2)]);
      }
    elsif ($ns[-1] == $s->{intersection}) {
      $o = calcDirection($s->{intersection},$ns[-min(scalar @ns,3)]);
      }
#     $out->{error} .= $o." ";  
    @ns = @{$db->{way}{$s->{from}}{nodes}};  
    if ($ns[0] == $s->{intersection}) {
      $p = calcDirection($ns[min(scalar @ns-1, 2)],$s->{intersection});
      }
    elsif ($ns[-1] == $s->{intersection}) {
      $p = calcDirection($ns[-min(scalar @ns,3)],$s->{intersection});
      }
#     $out->{error} .= $p." ";  
    if($o != -1000 && $p != -1000) {
      $o = -90 + $o - $p;  
      $s->{fromarrow} = 1;
      $s->{fromdir} = $p;
      return int $o; 
      }
    else {
      $o = -1000;
      }
#     $out->{error} .= $o."<br>";  
    } 
  
  #To-way and intersection node
  if($s->{to} && $s->{intersection} && !$s->{tonode}) {
    if($db->{way}{$s->{to}}){
      my @ns = @{$db->{way}{$s->{to}}{nodes}};
      if ($ns[0] == $s->{intersection}) {
        $o = calcDirection($ns[0],$ns[min(scalar @ns-1, 2)]);
        }
      elsif ($ns[-1] == $s->{intersection}) {
        $o = calcDirection($ns[-1],$ns[-min(scalar @ns,3)]);
        }
      }
    }
  #To-node and intersection node
  elsif ($s->{tonode} && $s->{intersection}) {
    $o = calcDirection($s->{intersection},$s->{tonode});
    }
  #To-node and sign node
  elsif ($s->{tonode} && $s->{sign}) {
    $o = calcDirection($s->{sign},$s->{tonode});
    }
  return int $o;  
  }

#Helper: is an object member of a given relation?  
sub isRelationMember {
  my ($type,$id,$parid) = @_;
  foreach my $k (@{$db->{relation}{$parid}{'members'}}) {
    if ($k->{'ref'} == $id  && $k->{'type'} eq $type) {
      return 1;
      }
    }
  return 0;  
  }

#Helper: is a node part of a given way?
sub isWayNode {
  my ($id,$parid) = @_;
  my $pos = -1;
  foreach my $k (@{$db->{way}{$parid}{'nodes'}}) {
    $pos++;
    if ($k == $id) {
      return $pos;
      }
    }
  return -1;  
  }  

  #Helper: is a node an end of a given way?
sub isWayEndNode {
  my ($id,$parid) = @_;
  if ( $db->{way}{$parid}{'nodes'}[0] == $id || $db->{way}{$parid}{'nodes'}[-1] == $id) {
    return 1;
    }
  return 0;  
  }  
  
#Helper: find a way the given node is on
sub findWayfromNode {
  my ($n,$match) =  @_;
  my @o;
  foreach my $w  (sort keys %{$db->{way}}) {
    if(isWayNode($n,$w)>=0) {
      push(@o,$w) if !defined $match || 0==$match--;
      }
    }
  return @o;  
  }  

#Find intersection by   
sub searchIntersection {
  my ($s) = @_;
  return unless $s->{to};
  return unless $s->{from};
  #sign used as intersection?
  if(isWayNode($s->{sign},$s->{to}) >= 0 || isWayEndNode($s->{sign},$s->{from})) {
    return $s->{sign};
    }
  #common point in to and from ways  
  if($db->{way}{$s->{to}}{'nodes'}[0] == $db->{way}{$s->{from}}{'nodes'}[0] || 
     $db->{way}{$s->{to}}{'nodes'}[0] == $db->{way}{$s->{from}}{'nodes'}[-1]){
    return $db->{way}{$s->{to}}{'nodes'}[0];
    }
  if($db->{way}{$s->{to}}{'nodes'}[-1] == $db->{way}{$s->{from}}{'nodes'}[0] || 
     $db->{way}{$s->{to}}{'nodes'}[-1] == $db->{way}{$s->{from}}{'nodes'}[-1]){
    return $db->{way}{$s->{to}}{'nodes'}[-1];
    }
  #end of to way somewhere in from way  
  if( isWayNode($db->{way}{$s->{to}}{'nodes'}[0],$s->{from}) >= 0 ) {
      return $db->{way}{$s->{to}}{'nodes'}[0];
    }
  if( isWayNode($db->{way}{$s->{to}}{'nodes'}[-1],$s->{from}) >= 0 ) {
      return $db->{way}{$s->{to}}{'nodes'}[-1];
    }
  }

  
sub getNamedWay {
  my ($s) = @_;
  my $o;
  foreach my $r (keys %{$db->{relation}}) { 
    if ($db->{relation}{$r}{'tags'}{'type'} eq 'route' &&
        grep(/^$db->{relation}{$r}{'tags'}{'route'}$/, qw(foot mtb hiking bicycle horse))) {
      if (isRelationMember('way',$s->{to},$r)) { 
        if ($db->{relation}{$r}{'tags'}{'name'}) {
          $o .= '<br>' if $o;
          $o .= $db->{relation}{$r}{'tags'}{'name'};
          }
        }
      }
    }
  return $o;  
  }
  
#Take destination string, add destination:lang:XX (if not already in string)
sub DestinationString {
  my ($r,$num) = @_;
  $num //= 0;
  my @t = split(';',$db->{relation}{$r}{'tags'}{'destination'});
  my $o = $t[$num];
  foreach my $k (keys %{$db->{relation}{$r}{'tags'}}) {
    if ($k =~ /^destination:lang:/) {
      @t = split(';',$db->{relation}{$r}{'tags'}{$k});
      next if (index($o,$t[$num]) != -1);
      $o .= '<br>'.$t[$num];
      }
    }
  $o =~ s/;/<br>/g;
  return $o;
  }

#Search through sources of refs  
sub getRef {
  my $s = shift @_;
  my $p = shift @_;
  my $o ='';
  my @out;
  #ref from destination:ref
  if ($db->{relation}{$s->{id}}{'tags'}{'destination:ref'}) {
    my @tmp = split(';',$db->{relation}{$s->{id}}{'tags'}{'destination:ref'});
    push(@out,@tmp) unless defined $p;
    push(@out,$tmp[$p]) if defined $p;
    }
  else {
    #ref from ref on to-way  
    if ($db->{way}{$s->{to}}{'tags'}{'ref'}) {
      push(@out,$db->{way}{$s->{to}}{'tags'}{'ref'});
      }
    #ref from relation to-way belongs to
    foreach my $r (keys %{$db->{relation}}) { 
      if ($db->{relation}{$r}{'tags'}{'type'} eq 'route' &&
          $db->{relation}{$r}{'tags'}{'route'} eq 'hiking') {
        if (isRelationMember('way',$s->{to},$r)) {    
          if ($db->{relation}{$r}{'tags'}{'ref'}) {
            push(@out,$db->{relation}{$r}{'tags'}{'ref'});
            }
          } 
        }
      }
    
    }
  $o = join (';',uniq(@out));  
  $o =~ s/;/<br>/g;   
  return $o;
  }

sub getSymbol {
  my ($r,$num) = @_;
  $num //= 0;
  my @t = split(';',$db->{relation}{$r}{'tags'}{'destination:symbol'});
  if($t[$num]) {
    return $t[$num];
    }  
  }
  
sub getTimeDistance {
  my ($r,$num) = @_;
  $num //= 0;
  my $o = '';
  my @t = split(';',$db->{relation}{$r}{'tags'}{'time'});
  if($t[$num]) {
    $o .= $t[$num];
    }
  @t = split(';',$db->{relation}{$r}{'tags'}{'distance'});
  if($t[$num]) {
    if($o) {$o .= ' | ';}
    $o .= $t[$num];
    $o .= ' km' if($t[$num] =~ /^[0-9\.]+$/)
    }
  return $o;  
  }

sub getBestTo {
  my ($s) = @_;
  my @tos = @{$s->{tos}};
  my $o = $tos[0];
  my $best = 0;
#   $out->{error} .= join('-',@tos).'<br>';
  foreach my $t (@tos) {
    my $val = 0;
    next if $t == $s->{from};
    $val++ if (isWayEndNode($s->{intersection},$t));
    $val++ if (isWayEndNode($s->{sign},$t));
    $val++ if (isWayNode($s->{tonode},$t) != -1);
    
    if ($val > $best) {
      $o = $t;
      $best = $val;
      }
    }
  return $o;
  }
  
#################################################
## Read & Display information from relations
#################################################  
sub parseData {
  my ($startnode) = @_;
  foreach my $w (keys %{$db->{relation}}) {
    next unless $db->{relation}{$w}{'tags'}{'type'} eq 'destination_sign';
    my $s;
    $s->{id} = $w;
    foreach my $m (@{$db->{relation}{$w}{'members'}}) {
      if ($m->{'role'} eq 'sign' && $m->{'type'} eq 'node') {
        next if $s->{sign} == $startnode;
        $s->{sign} = $m->{'ref'};
        }
      if (($m->{'role'} eq 'intersection' || $m->{'role'} eq 'via') && $m->{'type'} eq 'node') {
        next if $s->{intersection} == $startnode;
        $s->{intersection} = $m->{'ref'};
        }
      if ($m->{'role'} eq 'from' && $m->{'type'} eq 'way') {
        push(@{$s->{froms}},$m->{'ref'});
        }
      if ($m->{'role'} eq 'from' && $m->{'type'} eq 'node') {
        $s->{fromnode} = $m->{'ref'};
        push(@{$s->{froms}},findWayfromNode($m->{'ref'}));
        }
      if ($m->{'role'} eq 'to' && $m->{'type'} eq 'way') {
        push(@{$s->{tos}},$m->{'ref'});
        }
      if ($m->{'role'} eq 'to' && $m->{'type'} eq 'node') {
        $s->{tonode} = $m->{'ref'};
        push(@{$s->{tos}},findWayfromNode($m->{'ref'}));
        }
      }
    
    next if($startnode != $s->{sign} && $startnode != $s->{intersection});
    
    @{$s->{tos}}   = uniq @{$s->{tos}};
    @{$s->{froms}} = uniq @{$s->{froms}};
    
    push(@{$s->{froms}},'') if (scalar @{$s->{froms}} == 0);
    
    foreach my $f (@{$s->{froms}}) {
      $s->{fromarrow} = 0;  
      $s->{from} = $f;
      $s->{to}   = getBestTo($s);
      $s->{intersection} //= searchIntersection($s);
      $s->{dir}            = getDirection($s);

#       $out->{error} .= $s->{from}.'-'.$s->{to}.'-'.$s->{intersection}.'<br>';

      
      foreach my $i (0..(scalar split(';',$db->{relation}{$w}{'tags'}{destination})-1)) {
        $s->{dest} = DestinationString($w,$i);
        $s->{wayname} = getNamedWay($s);
        $s->{wayref}  = getRef($s, $i);
    
        $s->{dura} = getTimeDistance($w,$i);
        $s->{symbol} = getSymbol($w,$i);

        my $o;
        $o = "<div class=\"entry\" style=\"";
        $o .= "color:".$db->{relation}{$w}{'tags'}{'colour:text'}.";" if $db->{relation}{$w}{'tags'}{'colour:text'}; 
        $o .= "background:".$db->{relation}{$w}{'tags'}{'colour:back'}.";"; 
        $o .= "\">";
        
      
        $o .= "<div class=\"compass\" style=\"";
        if ($db->{relation}{$w}{'tags'}{'colour:arrow'} && $db->{relation}{$w}{'tags'}{'colour:back'} ne $db->{relation}{$w}{'tags'}{'colour:arrow'}) {
          $o .= "color:".$db->{relation}{$w}{'tags'}{'colour:arrow'}.";" ; 
          }
        $o .= "\"  onClick=\"showObj('relation',".$db->{relation}{$w}{'id'}.")\">";
        if($s->{dir} != -1000) {  
          if(defined $q->param('fromarrow') && $s->{fromarrow}) {
            $o .= "<div style=\"transform: rotate($s->{dir}deg);\">&#x21e8;</div>";
            }
          else {  
            $o .= "<div style=\"transform: rotate($s->{dir}deg);\">&#10137;</div>";
            }
          }
        else {
          $o .= "<div>?</div>";
          }
        $o .= '</div>';  
          
          
        $o .= "<div class=\"ref\">".($s->{wayref}||'&nbsp;')."</div>";
        $o .= "<div class=\"dest\">$s->{dest}";
        $o .= "<br><span>$s->{wayname}</span>" if $s->{wayname} && defined $q->param('namedroutes');
        $o .= "</div>";
        
        $o .= "<div class=\"dura\">$s->{dura}</div>";
        $o .= "<div class=\"symbol\"><div class=\"$s->{symbol}\">&nbsp;</div></div>" if $s->{symbol};
        $o .= "</div>";
        if(defined $q->param('fromarrow')  && $s->{fromarrow}) {
          $entries->{$s->{fromdir}}{$s->{dir}.$s->{dest}.$i.$w} = $o;
          }
        else {
          $entries->{'all'}{$s->{dir}.$s->{dest}.$i.$w} = $o;
          }
        }
      }

    my $o = '';
    unless($entries->{'Z'.$s->{sign}}) {
      $o .= "<span><a href=\"".$db->{node}{$s->{sign}}{'tags'}{'image'}."\">Image</a></span>" if $db->{node}{$s->{sign}}{'tags'}{'image'};
      $o .= "<span><a href=\"http://www.mapillary.com/map/im/".$db->{node}{$s->{sign}}{'tags'}{'mapillary'}."\">Mapillary</a></span>" if $db->{node}{$s->{sign}}{'tags'}{'mapillary'};
      $o .= "<span><a href=\"".$db->{node}{$s->{sign}}{'tags'}{'website'}."\">Website</a></span>" if $db->{node}{$s->{sign}}{'tags'}{'website'};
      $o .= "<span>Operator: $db->{node}{$s->{sign}}{'tags'}{'operator'}</span>" if $db->{node}{$s->{sign}}{'tags'}{'operator'};
      
      if($o) {
        $o = "<div class=\"details\">".$o."</div>";
        }
      $entries->{'all'}{'Z'.$s->{sign}} = $o;
      }  
    }
  }

  
  
 
readData($q->param('nodeid')) && parseData($q->param('nodeid'));

my $o;
foreach my $e (sort keys %{$entries}) {
  if ($e ne 'all') {
    $o .= "<div>Travel Direction <div style=\"display:inline-block;transform: rotate(".(int $e)."deg);\">&#10137;</div></div>";
    }
  else {
    $o .= "<div>&nbsp;</div>";
    }
  foreach my $f (sort keys %{$entries->{$e}}) {
    $o .= $entries->{$e}{$f}."\n";
    }
  }

$out->{html} = $o;
$out->{lat} = $db->{node}{$q->param('nodeid')}{lat};
$out->{lon} = $db->{node}{$q->param('nodeid')}{lon};

print  encode_json($out);

