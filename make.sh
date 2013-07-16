#!/bin/bash
#This script is capable of downloading an OSM file and convert it to Garmin's img format. This can be used directly from an SD-Card in a Garmin device.
#
# If the script is interrupted (most probaly due to insufficient disc space or ram) it won't recalculate everything from scratch but will reuse all the non-erronous maps.
#
# Thomas Wagner (wagner-thomas@gmx.at) Sept. 2012 - May 2013
# 
# This script comes with no warranty.
#
### Known limitations
# The reduce the computational demands of mkgmap, splitter is used to subdivide big maps into smaller ones that does not exeed a certain amound of nodes. Each of these smaller maps gets an individual, ascending number assigned. With the mkgmap argument "mapname" the start index can be shifted while generating a single map from the indivduals.  If you want to combine (and this script does this at the very end) several maps produced my mkgmap, you'll have to ensure by a propper start index that the map numbers will be unique in the final map. In this script, the difference of the start indices is 1000. This means you cannot reliable merge maps that have been split to 1000 or more maps. If you run into that problem, you can either adjust the start indicess manually or increase the maximum number of nodes of a submap.
# 
### Caution: memory and disc consumtion
# As it is true for any script that handles huges osm datasets, this script will require lots of memory and harddisk space.
# If you want to process a pbf file, you should consider the file size as requires memory and about 5 times the file size as available memory. (Note, that pbf is a heavily compressed filetype).

# TODO: properly eval exit status of mkgmap and splitter (not mix up with exit status of java binary)
# TODO: properly eval exit status of osmosis (is a java application invoced via bash script)
# Known minor Bug: there is a rm-warning on puring already empty directories
# Known Bug: if osmosis is interrupted (out of memory, hdd full, abort by CTRL-C) it leaves a near empty---but existing---pbf file. Uppon a consecutive execution of the script, osmosis isn't called again to finished it's job.

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
AIOSTYLES_DIR=$HOME"/osm/aiostyles/aiostyles"
TYP_DIR=$HOME"/osm/TYP"
APPS_DIR=$HOME"/osm/apps"
POLY_DIR=$HOME"/osm/poly"

# system settings
#TEMP_DIR="$HOME/noBackup/osmtemp"
TEMP_DIR=/pub/tmp/osmtemp
XmxRAM="-Xmx2048M" # max ram available to java for splitter and mkgmap
if [ ! -d "$TEMP_DIR/osmosis" ]; then
	mkdir -p "$TEMP_DIR/osmosis";
fi
export JAVACMD_OPTIONS="-Xmx3G -server -Djava.io.tmpdir=$TEMP_DIR/osmosis" # java options for osmosis
NICE_VAL="9" # values higher than 0 will reduce processor priority
SPLITTER_MAX_NODES=1000000 # maximum number of nodes per file (splitter will split the whole map in according to this number)

# jar files and binaries locations
# splitter (splits up huge input files in manageable parts) from http://www.mkgmap.org.uk/splitter/
# gmt (combines submaps to a single file) from http://www.gmaptool.eu/
# mkgmap (converts OSM data to garmin's file format) from http://www.mkgmap.org.uk/snapshots/
# osmfilter (used for boundary calculation; needed for address searches) from http://wiki.openstreetmap.org/wiki/Osmfilter
# osmconvert (converter between nearly all important OSM data formats) from http://wiki.openstreetmap.org/wiki/Osmconvert
# osmosis (used for cropping data) http://wiki.openstreetmap.org/wiki/Osmosis
# osbsql2osm (used for converting openstreetbugs)  http://tuxcode.org/john/osbsql2osm/osbsql2osm-latest.tar.gz 
SPLITTER_JAR="$APPS_DIR/splitter/splitter-r306/splitter.jar"
MKGMAP_JAR="$APPS_DIR/mkgmap/mkgmap-r2656/mkgmap.jar"
OSMFILTER_BIN="$APPS_DIR/osmfilter/osmfilter-1.2S/osmfilter"
OSMCONVERT_BIN="$APPS_DIR/osmconvert/osmconvert-0.7T/osmconvert"
GMT_BIN="$APPS_DIR/lgmt/lgmt08067/gmt"
JAVA_BIN="/usr/bin/java"
OSMOSIS_BIN="$APPS_DIR/osmosis/osmosis-0.43.1/bin/osmosis"
OSBSQL_BIN="$APPS_DIR/osbsql2osm/osbsql2osm-0.3.1/src/osbsql2osm"

# output folder (use "." for current folder)
GMAPOUT_DIR="."

######################### map settings ######################################
# Which map should be build?

# Austria
GEOFABRIK_CONTINENT_NAME="europe"
GEOFABRIK_MAP_NAME="austria"
COUNTRY_NAME="Austria"
COUNTRY_ABBR="AT"
MAP_GRP="8324" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
ISO="AT" # iso abbreviation of country
#POLY="UpperAustria"

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
#COUNTRY_ABBR="DE"
#MAP_GRP="7024" # first 4 digits garmin uses to identify a map (default: 6324, so use another number)
#ISO="DE" # iso abbreviation of country

################ internal settings ##################################
# If nothing goes wrong, leave the defaults. Of course you can play around at your own risk.

# debug flags (set to empty string "" for disabling debug output)
DEBUG_MKMAP="--verbose --list-styles"
DEBUG_OSMCONVERT="--verbose --statistics"
DEBUG_OSMFILTER="--verbose"
DEBUG_OSMOSIS="-v"
DEBUG_GMT="-v"

## parition the temporary directory
# temporary folders for separate maps
BASEMAP_DIR="$TEMP_DIR/gbasemap"
PKW_DIR="$TEMP_DIR/gpkw"
BIKE_DIR="$TEMP_DIR/gbike"
ADDR_DIR="$TEMP_DIR/gaddr"
FIXME_DIR="$TEMP_DIR/gfixme"
BOUNDARY_DIR="$TEMP_DIR/gboundary"
MAXSPEED_DIR="$TEMP_DIR/gmaxspeed"
BUGS_DIR="$TEMP_DIR/gosb"

# temporary folders for download splitter and bounds
OSM_SRC_DIR="$TEMP_DIR/osmcopy" # downloaded files go here
OSM_SRC_FILE_PBF="$OSM_SRC_DIR/map.pbf"
OSM_SRC_FILE_O5M="$OSM_SRC_DIR/map.o5m"
SPLITTER_DIR="$TEMP_DIR/splitted"
BOUNDS_DIR="$TEMP_DIR/bounds"
BOUNDS_FILE="$TEMP_DIR/map_boundaries"
BOUNDS_STAT_FILE="$TEMP_DIR/bounds_finished"
OSMCONVERT_WORKDIR="$TEMP_DIR/osmconvert_tmp"

#
KEEP_TMP_FILE="" # if this string is empty, the temporary files will be kept
ENABLE_PRECISE_CROP="y" # if string is not empty, "complete-ways" well be activated
ENABLE_BOUNDS="y" # needed for address search capabilty

# command to import split files in mkgmap
# Caution: with -c option in an un-preprocessed template.args file a lot of command line settings can be overwritten
# e.g. map-id will be overwritten. So gmt cannot combine the maps.
#MKGMAP_FILE_IMPORT="-c $SPLITTER_DIR/template.args"
MKGMAP_FILE_IMPORT="$SPLITTER_DIR/*.pbf"

##Hints for mkgmap:
# somewhat between mkgmap 2338 and 2386 the option --no-poi-address became invalid
# as of Dec 17th 2012 splitter r263 gots --keep-complete=true greatly enhances accuray of splitter with only slightly increased CPU and memory usage. (this option will possibly become default in future)
# as of Dec 21th 2012 the o5m format is supported for reading (automatically) and writing (with --output=o5m) with splitter and mkgmap; o5m files are larger than pbf but faster to read (especially splitter will run significantly faster)
# as of Dec 27th 2012 --remove-short-arcs is no longer needed by mkgmap (was previosly used to handle map errors but caused some routing problems)
# as of Jan 10th 2013 --createboundsfile for correct address assignment is replaced by the BoundaryPreprocessor
# as of r 2464 the documentation comes along with the sourcecode in  /trunk/docs
# as of Mar 2013 Java 1.7 should be used
# as of May 10th 2013 r2596 the legacy format for preprocessed bounds is dropped


############################ the work starts here ###################

### sanity checks
# check for executables and java files
if [ ! -x $JAVA_BIN ]; then
	echo "ERROR: JAVA binary is no executable file"
	exit
fi
if [ ! -f $SPLITTER_JAR ]; then
	echo "ERROR: $SPLITTER_JAR is missing"
	exit
fi
if [ ! -f $MKGMAP_JAR ]; then
	echo "ERROR: $MKGMAP_JAR is missing"
	exit
fi
if [ ! -x $OSMFILTER_BIN ]; then
	echo "ERROR: $OSMFILTER_BIN is no executable file"
	exit
fi
if [ ! -x $OSMCONVERT_BIN ]; then
	echo "ERROR: $OSMCONVERT_BIN is no executable file"
	exit
fi
if [ ! -x $GMT_START ]; then
	echo "ERROR: $GMT_BIN is no executable file"
	exit
fi
if [ ! -x $OSMOSIS_BIN ]; then
	echo "ERROR: $OSMOSIS_BIN is no executable file"
	exit
fi
if [ ! -x $OSBSQL_BIN ]; then
	echo "WARNING: $OSBSQL_BIN not found! Bugs will not be shown on map!"
	OSBSQL_START=""
else
	OSBSQL_START="nice -n $NICE_VAL $OSBSQL_BIN"
fi

# set nice values
OSMFILTER_START="nice -n $NICE_VAL $OSMFILTER_BIN"
OSMCONVERT_START="nice -n $NICE_VAL $OSMCONVERT_BIN"
GMT_START="nice -n $NICE_VAL $GMT_BIN"
JAVA_START="nice -n $NICE_VAL $JAVA_BIN"
OSMOSIS_START="nice -n $NICE_VAL $OSMOSIS_BIN"

# check for auxiliary files
if [ ! -d $AIOSTYLES_DIR ]; then
	echo "style directory $AIOSTYLES_DIR not found";
	exit
fi

### Download maps if not already present (just convert is pbf is present)

echo "----------------->Preprocess map"
if [ ! -s "$OSM_SRC_FILE_O5M" ] || [ ! -s "$OSM_SRC_FILE_PBF" ]; then 
# TODO: also check if newer version is available on server
	if [ ! -d "$OSM_SRC_DIR" ]; then
	 	mkdir -p "$OSM_SRC_DIR"
	 	if [ $? -ne 0 ]; then
	 		echo "ERROR creating $OSM_SRC_DIR";
			exit
		fi
	fi

	if [ ! -s "$OSM_SRC_FILE_PBF" ]; then
		# geofabrik's URL is differnt between countries and continents
		if [ "$GEOFABRIK_CONTINENT_NAME" == "" ]; then
			DOWNLOAD_URL="http://download.geofabrik.de/openstreetmap/$GEOFABRIK_MAP_NAME.osm.pbf"
		else
			DOWNLOAD_URL="http://download.geofabrik.de/openstreetmap/$GEOFABRIK_CONTINENT_NAME/$GEOFABRIK_MAP_NAME.osm.pbf"
		fi
		
		echo "-------------> Download map started @"`date`
		if [ ! -d "$OSMCONVERT_WORKDIR" ]; then
			mkdir "$OSMCONVERT_WORKDIR"
			if [ $? -ne 0 ]; then
				echo "ERROR creating $OSMCONVERT_WORKDIR"
				exit
			fi
		else
			rm "$OSMCONVERT_WORKDIR"/*
		fi
		# TODO: download and convert in parallel (should at least work if no cropping polygon is applied
		if [ "$POLY" == "" ]; then
			# download and convert in parallel does not work well. When input buffer of osmconvert is full, wget is stalled until osmconvert clears an procresses its buffer. This likely results in wget timeouts.
#			echo "download PBF and convert to o5m in parallel"
#			wget -O - $DOWNLOAD_URL  | \
#				tee $OSM_SRC_FILE_PBF | \
#				$OSMCONVERT_START - $DEBUG_OSMCONVERT -t=$OSMCONVERT_WORKDIR -o=$OSM_SRC_FILE_O5M
#			OSM_WGET_TMP_FILE=$TEMP_DIR/osmcopy/wget_tmp.osm.pbf
			OSM_WGET_TMP_FILE="$OSM_SRC_FILE_PBF";
			if [ ! -f "$OSM_WGET_TMP_FILE" ]; then
				wget -O "$OSM_WGET_TMP_FILE" $DOWNLOAD_URL 
				if [ $? -ne 0 ]; then
					echo "ERROR: Download of $DOWNLOAD_URL to $OSM_WGET_TMP_FILE failed"
					exit
				fi
			fi
			
		else
			echo "------>download PBF and convert with a cropping polygon"
			# complete-ways cannot be used then reading from incomplete file, so file is downloaded first. Then the polygon is applied and in parallel the file is converted to o5m
			#wget -O - $DOWNLOAD_URL  | \
			#	tee >($OSMCONVERT_START - $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS -o=$OSM_SRC_FILE_PBF) | \
			#	$OSMCONVERT_START - $DEBUG_OSMCONVERT $OSM_CONVERT_CUT_OPTIONS -o=$OSM_SRC_FILE_O5M		
			OSM_WGET_TMP_FILE=$TEMP_DIR/osmcopy/wget_tmp.osm.pbf

			if [ ! -f "$OSM_WGET_TMP_FILE" ]; then
				wget -O "$OSM_WGET_TMP_FILE" $DOWNLOAD_URL 
				if [ $? -ne 0 ]; then
					echo "ERROR: Download of $DOWNLOAD_URL to $OSM_WGET_TMP_FILE failed"
					exit
				fi
			fi
			# processing polygon on pdf and converting in parallel with two osmconvert instances is not reliable in current version (keeps crashing).
#			$OSMCONVERT_START $OSM_WGET_TMP_FILE $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS --out-pbf | \
# 				tee $OSM_SRC_FILE_PBF | \ 
#				$OSMCONVERT_START - $DEBUG_OSMCONVERT -o=$OSM_SRC_FILE_O5M

			echo "--->appling cropping polygon to downloaded file @"`date`
			# either osmosis or osmconvert can be used to crop the map along a polygon. Osmconvert is faster than osmosis. However, osmconvert is not stable right now with whole continents.
			if [ ! -d "$TEMP_DIR"/osmosis ]; then
				mkdir "$TEMP_DIR"/osmosis
				if [ $? -ne 0 ]; then
					echo "ERROR creating $TEMP_DIR/osmosis"
					exit
				fi
			else
				rm "$TEMP_DIR"/osmosis/*
			fi		
			
			if [ ! -z $ENABLE_PRECISE_CROP ]; then
				echo "->Precise cropping enabled!"
				OSMOSIS_POLY_OPTIONS="completeWays=yes completeRelations=yes"
			else
				echo "->Precise cropping disabled!"
				OSMOSIS_POLY_OPTONS=""
			fi
			
 			$OSMOSIS_START $DEBUG_OSMOSIS --read-pbf-fast file="$OSM_WGET_TMP_FILE" \
 				--bounding-polygon file="$POLY_DIR/$POLY.poly" $OSMOSIS_POLY_OPTIONS \
 				--write-pbf file="$OSM_SRC_FILE_PBF"
#			OSMCONVERT_CUT_OPTIONS="-B=$POLY_DIR/$POLY.poly --complete-ways --complex-ways"
#			$OSMCONVERT_START $OSM_WGET_TMP_FILE $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS -t=$OSMCONVERT_WORKDIR/tmp -o=$OSM_SRC_FILE_PBF
			#TODO: replace osmosis with https://github.com/MaZderMind/osm-history-splitter which should be faster
			
			# abort if error (can crash frequently on low powered machines and huge input maps (e.g. a whole continent)
			if [ $? -ne 0 ]; then
				echo "ERROR while appling polygon file! @"`date`
				# remove partially created file (most of the time, just an empty file is created, but this interferes with the -nt tests in this script)
				echo "Removing $OSM_SRC_FILE_PBF"
				rm "$OSM_SRC_FILE_PBF"
				exit
			else
				echo "Finshed cropping @"`date`
				if [ "$KEEP_TMP_FILE" != "" ]; then
					# remove raw (uncutted, thus huge) file
					rm "$OSM_WGET_TMP_FILE"
				fi
			fi

		fi

	fi
else
	echo "-------->Source map already present!"
fi

### generate boundary files (if not existing or older than pbf file)
# TODO: o5M file is only needed for creating boundaries. Osmfilter, which extracts the boundaries can not read pbf right now. Osmosis could but is much slower than osmfilter

echo "------------------->osmfilter (generate boundary files)"
if [ ! -z $ENABLE_BOUNDS ]; then
	if [ "$OSM_SRC_FILE_PBF" -nt "$BOUNDS_STAT_FILE" ]; then
		if [ ! -d "$BOUNDS_DIR" ]; then
		  mkdir -p "$BOUNDS_DIR"
		fi
		
		# convert from pbf to o5m since osmfilter does only understand o5m format
		# caution o5m format needs about twice the harddisk-space of the pbf format
		if [ "$OSM_SRC_FILE_PBF" -nt "$OSM_SRC_FILE_O5M" ] || [ ! -s "$OSM_SRC_FILE_O5M" ]; then
			echo "---------->convert to o5m @"`date`
			$OSMCONVERT_START $DEBUG_OSMCONVERT -t="$OSMCONVERT_WORKDIR"/tmp "$OSM_SRC_FILE_PBF" --out-o5m -o="$OSM_SRC_FILE_O5M"
			if [ $? -ne 0 ]; then 
				echo "ERROR while converting pbf input to o5m for boundaries failed! "`date`
				exit
			else
				echo `du -hs $OSM_SRC_FILE_O5M`
			fi 
		fi
		
		# Cannot pipeline pbf to o5m convertion with filtering bounds since osmfilter needs random access to it's inputs.		
		echo "---------------------> extracting bounds info from map @"`date`
		if [ "$OSM_SRC_FILE_O5M" -nt "$BOUNDS_FILE.o5m" ]; then
			# extract boundary information from source 
			$OSMFILTER_START "$OSM_SRC_FILE_O5M" $DEBUG_OSMFILTER -t="$TEMP_DIR/osmfilter_temp" --keep-nodes= \
				--keep-ways-relations="boundary=administrative =postal_code postal_code=" \
				-o="$BOUNDS_FILE.o5m"
			if [ $? -ne 0 ]; then
				echo "ERROR while filtering boundaries @"`date`
				exit
			else
				echo `du -hs "$BOUNDS_FILE.o5m"`
				
			fi
		fi
			
		### convert to *.bnd files
		echo "--------------------->creating bounds folder for mkgmap @"`date`
		rm "$BOUNDS_DIR"/* # delete old files
	#	$JAVA_START $XmxRAM -jar $MKGMAP_JAR --max-jobs --verbose \
	#		--bounds=$BOUNDS_DIR --createboundsfile=$BOUNDS_FILE.pbf
		$JAVA_START $XmxRAM -cp "$MKGMAP_JAR" uk.me.parabola.mkgmap.reader.osm.boundary.BoundaryPreprocessor \
			"$BOUNDS_FILE.o5m" \
			"$BOUNDS_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR while generating boundary file @"`date`
			exit
		else
			echo `du -hs "$BOUNDS_DIR"`
		fi
	
		### cleanup 
		echo "finished boundary processing @"`date` | tee "$BOUNDS_STAT_FILE"
		if [ "$KEEP_TMP_FILE" != "" ]; then
			rm "$OSM_SRC_FILE_O5M" # delete o5m input file since only the pbf is used further
		fi
	else
		echo "Already there!"
	fi
	MKGMAP_OPTION_BOUNDS="--index --location-autofill=bounds --bounds=$BOUNDS_DIR";
else
	echo "Bounds not needed!"
	MKGMAP_OPTION_BOUNDS=""
	
fi


### split map to reduce overall memory consumption
echo "-------------------->splitter @"`date`
SPLITTER_STAT_FILE=$TEMP_DIR/splitter_finished
if [ ! "$SPLITTER_STAT_FILE" -nt "$OSM_SRC_FILE_PBF" ]; then 
	if [ ! -d "$SPLITTER_DIR" ]; then
		mkdir -p "$SPLITTER_DIR"
		if [ $? -ne 0 ]; then
	  		echo "ERROR creating $SPLITTER"
		  	exit
		fi
	else
		# purging old files
		rm "$SPLITTER"/*
	fi
	$JAVA_START $XmxRAM -jar "$SPLITTER_JAR" \
		--mapid="$MAP_GRP"0345 --max-nodes=$SPLITTER_MAX_NODES --keep-complete=true \
		--output-dir="$SPLITTER_DIR" --write-kml=areas.kml "$OSM_SRC_FILE_PBF"
	echo `du -hs "$SPLITTER_DIR"`
	echo "Splitter finished @"`date` | tee "$SPLITTER_STAT_FILE"
else
	echo "Already there!"
fi


### Basemap (routable map for everyday usage)
echo "-------------------->gbasemap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BASEMAP_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BASEMAP_DIR" ]; then
		mkdir -p "$BASEMAP_DIR"
		if [ $? -ne 0 ]; then
	  		echo "ERROR creating $BASEMAP_DIR"
	  		exit
		fi
	else
		rm "$BASEMAP_DIR"/*
	fi
	echo "Basemap"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs $DEBUG_MKMAP --style-file="$AIOSTYLES_DIR"/basemap_style/ --description='Openstreetmap' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-bmap" --family-name=OSM --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--make-all-cycleways --check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--process-destination --process-exits \
		--location-autofill=is_in,nearest \
		$MKGMAP_OPTION_BOUNDS \
		--gmapsupp "$TYP_DIR"/basemap.TYP \
		--output-dir="$BASEMAP_DIR"/ \
		$MKGMAP_FILE_IMPORT
	
	if [ ! -s "$BASEMAP_DIR"/gmapsupp.img ]; then
		echo "ERROR: basemap could not be created"
		exit
	fi
	
	echo `du -hs "$BASEMAP_DIR"` " " `du -hs "$BASEMAP_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$BASEMAP_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Already there!"
fi

### bikemap
echo "-------------------->bikemap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BIKE_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BIKE_DIR" ]; then
		mkdir -p "$BIKE_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $BIKE_DIR"
			exit
		fi
	else
		rm "$BIKE_DIR"/*
	fi
	echo "Bike map"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/bikemap_style/ --description='Openstreetmap_Bike' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-bike" --family-name=OSM_BIKE --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--make-all-cycleways --check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--ignore-maxspeeds \
		$MKGMAP_OPTION_BOUNDS \
		"$AIOSTYLES_DIR"/bikemap_typ.txt\
		--gmapsupp \
		--output-dir="$BIKE_DIR" \
		$MKGMAP_FILE_IMPORT

	if [ ! -s $BIKE_DIR/gmapsupp.img ]; then
		echo "ERROR: bike could not be created"
		exit
	fi
	
	echo `du -hs "$BIKE_DIR"` " " `du -hs "$BIKE_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then	
		rm "$BIKE_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Already there!"
fi
	
### PKW map
echo "-------------------->gpkw @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$PKW_DIR"/gmapsupp.img ]; then
	if [ ! -d "$PKW_DIR" ]; then
		mkdir -p "$PKW_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $PKW_DIR"
			exit
		fi
	else
		rm "$PKW_DIR"/*
	fi
	echo "PKW map"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/pkw_style/ --description='Openstreetmap_PKW' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-pkw" --family-name=OSM_PKW --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--process-destination --process-exits \
		--location-autofill=is_in,nearest \
		$MKGMAP_OPTION_BOUNDS \
		--gmapsupp "$TYP_DIR"/pkw.TYP \
		--output-dir="$PKW_DIR" \
		$MKGMAP_FILE_IMPORT
	
	if [ ! -s "$PKW_DIR"/gmapsupp.img ]; then
		echo "ERROR: pkw map could not be created"
		exit
	fi

	echo `du -hs "$PKW_DIR"` " " `du -hs "$PKW_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then	
		rm "$PKW_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Already there!"
fi

### Addresses (Overlay map with pretty good visible address tags)
echo "-------------------->gaddr @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$ADDR_DIR"/gmapsupp.img ]; then
	if [ ! -d "$ADDR_DIR" ]; then
		mkdir -p "$ADDR_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $ADDR_DIR"
			exit
		fi
	else
		rm "$ADDR_DIR"/*
	fi
	echo "Adresses"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/addr_style/ --description='Adressen' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=5 --product-id=40 \
		--series-name="OSM-AllInOne-$ISO-Addr" --family-name=ADRESSEN --area-name=EU --latin1 \
		--mapname="$MAP_GRP"1001 --draw-priority=20 --add-pois-to-areas --transparent \
		--gmapsupp "$TYP_DIR"/addr.TYP \
		--output-dir="$ADDR_DIR" \
		$MKGMAP_FILE_IMPORT
		
	if [ ! -s "$ADDR_DIR"/gmapsupp.img ]; then
		echo "ERROR: address map could not be created"
		exit
	fi
	
	echo `du -hs "$ADDR_DIR"` " " `du -hs "$ADDR_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$ADDR_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Already there!"
fi

### FixMes (fixmes in gaudy colors will bother you for every-day usage of your navigation device. So it's a separate map you can easily hide)
echo "-------------------->gfixme @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$FIXME_DIR"/gmapsupp.img ]; then
	if [ ! -d "$FIXME_DIR" ]; then
		mkdir -p "$FIXME_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $FIXME_DIR"
			exit
		fi
	else
		rm "$FIXME_DIR"/*
	fi
	echo "Fixme"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/fixme_style/ --description='Fixme_Layer' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=3 --product-id=33 \
		--series-name="OSM-AllInOne-$ISO-Fixme" --family-name=FIXME --area-name=EU --latin1 \
		--mapname="$MAP_GRP"2001 --draw-priority=22 --transparent \
		--gmapsupp "$TYP_DIR"/fixme.TYP \
		--output-dir="$FIXME_DIR" \
		$MKGMAP_FILE_IMPORT
	
	if [ ! -s "$FIXME_DIR"/gmapsupp.img ]; then
		echo "ERROR: fixme map could not be created"
		exit
	fi
		
	echo `du -hs "$FIXME_DIR"` " " `du -hs "$FIXME_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$FIXME_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Already there!"
fi

### Boundaries (as they often coincide with streets or rivers, you might want them in a seperate map to hide them)
echo "-------------------->gboundary @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BOUNDARY_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BOUNDARY_DIR" ]; then
		mkdir -p "$BOUNDARY_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $BOUNDARY_DIR"
			exit
		fi
	else
		rm "$BOUNDARY_DIR"/*
	fi
	echo "Boundary"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/boundary_style/ --description='Boundary_Layer' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=6 --product-id=30 \
		--series-name="OSM-AllInOne-$ISO-boundary" --family-name=boundary --area-name=EU --latin1 \
		--mapname="$MAP_GRP"3001 --draw-priority=21 --transparent \
		--gmapsupp "$TYP_DIR"/boundary.TYP \
		--output-dir="$BOUNDARY_DIR" \
		$MKGMAP_FILE_IMPORT
	
	if [ ! -s "$BOUNDARY_DIR"/gmapsupp.img ]; then
		echo "ERROR: boundary map could not be created"
		exit
	fi
	
	echo `du -hs "$BOUNDARY_DIR"` " " `du -hs "$BOUNDARY_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$BOUNDARY_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Alread there!"
fi	

### Max Speed (as osm is not fully populated with speed limity, you might want a seperate map to hide them)
echo "-------------------->gmaxspeed @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$MAXSPEED_DIR"/gmapsupp.img ]; then
	if [ ! -d "$MAXSPEED_DIR" ]; then
		mkdir -p "$MAXSPEED_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR creating $MAXSPEED_DIR"
			exit
		fi
	else
		rm "$MAXSPEED_DIR"/*
	fi
	echo "Maxspeed"
	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/maxspeed_style/ --description='Maxspeed' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=84 --product-id=15 \
		--series-name="OSM-AllInOne-$ISO-Maxspeed" --family-name=MAXSPEED --area-name=EU --latin1 \
		--mapname="$MAP_GRP"4001 --draw-priority=19 --transparent \
		--gmapsupp "$TYP_DIR"/maxspeed.TYP \
		--output-dir="$MAXSPEED_DIR" \
		$MKGMAP_FILE_IMPORT
	
	if [ ! -s "$MAXSPEED_DIR"/gmapsupp.img ]; then
		echo "ERROR: maxspeed map could not be created"
		exit
	fi
	
	echo `du -hs "$MAXSPEED_DIR"` " " `du -hs "$MAXSPEED_DIR"/gmapsupp.img`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$MAXSPEED_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "Alread there!"
fi

### Bugs from openstreetbugs
echo "----------------------> gosb @"`date`
if [ ! -z $OSBSQL_BIN ]; then
	echo "-------------------->gosb"
	if [ "$OSM_SRC_FILE_PBF" -nt "$BUGS_DIR"/gmapsupp.img ]; then 
		if [ ! -d "$BUGS_DIR" ]; then
			mkdir -p "$BUGS_DIR"
			if [ $? -ne 0 ]; then
				echo "ERROR creating $BUGS_DIR"
				exit
			fi
		else
			rm "$BUGS_DIR"/*
		fi
		
		ALLBUGS_OSM="$OSM_SRC_DIR/osb.osm"
		ALLBUGS_PBF="$OSM_SRC_DIR/osb.pbf"
		ALLBUGS_STATE_FILE="$OSM_SRC_DIR/osb.state"

		echo "----> Download OSB"
		if [ ! "$ALLBUGS_STATE_FILE" -nt "$OSM_SRC_FILE_PBF" ]; then
			wget -O - http://openstreetbugs.schokokeks.org/dumps/osbdump_latest.sql.bz2 | nice -n $NICE_VAL bunzip2 | $OSBSQL_START > "$ALLBUGS_OSM"
			if [ $? -ne 0 ]; then
				echo "ERROR downloading OSB data!"
				exit
			else
				# write state file (to detect whether or not download was interrupted with STRG-C (not detectable via return value)
				echo "successfull downloaded @"`date` >> "$ALLBUGS_STATE_FILE"
			fi
		else
			echo "Alread there!"
		fi

		if [ "$POLY" == "" ]; then
			$OSMOSIS_START $DEBUG_OSMOSIS --read-xml file="$ALLBUGS_OSM" \
				--sort \
				--write-pbf file="$ALLBUGS_PBF"
			if [ $? -ne 0 ]; then
				echo "ERROR converting OSB file!"
				exit
			fi
		else
			# HINT: can't use osmconvert to crop polygon since OSB data is not sorted (osmconvert need sorted data)
			$OSMOSIS_START $DEBUG_OSMOSIS --read-xml file="$ALLBUGS_OSM" \
				--sort \
 				--bounding-polygon file="$POLY_DIR/$POLY.poly" $OSMOSIS_POLY_OPTIONS \
 				--write-pbf file="$ALLBUGS_PBF"
 			if [ $? -ne 0 ]; then
				echo "ERROR applying polygon to OSB file!"
				exit
			fi
		fi
		
		$JAVA_START $XmxRAM -jar "$SPLITTER_JAR" \
		--mapid="$MAP_GRP"5001 --max-nodes=$SPLITTER_MAX_NODES --keep-complete=true \
		--output-dir=$BUGS_DIR --write-kml=areas.kml $ALLBUGS_PBF
		
		$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/osb_style/ --description='Openstreetbugs' \
			--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=3 --product-id=34 \
			--series-name="OSM-AllInOne-$ISO-OSB" --family-name=OSB --area-name=EU --latin1 \
			--mapname="$MAP_GRP"5001 --draw-priority=23 --no-poi-address --transparent \
			--gmapsupp "$TYP_DIR"/osb.TYP \
			--output-dir="$BUGS_DIR" \
			-c "$BUGS_DIR"/template.args

		if [ ! -s "$BUGS_DIR"/gmapsupp.img ]; then
			echo "ERROR: OSB map could not be created"
			exit
		fi
	
		echo `du -hs "$BUGS_DIR"` " " `du -hs "$BUGS_DIR"/gmapsupp.img`
		if [ $? -ne 0 ]; then
			echo "ERROR OSB map not created!";
			exit
		fi
		if [ "$KEEP_TMP_FILE" != "" ]; then
			rm "$BUGS_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
			rm "$ALLBUGS_OSM"
		fi
	else
		echo "Already there!"
	fi
fi

### purge splitted files (only *.img files are needed further)
if [ "$KEEP_TMP_FILE" != "" ]; then
	echo "Purging "`du -hs $SPLITTER_DIR`
	rm "$SPLITTER_DIR";
fi



### Merge individual maps to a single *.img file
echo "-------------------->merge @"`date`
if [ ! -d "$GMAPOUT_DIR" ]; then
	mkdir -p "$GMAPOUT_DIR"
fi

if [ ! -z $OSBSQL_BIN ]; then
	OSB_MERGE="$BUGS_DIR/gmapsupp.img"
else
	OSB_MERGE=""
fi
echo "-->Basemap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_base.img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_base.img \
		"$BASEMAP_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img		
	if [ $? -ne 0 ]; then
		echo "ERROR merging basemap!"
		exit
	fi
else
	echo "gmapsupp_"$COUNTRY_NAME"_base.img is already there!"
fi 

echo "-->Bike @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_bike.img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_bike.img \
		"$BIKE_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img
	if [ $? -ne 0 ]; then
		echo "ERROR merging bike map!"
		exit
	fi
else
	echo "gmapsupp_"$COUNTRY_NAME"_bike.img is already there!"
fi


echo "-->PKW @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_pkw.img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_pkw.img \
		"$PKW_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img
	if [ $? -ne 0 ]; then
		echo "ERROR merging PKW map!"
		exit
	fi
else
	echo "gmapsupp_"$COUNTRY_NAME"_pkw.img is already there!"
fi

if [ "$KEEP_TMP_FILES" != "" ]; then
	### removing temp files
	echo "------------------->cleaning up temp files @"`date` 
	rm "$OSM_SRC_DIR"
	rm "$SPLITTER_DIR"
	rm "$BOUNDS_DIR"
	rm "$BASEMAP_DIR"
	rm "$BIKE_DIR"
	rm "$PKW_DIR"
	rm "$ADDR_DIR"
	rm "$FIXME_DIR"
	rm "$MAXSPEED_DIR"
	[ ! -z $OSBSQL ] && rm "$BUGS_DIR";
	[ ! -z $ENABLE_BOUNDS ] && rm "$BOUNDARY_DIR";
	rm "$OSMCONVERT_WORKDIR"
	rm -rf "$TEMP_DIR"/osmcopy/
	rm -rf "$TEMP_DIR"/osmosis/
	[ -f "$TEMP_DIR"/map_boundaries.osm.gz ] && rm "$TEMP_DIR"/map_boundaries.osm.gz
fi


# plot time of finishing the script
echo "------------------->finished @"`date`

