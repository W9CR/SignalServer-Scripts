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

#0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | 7 em1 | 8 em2 | 9 COORDINATED | 10 chan_Size | 11 record_ID
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
ID="${array[10]}"

	if (( $(echo "${array[4]} > 29.5000"|bc -l) )) &&  (( $(echo "${array[4]} < 29.7000" |bc -l) ))
		then
		CRITERIA_SVC=31
		CIRTERIA_INT=13
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# frequency is between 29.5000 and 29.7000"

	elif (( $(echo "${array[4]} > 50.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 54.0000" |bc -l) ))
		then
		CRITERIA_SVC=31
		CIRTERIA_INT=13
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
		echo "# frequency is between 50 and 54 "

	elif (( $(echo "${array[4]} > 144.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 146.0000" |bc -l) ))
		then 
		echo "# frequency is between 144 and 146"
			if [[ $CHAN_SIZE == '20.000' ]] 
			then
				CRITERIA_SVC=37
				CIRTERIA_INT=19
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"

			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E)
					CRITERIA_SVC=37
					CIRTERIA_INT=19
					CRITERIA_ADJ1=25
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference, $CRITERIA_INT dBu (50,10 Adjacent."
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but $EM1 is wider than 8 KHz"
					unset CRITERIA_ADJ1
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					CRITERIA_SVC=37
					CIRTERIA_INT=19
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
				CIRTERIA_INT=19
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '7.500' ]] 
			then 
				CRITERIA_SVC=37
				CIRTERIA_INT=19
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
				CIRTERIA_INT=19
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"

				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '10.000' ]] 
			then 
				#problem here, I'm only looking at emmision 1.  It should be the widest, but I don't like assuming it
				case $EM1 in 
					9K36F7W|9K80D7W|11K2F3E)
					CRITERIA_SVC=37
					CIRTERIA_INT=19
					CRITERIA_ADJ1=25
					echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference, $CRITERIA_INT dBu (50,10 Adjacent."
					echo "# $CALL $FREQ is Narrowband $CHAN_SIZE but $EM1 is wider than 8 KHz"
					unset CRITERIA_ADJ1
					;;
					# adjacent not needed for <8 khz emissions      
					150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E)
					CRITERIA_SVC=37
					CIRTERIA_INT=19
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
		CIRTERIA_INT=22
		echo "# frequency is between 420 and 440 and a 100 KHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 440.0000" |bc -l) )) && [[ $CHAN_SIZE == '8000.000' ]]
		then
		CRITERIA_SVC=45
		CIRTERIA_INT=22
		echo "# frequency is between 420 and 440 and a 8 MHz Channel"
		echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"


	
	elif (( $(echo "${array[4]} > 420.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 450.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '25.000' ]] 
			then
				CRITERIA_SVC=39
				CIRTERIA_INT=21
				echo "# frequency is between 420 and 450 and a 25 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				CRITERIA_SVC=39
				CIRTERIA_INT=21
				echo "# frequency is between 420 and 450 and a 12.5 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
			fi		 	 


        elif (( $(echo "${array[4]} > 902.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 928.0000" |bc -l) ))
                then
			if [[ $CHAN_SIZE == '25.000' ]] 
			then
				CRITERIA_SVC=40
				CIRTERIA_INT=22
				echo "# frequency is between 902 and 928 and a 25 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '12.500' ]] 
			then 
				CRITERIA_SVC=40
				CIRTERIA_INT=22
				echo "# frequency is between 902 and 928 and a 12.5 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
			fi		 	 
	elif (( $(echo "${array[4]} > 1240.0000"|bc -l) )) &&  (( $(echo "${array[4]} < 1300.0000" |bc -l) ))
		then
			if [[ $CHAN_SIZE == '50.000' ]] 
			then
				CRITERIA_SVC=40
				CIRTERIA_INT=22
				echo "# frequency is between 1240 and 1300 and a 50 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is wideband $CHAN_SIZE"
			elif [[ $CHAN_SIZE == '100.000' ]] 
			then 
				CRITERIA_SVC=40
				CIRTERIA_INT=22
				echo "# frequency is between 1240 and 1300 and a 100 KHz Channel"
				echo "# Criteria is $CRITERIA_SVC dBu (50,50) Service, $CRITERIA_INT dBu (50,10) Interference"
				echo "# $CALL $FREQ is NarrowBand $CHAN_SIZE"
	else echo frequency ${array[4]} of record number ${array[4]} is out of bounds
	fi
fi

#`echo ./144-146-WB.sh -lat ${array[0]} -lon ${array[1]} -txh ${array[2]} -erp ${array[3]} \
# -o ${array[4]}_${array[6]}_${array[5]}`
done < "$TMP_FILE"
# rm "$TMP_FILE"

