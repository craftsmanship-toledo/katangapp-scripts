#!/bin/bash

##
#     Copyright 2016-today Software Craftmanship Toledo
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#  http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##

CSV_FOLDER="csv"

mkdir -p $CSV_FOLDER

LINEAS_CSV=$CSV_FOLDER/lineas.csv
PARADAS_CSV=$CSV_FOLDER/paradas.csv

rm -fr $PARADAS_CSV

curl -s http://unauto.twa.es/code/getlineas.php | sed -n 's:.*<a href="javascript\:mostrarParadas(\(.*\)</a>.*:\1:p' | sed -e 's/)">/;/g' | sed -e "s/'//g" | sed -e "s/&nbsp;//g" > $LINEAS_CSV

# Generate the JSON from the CSV

JSON_FOLDER="json"

mkdir -p $JSON_FOLDER

ROUTES_JSON=$JSON_FOLDER/routes.json

BUS_STOPS_JSON="$JSON_FOLDER/bus-stops.json"

rm -f $BUS_STOPS_JSON

echo "Generating the routes.json and the bus-stops.json from the CSV..."

echo '{ "routes": [ ' > $ROUTES_JSON

# Generate the bus stops CSV files

IFS=";"

while read routeId routeDescription
do
	PARENT_FOLDER="$CSV_FOLDER/bus-stops/linea-$routeId"
	OUTPUTFILE="$PARENT_FOLDER/paradas.csv"

	echo "Capturing BusStops for Line [$routeId] - $routeDescription ..."

	mkdir -p $PARENT_FOLDER

	curl -s http://unauto.twa.es/code/getparadas.php?idl=$routeId | sed -n 's:.*<map name="imgmap" id="imgmap">\(.*\)</map>.*:\1:p' | sed -e "s/<area/;<area/g" | tr ';' '\012' | grep 'mostrarInfoParadas' | sed -n "s:.*value, '\(.*\) onmouseout.*:\1:p" | sed -e "s/')//g" | sed -e 's/"//g' | sed -e "s/::/;/g" > $OUTPUTFILE

	# Creating a temporary file to write there the file

	ADDRESSES_TEMP_FILE=$OUTPUTFILE".tmp"

	while read idp ido
	do
		echo "Capturing Address for BusStop $idp with order $ido ..."

		echo "$idp;$ido;`curl -s "http://unauto.twa.es/code/getparadas.php?idl=$routeId&idp=$idp&ido=$ido" | sed -n 's:.*<h3 id="titparada">Parada\: \(.*\)</h3>.*:\1:p'`" >> $ADDRESSES_TEMP_FILE

	done < $OUTPUTFILE

	# swap files

	mv $ADDRESSES_TEMP_FILE $OUTPUTFILE

	# generate the route entry and its bus stops in the routes.json file

	echo '	{' >> $ROUTES_JSON
	echo '		"id": "'$routeId'",' >> $ROUTES_JSON
	echo '		"name": "'$routeDescription'",' >> $ROUTES_JSON
	echo '		"busStops": [' >> $ROUTES_JSON

	IFS=";"

	while read stopId stopOrder stopAddress stopLat stopLong
	do
		STOP_ORDER=`echo $stopOrder | sed -e "s/ //g"`

		STOP_LAT=`echo $stopLat | sed -e "s/ //g"`
		STOP_LONG=`echo $stopLong | sed -e "s/ //g"`

		echo '			{ "id": "'$stopId'", "order": "'$STOP_ORDER'" },' >> $ROUTES_JSON

		DUPLICATED_REGEXP=""$stopId';'$stopAddress

		DUPLICATED_COUNT=`grep "$DUPLICATED_REGEXP" $PARADAS_CSV | wc -l`

		if [ $DUPLICATED_COUNT -eq 0 ]; then
			echo ''$stopId';'$stopAddress';'$STOP_LAT';'$STOP_LONG >> $PARADAS_CSV
		fi

		if [ "$STOP_LAT" == "" ] && [ "$STOP_LONG" == "" ]; then
			echo "Do not adding bus stop id ["$stopId"] until LatLong are present"
		else
			DUPLICATED_REGEXP="id\": \""$stopId'\", \"address\": \"'$stopAddress

			DUPLICATED_COUNT=`grep "$DUPLICATED_REGEXP" $BUS_STOPS_JSON | wc -l`

			if [ $DUPLICATED_COUNT -eq 0 ]; then
				echo '	{ "id": "'$stopId'", "address": "'$stopAddress'", "lat": "'$STOP_LAT'", "long": "'$STOP_LONG'" },' >> $BUS_STOPS_JSON
			fi
		fi

	done < $OUTPUTFILE

	cat $ROUTES_JSON | sed '$s/,$//' > $ROUTES_JSON.tmp && mv $ROUTES_JSON.tmp $ROUTES_JSON

	echo '		]' >> $ROUTES_JSON
	echo '	},' >> $ROUTES_JSON

done < $LINEAS_CSV

# sort paradas file

sort $PARADAS_CSV > $PARADAS_CSV.tmp && mv $PARADAS_CSV.tmp $PARADAS_CSV

# remove last comma

cat $ROUTES_JSON | sed '$s/,$//' > $ROUTES_JSON.tmp && mv $ROUTES_JSON.tmp $ROUTES_JSON

echo ']}' >> $ROUTES_JSON

## Building bus-stops.json

# sort bus stops

sort $BUS_STOPS_JSON > $BUS_STOPS_JSON.tmp

cat $BUS_STOPS_JSON.tmp | sed '$s/,$//' > $BUS_STOPS_JSON.sort && mv $BUS_STOPS_JSON.sort $BUS_STOPS_JSON.tmp

echo '{ "busStops": [ ' > $BUS_STOPS_JSON

cat $BUS_STOPS_JSON.tmp >> $BUS_STOPS_JSON

echo ']}' >> $BUS_STOPS_JSON

rm $BUS_STOPS_JSON.tmp

echo 'routes.json and bus-stops.json generated.'
