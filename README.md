OSM Destination Signs
=====================

This is a tool to show information stored in OSM in the form of destination_sign relations or destination tags on ways.

Supported tagging features:
---

* destination tags, including destination:lang:XX and destination:symbol
* distance and time
* colour:text, colour:back, colour:arrow
* direction of route from geometry of ways and nodes
* additional sources from guidepost node: image, mapillary, website, operator
* ref numbers of ways are taken from destination:ref on relations or ref on ways or ref on hiking routes the way belongs to

Usage
---
All code is included in the code directory - a Perl script generating the signs, a JavaScript file for control on the users' side and a style file.

The example directory contains a Leaflet map page with markers for interesting points. It needs an additional library to load data from Overpass (leaflet-layerjson.js) which can be found here: https://github.com/stefanocudini/leaflet-layerJSON and leaflet-permalink.js which can be found here: https://github.com/shramov/leaflet-plugins/ 

License
---
This tool is available under cc-by-sa 3.0 https://creativecommons.org/licenses/by-sa/3.0/ The code is distributed as-is without any guarantee whatsoever.
