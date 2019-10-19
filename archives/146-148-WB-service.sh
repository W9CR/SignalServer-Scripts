#/bin/bash
# Call Signal server from the CLI

set -e
shopt -s lastpipe
#set the SDF dir
SDFDIR=/home/SignalServer/sdf

#     -rel Reliability for ITM model (% of 'time') 1 to 99 (optional, default 50%)
#     -conf Confidence for ITM model (% of 'situations') 1 to 99 (optional, default 50%)

REL='50'
# Confidance 
CONF='50'
#color file
COLOR='blueblue'
#critera in dbu
CRITERA='37'
#frequency
FREQ='147'
#Suffix for the type of file this is
SUFFIX='Service-Contour'
if [[ $# -eq 0 ]] ; then
	echo Usage: all measuremetns in meters
	echo -lat/lon is location, -txh is AGL height of TX, -f is the frequesnt in MHz, -erp is the ERPd in Watts
	echo "-rt is the signal level in dBu, -conf is the longly-rice confidence in percent (50 or 10), -o is output" 
	echo $0 " -lat 27.98 -lon -82.50 -txh 150 -erp 650 -o blueblue "
	exit 1
fi

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    	-lat)
    	LAT="$2"
    	shift # past argument=value
	shift
    	;;
	-lon)
        LON="$2"
        shift # past argument=value
	shift
        ;;
        -txh)
        TXH="$2"
	shift
        shift # past argument=value
        ;;
        -erp)
        ERP="$2"
        shift # past argument=value
	shift
        ;;
        -o)
        OUTPUTFILE="$2"
	shift
        shift # past argument=value
        ;;
	*)
	POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
	;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

echo LATITUDE: 	$LAT
echo LONGITUDE:	$LON
echo TX Height: $TXH
echo ERP:	$ERP
echo OUTPUTFILE:$OUTPUTFILE
time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R 200km -res 600 \
     	-pm 1 -rel $REL -f $FREQ -conf $CONF -color $COLOR -rt $CRITERA -dbg -lat $LAT -lon $LON -txh $TXH \
	-erp $ERP -o $OUTPUTFILE 2>&1 | 
while read line
	do
	echo $line
	if [[ $line == \|* ]]
        	then
                while IFS='|' read -ra coords
                do
                        north=${coords[1]}
                        east=${coords[2]}
                        south=${coords[3]}
                        west=${coords[4]}
                done <<< $line
	fi
done 
echo north $north east $east south $south west $west
# to resize, add: -resize 7000x7000\>
echo NAME: $OUTPUTFILE"_"$SUFFIX
filename=$OUTPUTFILE"_"$SUFFIX.png
echo FILENAME: $filename
convert $OUTPUTFILE.ppm -transparent white $filename
rm $OUTPUTFILE.ppm

echo filename is: $filename ccords are $north $east $south $west

cat << EOF >doc.kml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
<Placemark> 
 <name>${OUTPUTFILE}_${SUFFIX}</name> 
 <description>${OUTPUTFILE}_${SUFFIX}</description>
 <Point>
  <coordinates>
   $LON, $LAT, 0 
  </coordinates>
 </Point> 
</Placemark>
<GroundOverlay>
    <name>$filename</name>
    <color>a0ffffff</color>
    <Icon>
        <href>$filename</href>
    </Icon>
    <LatLonBox>
        <north>$north</north>
        <east>$east</east>
        <south>$south</south>
        <west>$west</west>
    </LatLonBox>
</GroundOverlay>
</Document>
</kml>
EOF


zip $OUTPUTFILE"_"$SUFFIX.zip $filename doc.kml
mv $OUTPUTFILE"_"$SUFFIX.zip $OUTPUTFILE"_"$SUFFIX.kmz
#rm "$filename" doc.kml
echo Generated $OUTPUTFILE"_"$SUFFIX.kmz


