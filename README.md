osm2garmin
==========

provides a script for converting openstreetmap data to garmin's img-format

Dependencies
============

There are several dependencies. See the parameter section in the beginning of make.sh for explanations.

Usage
=====

1) Adjust the parameters in the first section of make.sh to your system and your needs.

2) Issue a ./make.sh

A more sophisticated start command can be "./make.sh | tee osm2garmin.log" from inside a screen.

Note on Hardware Demands
========================

Keep in mind that processing large portions (several countries or even a whole component) of OpenStreeMap data can heavily stress your system. Your free RAM should be larger than your source *.pdf and your temporary folder should be able to hold about 5 times the size of the source *.pbf file. Once you meet these requirements, you should also considere that it will most probably take server hours of CPU time to crop, filter and convert the OSM data.

