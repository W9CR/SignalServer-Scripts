#!/bin/bash

# ./144-146-NB.sh -lat 27.60 -lon -80.39 -txh 73.15 -erp 210 -o 145.1300_AB4AX_Vero-Beach
file=$@
# 0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | emission
while IFS='|' read -a array
do 
	case ${array[7]} in 
	9K36F7W|9K80D7W|11K2F3E) 
		echo ./144-146-NB.sh -lat ${array[0]} -lon ${array[1]} -txh ${array[2]} -erp ${array[3]} \
 		-a -o ${array[4]}_${array[6]}_${array[5]}
	;;

	# adjacent not needed for <8 khz emissions	
        150HA1A|2K80J3E|4K00F1E|6K00A3E|6K25F7W|7K60FXE|8K10F1E|8K30F1E) 
                echo ./144-146-NB.sh -lat ${array[0]} -lon ${array[1]} -txh ${array[2]} -erp ${array[3]} \
                 -o ${array[4]}_${array[6]}_${array[5]}
        ;;
	*)
	;;
	esac 
done <$file
