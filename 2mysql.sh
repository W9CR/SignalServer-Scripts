#!/bin/bash

# the inserts the png image into mysql as a blob
#  
#
#  Copyright 2019 Bryan Fields
#  License: GPLv2 only
# based off genkmz


cwd=$(pwd)
while read line
do
        echo $line
        if [[ $line == Writing* ]]
        then
                while IFS='"' read -ra writingline
                do
                        filename=${writingline[1]%.*}.png
                done <<< $line
        fi
        if [[ $line == \|* ]]
        then
                while IFS='|' read -ra coords
                do 
#		echo $coords	
	echo "INSERT INTO imageStore (imageData,fileType, leftLon, rightLon, topLat, bottomLat) VALUES (LOAD_FILE('$cwd/$filename'), 'PNG', '${coords[4]}', '${coords[2]}', '${coords[1]}' ,'${coords[3]}' ); SELECT LAST_INSERT_ID();" | mysql -uadmin -pbuttplugs import

		done <<< $line
	fi
done;
exit;
