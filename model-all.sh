#!/bin/bash
# vim: ts=2 sw=2  
set -e
shopt -s lastpipe
TMP_FILE="/tmp/db-query.txt"

# This will run through all models as a query from the db

SDFDIR=/home/SignalServer/sdf

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
SUFFIX_ADJ1='Adjacent-Narrow'
SUFFIX_ADJ2='Adjacent-Wide'
#color file
COLOR_SVC='blueblue'
COLOR_INF='green'
COLOR_ADJ='orange'
COLOR_ADJ1='yellow'
COLOR_ADJ2='magenta'
#BASE DIR
BASE_DIR='/home/SignalServer/plots'

#default for NODUPDATE
NOUPDATE='0'

# Options 
# -id database ID
# -model even if modeled flag is set in db
# -noupdate don't update db
# frequency range -flow 144.0000 -fhigh 146.0000
# -scandb scan the db for models needing to be built and process them

POSITIONAL=()
while [[ $# -gt 0 ]]
	do
	key="$1"
	case ${key} in
		-id) #db ID to model
		RECORD_ID="$2"
		shift # past argument=value
		shift
		;;
		-input) #input file name
		INPUT_FILE="$2"
		shift
		;;
		-noupdate)
		NOUPDATE='1'
		shift # past argument=value
		;;
		-scandb)
		SCANDB='1'
		shift # past argument=value
		;;
		-modeled)
		MODELED='1'
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

#Below is run to match the DB

if [[ ${SCANDB} = '1' ]]
	then
		echo "SCANNING DATABASE FOR CHANGES"
	  Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
		REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
		COORDINATED, chan_Size_kHz, record_ID, Service_Ring_km, Interference_Ring_km, adj1_ring_km, adj2_ring_km, modeled, model_Required, model_Name
		FROM filemaker  WHERE model_Required = '1' ;"
	  echo "$Query"
	  mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE" 
fi

if [[ ${MODELED} = '1' ]]
	then
		echo "ignore modeled ones"
		modeled=" AND modeled = '0'"
fi

if [[ ! -z ${FREQ_LOW} && ! -z ${FREQ_HIGH} ]] 
then
	echo FREQ_LOW \"${FREQ_LOW}\"
	echo FREQ_HIGH \"${FREQ_HIGH}\"
	Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
  REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
  COORDINATED, chan_Size_kHz, record_ID, Service_Ring_km, Interference_Ring_km, adj1_ring_km, adj2_ring_km, modeled, model_Required, model_Name
  FROM filemaker  WHERE Output_frequency BETWEEN '${FREQ_LOW}' AND '${FREQ_HIGH}' AND COORDINATED = '1'  ${modeled}
  ORDER BY  Output_frequency ;"
	echo "$Query"
	mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE"
#	cat $TMP_FILE
elif [[ ! -z ${FREQ_LOW+x} || ! -z ${FREQ_HIGH+x} ]]
then 
	echo FREQ_LOW and FREQ_HIGH must be set
fi

# model only one record ID

if [[ ! -z ${RECORD_ID} ]]
then
	Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
  REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
  COORDINATED, chan_Size_kHz, record_ID, Service_Ring_km, Interference_Ring_km, adj1_ring_km, adj2_ring_km, modeled, model_Required, model_Name
  FROM filemaker  WHERE record_ID = '${RECORD_ID}';"
	echo "$Query"
	mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE"
fi

#Take an input file and model it
#will this overwrite another file?  idk
if [[ ! -z ${INPUT_FILE} ]]
then
	TMP_FILE="${INPUT_FILE}"
fi

function SERVICE {

SUFFIX=${SUFFIX_SVC}

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
     	-pm 1 -rel $REL_SVC -f $FREQ -conf $CONF -color $COLOR_SVC -rt ${CRITERIA_SVC} -dbg -lat $LAT -lon $LON -txh $TXH \
	-erp $ERP -o $OUTPUTNAME 2>&1 | 
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
echo "NAME: ${OUTPUTNAME}_${SUFFIX}"
filename_svc=${OUTPUTNAME}_${SUFFIX}.png
echo FILENAME: ${filename_svc}
convert ${OUTPUTNAME}.ppm -transparent white ${filename_svc}
rm ${OUTPUTNAME}.ppm

echo filename is: ${filename_svc} ccords are ${north_svc} ${east_svc} ${south_svc} ${west_svc}

SVC_KML="$(cat << EOF 
<GroundOverlay>
    <name>${SUFFIX} ${FREQ} ${CALL}</name>
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
        -pm 1 -rel $REL_INF -f $FREQ -conf $CONF -color $COLOR_INF -rt ${CRITERIA_INT} -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTNAME 2>&1 |
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
echo NAME: ${OUTPUTNAME}_${SUFFIX}
filename_inf=${OUTPUTNAME}_${SUFFIX}.png
echo FILENAME: ${filename_inf}
convert ${OUTPUTNAME}.ppm -transparent white ${filename_inf}
rm ${OUTPUTNAME}.ppm

echo filename is: ${filename_inf} coords are ${north_inf} ${east_inf} ${south_inf} ${west_inf}

INF_KML="$(cat << EOF 
<GroundOverlay>
    <name>${SUFFIX} ${FREQ} ${CALL}</name>
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
#this function is only used if there's a single adjacency

SUFFIX=${SUFFIX_ADJ}

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel $REL_ADJ -f $FREQ -conf $CONF -color $COLOR_ADJ -rt ${CRITERIA_ADJ} -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTNAME 2>&1 |
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
echo NAME: ${OUTPUTNAME}_${SUFFIX}
filename_adj=${OUTPUTNAME}_${SUFFIX}.png
echo FILENAME: ${filename_adj}
convert $OUTPUTNAME.ppm -transparent white ${filename_adj}
rm $OUTPUTNAME.ppm

echo filename is: ${filename_adj} ccords are ${north_adj} ${east_adj} ${south_adj} ${west_adj}

ADJ_KML="$(cat << EOF 
<GroundOverlay>
    <name>${SUFFIX} ${FREQ} ${CALL}</name>
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


function ADJACENT_1 {
#this function is only used 146-148 if TX is 7.5 KHz to 7.5 KHz

SUFFIX=${SUFFIX_ADJ1}

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel ${REL_ADJ1} -f ${FREQ} -conf ${CONF} -color ${COLOR_ADJ1} -rt ${CRITERIA_ADJ1} -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTNAME 2>&1 |
while read line
        do
        echo ${line}
        if [[ ${line} == \|* ]]
                then
                while IFS='|' read -ra coords
                do
                        north_adj1=${coords[1]}
                        east_adj1=${coords[2]}
                        south_adj1=${coords[3]}
                        west_adj1=${coords[4]}
                done <<< ${line}
        fi
done
# to resize, add: -resize 7000x7000\>
echo NAME: ${OUTPUTNAME}_${SUFFIX}
filename_adj1=${OUTPUTNAME}_${SUFFIX}.png
echo FILENAME: ${filename_adj1}
convert $OUTPUTNAME.ppm -transparent white ${filename_adj1}
rm $OUTPUTNAME.ppm

echo filename is: ${filename_adj1} coords are ${north_adj1} ${east_adj1} ${south_adj1} ${west_adj1}

ADJ_KML1="$(cat << EOF 
<GroundOverlay>
    <name>${SUFFIX} ${FREQ} ${CALL}</name>
    <color>a0ffffff</color>
    <Icon>
        <href>${filename_adj1}</href>
    </Icon>
    <LatLonBox>
        <north>${north_adj1}</north>
        <east>${east_adj1}</east>
        <south>${south_adj1}</south>
        <west>${west_adj1}</west>
    </LatLonBox>
</GroundOverlay>
EOF
)"
}


function ADJACENT_2 {
#this function is only used from 146-148 if TX is 7.5 KHz Spliter adjacent to a 15KHz Wide Band

SUFFIX=${SUFFIX_ADJ2}

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R $DISTANCE -res 600 \
        -pm 1 -rel ${REL_ADJ2} -f ${FREQ} -conf ${CONF} -color ${COLOR_ADJ2} -rt ${CRITERIA_ADJ2} -dbg -lat $LAT -lon $LON -txh $TXH \
        -erp $ERP -o $OUTPUTNAME 2>&1 |
while read line
        do
        echo ${line}
        if [[ ${line} == \|* ]]
                then
                while IFS='|' read -ra coords
                do
                        north_adj2=${coords[1]}
                        east_adj2=${coords[2]}
                        south_adj2=${coords[3]}
                        west_adj2=${coords[4]}
                done <<< ${line}
        fi
done
# to resize, add: -resize 7000x7000\>
echo NAME: ${OUTPUTNAME}_${SUFFIX}
filename_adj2=${OUTPUTNAME}_${SUFFIX}.png
echo FILENAME: ${filename_adj2}
convert $OUTPUTNAME.ppm -transparent white ${filename_adj2}
rm $OUTPUTNAME.ppm

echo filename is: ${filename_adj2} coords are ${north_adj2} ${east_adj2} ${south_adj2} ${west_adj2}

ADJ_KML2="$(cat << EOF 
<GroundOverlay>
    <name>${SUFFIX} ${FREQ} ${CALL}</name>
    <color>a0ffffff</color>
    <Icon>
        <href>${filename_adj2}</href>
    </Icon>
    <LatLonBox>
        <north>${north_adj2}</north>
        <east>${east_adj2}</east>
        <south>${south_adj2}</south>
        <west>${west_adj2}</west>
    </LatLonBox>
</GroundOverlay>
EOF
)"
}


function MAKE_FILE {
zip ${OUTPUTNAME}.zip ${filename_svc} ${filename_inf} ${filename_adj} ${filename_adj1} ${filename_adj2} doc.kml
mv ${OUTPUTNAME}.zip ${OUTPUTNAME}.kmz
rm ${filename_svc} ${filename_inf} ${filename_adj} ${filename_adj1} ${filename_adj2} #doc.kml
echo Generated ${OUTPUTNAME}.kmz
}
function UNSET {
unset filename_svc 
unset filename_inf 
unset filename_adj 
unset filename_adj1 
unset filename_adj2 
}

#this function builds the placemark part of the KML.  
function BUILD_LOC_KML {
LOC_KML="$(cat << EOF
<Placemark> 
 <name>${FREQ} ${CALL} ${CITY}</name> 
  <description><![CDATA[<pre>
RECORD: ${ID}
CALL: ${CALL}
CITY: ${CITY}
FREQ: ${FREQ} 
STATUS: ${COORD}
ERP: ${ERP}		AGL: ${TXH} m
LAT: ${LAT}		LON: ${LON}
EM1: ${EM1}		EM2: ${EM2}
Channel Size: ${CHAN_SIZE} kHz
Service Criteria: ${CRITERIA_SVC} dBu (50,50)  
Service Contour: ${SVC_RING} km
Interference/Adjacent Criteria: ${CRITERIA_INT} dBu (50,10)
Interference Contour: ${INT_RING} km
Adjacent Contour: ${ADJ1_RING} km 
Adjacent-Narrow : ${ADJ1_RING} km
Adjacent-Wide 	: ${ADJ2_RING} km
Note: 
Adjacent Contours are only used in certian cases.
</pre>
<br>
<a href=https://plots.fasma.org>Plots of all Coordinated repeaters in FASMA Database</a>
<br><br>
<a href=https://fasma.org>fasma.org</a>  
]]></description>

<Point>
  <coordinates>
   ${LON}, ${LAT}, 0
  </coordinates>
 </Point> 
</Placemark>
EOF
)"
}

function UPDATE_DB {
	WEB_PATH="$(echo ${OUTPUT_DIR}/${OUTPUTNAME}.kmz |sed 's/\/home\/SignalServer\/plots//g')"
	Query="UPDATE filemaker SET modeled = '1', model_Required = '0', model_Name ='https://plots.fasma.org${WEB_PATH}' where record_ID ='${ID}';"
	echo "$Query"
	mysql import -e "${Query}" -NB 
}

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

#this is the main loop for the program and the coordination logic

while IFS='|' read -a array
do 

#0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | 7 em1 | 8 em2 | 9 COORDINATED | 10 chan_Size | 11 record_ID
#12 Service_Ring_km | 13 Interference_Ring_km | 14 adj1_ring_km | 15 adj2_ring_km | 16 modeled | 17 model_Required | 18  model_Name
LAT="${array[0]}"
LON="${array[1]}"
TXH="${array[2]}"
ERP="${array[3]}"
FREQ="${array[4]}" 
CITY="${array[5]}"
CALL="${array[6]}"
EM1="${array[7]}"
EM2="${array[8]}"
if [[ ${array[9]} = 1 ]]
	then
	COORD="COORDINATED"
	else
	COORD="UNCOORDINATED"
fi
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
		CRITERIA_SVC='31'
		CRITERIA_INT='13'
		OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
		if [[ ${array[9]} = 1 ]] 
			then
				#The output directory for coordinated repeaters
				OUTPUT_DIR="${BASE_DIR}/29"
			else 
				OUTPUT_DIR="${BASE_DIR}/uncoordinated"
		fi
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
		BUILD_LOC_KML
		#make the doc.xml file
		echo "${KML_HEAD}" >doc.kml
		echo "${LOC_KML}" >>doc.kml
		echo "${INF_KML}" >>doc.kml
		echo "${SVC_KML}" >>doc.kml
		echo "${KML_FOOT}" >>doc.kml
		echo "BUILDING KMZ"
		MAKE_FILE
		echo "MOVING FILE"
    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
		if [[ ${NOUPDATE} = 0 ]]
			then
			echo "UPDATING DB"
    	UPDATE_DB
			else
			echo "NOT UPDATING DB"
		fi
		UNSET
		echo "DONE"
	#6 meters
	elif (( $(echo "${array[4]} > 50.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 54.0000" |bc -l) ))
		then
		DISTANCE='300km' # Distance needs to be wider for lowband
		CRITERIA_SVC='31'
		CRITERIA_INT='13'
		OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
		if [[ ${array[9]} = 1 ]] 
			then
				#The output directory for coordinated repeaters
				OUTPUT_DIR="${BASE_DIR}/50"
			else 
				OUTPUT_DIR="${BASE_DIR}/uncoordinated"
		fi
		echo NAME: ${OUTPUTNAME}
		echo DISTANCE: ${DISTANCE}
		echo SVC CRIT: ${CRITERIA_SVC}
		echo INT CRIT: ${CRITERIA_INT}
		echo DIR: ${OUTPUT_DIR}
		echo "# frequency is between 50.0000 and 54.0000"
		echo "DOING SERVICE"
		SERVICE
		echo "DOING INTERFERENCE"
		INTERFERENCE
		echo "BUILDING KML"
		BUILD_LOC_KML
		#make the doc.xml file
		echo "${KML_HEAD}" >doc.kml
		echo "${LOC_KML}" >>doc.kml
		echo "${INF_KML}" >>doc.kml
		echo "${SVC_KML}" >>doc.kml
		echo "${KML_FOOT}" >>doc.kml
		echo "BUILDING KMZ"
		MAKE_FILE
		echo "MOVING FILE"
    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
		if [[ ${NOUPDATE} = 0 ]]
			then
			echo "UPDATING DB"
    	UPDATE_DB
			else
			echo "NOT UPDATING DB"
		fi
		UNSET	
		echo "DONE"
	elif (( $(echo "${array[4]} > 144.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 146.0000" |bc -l) ))
		then 
		echo "# frequency is between 144 and 146"
			if [[ ${CHAN_SIZE} == '20.000' ]] 
			then
				DISTANCE='200km' # only model out to 200km
				CRITERIA_SVC='37'
				CRITERIA_INT='19'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/144"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
		    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
    				UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"

			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				# on a 10 khz channel we only need to model tx to adjacent if the signal is >8 KHz occupied bandwidth
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E) #these emissions are >8 KHz
					DISTANCE='200km' # only model out to 200km
					CRITERIA_SVC='37'
					CRITERIA_INT='19'
					CRITERIA_ADJ='25'
					OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
					if [[ ${array[9]} = 1 ]] 
						then
							#The output directory for coordinated repeaters
							OUTPUT_DIR="${BASE_DIR}/144"
						else 
							OUTPUT_DIR="${BASE_DIR}/uncoordinated"
					fi
					echo NAME: ${OUTPUTNAME}
					echo DISTANCE: ${DISTANCE}
					echo SVC CRIT: ${CRITERIA_SVC}
					echo INT CRIT: ${CRITERIA_INT}
					echo DIR: ${OUTPUT_DIR}
					echo "DOING SERVICE"
					SERVICE
					echo "DOING INTERFERENCE"
					INTERFERENCE
					echo "DOING ADJACENT"
					ADJACENT
					echo "BUILDING KML"
					BUILD_LOC_KML
					#make the doc.xml file
					echo "${KML_HEAD}" >doc.kml
					echo "${LOC_KML}" >>doc.kml
					echo "${INF_KML}" >>doc.kml
					echo "${ADJ_KML}" >>doc.kml
					echo "${SVC_KML}" >>doc.kml
					echo "${KML_FOOT}" >>doc.kml
					echo "BUILDING KMZ"
					MAKE_FILE
					echo "MOVING FILE"
			    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
					if [[ ${NOUPDATE} = 0 ]]
						then
							echo "UPDATING DB"
    					UPDATE_DB
						else
							echo "NOT UPDATING DB"
					fi
					UNSET
					echo "DONE"

					unset CRITERIA_ADJ1
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					DISTANCE='200km' # only model out to 200km
					CRITERIA_SVC='37'
					CRITERIA_INT='19'
					OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
					if [[ ${array[9]} = 1 ]] 
						then
							#The output directory for coordinated repeaters
							OUTPUT_DIR="${BASE_DIR}/144"
						else 
							OUTPUT_DIR="${BASE_DIR}/uncoordinated"
					fi
					echo NAME: ${OUTPUTNAME}
					echo DISTANCE: ${DISTANCE}
					echo SVC CRIT: ${CRITERIA_SVC}
					echo INT CRIT: ${CRITERIA_INT}
					echo DIR: ${OUTPUT_DIR}
					echo "DOING SERVICE"
					SERVICE
					echo "DOING INTERFERENCE"
					INTERFERENCE
					echo "BUILDING KML"
					BUILD_LOC_KML
					#make the doc.xml file
					echo "${KML_HEAD}" >doc.kml
					echo "${LOC_KML}" >>doc.kml
					echo "${INF_KML}" >>doc.kml
					echo "${SVC_KML}" >>doc.kml
					echo "${KML_FOOT}" >>doc.kml
					echo "BUILDING KMZ"
					MAKE_FILE
					echo "MOVING FILE"
			    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
					if [[ ${NOUPDATE} = 0 ]]
						then
							echo "UPDATING DB"
 							UPDATE_DB
						else
							echo "NOT UPDATING DB"
					fi
					UNSET
					echo "DONE"
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
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				DISTANCE='200km' # only model out to 200km
				CRITERIA_SVC='37'
				CRITERIA_ADJ='42'
				CRITERIA_INT='19'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/144"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "DOING ADJACENT"
				ADJACENT
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${ADJ_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
		    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
   					UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"


			elif [[ $CHAN_SIZE == '7.500' ]] 
			then 
				# and here we need to model adj1 and adj2  fucking 7.5 KHz channels.  2 meters is so fucked.
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				DISTANCE='200km' # only model out to 200km
				CRITERIA_SVC='37'
				CRITERIA_ADJ1='44'
        CRITERIA_ADJ2='25'
				CRITERIA_INT='19'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/144"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "DOING ADJACENT_1"
				ADJACENT_1
        echo "DOING ADJACENT_2"
        ADJACENT_2
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file bottom most file is the top on display
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${ADJ_KML2}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml 
				echo "${ADJ_KML1}" >>doc.kml 
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
		    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
   					UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
				unset CRITERIA_ADJ1 && unset CRITERIA_ADJ2
			fi 

	elif (( $(echo "${array[4]} > 222.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 225.0000" |bc -l) ))
		then
		echo "# frequency is between 222 and 225"
			if [[ $CHAN_SIZE == '20.000' ]] 
				then
					# 222 is same as 2m below 146 mhz
					DISTANCE='200km' # only model out to 200km
					CRITERIA_SVC='37'
					CRITERIA_INT='19'
					OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
					if [[ ${array[9]} = 1 ]] 
						then
							#The output directory for coordinated repeaters
							OUTPUT_DIR="${BASE_DIR}/222"
						else 
							OUTPUT_DIR="${BASE_DIR}/uncoordinated"
					fi
					echo NAME: ${OUTPUTNAME}
					echo DISTANCE: ${DISTANCE}
					echo SVC CRIT: ${CRITERIA_SVC}
					echo INT CRIT: ${CRITERIA_INT}
					echo DIR: ${OUTPUT_DIR}
					echo "DOING SERVICE"
					SERVICE
					echo "DOING INTERFERENCE"
					INTERFERENCE
					echo "BUILDING KML"
					BUILD_LOC_KML
					#make the doc.xml file
					echo "${KML_HEAD}" >doc.kml
					echo "${LOC_KML}" >>doc.kml
					echo "${INF_KML}" >>doc.kml
					echo "${SVC_KML}" >>doc.kml
					echo "${KML_FOOT}" >>doc.kml
					echo "BUILDING KMZ"
					MAKE_FILE
					echo "MOVING FILE"
			    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
					if [[ ${NOUPDATE} = 0 ]]
						then
							echo "UPDATING DB"
 		   				UPDATE_DB
						else
							echo "NOT UPDATING DB"
					fi
					UNSET
					echo "DONE"
			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				# on a 10 khz channel we only need to model tx to adjacent if the signal is >8 KHz occupied bandwidth
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E) #these emissions are >8 KHz
					DISTANCE='200km' # only model out to 200km
					CRITERIA_SVC='37'
					CRITERIA_INT='19'
					CRITERIA_ADJ='25'
					OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
					if [[ ${array[9]} = 1 ]] 
						then
							#The output directory for coordinated repeaters
							OUTPUT_DIR="${BASE_DIR}/222"
						else 
							OUTPUT_DIR="${BASE_DIR}/uncoordinated"
					fi
					echo NAME: ${OUTPUTNAME}
					echo DISTANCE: ${DISTANCE}
					echo SVC CRIT: ${CRITERIA_SVC}
					echo INT CRIT: ${CRITERIA_INT}
					echo DIR: ${OUTPUT_DIR}
					echo "DOING SERVICE"
					SERVICE
					echo "DOING INTERFERENCE"
					INTERFERENCE
					echo "DOING ADJACENT"
					ADJACENT
					echo "BUILDING KML"
					BUILD_LOC_KML
					#make the doc.xml file
					echo "${KML_HEAD}" >doc.kml
					echo "${LOC_KML}" >>doc.kml
					echo "${INF_KML}" >>doc.kml
					echo "${ADJ_KML}" >>doc.kml
					echo "${SVC_KML}" >>doc.kml
					echo "${KML_FOOT}" >>doc.kml
					echo "BUILDING KMZ"
					MAKE_FILE
					echo "MOVING FILE"
			    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
					if [[ ${NOUPDATE} = 0 ]]
						then
							echo "UPDATING DB"
    					UPDATE_DB
						else
							echo "NOT UPDATING DB"
					fi
					UNSET
					echo "DONE"
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					DISTANCE='200km' # only model out to 200km
					CRITERIA_SVC='37'
					CRITERIA_INT='19'
					OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
					if [[ ${array[9]} = 1 ]] 
						then
							#The output directory for coordinated repeaters
							OUTPUT_DIR="${BASE_DIR}/222"
						else 
							OUTPUT_DIR="${BASE_DIR}/uncoordinated"
					fi
					echo NAME: ${OUTPUTNAME}
					echo DISTANCE: ${DISTANCE}
					echo SVC CRIT: ${CRITERIA_SVC}
					echo INT CRIT: ${CRITERIA_INT}
					echo DIR: ${OUTPUT_DIR}
					echo "DOING SERVICE"
					SERVICE
					echo "DOING INTERFERENCE"
					INTERFERENCE
					echo "BUILDING KML"
					BUILD_LOC_KML
					#make the doc.xml file
					echo "${KML_HEAD}" >doc.kml
					echo "${LOC_KML}" >>doc.kml
					echo "${INF_KML}" >>doc.kml
					echo "${SVC_KML}" >>doc.kml
					echo "${KML_FOOT}" >>doc.kml
					echo "BUILDING KMZ"
					MAKE_FILE
					echo "MOVING FILE"
			    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
					if [[ ${NOUPDATE} = 0 ]]
						then
							echo "UPDATING DB"
 							UPDATE_DB
						else
							echo "NOT UPDATING DB"
					fi
					UNSET
					echo "DONE"
					;;
					*)
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but some error >&2"
					exit 1
					;;
				esac
			fi		 	 
	
	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 440.0000" |bc -l) )) && [[ $CHAN_SIZE == '100.000' ]]
		then
		#the 420-440 MHz 100 KHz Channels.  No Adjacent users, and liekly won't be omni
		DISTANCE='200km'
		CRITERIA_SVC='40'
		CRITERIA_INT='22'
		echo "# frequency is between 420 and 440 and a 100 KHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# $CALL $FREQ is $CHAN_SIZE and emission is $EM1"
		OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
		if [[ ${array[9]} = 1 ]] 
			then
				#The output directory for coordinated repeaters
				OUTPUT_DIR="${BASE_DIR}/420"
			else 
				OUTPUT_DIR="${BASE_DIR}/uncoordinated"
		fi
		echo NAME: ${OUTPUTNAME}
		echo DISTANCE: ${DISTANCE}
		echo SVC CRIT: ${CRITERIA_SVC}
		echo INT CRIT: ${CRITERIA_INT}
		echo DIR: ${OUTPUT_DIR}
		echo "DOING SERVICE"
		SERVICE
		echo "DOING INTERFERENCE"
		INTERFERENCE
		echo "BUILDING KML"
		BUILD_LOC_KML
		#make the doc.xml file
		echo "${KML_HEAD}" >doc.kml
		echo "${LOC_KML}" >>doc.kml
		echo "${INF_KML}" >>doc.kml
		echo "${SVC_KML}" >>doc.kml
		echo "${KML_FOOT}" >>doc.kml
		echo "BUILDING KMZ"
		MAKE_FILE
		echo "MOVING FILE"
    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
		if [[ ${NOUPDATE} = 0 ]]
			then
			echo "UPDATING DB"
    	UPDATE_DB
			else
			echo "NOT UPDATING DB"
		fi
		UNSET
		echo "DONE"
	

	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 440.0000" |bc -l) )) && [[ $CHAN_SIZE == '8000.000' ]]
		then
		# this is the 420-440 MHz ATV users, 8 mhz channel, 25 dB SNR
		DISTANCE='200km'
		CRITERIA_SVC='45'
		CRITERIA_INT='22'
		echo "# frequency is between 420 and 440 and a 8 MHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# $CALL $FREQ is $CHAN_SIZE and emission is $EM1"
		OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
		if [[ ${array[9]} = 1 ]] 
			then
				#The output directory for coordinated repeaters
				OUTPUT_DIR="${BASE_DIR}/420"
			else 
				OUTPUT_DIR="${BASE_DIR}/uncoordinated"
		fi
		echo NAME: ${OUTPUTNAME}
		echo DISTANCE: ${DISTANCE}
		echo SVC CRIT: ${CRITERIA_SVC}
		echo INT CRIT: ${CRITERIA_INT}
		echo DIR: ${OUTPUT_DIR}
		echo "DOING SERVICE"
		SERVICE
		echo "DOING INTERFERENCE"
		INTERFERENCE
		echo "BUILDING KML"
		BUILD_LOC_KML
		#make the doc.xml file
		echo "${KML_HEAD}" >doc.kml
		echo "${LOC_KML}" >>doc.kml
		echo "${INF_KML}" >>doc.kml
		echo "${SVC_KML}" >>doc.kml
		echo "${KML_FOOT}" >>doc.kml
		echo "BUILDING KMZ"
		MAKE_FILE
		echo "MOVING FILE"
    mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
		if [[ ${NOUPDATE} = 0 ]]
			then
			echo "UPDATING DB"
    	UPDATE_DB
			else
			echo "NOT UPDATING DB"
		fi
		UNSET
		echo "DONE"
	

	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 450.0000" |bc -l) ))
		then
			#440-450 is a 25 KHz wide and 12.5 KHz narrow, it doesn't need adjacent modeling in either case
			# a 16khz FM wide band signal has 5.25 khz away from the egde of a 11.2 KHz NB repeater
			# Digital is better 
			if [[ $CHAN_SIZE == '25.000' ]] 
			then
				echo "# frequency is between 420 and 450 and a 25 KHz Channel"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='39'
				CRITERIA_INT='21'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/440"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
		
		elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				echo "# frequency is between 420 and 450 and a 12.5 KHz Channel"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='39'
				CRITERIA_INT='21'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/440"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
			fi		 	 


	elif (( $(echo "${array[4]} > 902.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 928.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '25.000' ]] 
				then
				echo "# frequency is between 902 and 928 and a 25 KHz Channel"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='40'
				CRITERIA_INT='22'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/902"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
	
		
		elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				echo "# frequency is between 902 and 928 and a 12.5 KHz Channel"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='40'
				CRITERIA_INT='22'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/902"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
		fi		 	 
	elif (( $(echo "${array[4]} > 1240.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 1300.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '50.000' ]] 
			then
				echo "# frequency is between 1240 and 1300 and a 50 KHz Channel"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='40'
				CRITERIA_INT='22'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/1240"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
			
			elif [[ $CHAN_SIZE == '100.000' ]] 
			then 
				echo "# frequency is between 1240 and 1300 and a 100 KHz Channel"
				echo "# $CALL $FREQ $CHAN_SIZE"
				DISTANCE='200km'
				CRITERIA_SVC='40'
				CRITERIA_INT='22'
				OUTPUTNAME=${FREQ}_${CALL}_${CITY}_${ID} # This is be base name of the file
				if [[ ${array[9]} = 1 ]] 
					then
						#The output directory for coordinated repeaters
						OUTPUT_DIR="${BASE_DIR}/1240"
					else 
						OUTPUT_DIR="${BASE_DIR}/uncoordinated"
				fi
				echo NAME: ${OUTPUTNAME}
				echo DISTANCE: ${DISTANCE}
				echo SVC CRIT: ${CRITERIA_SVC}
				echo INT CRIT: ${CRITERIA_INT}
				echo DIR: ${OUTPUT_DIR}
				echo "DOING SERVICE"
				SERVICE
				echo "DOING INTERFERENCE"
				INTERFERENCE
				echo "BUILDING KML"
				BUILD_LOC_KML
				#make the doc.xml file
				echo "${KML_HEAD}" >doc.kml
				echo "${LOC_KML}" >>doc.kml
				echo "${INF_KML}" >>doc.kml
				echo "${SVC_KML}" >>doc.kml
				echo "${KML_FOOT}" >>doc.kml
				echo "BUILDING KMZ"
				MAKE_FILE
				echo "MOVING FILE"
				mv ${OUTPUTNAME}.kmz ${OUTPUT_DIR}
				if [[ ${NOUPDATE} = 0 ]]
					then
						echo "UPDATING DB"
  		  	UPDATE_DB
					else
						echo "NOT UPDATING DB"
				fi
				UNSET
				echo "DONE"
			fi
					 	 
	else echo frequency ${array[4]} of record number ${array[4]} is out of bounds
fi
done < "$TMP_FILE"
# rm "$TMP_FILE"



#
# TODO: not sure where the VARs in func. INTERFERENCE are coming from
#       or how namespaces work in bash or that you could have function calls in bash
#


exit
