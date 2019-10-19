#/bin/bash
# Call Signal server from the CLI

set -e
#set the SDF dir
SDFDIR=/home/SignalServer/sdf

#     -rel Reliability for ITM model (% of 'time') 1 to 99 (optional, default 50%)
#     -conf Confidence for ITM model (% of 'situations') 1 to 99 (optional, default 50%)

REL='10'
# Confidance 
CONF='50'
#color file
COLOR='green'
#critera in dbu
CRITERA='19'
#frequency
FREQ='147'

if [[ $# -eq 0 ]] ; then
	echo Usage: all measuremetns in meters
	echo -lat/lon is location, -txh is AGL height of TX, -f is the frequesnt in MHz, -erp is the ERPd in Watts
	echo "-rt is the signal level in dBu, -conf is the longly-rice confidence in percent (50 or 10), -o is output" 
	echo $0 " -lat 27.98 -lon -82.50 -txh 150 -f 440 -erp 650 -rt 39 -conf 50 -o blueblue | ./genkmz.sh"
	echo The last argument must be the output name that matches the .scf color you want.
	exit 1
fi

for name; do true; done

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R 200km -res 600 \
     -pm 1 -rel $REL -f $FREQ -conf $CONF -color $COLOR -rt $CRITERA -dbg $@ 2>&1
# to resize, add: -resize 7000x7000\>
convert $name.ppm -transparent white $name.png
rm $name.ppm
