#!/bin/bash

set -e
shopt -s lastpipe
TMP_FILE="/tmp/db-query.txt"

# ./144-146-WB.sh -lat 27.60 -lon -80.39 -txh 73.15 -erp 210 -o 145.1300_AB4AX_Vero-Beach
#file='/tmp/145mhz.txt'
# 0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | emission

# This will run through all models as a query from the db

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
case $key in
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
	echo FREQ_LOW \"$FREQ_LOW\"
	echo FREQ_HIGH \"$FREQ_HIGH\"
 	Query="SELECT Latitude, Longitude, antenna_Height_Meters , ERP,  Output_frequency, 
        REPLACE(Repeater_city, ' ','-') AS City, Repeater_callsign,  emission_1, emission_2, 
	COORDINATED, chan_Size_kHz, record_ID
        FROM filemaker  WHERE Output_frequency BETWEEN '$FREQ_LOW' AND '$FREQ_HIGH' AND COORDINATED = '1' 
        ORDER BY  Output_frequency ;"
	echo "$Query"
	mysql import -e "$Query" -NB | tr '\t' '|' >"$TMP_FILE"
#	cat $TMP_FILE
elif [[ ! -z ${FREQ_LOW+x} || ! -z ${FREQ_HIGH+x} ]]
then 
	echo FREQ_LOW or FREQ_HIGH must be set
fi


while IFS='|' read -a array
do 
echo "FREQ = ${array[4]}"
        if (( $(echo "${array[4]} > 29.5000"|bc -l) )) &&  (( $(echo "${array[4]} < 29.7000" |bc -l) ))
                then
                echo frequency is between 29.5000 and 29.7000

        elif (( $(echo "${array[4]} > 50.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 54.0000" |bc -l) ))
                then
                echo frequency is between 50 and 54 
	elif (( $(echo "${array[4]} > 144.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 146.0000" |bc -l) ))
		then 
		echo frequency is between 144 and 146
	elif (( $(echo "${array[4]} > 146.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 148.0000" |bc -l) ))		
		then
		echo frequency is between 146 and 148
        elif (( $(echo "${array[4]} > 222.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 225.0000" |bc -l) ))
                then
                echo frequency is between 222 and 225
        elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 450.0000" |bc -l) ))
                then
                echo frequency is between 420 and 450
        elif (( $(echo "${array[4]} > 902.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 928.0000" |bc -l) ))
                then
                echo frequency is between 902 and 928
        elif (( $(echo "${array[4]} > 1240.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 1300.0000" |bc -l) ))
                then
                echo frequency is between 1240 and 1300
	else echo frequency ${array[4]} of record number ${array[4]} is out of bounds
	fi


#`echo ./144-146-WB.sh -lat ${array[0]} -lon ${array[1]} -txh ${array[2]} -erp ${array[3]} \
# -o ${array[4]}_${array[6]}_${array[5]}`
done < "$TMP_FILE"
