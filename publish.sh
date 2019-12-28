#!/bin/bash
# vim: ts=2 sw=2  
set -e
shopt -s lastpipe
COORD_FILE="/tmp/coord-query.txt"
UNCOORD_FILE="/tmp/uncoord-query.txt"
COORD_FINAL="/home/SignalServer/plots/listings/FASMA-All-Coordinated-Repeaters.txt"
UNCOORD_FINAL="/home/SignalServer/plots/listings/FASMA-All-Uncoordinated-Repeaters.txt"
# This script will publish as pipe deleminated to the server 



QUERY="SELECT Output_frequency AS 'output', Input_frequency AS 'input', emission_1 AS 'emission1', emission_2 AS 'emission2', 
  CTCSS_IN AS 'ctcssIn', CTCSS_OUT AS 'ctcssOut',
  DMR1_COLOR_CODE AS 'dmrCc1', DMR1_GROUP_CODE 'dmrGc1', DMR2_COLOR_CODE AS 'dmrCc2', DMR2_GROUP_CODE AS 'dmrGc2',
  FUSION AS 'fusion', FUSION_DSQ AS 'fusionDsq',
  NXDN_RAN AS 'nxdnRan',
  P25_NAC AS 'p25NacOut', P25_NAC_IN AS  'p25NacIn',
  record_ID AS 'recordId', COORDINATED AS 'coordinated', Repeater_callsign AS 'callsign', Holder_name AS 'holder', Repeater_city AS 'city', 
  Coordination_date AS 'coordDate', update_date AS 'updateDate',
  Latitude AS 'latitude', Longitude AS 'longitude', antenna_Height_Meters AS 'agl',  antStructType AS 'structure', antennaModelCode AS 'antenna', 
  ERP AS 'erp', chan_Size_kHz AS 'chanSize', Service_Ring_km AS 'svcRing', Interference_Ring_km AS 'intRing', adj1_ring_km AS 'adj1Ring', adj2_ring_km AS 'adj2Ring',
  modeled AS 'modeled', model_Name AS 'modelUrl',
  AUTOPATCH AS 'autopatch', CLOSED_PATCH AS 'autopatchClosed?', BILINGUAL AS 'bilingual', DTMF AS 'dtmf', DTMF_SEQ AS 'dtmfSeq', P25_PHASE_1 AS 'p25Phase1', URL AS 'url', 
  LINKED AS 'linked?', LITZ AS 'litz', RACES AS 'races', REMOTE_BASE AS 'remoteBase', WEATHER AS 'weather', WEATHER_DTMF AS 'weatherDtmfSeq', WIDE_AREA AS 'wideAreaCoverage'
  FROM filemaker 
WHERE  COORDINATED = '1' ORDER BY output ;"


mysql import -e "$QUERY" -NB | tr '\t' '|' >"$COORD_FILE"


QUERY="SELECT Output_frequency AS 'output', Input_frequency AS 'input', emission_1 AS 'emission1', emission_2 AS 'emission2', 
  CTCSS_IN AS 'ctcssIn', CTCSS_OUT AS 'ctcssOut',
  DMR1_COLOR_CODE AS 'dmrCc1', DMR1_GROUP_CODE 'dmrGc1', DMR2_COLOR_CODE AS 'dmrCc2', DMR2_GROUP_CODE AS 'dmrGc2',
  FUSION AS 'fusion', FUSION_DSQ AS 'fusionDsq',
  NXDN_RAN AS 'nxdnRan',
  P25_NAC AS 'p25NacOut', P25_NAC_IN AS  'p25NacIn',
  record_ID AS 'recordId', COORDINATED AS 'coordinated', Repeater_callsign AS 'callsign', Holder_name AS 'holder', Repeater_city AS 'city', 
  Coordination_date AS 'coordDate', update_date AS 'updateDate',
  Latitude AS 'latitude', Longitude AS 'longitude', antenna_Height_Meters AS 'agl',  antStructType AS 'structure', antennaModelCode AS 'antenna', 
  ERP AS 'erp', chan_Size_kHz AS 'chanSize', Service_Ring_km AS 'svcRing', Interference_Ring_km AS 'intRing', adj1_ring_km AS 'adj1Ring', adj2_ring_km AS 'adj2Ring',
  modeled AS 'modeled', model_Name AS 'modelUrl',
  AUTOPATCH AS 'autopatch', CLOSED_PATCH AS 'autopatchClosed?', BILINGUAL AS 'bilingual', DTMF AS 'dtmf', DTMF_SEQ AS 'dtmfSeq', P25_PHASE_1 AS 'p25Phase1', URL AS 'url', 
  LINKED AS 'linked?', LITZ AS 'litz', RACES AS 'races', REMOTE_BASE AS 'remoteBase', WEATHER AS 'weather', WEATHER_DTMF AS 'weatherDtmfSeq', WIDE_AREA AS 'wideAreaCoverage'
  FROM filemaker 
WHERE  COORDINATED = '0' ORDER BY output ;"


mysql import -e "$QUERY" -NB | tr '\t' '|' >"$UNCOORD_FILE"

#copy temp files to final
cp $COORD_FILE $COORD_FINAL
cp $UNCOORD_FILE $UNCOORD_FINAL

#clean up 
rm $COORD_FILE $UNCOORD_FILE




