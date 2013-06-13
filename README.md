osm2garmin
==========

This project provides a script for converting OpenStreetMap data to Garmin's img-format. 

I do not intend to provide a fully functional out-of-the-box experience. It would be a shame that the wide variety of geo-information provided by OpenStreetMap is limited by means of simple filter script. The users of such a script would never get a glimpse of the possibilities they have with the data.
This project is intended to provide a starting point for your personal OSM to Garmin conversion project.

Nonetheless, I would be happy for feedback, contributions and bug-reports within the project site https://github.com/Aikhjarto/osm2garmin

Dependencies
============

This script has to type of dependencies. Firstly, it needs auxiliary scripts and programs. Secondly, it needs auxiliary (beside osm) data. Great thanks to the people who developed those.
See the parameter section in the beginning of make.sh for examples of how to set the path's to auxiliary files.


Auxiliary programs
------------------
This script makes use of well developed applications for processing, filtering and modifying OSM data. 

* splitter (splits up huge input files in manageable parts) from http://www.mkgmap.org.uk/splitter/
* gmt (combines sub-maps to a single file) from http://www.gmaptool.eu/
* mkgmap (converts OSM data to Garmin's file format) from http://www.mkgmap.org.uk/snapshots/
* osmfilter (used for boundary calculation; needed for address searches) from http://wiki.openstreetmap.org/wiki/Osmfilter
* osmconvert (converter between nearly all important OSM data formats) from http://wiki.openstreetmap.org/wiki/Osmconvert
* osmosis (used for cropping data) http://wiki.openstreetmap.org/wiki/Osmosis


Auxiliary data
--------------
MKGMAP will require style files. These files hold rules how OSM object IDs should be translated to Garmin object IDs. Possible sources include:

* https://github.com/berndw1960/aiostyles
* http://wiki.openstreetmap.org/wiki/User:Computerteddy
* https://github.com/miramikes/garmin_hiking_map
* https://github.com/Helius/osm2garmin

If you want to modify the styles yourself, you can find an explanation of the syntac here: http://wiki.openstreetmap.org/wiki/Mkgmap/help/style_rules#Element_type_definition

TYP files define the look (shape, color) how items (streets, buildings, POI, landscape,...) are displayed on your Garmin device.
There are serveral sources like

* http://www.avdweb.nl/gps/garmin/improved-garmin-map-view-with-typ-files.html
* http://www.cferrero.net/maps/guide_to_TYPs.html
* http://pinns.co.uk/osm/typwiz3.html
* http://wiki.openstreetmap.org/wiki/User:Computerteddy

There are also several editor for TYP-files our there:

* http://ati.land.cz/gps/typedit/editor.cgi
* http://pinns.co.uk/osm/typwiz3.html

POLY files define a polygon around a specific section on a map. This can be used to crop e.g. the map of Europe to contain only the Alps. As the the whole world (even not whole continents) probably won't fit on your Garmin device you'll want to crop the maps. The structure of *.poly files is explained in 

* https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format

I recommend an OSM editor like http://josm.openstreetmap.de/ to edit the file.

Usage
=====

1) Adjust the parameters in the first section of make.sh to your system and your needs.

2) Issue a ./make.sh

A more sophisticated start command can be "./make.sh | tee osm2garmin.log" from inside a screen.

Note on Hardware Demands
========================

Keep in mind that processing large portions (several countries or even a whole component) of OpenStreeMap data can heavily stress your system. Your free RAM should be larger than your source *.pdf and your temporary folder should be able to hold about 5 times the size of the source *.pbf file. Once you meet these requirements, you should also consider that it will most probably take server hours of CPU time to crop, filter and convert the OSM data.

Disclaimer
==========

The files in this project are distributed WITHOUT ANY WARRANTY and  WITHOUT ANY IMPLIED WARRANTY.
