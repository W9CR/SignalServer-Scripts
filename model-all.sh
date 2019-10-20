#!/bin/bash
# vim: ts=2 sw=2  
set -e
shopt -s lastpipe
TMP_FILE="/tmp/db-query.txt"

# ./144-146-WB.sh -lat 27.60 -lon -80.39 -txh 73.15 -erp 210 -o 145.1300_AB4AX_Vero-Beach
#file='/tmp/145mhz.txt'
# 0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | emission

# This will run through all models as a query from the db



# Global defines for Signal Server, these don't change
REL_SVC='50'
REL_INF='10'
REL_ADJ='10'
REL_ADJ1='10'
REL_ADJ2='10'
# Confidance 
CONF='50'
#Suffix for the type of file this is
SUFFIX_SVC='Service'
SUFFIX_INF='Interference'
SUFFIX_ADJ='Adjacent'
SUFFIX_ADJ1='To-Narrow-Adjacent'
SUFFIX_ADJ2='To-Wide-Adjacent'
#color file
COLOR_SVC='blueblue'
COLOR_INF='green'
COLOR_ADJ='orange'
COLOR_ADJ1='yellow'
COLOR_ADJ2='magenta'
#BASE DIR
BASE_DIR='/home/SignalServer/plots'

# Options 
# -id database ID
# -model even if modeled flag is set in db
# -noupdate don't update db
# frequency range -flow 144.0000 -fhigh 146.0000
# 

POSITIONAL=()
while [[ $# -gt 0 ]]
	do
	key="$1"
	case ${key} in
		-id)
		ID="$2"
		shift # past argument=value
		shift
		;;
		-model)
		MODEL='1'
		shift
		;;
		-noupdate)
		NOUPDATE='1'
		shift # past argument=value
		;;
		-flow)
		FREQ_LOW="$2"
		shift # past argument=value
		shift
		;;
		-fhigh)
		FREQ_HIGH="$2"
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

if [[ ! -z ${FREQ_LOW} && ! -z ${FREQ_HIGH} ]]
then
	echo FREQ_LOW \"${FREQ_LOW}\"
	echo FREQ_HIGH \"${FREQ_HIGH}\"
	Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
  REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
  COORDINATED, chan_Size_kHz, record_ID, Service_Ring_km, Interference_Ring_km, adj1_ring_km, adj2_ring_km, modeled, model_Required, model_Name
  FROM filemaker  WHERE Output_frequency BETWEEN '${FREQ_LOW}' AND '${FREQ_HIGH}' AND COORDINATED = '1' 
  ORDER BY  Output_frequency ;"
	echo "$Query"
	mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE"
#	cat $TMP_FILE
elif [[ ! -z ${FREQ_LOW+x} || ! -z ${FREQ_HIGH+x} ]]
then 
	echo FREQ_LOW or FREQ_HIGH must be set
fi

function SERVICE {

SUFFIX=${SUFFIX_SVC}

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
echo "NAME: ${OUTPUTFILE}_${SUFFIX}"
filename_svc=${OUTPUTFILE}_${SUFFIX}.png
echo FILENAME: ${filename}
convert ${OUTPUTFILE}.ppm -transparent white ${filename_svc}
rm ${OUTPUTFILE}.ppm

echo filename is: ${filename_svc} ccords are ${north_svc} ${east_svc} ${south_svc} ${west_svc}

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

SUFFIX=${SUFFIX_INF}

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
echo NAME: ${OUTPUTFILE}_${SUFFIX}
filename_inf=${OUTPUTFILE}_${SUFFIX}.png
echo FILENAME: ${filename_inf}
convert ${OUTPUTFILE}.ppm -transparent white ${filename_inf}
rm ${OUTPUTFILE}.ppm

echo filename is: ${filename_inf} coords are ${north_inf} ${east_inf} ${south_inf} ${west_inf}

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


SUFFIX=${SUFFIX_ADJ}

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel $REL_ADJ -f $FREQ -conf $CONF -color $COLOR_ADJ -rt $CRITERA_ADJ -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTFILE 2>&1 |
while read line
        do
        echo ${line}
        if [[ ${line} == \|* ]]
                then
                while IFS='|' read -ra coords
                do
                        north_adj=${coords[1]}
                        east_adj=${coords[2]}
                        south_adj=${coords[3]}
                        west_adj=${coords[4]}
                done <<< ${line}
        fi
done
# to resize, add: -resize 7000x7000\>
echo NAME: ${OUTPUTFILE}_${SUFFIX}
filename_adj=${OUTPUTFILE}_${SUFFIX}.png
echo FILENAME: ${filename_adj}
convert $OUTPUTFILE.ppm -transparent white ${filename_adj}
rm $OUTPUTFILE.ppm

echo filename is: ${filename_adj} ccords are ${north_adj} ${east_adj} ${south_adj} ${west_adj}

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

function MAKE_FILE {
zip ${OUTPUTFILE}.zip ${filename_svc} ${filename_inf} ${filename_adj} ${filename_adj1} ${filename_adj2} doc.kml
mv ${OUTPUTFILE}.zip ${OUTPUTFILE}.kmz
#rm ${filename_svc} ${filename_inf} ${filename_adj} ${filename_adj1} ${filename_adj2} doc.kml
echo Generated ${OUTPUTFILE}.kmz
}

LOC_KML=$(cat << EOF
<Placemark> 
 <name>${OUTPUTFILE}</name> 
  <description><![CDATA[<pre>
CALL: ${CALL}
CITY: ${CITY}
FREQ: ${FREQ} 
ERP: ${ERP}          AGL: ${AGL}m
LAT: ${LAT}          LON: ${LON}
EM1: ${EM1}          EM2: ${EM2}
Service Criteria: ${CRITERIA_SVC} dBu "(50,50)"
Interference Criteria: ${CRITERIA_INT} dBu "(50,10)"
</pre>
<br>
<a href=https://plots.fasma.org>Plots of all Coordinated repeaters in FASMA Database</a>
<br>
<a href=https://fasma.org>fasma.org</a>  
]]></description>

	<Point>
  <coordinates>
   ${LON}, ${LAT}, 0
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






while IFS='|' read -a array
do 

#0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | 7 em1 | 8 em2 | 9 COORDINATED | 10 chan_Size | 11 record_ID
#12 Service_Ring_km | 13 Interference_Ring_km | 14 adj1_ring_km | 15 adj2_ring_km | 16 modeled | 17 model_Required | 18  model_Name
LAT="${array[0]}"
LON="${array[1]}"
AGL="${array[2]}"
ERP="${array[3]}"
FREQ="${array[4]}" 
CITY="${array[5]}"
CALL="${array[6]}"
EM1="${array[7]}"
EM2="${array[8]}"
COORD="${array[9]}"
CHAN_SIZE="${array[10]}"
ID="${array[11]}"
SVC_RING="${array[12]}"
INT_RING="${array[13]}"
ADJ1_RING="${array[14]}"
ADJ2_RING="${array[15]}"
MODELED="${array[16]}"
MOD_REQ="${array[17]}"
MOD_NAME="${array[18]}"

	if (( $(echo "${array[4]} > 29.5000"|bc -l) )) &&  (( $(echo "${array[4]} < 29.7000" |bc -l) ))
		then
		DISTANCE='300km' # Distance needs to be wider for lowband
		CRITERIA_SVC=31
		CRITERIA_INT=13
		OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
		#The output directory 
		OUTPUT_DIR="${BASE_DIR}/29"
		echo NAME: ${OUTPUTNAME}
		echo DISTANCE: ${DISTANCE}
		echo SVC CRIT: ${CRITERIA_SVC}
		echo INT CRIT: ${CRITERIA_INT}
		echo DIR: ${OUTPUT_DIR}
		echo "# frequency is between 29.5000 and 29.7000"
		echo "DOING SERVICE"
		SERVICE
		echo "DOING INTERFERENCE"
		INTERFERENCE
		echo "BUILDING KML"
		echo "${KML_HEAD}" >doc.kml
		echo "${LOC_KML}" >>doc.kml
		echo "${INF_KML}" >>doc.kml
		echo "${SVC_KML}" >>doc.kml
		#echo "${ADJ_KML}" >>doc.kml
		echo "${KML_FOOT}" >>doc.kml
		echo "BUILDING KMZ"
		MAKE_FILE
		echo "MOVING FILE"
    move ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
		echo "UPDATING DB"
    #need to write this
		echo "DONE"
	elif (( $(echo "${array[4]} > 50.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 54.0000" |bc -l) ))
		then
		DISTANCE='300km'
		CRITERIA_SVC=31
		CRITERIA_INT=13
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# frequency is between 50 and 54 "

	elif (( $(echo "${array[4]} > 144.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 146.0000" |bc -l) ))
		then 
		echo "# frequency is between 144 and 146"
			if [[ ${CHAN_SIZE} == '20.000' ]] 
			then
				CRITERIA_SVC=37
				CRITERIA_INT=19
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"

			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E)
					CRITERIA_SVC=37
					CRITERIA_INT=19
					CRITERIA_ADJ1=25
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference, $CRITERIA_INT dBu (50,10 Adjacent."
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but $EM1 is wider than 8 KHz"
					unset CRITERIA_ADJ1
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					CRITERIA_SVC=37
					CRITERIA_INT=19
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE and $EM1 is narrower than 8 KHz"
					;;
					*)
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but some error >&2"
					exit 1
					;;
				esac
			fi		 	 
	elif (( $(echo "${array[4]} > 146.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 148.0000" |bc -l) ))		
		then
		echo "# frequency is between 146 and 148"
			if [[ $CHAN_SIZE == '15.000' ]] 
			then
				CRITERIA_SVC=37
				CRITERIA_INT=19
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '7.500' ]] 
			then 
				CRITERIA_SVC=37
				CRITERIA_INT=19
				CRITERIA_ADJ1=44
				CRITERIA_ADJ2=25
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# Narrow to Narrow adjacent is $CRITERIA_ADJ1 dBu (50,10), Narrow to Wide adjacent is $CRITERIA_ADJ2 dBu (50,10)"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				unset CRITERIA_ADJ1 && unset CRITERIA_ADJ2
			fi 

	elif (( $(echo "${array[4]} > 222.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 225.0000" |bc -l) ))
		then
		echo "# frequency is between 222 and 225"
			if [[ $CHAN_SIZE == '20.000' ]] 
				then
					CRITERIA_SVC=37
					CRITERIA_INT=19
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
					echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E)
					CRITERIA_SVC=37
					CRITERIA_INT=19
					CRITERIA_ADJ1=25
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference, $CRITERIA_INT dBu (50,10 Adjacent."
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but $EM1 is wider than 8 KHz"
					unset CRITERIA_ADJ1
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					CRITERIA_SVC=37
					CRITERIA_INT=19
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE and $EM1 is narrower than 8 KHz"
					;;
					*)
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but some error >&2"
					exit 1
				esac
			fi		 	 
	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 440.0000" |bc -l) )) && [[ $CHAN_SIZE == '100.000' ]]
		then
		CRITERIA_SVC=40
		CRITERIA_INT=22
		echo "# frequency is between 420 and 440 and a 100 KHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# $CALL $FREQ is $CHAN_SIZE and emission is $EM1"
	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 440.0000" |bc -l) )) && [[ $CHAN_SIZE == '8000.000' ]]
		then
		CRITERIA_SVC=45
		CRITERIA_INT=22
		echo "# frequency is between 420 and 440 and a 8 MHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# $CALL $FREQ is $CHAN_SIZE and emission is $EM1"

	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 450.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '25.000' ]] 
			then
				CRITERIA_SVC=39
				CRITERIA_INT=21
				echo "# frequency is between 420 and 450 and a 25 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				CRITERIA_SVC=39
				CRITERIA_INT=21
				echo "# frequency is between 420 and 450 and a 12.5 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
			fi		 	 


	elif (( $(echo "${array[4]} > 902.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 928.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '25.000' ]] 
			then
				CRITERIA_SVC=40
				CRITERIA_INT=22
				echo "# frequency is between 902 and 928 and a 25 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				CRITERIA_SVC=40
				CRITERIA_INT=22
				echo "# frequency is between 902 and 928 and a 12.5 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
			fi		 	 
	elif (( $(echo "${array[4]} > 1240.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 1300.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '50.000' ]] 
			then
				CRITERIA_SVC=40
				CRITERIA_INT=22
				echo "# frequency is between 1240 and 1300 and a 50 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '100.000' ]] 
			then 
				CRITERIA_SVC=40
				CRITERIA_INT=22
				echo "# frequency is between 1240 and 1300 and a 100 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
	else echo frequency ${array[4]} of record number ${array[4]} is out of bounds
	fi
fi

done < "$TMP_FILE"
# rm "$TMP_FILE"



#
# TODO: not sure where the VARs in func. INTERFERENCE are coming from
#       or how namespaces work in bash or that you could have function calls in bash
#


#echo "${KML_HEAD}" >doc.kml
#echo "${LOC_KML}" >>doc.kml
#echo "${INF_KML}" >>doc.kml
#echo "${SVC_KML}" >>doc.kml
#echo "${ADJ_KML}" >>doc.kml
#echo "${KML_FOOT}" >>doc.kml

#make_file

exit
