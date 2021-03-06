#!/bin/bash
######################### map settings ######################################
# Which map should be build?
# HINT: You should state a polygon even if you don't want to reduce the data in the input file. The polygon will also be used to crop openstreetbugs data!

# Maps are downloaded from Geofabrik the variable must be set to match either
# http://download.geofabrik.de/$GEOFABRIK_CONTINENT_NAME/$GEOFABRIK_MAP_NAME.osm.pbf
# or, if $GEOFABRIK_CONTINENT_NAME is unset,
# http://download.geofabrik.de/$GEOFABRIK_MAP_NAME.osm.pbf

# Austria
#GEOFABRIK_CONTINENT_NAME="europe"
#GEOFABRIK_MAP_NAME="austria"
#COUNTRY_NAME="Austria" # This name will be used as country on your device
#COUNTRY_ABBR="AUT" #three digit country abbreviation, see resources/LocatorConfig.xml from mkgmap for examples
#MAP_GRP="8324" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="AT" # iso abbreviation of country
#POLY="UpperAustria" # part of Austria
#POLY="Austria_Vicinity" # poly just to reduce data from openstreetbugs

# Austria
#GEOFABRIK_CONTINENT_NAME="europe"
##GEOFABRIK_MAP_NAME="spain"
#COUNTRY_NAME="Spain" # This name will be used as country on your device
#COUNTRY_ABBR="ESP" #three digit country abbreviation, see resources/LocatorConfig.xml from mkgmap for examples
#MAP_GRP="8324" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="ES" # iso abbreviation of country


# Cut out a piece of Europe
GEOFABRIK_MAP_NAME="europe"
COUNTRY_NAME="AustriaVicinity"
COUNTRY_ABBR="EU"
MAP_GRP="6800"
ISO="EU"
POLY="Austria_Vicinity"

# Cut out a piece of Europe
#GEOFABRIK_MAP_NAME="europe"
#COUNTRY_NAME="DACH"
#COUNTRY_ABBR="EU"
#MAP_GRP="6800"
#ISO="EU"
#POLY="DACH"

# Cut out a piece of Europe
#GEOFABRIK_MAP_NAME="europe"
#COUNTRY_NAME="CHAI"
#COUNTRY_ABBR="EU"
#MAP_GRP="6800"
#ISO="EU"
#POLY="CHAI"

# Germany
#GEOFABRIK_CONTINENT_NAME="europe"
#GEOFABRIK_MAP_NAME="germany"
#COUNTRY_NAME="Germany"
#COUNTRY_ABBR="DEU"
#MAP_GRP="7024" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="DE" # iso abbreviation of country
#POLY=Germany_Berlin

# Paris
#GEOFABRIK_CONTINENT_NAME="europe"
#GEOFABRIK_MAP_NAME="france"
#COUNTRY_NAME="France"
#COUNTRY_ABBR="FRA"
#MAP_GRP="7024" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="FR" # iso abbreviation of country
#POLY=France_Paris

# England
#GEOFABRIK_CONTINENT_NAME="europe"
#GEOFABRIK_MAP_NAME="great-britain"
#COUNTRY_NAME="GreatBritain"
#COUNTRY_ABBR="GBR"
#MAP_GRP="7024" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="GB"



# specify additional output formats like tdb (for viewing on an PC) or nsis for the Nullsoft Scriptable Installer System to later create a Mapsource installer
MKGMAP_OPTION_TDBFILE="--tdbfile --nsis"
