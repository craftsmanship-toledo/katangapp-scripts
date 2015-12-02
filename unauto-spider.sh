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

	echo "idl;ido" > $OUTPUTFILE

	curl http://unauto.twa.es/code/getparadas.php?idl=$l1 | sed -n 's:.*<map name="imgmap" id="imgmap">\(.*\)</map>.*:\1:p' | sed -e "s/<area/;<area/g" | tr ';' '\012' | grep 'mostrarInfoParadas' | sed -n "s:.*value, '\(.*\) onmouseout.*:\1:p" | sed -e "s/')//g" | sed -e 's/"//g' | sed -e "s/::/;/g" >> $OUTPUTFILE

done < $LINEAS_CSV
