#!/bin/bash

CSV_FOLDER="csv"

mkdir -p $CSV_FOLDER

LINEAS_CSV=$CSV_FOLDER/lineas.csv

curl -s http://unauto.twa.es/code/getlineas.php | sed -n 's:.*<a href="javascript\:mostrarParadas(\(.*\)</a>.*:\1:p' | sed -e 's/)">/;/g' | sed -e "s/'//g" | sed -e "s/&nbsp;//g" > $LINEAS_CSV

# Generate the JSON from the CSV

JSON_FOLDER="json"

mkdir -p $JSON_FOLDER

ROUTES_JSON=$JSON_FOLDER/routes.json

echo "Generating the routes.json from the CSV..."

echo '{ "routes": [ ' > $ROUTES_JSON

# Generate the bus stops CSV files

IFS=";"

while read l1 l2
do
	PARENT_FOLDER="$CSV_FOLDER/bus-stops/linea-$l1"
	OUTPUTFILE="$PARENT_FOLDER/paradas.csv"

	echo "Capturing BusStops for Line [$l1] - $l2 ..."

	mkdir -p $PARENT_FOLDER

	curl -s http://unauto.twa.es/code/getparadas.php?idl=$l1 | sed -n 's:.*<map name="imgmap" id="imgmap">\(.*\)</map>.*:\1:p' | sed -e "s/<area/;<area/g" | tr ';' '\012' | grep 'mostrarInfoParadas' | sed -n "s:.*value, '\(.*\) onmouseout.*:\1:p" | sed -e "s/')//g" | sed -e 's/"//g' | sed -e "s/::/;/g" > $OUTPUTFILE

	# Creating a temporary file to write there the file

	ADDRESSES_TEMP_FILE=$OUTPUTFILE".tmp"

	while read idp ido
	do
		echo "Capturing Address for BusStop $idp with order $ido ..."

		echo "$idp;$ido;`curl -s "http://unauto.twa.es/code/getparadas.php?idl=$l1&idp=$idp&ido=$ido" | sed -n 's:.*<h3 id="titparada">Parada\: \(.*\)</h3>.*:\1:p'`, Toledo, España" >> $ADDRESSES_TEMP_FILE

	done < $OUTPUTFILE

	# swap files

	mv $ADDRESSES_TEMP_FILE $OUTPUTFILE

	# generate the route entry and its bus stops in the routes.json file

	echo '	{' >> $ROUTES_JSON
	echo '		"routeId": "'$l1'",' >> $ROUTES_JSON
	echo '		"routeName": "'$l2'",' >> $ROUTES_JSON
	echo '		"busStops": [' >> $ROUTES_JSON

	IFS=";"

	while read stopId stopOrder stopAddress
	do
		STOP_ORDER=`echo $stopOrder | sed -e "s/ //g"`

		echo '			{ "busStopId": "'$stopId'", "orderId": "'$STOP_ORDER'" },' >> $ROUTES_JSON

	done < $OUTPUTFILE

	cat $ROUTES_JSON | sed '$s/,$//' > $ROUTES_JSON.tmp && mv $ROUTES_JSON.tmp $ROUTES_JSON

	echo '		]' >> $ROUTES_JSON
	echo '	},' >> $ROUTES_JSON

done < $LINEAS_CSV

# remove last comma

cat $ROUTES_JSON | sed '$s/,$//' > $ROUTES_JSON.tmp && mv $ROUTES_JSON.tmp $ROUTES_JSON

echo ']}' >> $ROUTES_JSON

echo 'routes.json generated.'
