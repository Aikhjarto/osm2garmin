#!/bin/bash
#This script is capable of downloading an OSM file and convert it to Garmin's img format. This can be used directly from an SD-Card in a Garmin device.
#
# If the script is interrupted (most probably due to insufficient disc space or ram) it won't recalculate everything from scratch but will reuse all the non-erroneous maps.
#
# Thomas Wagner (wagner-thomas@gmx.at) Sept. 2012 - May 2013
# 
# This script comes with no warranty.
#
### Known limitations
# The reduce the computational demands of mkgmap, splitter is used to subdivide big maps into smaller ones that does not exceed a certain amount of nodes. Each of these smaller maps gets an individual, ascending number assigned. With the mkgmap argument "mapname" the start index can be shifted while generating a single map from the individuals.  If you want to combine (and this script does this at the very end) several maps produced my mkgmap, you'll have to ensure by a proper start index that the map numbers will be unique in the final map. In this script, the difference of the start indices is 1000. This means you cannot reliable merge maps that have been split to 1000 or more maps. If you run into that problem, you can either adjust the start indicess manually or increase the maximum number of nodes of a submap.
# 
### Caution: memory and disc consumption
# As it is true for any script that handles huge osm datasets, this script will require lots of memory and harddisk space.
# If you want to process a pbf file, you should consider the file size as requires memory and about 5 times the file size as available memory. (Note, that pbf is a heavily compressed filetype).

# TODO: properly eval exit status of mkgmap and splitter (not mix up with exit status of java binary)
# TODO: properly eval exit status of osmosis (is a java application invoked via bash script)
# Known minor Bug: there is a rm-warning on purging already empty directories
# Known Bug: if osmosis is interrupted (out of memory, hdd full, abort by CTRL-C) it leaves a near empty---but existing---pbf file. Upon a consecutive execution of the script, osmosis isn't called again to finished it's job.

##################### load map config ################################
source osm_map_config.sh

##################### system setting section ##########################
# You'll have to adjust the variables to match your system in osm_sys_config.sh
source osm_sys_config.sh

XmxRAM="-Xmx$JAVA_RAM" # max ram available to java for splitter and mkgmap
if [ ! -d "$TEMP_DIR/osmosis" ]; then
	mkdir -p "$TEMP_DIR/osmosis";
fi
export JAVACMD_OPTIONS="-Xmx$JAVA_RAM -server -Djava.io.tmpdir=$TEMP_DIR/osmosis" # java options for osmosis

## parition the temporary directory
# temporary folders for separate maps
DEFAULTMAP_DIR="$TEMP_DIR/gdefaultmap"
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
ENABLE_BOUNDS="y" # needed for address search capability

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
# as of 2636: overview maps are available
# as of 2678: ignore-maxspeeds is removed
# as of 2690: mkgmap:toll is available
# as of 2701: Rename all mkgmap:access:* tags to mkgmap:* to make style files a bit shorter
# as of 2705: some changes to default style file location were 
# as of 2747: Add new addaccess and setaccess actions; mkgmap:access is no longer evaluated
# as of 2760: java 1.7 is mandatory (1.6 support is dropped)
# as of 2762: codepage for TYP and txt files is now UTF-8 per default. This makes --code-page pretty obsolete
# as of 2763: mkgmap:bike to mkgmap:bicycle.
# as of 2790: change in RoadMerger, check if --link-pois-to-ways still works
# as of 2814: compare of names available name = $name:en { ... }
# as of 2818: beautifyRoundabouts (enhanced placement of nodes to reduce bad angles)
# as of 2827: change in labels mkgmap:label:1-4
# as of 2906: merged the mergeroads branch. This makes maps better readable for the device but most likely is incomaptible with old style files (access, maxspeed and labels changed)


############################ the work starts here ###################

### sanity checks
# check for executables and java files
if [ ! -x $JAVA_BIN ]; then
	echo "ERROR: JAVA binary is no executable file"
	exit 1
fi
if [ ! -f $SPLITTER_JAR ]; then
	echo "ERROR: $SPLITTER_JAR is missing"
	exit 1
fi
if [ ! -f $MKGMAP_JAR ]; then
	echo "ERROR: $MKGMAP_JAR is missing"
	exit 1
fi
if [ ! -x $OSMFILTER_BIN ]; then
	echo "ERROR: $OSMFILTER_BIN is no executable file"
	exit 1
fi
if [ ! -x $OSMCONVERT_BIN ]; then
	echo "ERROR: $OSMCONVERT_BIN is no executable file"
	exit 1
fi
if [ ! -x $GMT_START ]; then
	echo "ERROR: $GMT_BIN is no executable file"
	exit 1
fi
if [ ! -x $OSMOSIS_BIN ]; then
	echo "ERROR: $OSMOSIS_BIN is no executable file"
	exit 1
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
MD5SUM_START="nice -n $NICE_VAL md5sum"

# check for auxiliary files
if [ ! -d $AIOSTYLES_DIR ]; then
	echo "ERROR: style directory $AIOSTYLES_DIR not found";
	exit 1
fi

### Download maps if not already present (just convert is pbf is present)

echo "--> Preprocess map @"`date`
if [ ! -s "$OSM_SRC_FILE_O5M" ] || [ ! -s "$OSM_SRC_FILE_PBF" ]; then 
# TODO: also check if newer version is available on server
	if [ ! -d "$OSM_SRC_DIR" ]; then
	 	mkdir -p "$OSM_SRC_DIR"
	 	if [ $? -ne 0 ]; then
	 		echo "ERROR: creating $OSM_SRC_DIR";
			exit 1
		fi
	fi

	if [ ! -s "$OSM_SRC_FILE_PBF" ]; then
		# geofabrik's URL is different between countries and continents
		GEOFABRIK_FILE="$GEOFABRIK_MAP_NAME-latest.osm.pbf"
		if [ "$GEOFABRIK_CONTINENT_NAME" == "" ]; then
			DOWNLOAD_URL="http://download.geofabrik.de/openstreetmap/$GEOFABRIK_FILE"
		else
			DOWNLOAD_URL="http://download.geofabrik.de/openstreetmap/$GEOFABRIK_CONTINENT_NAME/$GEOFABRIK_FILE"
		fi
		
		echo "---> Download map started @"`date`
		if [ ! -d "$OSMCONVERT_WORKDIR" ]; then
			mkdir "$OSMCONVERT_WORKDIR"
			if [ $? -ne 0 ]; then
				echo "ERROR: Couldn't create $OSMCONVERT_WORKDIR"
				exit 1
			fi
		else
			rm "$OSMCONVERT_WORKDIR"/*
		fi


		# download md5 checksum (check for existent file to allow manually copying rather than downloading)
		wget -O "$OSM_SRC_DIR/$GEOFABRIK_FILE.md5" "$DOWNLOAD_URL.md5"
		if [ $? -ne 0 ]; then
			echo "ERROR: Download of $DOWNLOAD_URL.md5 to $OSM_SRC_DIR/$GEOFABRIK_FILE.md5 failed"
			exit 1;
		fi

		# download actual map (check for existent file to allow manually copying rather than downloading)	
		if [  ! -f "$OSM_SRC_DIR/$GEOFABRIK_FILE" ]; then
			wget -O  "$OSM_SRC_DIR/$GEOFABRIK_FILE" "$DOWNLOAD_URL"
			if [ $? -ne 0 ]; then
				echo "ERROR: Download of $DOWNLOAD_URL to $OSM_SRC_DIR/$GEOFABRIK_FILE failed"
				exit 1
			fi
		fi
		
		echo "---> start check of md5 checksum @"`date`
		DIR_OLD=`pwd`
		cd $OSM_SRC_DIR
		$MD5SUM_START $DEBUG_MD5 -c "$GEOFABRIK_FILE.md5" 
		if [ $? -ne 0 ]; then
			echo "ERROR: md5 check of map failed"; 
			exit 1;
		else
			cd $DIR_OLD
			# approve map file
			OSM_WGET_TMP_FILE="$OSM_SRC_DIR/$GEOFABRIK_FILE"
		fi
			
			
		
				
		if [ "$POLY" == "" ]; then
			# download and convert in parallel does not work well. When input buffer of osmconvert is full, wget is stalled until osmconvert clears an processes its buffer. This likely results in wget timeouts.
#			echo "download PBF and convert to o5m in parallel"
#			wget -O - $DOWNLOAD_URL  | \
#				tee $OSM_SRC_FILE_PBF | \
#				$OSMCONVERT_START - $DEBUG_OSMCONVERT -t=$OSMCONVERT_WORKDIR -o=$OSM_SRC_FILE_O5M
#			OSM_WGET_TMP_FILE=$TEMP_DIR/osmcopy/wget_tmp.osm.pbf
			
			# simply rename file from g
			mv "$OSM_WGET_TMP_FILE" "$OSM_SRC_FILE_PBF"
			
			
		else
			echo "---> download PBF and convert with a cropping polygon @"`date`
			# complete-ways cannot be used then reading from incomplete file, so file is downloaded first. Then the polygon is applied and in parallel the file is converted to o5m
			#wget -O - $DOWNLOAD_URL  | \
			#	tee >($OSMCONVERT_START - $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS -o=$OSM_SRC_FILE_PBF) | \
			#	$OSMCONVERT_START - $DEBUG_OSMCONVERT $OSM_CONVERT_CUT_OPTIONS -o=$OSM_SRC_FILE_O5M		
			#OSM_WGET_TMP_FILE=$TEMP_DIR/osmcopy/wget_tmp.osm.pbf
			

			# processing polygon on pdf and converting in parallel with two osmconvert instances is not reliable in current version (keeps crashing).
#			$OSMCONVERT_START $OSM_WGET_TMP_FILE $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS --out-pbf | \
# 				tee $OSM_SRC_FILE_PBF | \ 
#				$OSMCONVERT_START - $DEBUG_OSMCONVERT -o=$OSM_SRC_FILE_O5M

			echo "---> appling cropping polygon to downloaded file @"`date`
			# either osmosis or osmconvert can be used to crop the map along a polygon. Osmconvert is faster than osmosis. However, osmconvert is not stable right now with whole continents.
			if [ ! -d "$TEMP_DIR"/osmosis ]; then
				mkdir "$TEMP_DIR"/osmosis
				if [ $? -ne 0 ]; then
					echo "ERROR: creating $TEMP_DIR/osmosis"
					exit 1
				fi
			else
				rm "$TEMP_DIR"/osmosis/*
			fi		
			
			if [ ! -z $ENABLE_PRECISE_CROP ]; then
				#echo "----> Precise cropping enabled!"
				OSMOSIS_POLY_OPTIONS="completeWays=yes completeRelations=yes"
			else
				#echo "----> Precise cropping disabled!"
				OSMOSIS_POLY_OPTONS=""
			fi
			
			# don't write directly to $OSM_SRC_FILE_PBF. Osmosis will touch output file when started. If osmosis gets interrupted by e.g. CTRL-C, an unfinished PBF would be used if this script is restarted
 			$OSMOSIS_START $DEBUG_OSMOSIS --read-pbf-fast file="$OSM_WGET_TMP_FILE" --buffer \
 				--bounding-polygon file="$POLY_DIR/$POLY.poly" $OSMOSIS_POLY_OPTIONS --buffer \
 				--write-pbf file="$TEMP_DIR/osmosis/tmp.pbf"
#			OSMCONVERT_CUT_OPTIONS="-B=$POLY_DIR/$POLY.poly --complete-ways --complex-ways"
#			$OSMCONVERT_START $OSM_WGET_TMP_FILE $DEBUG_OSMCONVERT $OSMCONVERT_CUT_OPTIONS -t=$OSMCONVERT_WORKDIR/tmp -o=$OSM_SRC_FILE_PBF
			#TODO: replace osmosis with https://github.com/MaZderMind/osm-history-splitter which should be faster
			
			# abort if error (can crash frequently on low powered machines and huge input maps (e.g. a whole continent)
			if [ $? -ne 0 ]; then
				echo "ERROR: Osmosis crashed while applying polygon file! @"`date`
				# remove partially created file (most of the time, just an empty file is created, but this interferes with the -nt tests in this script)
				echo "---> Removing $OSM_SRC_FILE_PBF @"`date`
				rm "$OSM_SRC_FILE_PBF"
				rm "$TEMP_DIR/osmosis/tmp.pbf"
				exit 1
			else
				echo "---> Finshed cropping @"`date`
				mv "$TEMP_DIR/osmosis/tmp.pbf" "$OSM_SRC_FILE_PBF"
				if [ "$KEEP_TMP_FILE" != "" ]; then
					# remove raw (uncutted, thus huge) file
					rm "$OSM_WGET_TMP_FILE"
				fi
			fi

		fi

	fi
else
	echo "---> Source map already present! @"`date`
fi

### generate boundary files (if not existing or older than pbf file)
# TODO: o5M file is only needed for creating boundaries. Osmfilter, which extracts the boundaries can not read pbf right now. Osmosis could but is much slower than osmfilter

echo "--> osmfilter (generate boundary files) @"`date`
if [ ! -z $ENABLE_BOUNDS ]; then
	if [ "$OSM_SRC_FILE_PBF" -nt "$BOUNDS_STAT_FILE" ]; then
		if [ ! -d "$BOUNDS_DIR" ]; then
		  mkdir -p "$BOUNDS_DIR"
		fi
		
		# convert from pbf to o5m since osmfilter does only understand o5m format
		# caution o5m format needs about twice the harddisk-space of the pbf format
		if [ "$OSM_SRC_FILE_PBF" -nt "$OSM_SRC_FILE_O5M" ] || [ ! -s "$OSM_SRC_FILE_O5M" ]; then
			echo "---> convert to o5m @"`date`
			$OSMCONVERT_START $DEBUG_OSMCONVERT -t="$OSMCONVERT_WORKDIR"/tmp "$OSM_SRC_FILE_PBF" --out-o5m -o="$OSM_SRC_FILE_O5M"
			if [ $? -ne 0 ]; then 
				echo "ERROR: Converting pbf input to o5m for boundaries failed! @"`date`
				exit 1
			else
				echo `du -hs $OSM_SRC_FILE_O5M`
			fi 
		fi
		
		# Cannot pipeline pbf to o5m conversion with filtering bounds since osmfilter needs random access to it's inputs.		
		echo "--->  extracting bounds info from map @"`date`
		if [ "$OSM_SRC_FILE_O5M" -nt "$BOUNDS_FILE.o5m" ]; then
			# extract boundary information from source 
			$OSMFILTER_START "$OSM_SRC_FILE_O5M" $DEBUG_OSMFILTER -t="$TEMP_DIR/osmfilter_temp" --keep-nodes= \
				--keep-ways-relations="boundary=administrative =postal_code postal_code=" \
				-o="$BOUNDS_FILE.o5m"
			if [ $? -ne 0 ]; then
				echo "ERROR: Osmfilter crashed while filtering boundaries @"`date`
				exit 1
			else
				echo `du -hs "$BOUNDS_FILE.o5m"`
				
			fi
		fi
			
		### convert to *.bnd files
		echo "---> creating bounds folder for mkgmap @"`date`
		rm "$BOUNDS_DIR"/* # delete old files
	#	$JAVA_START $XmxRAM -jar $MKGMAP_JAR --max-jobs --verbose \
	#		--bounds=$BOUNDS_DIR --createboundsfile=$BOUNDS_FILE.pbf
		$JAVA_START $XmxRAM -cp "$MKGMAP_JAR" uk.me.parabola.mkgmap.reader.osm.boundary.BoundaryPreprocessor \
			"$BOUNDS_FILE.o5m" \
			"$BOUNDS_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Mkgmap crashed while generating boundary file @"`date`
			exit 1
		else
			echo `du -hs "$BOUNDS_DIR"`
		fi
	
		### cleanup 
		echo "---> finished boundary processing @"`date` | tee "$BOUNDS_STAT_FILE"
		if [ "$KEEP_TMP_FILE" != "" ]; then
			rm "$OSM_SRC_FILE_O5M" # delete o5m input file since only the pbf is used further
		fi
	else
		echo "---> Already there! @"`date`
	fi
	MKGMAP_OPTION_BOUNDS="--index --location-autofill=bounds --bounds=$BOUNDS_DIR";
else
	echo "---> Bounds not needed! @"`date`
	MKGMAP_OPTION_BOUNDS=""
	
fi


### split map to reduce overall memory consumption
echo "--> splitter @"`date`
SPLITTER_STAT_FILE=$TEMP_DIR/splitter_finished
if [ ! "$SPLITTER_STAT_FILE" -nt "$OSM_SRC_FILE_PBF" ]; then 
	if [ ! -d "$SPLITTER_DIR" ]; then
		mkdir -p "$SPLITTER_DIR"
		if [ $? -ne 0 ]; then
	  		echo "ERROR: Couldn't create $SPLITTER"
		  	exit 1
		fi
	else
		# purging old files
		rm "$SPLITTER"/*
	fi
	$JAVA_START $XmxRAM -jar "$SPLITTER_JAR" \
		--mapid="$MAP_GRP"0345 --max-nodes=$SPLITTER_MAX_NODES --keep-complete=true \
		--output-dir="$SPLITTER_DIR" --write-kml=areas.kml "$OSM_SRC_FILE_PBF"
	echo `du -hs "$SPLITTER_DIR"`
	echo "---> Splitter finished @"`date` | tee "$SPLITTER_STAT_FILE"
else
	echo "---> Already there! @"`date`
fi


### Basemap (routable map for everyday usage)
echo "--> gdefaultmap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$DEFAULTMAP_DIR"/gmapsupp.img ]; then
	if [ ! -d "$DEFAULTMAP_DIR" ]; then
		mkdir -p "$DEFAULTMAP_DIR"
		if [ $? -ne 0 ]; then
	  		echo "ERROR: Couldn't create $DEFAULTMAP_DIR"
	  		exit 1
		fi
	else
		rm "$DEFAULTMAP_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --description='Openstreetmap' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-Default-$ISO-bmap" --family-name=OSM --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--make-all-cycleways --check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--process-destination --process-exits \
		--location-autofill=is_in,nearest \
		--housenumbers \
		$MKGMAP_OPTION_BOUNDS \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp \
		--output-dir="$DEFAULTMAP_DIR"/ \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
		
	
	if [ ! -s "$DEFAULTMAP_DIR"/gmapsupp.img ]; then
		echo "ERROR: defaultmap could not be created"
		exit 1
	fi
	
	echo "---> size: " `du -hs "$DEFAULTMAP_DIR"` " " `du -hs "$DEFAULTMAP_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$DEFAULTMAP_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi

### Basemap (routable map for everyday usage)
echo "--> gbasemap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BASEMAP_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BASEMAP_DIR" ]; then
		mkdir -p "$BASEMAP_DIR"
		if [ $? -ne 0 ]; then
	  		echo "ERROR: Couldn't create $BASEMAP_DIR"
	  		exit 1
		fi
	else
		rm "$BASEMAP_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --style-file="$AIOSTYLES_DIR"/basemap_style/ --description='Openstreetmap' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-bmap" --family-name=OSM --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--make-all-cycleways --check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--process-destination --process-exits \
		--location-autofill=is_in,nearest \
		--housenumbers \
		$MKGMAP_OPTION_BOUNDS \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$AIOSTYLES_DIR"/basemap_typ.txt \
		--output-dir="$BASEMAP_DIR"/ \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
		
	
	if [ ! -s "$BASEMAP_DIR"/gmapsupp.img ]; then
		echo "ERROR: basemap could not be created"
		exit 1
	fi
	
	echo "---> size: " `du -hs "$BASEMAP_DIR"` " " `du -hs "$BASEMAP_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$BASEMAP_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi

### bikemap
echo "--> bikemap @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BIKE_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BIKE_DIR" ]; then
		mkdir -p "$BIKE_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $BIKE_DIR"
			exit 1
		fi
	else
		rm "$BIKE_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --style-file="$AIOSTYLES_DIR"/bikemap_style/ --description='Openstreetmap_Bike' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-bike" --family-name=OSM_BIKE --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--make-all-cycleways --check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--location-autofill=is_in,nearest \
		--housenumbers \
		$MKGMAP_OPTION_BOUNDS \
		"$AIOSTYLES_DIR"/bikemap_typ.txt\
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp \
		--output-dir="$BIKE_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP

	if [ ! -s $BIKE_DIR/gmapsupp.img ]; then
		echo "ERROR: bike could not be created"
		exit 1
	fi
	
	echo "---> size: " `du -hs "$BIKE_DIR"` " " `du -hs "$BIKE_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then	
		rm "$BIKE_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi
	
### PKW map
echo "--> gpkw @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$PKW_DIR"/gmapsupp.img ]; then
	if [ ! -d "$PKW_DIR" ]; then
		mkdir -p "$PKW_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $PKW_DIR"
			exit 1
		fi
	else
		rm "$PKW_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --style-file="$AIOSTYLES_DIR"/pkw_style/ --description='Openstreetmap_PKW' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=4 --product-id=45 \
		--series-name="OSM-AllInOne-$ISO-pkw" --family-name=OSM_PKW --area-name=EU --latin1 \
		--mapname="$MAP_GRP"0001 --draw-priority=10 \
		--add-pois-to-areas --poi-address \
		--check-roundabouts \
		--link-pois-to-ways --route --drive-on-right \
		--process-destination --process-exits \
		--location-autofill=is_in,nearest \
		--housenumbers \
		$MKGMAP_OPTION_BOUNDS \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$TYP_DIR"/pkw.TYP \
		--output-dir="$PKW_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
	
	if [ ! -s "$PKW_DIR"/gmapsupp.img ]; then
		echo "ERROR: pkw map could not be created"
		exit 1
	fi

	echo "---> size: " `du -hs "$PKW_DIR"` " " `du -hs "$PKW_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then	
		rm "$PKW_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi

### Addresses (Overlay map with pretty good visible address tags)
echo "--> gaddr @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$ADDR_DIR"/gmapsupp.img ]; then
	if [ ! -d "$ADDR_DIR" ]; then
		mkdir -p "$ADDR_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $ADDR_DIR"
			exit 1
		fi
	else
		rm "$ADDR_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --style-file="$AIOSTYLES_DIR"/addr_style/ --description='Adressen' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=5 --product-id=40 \
		--series-name="OSM-AllInOne-$ISO-Addr" --family-name=ADRESSEN --area-name=EU --latin1 \
		--mapname="$MAP_GRP"1001 --draw-priority=20 --add-pois-to-areas --transparent \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$TYP_DIR"/addr.TYP \
		--output-dir="$ADDR_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
		
	if [ ! -s "$ADDR_DIR"/gmapsupp.img ]; then
		echo "ERROR: address map could not be created"
		exit 1
	fi
	
	echo "---> size: " `du -hs "$ADDR_DIR"` " " `du -hs "$ADDR_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$ADDR_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi

### FixMes (fixmes in gaudy colors will bother you for every-day usage of your navigation device. So it's a separate map you can easily hide)
echo "--> gfixme @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$FIXME_DIR"/gmapsupp.img ]; then
	if [ ! -d "$FIXME_DIR" ]; then
		mkdir -p "$FIXME_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $FIXME_DIR"
			exit 1
		fi
	else
		rm "$FIXME_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" --max-jobs --style-file="$AIOSTYLES_DIR"/fixme_style/ --description='Fixme_Layer' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=3 --product-id=33 \
		--series-name="OSM-AllInOne-$ISO-Fixme" --family-name=FIXME --area-name=EU --latin1 \
		--mapname="$MAP_GRP"2001 --draw-priority=22 --transparent \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$TYP_DIR"/fixme.TYP \
		--output-dir="$FIXME_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
	
	if [ ! -s "$FIXME_DIR"/gmapsupp.img ]; then
		echo "ERROR: fixme map could not be created"
		exit 1
	fi
		
	echo "---> size:" `du -hs "$FIXME_DIR"` " " `du -hs "$FIXME_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$FIXME_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Already there! @"`date`
fi

### Boundaries (as they often coincide with streets or rivers, you might want them in a seperate map to hide them)
echo "--> gboundary @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$BOUNDARY_DIR"/gmapsupp.img ]; then
	if [ ! -d "$BOUNDARY_DIR" ]; then
		mkdir -p "$BOUNDARY_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $BOUNDARY_DIR"
			exit 1
		fi
	else
		rm "$BOUNDARY_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/boundary_style/ --description='Boundary_Layer' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=6 --product-id=30 \
		--series-name="OSM-AllInOne-$ISO-boundary" --family-name=boundary --area-name=EU --latin1 \
		--mapname="$MAP_GRP"3001 --draw-priority=21 --transparent \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$TYP_DIR"/boundary.TYP \
		--output-dir="$BOUNDARY_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
	
	if [ ! -s "$BOUNDARY_DIR"/gmapsupp.img ]; then
		echo "ERROR: boundary map could not be created"
		exit 1
	fi
	
	echo "---> size: " `du -hs "$BOUNDARY_DIR"` " " `du -hs "$BOUNDARY_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$BOUNDARY_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Alread there! @"`date`
fi	

### Max Speed (as osm is not fully populated with speed limits, you might want a separate map to hide them)
echo "--> gmaxspeed @"`date`
if [ "$OSM_SRC_FILE_PBF" -nt "$MAXSPEED_DIR"/gmapsupp.img ]; then
	if [ ! -d "$MAXSPEED_DIR" ]; then
		mkdir -p "$MAXSPEED_DIR"
		if [ $? -ne 0 ]; then
			echo "ERROR: Couldn't create $MAXSPEED_DIR"
			exit 1
		fi
	else
		rm "$MAXSPEED_DIR"/*
	fi

	$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/maxspeed_style/ --description='Maxspeed' \
		--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=84 --product-id=15 \
		--series-name="OSM-AllInOne-$ISO-Maxspeed" --family-name=MAXSPEED --area-name=EU --latin1 \
		--mapname="$MAP_GRP"4001 --draw-priority=19 --transparent \
		$MKGMAP_OPTION_TDBFILE \
		--gmapsupp "$TYP_DIR"/maxspeed.TYP \
		--output-dir="$MAXSPEED_DIR" \
		$MKGMAP_FILE_IMPORT \
		$DEBUG_MKGMAP
		
	if [ ! -s "$MAXSPEED_DIR"/gmapsupp.img ]; then
		echo "ERROR: maxspeed map could not be created"
		exit 1
	fi
	
	echo "---> size: "`du -hs "$MAXSPEED_DIR"` " " `du -hs "$MAXSPEED_DIR"/gmapsupp.img` " @"`date`
	if [ "$KEEP_TMP_FILE" != "" ]; then
		rm "$MAXSPEED_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
	fi
else
	echo "---> Alread there! @"`date`
fi

### Bugs from openstreetbugs
echo "--> gosb @"`date`
if [ ! -z $OSBSQL_BIN ]; then
	if [ "$OSM_SRC_FILE_PBF" -nt "$BUGS_DIR"/gmapsupp.img ]; then 
		if [ ! -d "$BUGS_DIR" ]; then
			mkdir -p "$BUGS_DIR"
			if [ $? -ne 0 ]; then
				echo "ERROR: Couldn't create $BUGS_DIR"
				exit 1
			fi
		else
			rm "$BUGS_DIR"/*
		fi
		
		ALLBUGS_OSM="$OSM_SRC_DIR/osb.osm"
		ALLBUGS_PBF="$OSM_SRC_DIR/osb.pbf"
		ALLBUGS_STATE_FILE="$OSM_SRC_DIR/osb.state"

		echo "---> Download OSB @"`date`
		if [ ! "$ALLBUGS_STATE_FILE" -nt "$OSM_SRC_FILE_PBF" ]; then
			wget -O - http://openstreetbugs.schokokeks.org/dumps/osbdump_latest.sql.bz2 | nice -n $NICE_VAL bunzip2 | $OSBSQL_START > "$ALLBUGS_OSM"
			if [ $? -ne 0 ]; then
				echo "ERROR: Wget had an error while downloading OSB data!"
				exit 1
			else
				# write state file (to detect whether or not download was interrupted with STRG-C (not detectable via return value)
				echo "---> successfull downloaded @"`date` | tee "$ALLBUGS_STATE_FILE"
			fi
		else
			echo "---> Alread there! @"`date`
		fi

		if [ "$POLY" == "" ]; then
			echo "---> converting OSB without poly @"`date`
			$OSMOSIS_START $DEBUG_OSMOSIS --read-xml file="$ALLBUGS_OSM" \
				--sort \
				--write-pbf file="$ALLBUGS_PBF"
			if [ $? -ne 0 ]; then
				echo "ERROR converting OSB file!"
				exit 1
			fi
		else
			# HINT: can't use osmconvert to crop polygon since OSB data is not sorted (osmconvert need sorted data)
			echo "---> converting OSB with poly @"`date`
			$OSMOSIS_START $DEBUG_OSMOSIS --read-xml file="$ALLBUGS_OSM" \
				--sort \
 				--bounding-polygon file="$POLY_DIR/$POLY.poly" $OSMOSIS_POLY_OPTIONS \
 				--write-pbf file="$ALLBUGS_PBF"
 			if [ $? -ne 0 ]; then
				echo "ERROR: Osmosis crashed while applying polygon to OSB file!"
				exit 1
			fi
		fi
		
		echo "---> splitting OSB @"`date`
		$JAVA_START $XmxRAM -jar "$SPLITTER_JAR" \
		--mapid="$MAP_GRP"5001 --max-nodes=$SPLITTER_MAX_NODES --keep-complete=true \
		--output-dir=$BUGS_DIR --write-kml=areas.kml $ALLBUGS_PBF
		
		echo "---> generating OSB @"`date`
		$JAVA_START $XmxRAM -jar "$MKGMAP_JAR" $DEBUG_MKMAP --max-jobs --style-file="$AIOSTYLES_DIR"/osb_style/ --description='Openstreetbugs' \
			--country-name=$COUNTRY_NAME --country-abbr=$COUNTRY_ABBR --family-id=3 --product-id=34 \
			--series-name="OSM-AllInOne-$ISO-OSB" --family-name=OSB --area-name=EU --latin1 \
			--mapname="$MAP_GRP"5001 --draw-priority=23 --no-poi-address --transparent \
			$MKGMAP_OPTION_TDBFILE \
			--gmapsupp "$TYP_DIR"/osb.TYP \
			--output-dir="$BUGS_DIR" \
			$BUGS_DIR/*.pbf \
			$DEBUG_MKGMAP
#			-c "$BUGS_DIR"/template.args

		if [ ! -s "$BUGS_DIR"/gmapsupp.img ]; then
			echo "ERROR: OSB map could not be created"
			exit 1
		fi
	
		echo `du -hs "$BUGS_DIR"` " " `du -hs "$BUGS_DIR"/gmapsupp.img`
		if [ $? -ne 0 ]; then
			echo "ERROR OSB map not created!";
			exit 1
		fi
		if [ "$KEEP_TMP_FILE" != "" ]; then
			rm "$BUGS_DIR"/$MAP_GRP*.img # clean up, since mkgmap does not
			rm "$ALLBUGS_OSM"
		fi
	else
		echo "---> Already there! @"`date`
	fi
fi

### purge splitted files (only *.img files are needed further)
if [ "$KEEP_TMP_FILE" != "" ]; then
	echo "--> Purging "`du -hs $SPLITTER_DIR` " @"`date`
	rm "$SPLITTER_DIR";
fi



### Merge individual maps to a single *.img file
echo "--> merge @"`date`
if [ ! -d "$GMAPOUT_DIR" ]; then
	mkdir -p "$GMAPOUT_DIR"
fi

if [ ! -z $OSBSQL_BIN ]; then
	OSB_MERGE="$BUGS_DIR/gmapsupp.img"
else
	OSB_MERGE=""
fi

MAP_POSTFIX="default"
echo "---> Defaultmap @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	cp "$DEFAULTMAP_DIR"/gmapsupp.img "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi 


MAP_POSTFIX="base"
echo "---> Basemap @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	cp "$BASEMAP_DIR"/gmapsupp.img "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi 

MAP_POSTFIX="bike"
echo "---> Bike @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	cp "$BIKE_DIR"/gmapsupp.img "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi

MAP_POSTFIX="pkw"
echo "---> PKW @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	cp "$PKW_DIR"/gmapsupp.img "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi

MAP_POSTFIX="default_overlays"
echo "---> Defaultmap @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
		"$DEFAULTMAP_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img		
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi 

MAP_POSTFIX="base_overlays"
echo "---> Basemap @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
		"$BASEMAP_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img		
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi 

MAP_POSTFIX="bike_overlays"
echo "---> Bike @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
		"$BIKE_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi

MAP_POSTFIX="pkw_overlays"
echo "---> PKW @"`date`" postfix: "$MAP_POSTFIX
if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
	$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
		"$PKW_DIR"/gmapsupp.img \
		"$ADDR_DIR"/gmapsupp.img \
		"$MAXSPEED_DIR"/gmapsupp.img \
		"$BOUNDARY_DIR"/gmapsupp.img
	if [ $? -ne 0 ]; then
		echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
		exit 1
	fi
else
	echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
fi

if [ ! -z $OSBSQL_BIN ]; then
	MAP_POSTFIX="base_with_bugs"
	echo "---> Basemap @"`date`" postfix: "$MAP_POSTFIX
	if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
		$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
			"$BASEMAP_DIR"/gmapsupp.img \
			"$ADDR_DIR"/gmapsupp.img \
			"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
			"$MAXSPEED_DIR"/gmapsupp.img \
			"$BOUNDARY_DIR"/gmapsupp.img		
		if [ $? -ne 0 ]; then
			echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
			exit 1
		fi
	else
		echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
	fi 

	MAP_POSTFIX="bike_with_bugs"
	echo "---> Bike @"`date`" postfix: "$MAP_POSTFIX
	if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
		$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
			"$BIKE_DIR"/gmapsupp.img \
			"$ADDR_DIR"/gmapsupp.img \
			"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
			"$MAXSPEED_DIR"/gmapsupp.img \
			"$BOUNDARY_DIR"/gmapsupp.img
		if [ $? -ne 0 ]; then
			echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
			exit 1
		fi
	else
		echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
	fi

	MAP_POSTFIX="pkw_with_bugs"
	echo "---> PKW @"`date`" postfix: "$MAP_POSTFIX
	if [ "$OSM_SRC_FILE_PBF" -nt "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img ]; then
		$GMT_START $DEBUG_GMT -jo "$GMAPOUT_DIR"/gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img \
			"$PKW_DIR"/gmapsupp.img \
			"$ADDR_DIR"/gmapsupp.img \
			"$FIXME_DIR"/gmapsupp.img "$OSB_MERGE" \
			"$MAXSPEED_DIR"/gmapsupp.img \
			"$BOUNDARY_DIR"/gmapsupp.img
		if [ $? -ne 0 ]; then
			echo "ERROR merging gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img!"
			exit 1
		fi
	else
		echo "----> gmapsupp_"$COUNTRY_NAME"_"$MAP_POSTFIX".img is already there!"
	fi
fi

if [ "$KEEP_TMP_FILES" != "" ]; then
	### removing temp files
	echo "--> cleaning up temp files @"`date` 
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
echo "-->finished @"`date`
