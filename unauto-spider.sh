#!/bin/bash

CSV_FOLDER="csv"

mkdir -p $CSV_FOLDER

LINEAS_CSV=$CSV_FOLDER/lineas.csv

curl http://unauto.twa.es/code/getlineas.php | sed -n 's:.*<a href="javascript\:mostrarParadas(\(.*\)</a>.*:\1:p' | sed -e 's/)">/;/g' | sed -e "s/'//g" | sed -e "s/&nbsp;//g" > $LINEAS_CSV

IFS=";"

while read l1 l2
do
	PARENT_FOLDER="$CSV_FOLDER/bus-stops/linea-$l1"
	OUTPUTFILE="$PARENT_FOLDER/paradas.csv"

	echo "Capturing BusStops for Line [$l1] - $l2 ..."

	mkdir -p $PARENT_FOLDER

	curl http://unauto.twa.es/code/getparadas.php?idl=$l1 | sed -n 's:.*<map name="imgmap" id="imgmap">\(.*\)</map>.*:\1:p' | sed -e "s/<area/;<area/g" | tr ';' '\012' | grep 'mostrarInfoParadas' | sed -n "s:.*value, '\(.*\) onmouseout.*:\1:p" | sed -e "s/')//g" | sed -e 's/"//g' | sed -e "s/::/;/g" > $OUTPUTFILE

	# Creating a temporary file to write there the file

	ADDRESSES_TEMP_FILE=$OUTPUTFILE".tmp"

	while read idp ido
	do
		echo "Capturing Address for BusStop $idp with order $ido ..."

		echo "$idp;$ido;`curl -s "http://unauto.twa.es/code/getparadas.php?idl=$l1&idp=$idp&ido=$ido" | sed -n 's:.*<h3 id="titparada">Parada\: \(.*\)</h3>.*:\1:p'`, Toledo, España" >> $ADDRESSES_TEMP_FILE

	done < $OUTPUTFILE

	# swap files

	mv $ADDRESSES_TEMP_FILE $OUTPUTFILE

done < $LINEAS_CSV
