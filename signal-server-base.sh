#/bin/bash
# Call Signal server from the CLI
# -sdf is the path to sdf files for US in 3 Arc seconds
# -rxh is 1.83 meters or 6 feet AGL
# -rxg is 2.15 dBi making this a 0 dBd gain on receive
# -m sets this in metric
# -pe is the propogation mode suburban (2)
# -cl 3 is Maritime sub tropical (3)
# -R 300km is a radius of 300km, perhaps 200km would be more aceptiable for most use
# -res is the resoultion of the model in Pixels per tile. 300/600/1200/3600
# -pm is the prop model (1) is ITM
#-dbg is debug
#-rel 50
#-conf
#-rt
#-txh
#-f 
#-erp
#-ant (optional)
#-scf not working
#-o output file name



#signalserver -sdf /Users/bryan/sdf -rxh 1.83 -rxg 2.15 -m \
#-pe 2 -cl 3 -R 300km -res 600 -pm 1 -dbg \
#-lat  27.947804 -lon -82.459437 -txh 145 -f 220 -erp 630  -dbg -res 1200 -ant ./ant/450Y10 -scf default.scf -o tmp

set -e
#set the SDF dir
SDFDIR=/home/SignalServer/sdf

if [[ $# -eq 0 ]] ; then
	echo Usage: all measuremetns in meters
	echo -lat/lon is location, -txh is AGL height of TX, -f is the frequesnt in MHz, -erp is the ERPd in Watts
	echo "-rt is the signal level in dBu, -conf is the longly-rice confidence in percent (50 or 10), -o is output" 
	echo $0 " -lat 27.98 -lon -82.50 -txh 150 -f 440 -erp 650 -rt 39 -conf 50 -o blueblue | ./genkmz.sh"
	echo The last argument must be the output name that matches the .scf color you want.
	exit 1
fi

for name; do true; done

time nice /usr/local/bin/signalserver -sdf $SDFDIR -rxh 1.83 -rxg 2.15 -m -pe 3 -cl 3 -te 3 -R 200km -res 600 -pm 1 -rel 50 -dbg $@ 2>&1
# to resize, add: -resize 7000x7000\>
convert $name.ppm -transparent white $name.png
rm $name.ppm
