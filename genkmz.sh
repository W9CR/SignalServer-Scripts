#!/bin/bash

#  genkmz.sh
#  
#
#  Created by Bryan on 4/11/18.
#!/bin/bash
while read line
do
	echo $line
	if [[ $line == NAME:* ]]
	then
		while IFS='"' read -ra writingline
		do
			filename=${writingline[1]%.png}
		done <<< $line
	fi
	if [[ $line == \|* ]]
	then
		while IFS='|' read -ra coords
		do
			north=${coords[1]}
			east=${coords[2]}
			south=${coords[3]}
			west=${coords[4]}		
		done <<< $line
	fi
done

echo filename is: $filename ccords are $north $east $south $west	

cat << EOF > doc.kml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
<Placemark> 
 <name>$filename</name> 
 <description>$filename</description>
 <Point>
  <coordinates>
   -82.01, 30.34, 0 
  </coordinates>
 </Point> 
</Placemark>
<GroundOverlay>
    <name>$filename</name>
    <color>a0ffffff</color>
    <Icon>
        <href>$filename.png</href>
    </Icon>
    <LatLonBox>
        <north>$north</north>
        <east>$east</east>
        <south>$south</south>
        <west>$west</west>
    </LatLonBox>
</GroundOverlay>
</Document>
</kml>
EOF
echo "$@"
#echo this is the filename: "${filename}"
zip "${filename}".zip "${filename}.png" doc.kml
mv "${filename}".zip "${filename}".kmz
rm "$filename.png" doc.kml
echo Generated "${filename}".kmz
