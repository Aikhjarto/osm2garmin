#!/bin/bash
######################### map settings ######################################
# Which map should be build?
# HINT: You should state a polygon even if you don't want to reduce the data in the input file. The polygon will also be used to crop openstreetbugs data!

# Maps are downloaded from Geofabrik the variable must be set to match either
# http://download.geofabrik.de/$GEOFABRIK_CONTINENT_NAME/$GEOFABRIK_MAP_NAME.osm.pbf
# or, if $GEOFABRIK_CONTINENT_NAME is unset,
# http://download.geofabrik.de/$GEOFABRIK_MAP_NAME.osm.pbf

# Austria
GEOFABRIK_CONTINENT_NAME="europe"
GEOFABRIK_MAP_NAME="austria"
COUNTRY_NAME="Austria" # This name will be used as country on the navi
COUNTRY_ABBR="AUT" #three digit country abbreviatin, see resources/LocatorConfig.xml from mkgmap for examples
MAP_GRP="8324" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
ISO="AT" # iso abbreviation of country
#POLY="UpperAustria" # part of austria
#POLY="Austria_Vicinity" # poly just to reduce data from openstreetbugs

# Cut out a piece of Europe
#GEOFABRIK_MAP_NAME="europe-latest"
#COUNTRY_NAME="AustriaVicinity"
#COUNTRY_ABBR="EU"
#MAP_GRP="6800"
#ISO="EU"
#POLY="Austria_Vicinity"

# Germany
#GEOFABRIK_CONTINENT_NAME="europe"
#GEOFABRIK_MAP_NAME="germany"
#COUNTRY_NAME="Germany"
#COUNTRY_ABBR="DEU"
#MAP_GRP="7024" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="DE" # iso abbreviation of country
#POLY=Germany_Berlin


MKGMAP_OPTION_TDBFILE="--tdbfile"
