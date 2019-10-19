#/bin/bash
# Call Signal server from the CLI

#invoke signal server and build 3 plots in a single KML
# Copyright 2019 Bryan Fields W9CR
# Licensed under the Affero Public License

set -e
shopt -s lastpipe
#set the SDF dir
SDFDIR=/home/SignalServer/sdf

#     -rel Reliability for ITM model (% of 'time') 1 to 99 (optional, default 50%)
#     -conf Confidence for ITM model (% of 'situations') 1 to 99 (optional, default 50%)

REL_SVC='50'
REL_INF='10'
REL_ADJ='10'
# Confidance 
CONF='50'

# only mode ADJ if >8 khz wide.  
#critera in dbu
CRITERA_SVC='37'
CRITERA_INF='19'
CRITERA_ADJ='25'
#frequency
FREQ='145'
#radius model distance in KM
DISTANCE='200km'
#Suffix for the type of file this is
SUFFIX_SVC='Service'
SUFFIX_INF='Interference'
SUFFIX_ADJ='Adjacent'
#color file
COLOR_SVC='blueblue'
COLOR_INF='green'
COLOR_ADJ='orange'

if [[ $# -eq 0 ]] ; then
	echo Scipt to run SignalServer for FASMA 144-146 MHz and generate a KMZ.  This is 10 khz channels
	echo Usage: all measuremetns in meters
	echo -e \\t -lat -lon is location, -txh is AGL height of TX, -erp is the ERPd in Watts
	echo -e \\t "-o is output name with out the exention." ,-a do the adjacent calc
	echo $0 " -lat 28.27 -lon -82.48 -txh 36.58 -erp 30 -o 145.3300_WA4GDN_Land-O-Lakes "
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
        -a)
        DO_ADJ="1"
        shift # past argument
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




function SERVICE {

SUFFIX=$SUFFIX_SVC

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
     	-pm 1 -rel $REL_SVC -f $FREQ -conf $CONF -color $COLOR_SVC -rt $CRITERA_SVC -dbg -lat $LAT -lon $LON -txh $TXH \
	-erp $ERP -o $OUTPUTFILE 2>&1 | 
while read line
	do
	echo $line
	if [[ $line == \|* ]]
        	then
                while IFS='|' read -ra coords
                do
                        north_svc=${coords[1]}
                        east_svc=${coords[2]}
                        south_svc=${coords[3]}
                        west_svc=${coords[4]}
                done <<< $line
	fi
done 
# to resize, add: -resize 7000x7000\>
echo NAME: $OUTPUTFILE"_"$SUFFIX
filename_svc=$OUTPUTFILE"_"$SUFFIX.png
echo FILENAME: $filename
convert $OUTPUTFILE.ppm -transparent white $filename_svc
rm $OUTPUTFILE.ppm

echo filename is: $filename_svc ccords are $north_svc $east_svc $south_svc $west_svc

SVC_KML="$(cat << EOF 
<GroundOverlay>
    <name>${OUTPUTFILE}_${SUFFIX}</name>
    <color>a0ffffff</color>
    <Icon>
        <href>${filename_svc}</href>
    </Icon>
    <LatLonBox>
        <north>${north_svc}</north>
        <east>${east_svc}</east>
        <south>${south_svc}</south>
        <west>${west_svc}</west>
    </LatLonBox>
</GroundOverlay>
EOF
)"
}

function INTERFERENCE {

SUFFIX=$SUFFIX_INF

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel $REL_INF -f $FREQ -conf $CONF -color $COLOR_INF -rt $CRITERA_INF -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTFILE 2>&1 |
while read line
        do
        echo $line
        if [[ $line == \|* ]]
                then
                while IFS='|' read -ra coords
                do
                        north_inf=${coords[1]}
                        east_inf=${coords[2]}
                        south_inf=${coords[3]}
                        west_inf=${coords[4]}
                done <<< $line
        fi
done
# to resize, add: -resize 7000x7000\>
echo NAME: $OUTPUTFILE"_"$SUFFIX
filename_inf=$OUTPUTFILE"_"$SUFFIX.png
echo FILENAME: $filename_inf
convert $OUTPUTFILE.ppm -transparent white $filename_inf
rm $OUTPUTFILE.ppm

echo filename is: $filename_inf ccords are $north_inf $east_inf $south_inf $west_inf

INF_KML="$(cat << EOF 
<GroundOverlay>
    <name>${OUTPUTFILE}_${SUFFIX}</name>
    <color>a0ffffff</color>
    <Icon>
        <href>${filename_inf}</href>
    </Icon>
    <LatLonBox>
        <north>${north_inf}</north>
        <east>${east_inf}</east>
        <south>${south_inf}</south>
        <west>${west_inf}</west>
    </LatLonBox>
</GroundOverlay>
EOF
)"
}

function ADJACENT {

SUFFIX=$SUFFIX_ADJ

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel $REL_ADJ -f $FREQ -conf $CONF -color $COLOR_ADJ -rt $CRITERA_ADJ -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTFILE 2>&1 |
while read line
        do
        echo $line
        if [[ $line == \|* ]]
                then
                while IFS='|' read -ra coords
                do
                        north_adj=${coords[1]}
                        east_adj=${coords[2]}
                        south_adj=${coords[3]}
                        west_adj=${coords[4]}
                done <<< $line
        fi
done
# to resize, add: -resize 7000x7000\>
echo NAME: $OUTPUTFILE"_"$SUFFIX
filename_adj=$OUTPUTFILE"_"$SUFFIX.png
echo FILENAME: $filename_adj
convert $OUTPUTFILE.ppm -transparent white $filename_adj
rm $OUTPUTFILE.ppm

echo filename is: $filename_adj ccords are $north_adj $east_adj $south_adj $west_adj

ADJ_KML="$(cat << EOF 
<GroundOverlay>
    <name>${OUTPUTFILE}_${SUFFIX}</name>
    <color>a0ffffff</color>
    <Icon>
        <href>${filename_adj}</href>
    </Icon>
    <LatLonBox>
        <north>${north_adj}</north>
        <east>${east_adj}</east>
        <south>${south_adj}</south>
        <west>${west_adj}</west>
    </LatLonBox>
</GroundOverlay>
EOF
)"
}


function make_file {
zip $OUTPUTFILE.zip $filename_svc $filename_inf $filename_adj doc.kml
mv $OUTPUTFILE.zip $OUTPUTFILE.kmz
rm $filename_svc $filename_inf $filename_adj #doc.kml
echo Generated $OUTPUTFILE.kmz
}

LOC_KML=$(cat << EOF
<Placemark> 
 <name>${OUTPUTFILE}</name> 
 <description>${OUTPUTFILE}</description>
 <Point>
  <coordinates>
   $LON, $LAT, 0 
  </coordinates>
 </Point> 
</Placemark>
EOF
)

KML_HEAD=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
EOF
)

KML_FOOT=$(cat <<EOF
</Document>
</kml>
EOF
)

# Do the Service
echo "Doing Service"
SERVICE

# Do the Interference
echo "Doing Interference"
INTERFERENCE

# Do the Adjacent
#echo "Doing Adjacent"
if [[ $DO_ADJ = '1' ]] 
then 
	ADJACENT
fi

echo service filename is: $filename_svc coords are $north_svc $east_svc $south_svc $west_svc

echo "$KML_HEAD" >doc.kml
echo "$LOC_KML" >>doc.kml
echo "$INF_KML" >>doc.kml
if [[ $DO_ADJ = '1' ]]
 then 
	echo "$ADJ_KML" >>doc.kml
fi
echo "$SVC_KML" >>doc.kml
echo "$KML_FOOT" >>doc.kml

make_file 

exit



