#!/bin/bash
# vim: ts=2 sw=2  
set -e
shopt -s lastpipe
TMP_FILE="/tmp/db-query-notice.txt"

# This script is desinged to send a notice to a trustee based on the record ID.


#default for NODUPDATE
NOUPDATE='0'

function Query_DB {
#Function to query the DB

Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
  REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
  COORDINATED, chan_Size_kHz, record_ID, Service_Ring_km, Interference_Ring_km, adj1_ring_km, adj2_ring_km, modeled, model_Required, model_Name,
  CTCSS_IN, CTCSS_OUT, DCS_CODE, Holder_name, Trustee_name, Trustee_email_adddress, County, Repeater_city
  FROM filemaker  WHERE record_ID = '${RECORD_ID}';"
 #       echo "$Query"
        mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE"
#cat $TMP_FILE
}

function READ_FILE {
while IFS='|' read -a array
do 

#0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | 7 em1 | 8 em2 | 9 COORDINATED | 10 chan_Size | 11 record_ID
#12 Service_Ring_km | 13 Interference_Ring_km | 14 adj1_ring_km | 15 adj2_ring_km | 16 modeled | 17 model_Required | 18  model_Name
#19 CTCSS_IN | 20 CTCSS_OUT | 21 DCS_CODE | 22 Holder | 23 Trustee | 24 Trustee Email | 25 County | 26 City
LAT="${array[0]}"
LON="${array[1]}"
AGL="${array[2]}"
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
MODEL_URL="${array[18]}"
CTCSS_IN="${array[19]}"
CTCSS_OUT="${array[20]}"
DCS_CODE="${array[21]}"
HOLDER="${array[22]}"
TRUSTEE="${array[23]}"
TRUSTEE_EMAIL="${array[24]}"
REPEATER_COUNTY="${array[25]}"
REPEATER_CITY="${array[26]}"
done < "$TMP_FILE"
# rm "$TMP_FILE"

}

function COMPOSE_EMAIL {

if [ -z ${TRUSTEE_EMAIL} ] || [ ${TRUSTEE_EMAIL} = NULL ]
then
	echo "ERROR: Record: ${ID} TRUSTEE_EMAIL is NULL or Empty"
	exit 255
fi  

while IFS= read -r line
do
	while [[ "$line" =~ (\$\{[a-zA-Z_][a-zA-Z_0-9]*\}) ]] ; do
        LHS=${BASH_REMATCH[1]}
        RHS="$(eval echo "\"$LHS\"")"
        line=${line//$LHS/$RHS}
    	done
    echo "$line"
done < "$TEXT_FILE"
}



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
		TEXT_FILE="$2"
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

# model only one record ID

if [[ ! -z ${RECORD_ID} ]]
	then
	Query_DB
fi
if [[ -z ${TEXT_FILE} ]]
	then
	echo "ERROR: -input missing template file name"
	exit 255
fi




READ_FILE
COMPOSE_EMAIL
