osm2garmin
==========

provides a script for converting openstreetmap data to garmin's img-format

Dependencies
============

This script has to type of dependencies. Firstly, it needs auxiliary scripts and programs. Secondly, it needs auxiliary (beside osm) data. Great thanks to the people who developed those.

Auxiliary programs
------------------
This script makes use of well developed applications for processing, filtering and modifing OSM data. 

* splitter (splits up huge input files in manageable parts) from http://www.mkgmap.org.uk/splitter/
* gmt (combines submaps to a single file) from http://www.gmaptool.eu/
* mkgmap (converts OSM data to garmin's file format) from http://www.mkgmap.org.uk/snapshots/
* osmfilter (used for boundary calculation; needed for address searches) from http://wiki.openstreetmap.org/wiki/Osmfilter
* osmconvert (converter between nearly all important OSM data formats) from http://wiki.openstreetmap.org/wiki/Osmconvert
* osmosis (used for cropping data) http://wiki.openstreetmap.org/wiki/Osmosis


Auxiliary data
--------------
MKGMAP will require style files. These files hold rules how OSM object IDs should be translated to garmin object IDs. Possible sources include:

* https://github.com/berndw1960/aiostyles
* http://wiki.openstreetmap.org/wiki/User:Computerteddy


TYP files define the look (shape, color) how items (streets, buildings, POI, landscape,...) are displayed on your garmin device.
There are serveral sources like

* http://www.avdweb.nl/gps/garmin/improved-garmin-map-view-with-typ-files.html
* http://www.cferrero.net/maps/guide_to_TYPs.html
* http://pinns.co.uk/osm/typwiz3.html
* http://wiki.openstreetmap.org/wiki/User:Computerteddy

There are also several editor for TYP-files our there:
* http://ati.land.cz/gps/typedit/editor.cgi
* http://pinns.co.uk/osm/typwiz3.html

See the parameter section in the beginning of make.sh for explanations.

Usage
=====

1) Adjust the parameters in the first section of make.sh to your system and your needs.

2) Issue a ./make.sh

A more sophisticated start command can be "./make.sh | tee osm2garmin.log" from inside a screen.

Note on Hardware Demands
========================

Keep in mind that processing large portions (several countries or even a whole component) of OpenStreeMap data can heavily stress your system. Your free RAM should be larger than your source *.pdf and your temporary folder should be able to hold about 5 times the size of the source *.pbf file. Once you meet these requirements, you should also considere that it will most probably take server hours of CPU time to crop, filter and convert the OSM data.

Disclaimer
==========

The files in this project are distributed WITHOUT ANY WARRANTY and  WITHOUT ANY IMPLIED WARRANTY.