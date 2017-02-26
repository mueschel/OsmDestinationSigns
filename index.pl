#!/usr/bin/perl 
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 

print "Content-Type: text/html; charset=utf-8\r\n\r\n";


print <<HDOC;
<!DOCTYPE html>
<html lang="en">
<head>
 <title>OSM Destination Signs</title>
 <link rel="stylesheet" type="text/css" href="../destinationsign/style.css">
 <script src="../destinationsign/scripts.js" type="text/javascript"></script>
 <meta  charset="UTF-8"/>
 <link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet/v0.7.7/leaflet.css" />
 <script src="http://cdn.leafletjs.com/leaflet/v0.7.7/leaflet.js"></script>
 <base target="_blank">
</head>
<body>
<h1>Destination Signs</h1>
<div id="header">
<p>Please enter an Id of an intersection node or a guidepost.
<br>Click on the arrow to get to the corresponding OSM object.
<br>Here is <a href="http://overpass-turbo.eu/s/n1p">a overpass query</a> with interesting nodes - blue dots have relations.
<br>The code is available on <a href="https://github.com/mueschel/OsmDestinationSigns">Github</a>.
<div class="config">
<h3>Configuration</h3>
<form action="" onsubmit="getsign(0); return false;">
  <label title="Id of an intersection or guidepost node">Node Id: 
    <input type="text" name="nodeid"></label> 
</form>
<!--<br><label title="Select output styles">Styles <select name="style" multiple="multiple"><option>compass<option>image</select></label>-->
<form action="" onsubmit="getsign(0); return false;">
  <label title="Some Examples">Examples: 
    <select name="nodeid" onChange="getsign(1);">
      <option value="3731895314">3731895314 - bi-lingual
      <option value="1938162531">1938162531
      <option value="4313151794">4313151794 - node as 'to'
      <option value="3719751885">3719751885 - node as 'to', in middle of way
      <option value="3721184276">3721184276 - ref from relation of ways
      <option value="2399730302">2399730302 - with symbol and colour
      <option value="3033139388">3033139388 - bicycle with colour but missing intersection
      <option value="2400684815">2400684815 - list of destinations and times
      <option value="3669231450">3669231450 - coloured arrows
      <option value="3740138783">3740138783 - error - entries from several signs
      <option value="3908107497">3908107497 - an awful lot of entries
      <option value="3700303286">3700303286 - with image and operator
      <option value="3906804369">3906804369 - with Mapillary
      <option value="1670509673">1670509673 - from way, no intersection
      <option value="3314100014">3314100014 - at a motorway
    </select>
</form>
</div>
</div>
</div>
<div id="map"></div>
<hr style="margin-bottom:50px;margin-top:10px;clear:both;">
<div id="container">&nbsp;</div>


</body>
<script type="text/javascript">
var map = L.map('map').setView([0, 0], 1);
L.tileLayer('http://tile.openstreetmap.org/{z}/{x}/{y}.png',
	{ attribution: 'Map &copy; <a href="https://www.openstreetmap.org">OpenStreetMap</a>' }).addTo(map);
var marker = L.marker(map.getCenter(), { draggable: false }).addTo(map);
var polyline = L.polyline([[0,0]]).addTo(map);
</script>

</html>
HDOC
