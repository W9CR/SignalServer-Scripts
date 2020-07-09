#!/bin/bash
# vim: ts=2 sw=2  
set -e
shopt -s lastpipe
TMP_FILE="/tmp/db-query-notice.txt"

# This script is desinged to send a notice to a trustee based on the record ID.


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

	else echo frequency ${array[4]} of record number ${array[4]} is out of bounds
fi
done < "$TMP_FILE"
# rm "$TMP_FILE"



#
# TODO: not sure where the VARs in func. INTERFERENCE are coming from
#       or how namespaces work in bash or that you could have function calls in bash
#


exit
