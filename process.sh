#!/bin/bash

# ./144-146-WB.sh -lat 27.60 -lon -80.39 -txh 73.15 -erp 210 -o 145.1300_AB4AX_Vero-Beach
file='/tmp/145mhz.txt'
# 0 Lat | 1 Long | 2 AGL | 3 ERP | 4 Freq | 5 City | 6 call | emission
while IFS='|' read -a array
do 
`echo ./144-146-WB.sh -lat ${array[0]} -lon ${array[1]} -txh ${array[2]} -erp ${array[3]} \
 -o ${array[4]}_${array[6]}_${array[5]}`
done <$file
