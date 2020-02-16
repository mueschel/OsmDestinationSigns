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
use HTML::Entities qw(encode_entities_numeric);
use Encode;
use Storable 'dclone';

print "Content-Type: application/json; charset=utf-8\r\n";
print "Access-Control-Allow-Origin: *\r\n\r\n";

my $q = CGI->new;
my $data, my $db;
my $entries;
my $out;
my $d;  #data store for json
$out->{error} = '';

my $format = $q->param('format') || 'html';
my $fast   = $q->param('fast');
my $distanceunit = $q->param('distunit') || ''; #km, mi, m, empty (no change)

#################################################
## Read and organize data
## reads data from JSON input
################################################# 
sub readData {
  my $input = shift @_;
  my $st = shift @_ || 0;
  my $json;
  
#   if($input =~ /elements/) {
#     from_to ($input,"iso-8859-1","utf-8");
#     $json = uri_unescape($input);
#     }
#   els
  if ($input =~ /^[0-9]+$/ ) {
    my $url = 'http://overpass-api.de/api/interpreter';
#     if($fast) {
      $url = 'http://osm.mueschelsoft.de/overpass/';
#       }
    if (-e "../data/$input.json") {
      $url = "http://osm.mueschelsoft.de/destinationsign/data/$input.json";
      }
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
  
  return int $anga if defined $anga;
  }     
  
#################################################
## Prepare direction calc for one end of way
#################################################  
sub getDirection {
  my ($s) = @_;
  $s->{fromdir} = undef;
  $s->{todir}   = undef;
  $s->{reladir} = undef;
  #from from to to
  if(defined $q->param('fromarrow') && $s->{to} && $s->{from}) {
    my @ns = @{$db->{way}{$s->{to}}{nodes}};
    if ($ns[0] == $s->{intersection}) {
      $s->{todir} = calcDirection($s->{intersection},$ns[min(scalar @ns-1, 2)]);;
      }
    elsif ($ns[-1] == $s->{intersection}) {
      $s->{todir} = calcDirection($s->{intersection},$ns[-min(scalar @ns,3)]);
      }
#     $out->{error} .= $o." ";  
    @ns = @{$db->{way}{$s->{from}}{nodes}};  
    if ($ns[0] == $s->{intersection}) {
      $s->{fromdir} = calcDirection($ns[min(scalar @ns-1, 2)],$s->{intersection});
      }
    elsif ($ns[-1] == $s->{intersection}) {
      $s->{fromdir} = calcDirection($ns[-min(scalar @ns,3)],$s->{intersection});
      }
#     $out->{error} .= $p." ";  
    if(defined $s->{fromdir} && defined $s->{todir}) {
      $s->{reladir} = -90 + $s->{todir} - $s->{fromdir};  
      $s->{fromarrow} = 1;
      return int $s->{reladir}; 
      }
#     $out->{error} .= $o."<br>";  
    } 
  
  #To-way and intersection node
  if($s->{to} && $s->{intersection} && !$s->{tonode}) {
    if($db->{way}{$s->{to}}){
      my @ns = @{$db->{way}{$s->{to}}{nodes}};
      if ($ns[0] == $s->{intersection}) {
        $s->{todir} = calcDirection($ns[0],$ns[min(scalar @ns-1, 2)]);
        }
      elsif ($ns[-1] == $s->{intersection}) {
        $s->{todir} = calcDirection($ns[-1],$ns[-min(scalar @ns,3)]);
        }
      }
    }
  #To-node and intersection node
  elsif ($s->{tonode} && $s->{intersection}) {
    $s->{todir} = calcDirection($s->{intersection},$s->{tonode});
    }
  #To-node and sign node
  elsif ($s->{tonode} && $s->{sign}) {
    $s->{todir} = calcDirection($s->{sign},$s->{tonode});
    }
  return int $s->{todir}   if defined $s->{todir};  
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
    if ($k == ($id||0)) {
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

#TODO get name if 'to' is node of way belonging to named route
sub getNamedWay {
  my ($s) = @_;
  my $o;
  foreach my $r (keys %{$db->{relation}}) { 
    if ($db->{relation}{$r}{'tags'}{'type'} eq 'route' &&
        grep(/^$db->{relation}{$r}{'tags'}{'route'}$/, qw(foot mtb hiking bicycle horse))) {
      if (isRelationMember('way',$s->{to},$r)) { 
        if ($db->{relation}{$r}{'tags'}{'name'} && 
            $db->{relation}{$r}{'tags'}{'name'} ne $db->{relation}{$r}{'tags'}{'ref'}) {
          $o .= '<br>' if $o;
          $o .= $db->{relation}{$r}{'tags'}{'name'};
          }
        }
      }
    }
  return $o;  
  }

sub getSymboledWay {
  my ($s) = @_;
  my @o;
  foreach my $r (keys %{$db->{relation}}) { 
    if ($db->{relation}{$r}{'tags'}{'type'} eq 'route' &&
        grep(/^$db->{relation}{$r}{'tags'}{'route'}$/, qw(foot mtb hiking bicycle horse))) {
      if (isRelationMember('way',$s->{to},$r)) { 
        if ($db->{relation}{$r}{'tags'}{'osmc:symbol'}) {
          push(@o,$db->{relation}{$r}{'tags'}{'osmc:symbol'});
          }
        }
      }
    }
  return \@o;  
  }  
  
#Take destination string, add destination:lang:XX (if not already in string)
sub DestinationString {
  my ($s,$r,$num) = @_;
  $num //= 0;
  my @t = split(';',$db->{relation}{$r}{'tags'}{'destination'});
  my $o = $t[$num];
  $s->{destination} = $t[$num];
  foreach my $k (keys %{$db->{relation}{$r}{'tags'}}) {
    if ($k =~ /^destination:lang:(.*)/) {
      @t = split(';',$db->{relation}{$r}{'tags'}{$k});
      $s->{"destination:$1"} = $t[$num];
      next if (index($o,$t[$num]) != -1);
      $o .= '<br> '.$t[$num];
      }
    }
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
    push(@out,$tmp[$p]) if defined $p && scalar @tmp > $p;
    push(@out,$tmp[0])  if defined $p && scalar @tmp == 1;
    }
  else {
    #ref from ref on to-way  
    if ($db->{way}{$s->{to}}{'tags'}{'ref'}) {
      my @tmp = split(';',$db->{way}{$s->{to}}{'tags'}{'ref'});
      push(@out,@tmp);
      }
    #ref from relation to-way belongs to
    foreach my $r (keys %{$db->{relation}}) { 
      if ($db->{relation}{$r}{'tags'}{'type'} eq 'route' &&
          $db->{relation}{$r}{'tags'}{'route'} eq 'hiking') {
        if (isRelationMember('way',$s->{to},$r)) {    
          if ($db->{relation}{$r}{'tags'}{'ref'}) {
            my @tmp = split(';',$db->{relation}{$r}{'tags'}{'ref'});
            push(@out,@tmp);
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

#check and convert times  
sub fixTime {
  my ($o) = @_;  
  if ($o =~ /^([0-9]?[0-9]):([0-9]?[0-9])$/) { 
    return sprintf("%02i:%02i",$1,$2); 
    }
  if ($o =~ /^\s*([0-9]+)\s*h\s*([0-9]{0,2})\s*$/) {
    return sprintf("%02i:%02i",$1,$2//0); 
    }
  if ($o =~ /^\s*([0-9]+\.?[0-9]*)\s*h\s*$/) {
    my $t = floor($1 * 60);
    my $min = $t % 60; my $hour = floor($t / 60);
    return sprintf("%02i:%02i",$hour,$min//0); 
    }
  if ($o =~ /^\s*([0-9]+)\s*min\s*$/) {
    my $min = $1 % 60; my $hour = floor($1 / 60);
    return sprintf("%02i:%02i",$hour,$min//0); 
    }
  }
  
sub getTime {
  my ($r,$num) = @_;
  $num //= 0;
  my @t = split(';',$db->{relation}{$r}{'tags'}{'time'});
  if($t[$num]) {
    return fixTime($t[$num]);
    } 
  }  

#check and convert distances  
sub fixDistance {
  my ($o,$distanceunit) = @_;
  $o =~ s/,/\./;
  $o .= ' km' if $o =~ /^[0-9\.]+$/;
  if ($o =~ /([0-9\.]+)\s*(mi|km|m)/) {
    $o = $1;
    my $unit = $2;
    if ($distanceunit eq '') {
      $o .= ' '.$unit;
      }
    else {
      if ($distanceunit eq 'm') {
        $o = $o * 1609.344 if($unit eq 'mi');
        $o = $o * 1000     if($unit eq 'km');
        }
      elsif ($distanceunit eq 'km') {
        $o = $o * 1.609344 if($unit eq 'mi');
        $o = $o / 1000     if($unit eq 'm');
        }
      elsif ($distanceunit eq 'mi') {
        $o = $o / 1.609344 if($unit eq 'km');
        $o = $o / 1609.344 if($unit eq 'm');
        }
      }
    }
  return $o;  
  }
  
sub getDistance {
  my ($r,$num) = @_;
  $num //= 0;
  my @t = split(';',$db->{relation}{$r}{'tags'}{'distance'});
  if($t[$num]) {
    return fixDistance($t[$num],$distanceunit);
    }
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

sub getColours {
  my ($w,$s) = @_;
  $s->{colourtext} = $db->{relation}{$w}{'tags'}{'colour:text'};
  $s->{colourback} = $db->{relation}{$w}{'tags'}{'colour:back'};
  $s->{colourarrow}= $db->{relation}{$w}{'tags'}{'colour:arrow'};
  
  if($s->{colourarrow} eq $s->{colourback}) {
    $s->{colourarrow} = '';
    }
  if($s->{colourtext} eq $s->{colourback}) {
    $s->{colourtext} = '';
    }
  if($s->{colourarrow} eq 'white' && $s->{colourback} eq '') {  
    $s->{colourback} = '#ffbbbb';
    }
  if($s->{colourtext} eq 'white' && $s->{colourback} eq '') {  
    $s->{colourback} = '#ffbbbb';
    }    
  }

  
sub cleanValues {
  my ($s) = @_;
  $s->{symbol} =~ s/[^a-z0-9_]//g;
  $s->{colourarrow} =~ s/[^#0-9a-zA-Z]//g;
  $s->{colourback}  =~ s/[^#0-9a-zA-Z]//g;
  $s->{colourtext}  =~ s/[^#0-9a-zA-Z]//g;
  }

  
sub encodeDespiteBR {
  my $s = shift @_;
  encode_entities_numeric($s);
  $s =~ s/&#x3C;br&#x3E;/<br>/g;
  return $s;
  }
  
sub encodeValues {  
  my ($s) = @_;
  foreach my $k (keys %$s) {
    if($k =~ /^destination/) {
      $s->{$k} = encode_entities_numeric($s->{$k});
      }
    }
  
  $s->{deststring} = encodeDespiteBR($s->{deststring}); 
  $s->{wayref}     = encodeDespiteBR($s->{wayref});  
  $s->{wayname}    = encodeDespiteBR($s->{wayname});  
  
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
        $s->{deststring} = DestinationString($s,$w,$i);
        $s->{wayname} = getNamedWay($s);
        $s->{waysymbol} = getSymboledWay($s);
        $s->{wayref}  = getRef($s, $i);
    
        $s->{duration} = getTime($w,$i);
        $s->{distance} = getDistance($w,$i);
        $s->{symbol} = getSymbol($w,$i);
        getColours($w,$s);
        cleanValues($s);
        
        push(@$d,dclone $s);
        delete($d->[-1]{fromarrow});
        
        encodeValues($s);
        
        if($format ne 'json') {
          my $o;
          $o = "<div class=\"entry\" style=\"";
          $o .= "color:".$s->{colourtext}.";" if $s->{colourtext}; 
          $o .= "background:".$s->{colourback}.";" if $s->{colourback}; 
          $o .= "\">";
          
        
          $o .= "<div class=\"compass\" style=\"";
          if ($s->{colourarrow} && $s->{colourback} ne $s->{colourarrow}) {
            $o .= "color:".$s->{colourarrow}.";" ; 
            }
          $o .= "\"  onClick=\"showObj('relation',".$db->{relation}{$w}{'id'}.")\">";
          if(defined $s->{dir} && $s->{dir} ne '') {  
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
          $o .= "<div class=\"dest\">".$s->{deststring};
          $o .= "<br><span>$s->{wayname}</span>" if $s->{wayname} && defined $q->param('namedroutes');
          $o .= "</div>";
          
          $o .= "<div class=\"dura\">$s->{duration}$s->{distance}</div>";
          $o .= "<div class=\"symbol\"><div class=\"$s->{symbol}\">&nbsp;</div></div>" if $s->{symbol};
          if ($db->{relation}{$w}{'tags'}{'osmc:symbol'}) {
            my $osmc = $db->{relation}{$w}{'tags'}{'osmc:symbol'};
            $o .= "<div class=\"symbol\"><img src=\"../../osmc/generate.pl?osmc=".$osmc."&opt=rectborder&size=32&out=svg\"></div>";
            }
          elsif($s->{waysymbol} && scalar @{$s->{waysymbol}}) {
            $o .= "<div class=\"symbol\">";
            foreach my $osmc (@{$s->{waysymbol}}) {
              $o .= "<img src=\"../../osmc/generate.pl?osmc=".$osmc."&opt=rectborder&size=32&out=svg\">";            
              }
            $o .= "</div>";  
            }
          $o .= "</div>";

          my $order = $s->{dir}.$i.$s->{deststring}.$w;
          if(defined $q->param('fromarrow')  && $s->{fromarrow}) {
            $entries->{$s->{fromdir}}{$order} = $o;
            }
          else {
            $entries->{'all'}{$order} = $o;
            }
          }
        }
      }
    }
    
#The 'direction' stuff    
  my $o = '';
  my $sign = $startnode;
  my $tags = join(' ',keys(%{$db->{node}{$sign}{'tags'}}));
  my $dir = 45;
  if ($tags =~ /direction_/ ) {
    foreach my $ke (qw(direction_east direction_northeast direction_north direction_northwest direction_west direction_southwest direction_south direction_southeast)) {
      my $key = $ke;
      $dir -= 45;
      next unless defined $db->{node}{$sign}{'tags'}{$key};
      
      my @dests = split(/;/,$db->{node}{$sign}{'tags'}{$key});      
      if (scalar @dests == 1) {
        @dests = split(/,/,$db->{node}{$sign}{'tags'}{$key});      
        }
      for my $i (0 .. scalar @dests -1) {
        my $s;
        $s->{dir} = $dir;
        $s->{deststring} = $dests[$i];
        cleanValues($s);
        $o = "<div class=\"entry\">";
        $o .= "<div class=\"compass\"";
        $o .= "onClick=\"showObj('node',".$sign.")\">";
        $o .= "<div style=\"transform: rotate($s->{dir}deg);\">&#x21e2;</div>";
        $o .= '</div>';  
        $o .= "<div class=\"dest\">$s->{deststring}</div>";
        if ($db->{node}{$sign}{'tags'}{'osmc:symbol'}) {
          my $osmc = $db->{node}{$sign}{'tags'}{'osmc:symbol'};
          $o .= "<div class=\"symbol\"><img src=\"../../osmc/generate.pl?osmc=".$osmc."&opt=rectborder&size=32&out=svg\"></div>";
          }        
        $o .= "</div>";
        push(@$d,dclone $s);
        $entries->{'all'}{$s->{dir}.$i.' '.$s->{deststring}} = $o;
        }
      }
    } 

 if ($tags =~ /destination/) {
    my $key = 'destination';
    my $dest = $db->{node}{$sign}{'tags'}{$key};
    my @dests;
    if (index($dest,'|') != -1) {
      $dest =~ s/;/<br>/g;
      @dests = split(/\|/,$dest);
      }
    else {  
      $dest =~ s/,/<br>/g;
      @dests = split(/;/,$dest);
      }
    for my $i (0 .. scalar @dests -1) {
      my $s;
      $s->{dir} = $dir;
      $s->{deststring} = $dests[$i];
      cleanValues($s);
      $o = "<div class=\"entry\">";
      $o .= "<div class=\"compass\"";
      $o .= "onClick=\"showObj('node',".$sign.")\">";
      $o .= '</div>';  
      $o .= "<div class=\"dest\">$s->{deststring}</div>";
      $o .= "</div>";
      push(@$d,dclone $s);
      $entries->{'all'}{$s->{dir}.$i.' '.$s->{deststring}} = $o;
      }
    
    }    
    
    
#Information added to sign  
  $o = '';
  if(defined $d && scalar @$d) {
    $sign = $d->[-1]{sign};
    $o .= "<span><a href=\"".$db->{node}{$sign}{'tags'}{'image'}."\">Image</a></span>" if $db->{node}{$sign}{'tags'}{'image'};
    $o .= "<span><a href=\"http://www.mapillary.com/map/im/".$db->{node}{$sign}{'tags'}{'mapillary'}."\">Mapillary</a></span>" if $db->{node}{$sign}{'tags'}{'mapillary'};
    $o .= "<span><a href=\"".$db->{node}{$sign}{'tags'}{'website'}."\">Website</a></span>" if $db->{node}{$sign}{'tags'}{'website'};
    $o .= "<span>Operator: $db->{node}{$sign}{'tags'}{'operator'}</span>" if $db->{node}{$sign}{'tags'}{'operator'};
    
    if($o) {
      $o = "<div class=\"details\">".$o."</div>";
      }
    $entries->{'all'}{'Z'.$sign} = $o;
    }

  }

 
readData(scalar $q->param('nodeid')) && parseData(scalar $q->param('nodeid'));

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

$out->{data} = $d;
$out->{html} = $o unless $format eq 'json';
$out->{lat} = $db->{node}{$q->param('nodeid')}{lat};
$out->{lon} = $db->{node}{$q->param('nodeid')}{lon};
$out->{node} = $q->param('nodeid');

print  encode_json($out);

