#!/bin/bash
##################### system setting section ##########################
# You'll have to adjust the variables to match your system.

# directories where auxiliar files can be found (without trailing slashes)
# AIOSTYLES: https://github.com/berndw1960/aiostyles
# 	If you want to use alternative styles you'll probably have to adjust the script.
# 	Possibly alternatives include: http://wiki.openstreetmap.org/wiki/User:Computerteddy
# TYP files: serveral sources like 
# 	http://www.avdweb.nl/gps/garmin/improved-garmin-map-view-with-typ-files.html
#	http://www.cferrero.net/maps/guide_to_TYPs.html
# 	http://pinns.co.uk/osm/typwiz3.html
#	http://wiki.openstreetmap.org/wiki/User:Computerteddy
# APPS: see hints in parameters block below
# TEMP_DIR: any directory that can hold several gigabytes of temporary data
AIOSTYLES_DIR=$HOME"/osm/aiostyles"
TYP_DIR=$HOME"/osm/TYP"
APPS_DIR=$HOME"/osm/apps"
POLY_DIR=$HOME"/osm/poly"

# system settings
TEMP_DIR=/scratch/osmtemp
JAVA_RAM="9G" # max RAM memory available to java VM

NICE_VAL="9" # values higher than 0 will reduce processor priority
SPLITTER_MAX_NODES=1600000 # (default: 1600000) maximum number of nodes per file (splitter will split the whole map in according to this number)

# jar files and binaries locations
# splitter (splits up huge input files in manageable parts) from http://www.mkgmap.org.uk/splitter/
# gmt (combines submaps to a single file) from http://www.gmaptool.eu/
# mkgmap (converts OSM data to garmin's file format) from http://www.mkgmap.org.uk/snapshots/
# osmfilter (used for boundary calculation; needed for address searches) from http://wiki.openstreetmap.org/wiki/Osmfilter
# osmconvert (converter between nearly all important OSM data formats) from http://wiki.openstreetmap.org/wiki/Osmconvert
# osmosis (used for cropping data) http://wiki.openstreetmap.org/wiki/Osmosis
# osbsql2osm (used for converting openstreetbugs)  http://tuxcode.org/john/osbsql2osm/osbsql2osm-latest.tar.gz 
SPLITTER_JAR="$APPS_DIR/splitter/splitter-r389/splitter.jar"
#MKGMAP_JAR="$APPS_DIR/mkgmap/mkgmap-r2815/mkgmap.jar"
MKGMAP_JAR="$APPS_DIR/mkgmap/mkgmap-r3280/mkgmap.jar"
OSMFILTER_BIN="$APPS_DIR/osmfilter/osmfilter-1.2S/osmfilter"
OSMCONVERT_BIN="$APPS_DIR/osmconvert/osmconvert-0.7T/osmconvert"
GMT_BIN="$APPS_DIR/lgmt/lgmt08186/gmt"
JAVA_BIN="/usr/bin/java"
OSMOSIS_BIN="$APPS_DIR/osmosis/osmosis-0.43.1/bin/osmosis"
#OSBSQL_BIN="$APPS_DIR/osbsql2osm/osbsql2osm-0.3.1/src/osbsql2osm" # if empty string, OSB will not be processed (but script will create useable maps)


# output folder (use "." for current folder)
#GMAPOUT_DIR="/pub/daten/transfer/OSM/test2815"
GMAPOUT_DIR="/pub/daten/transfer/OSM/test3072_DACH"

################ internal settings ##################################
# If nothing goes wrong, leave the defaults. Of course you can play around at your own risk.

# debug flags (set to empty string "" for disabling debug output)
DEBUG_MKGMAP="--verbose --list-styles --check-styles"
DEBUG_OSMCONVERT="--verbose --statistics"
DEBUG_OSMFILTER="--verbose"
DEBUG_OSMOSIS="-v"
DEBUG_GMT="-v"
DEBUG_MD5="" # "--quiet" disables output of md5sum