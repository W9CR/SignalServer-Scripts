#!/usr/bin/env php
<?php

include('config.php');

require 'vendor/autoload.php';
use GetOptionKit\OptionCollection;
use GetOptionKit\OptionParser;
use GetOptionKit\OptionPrinter\ConsoleOptionPrinter;

$specs = new OptionCollection;
$specs->add('i|id:', 'Record ID' )
    ->isa('number');


$parser = new OptionParser($specs);
$result = $parser->parse($argv);

//var_dump($result);

$id = $result->id;

//echo "$id \n";

//echo "<table style='border: solid 1px black;'>";
//echo "<tr><th>Id</th><th>Firstname</th><th>Lastname</th></tr>";
function formatNum($num){
    return sprintf("%+g",$num);
}


$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$stmt = $conn->prepare("SELECT *, Watts2dBm(ERP) AS dBm FROM filemaker where record_id = $id");
$stmt->execute();

  // set the resulting array to associative
$result = $stmt->setFetchMode(PDO::FETCH_ASSOC);
$data = $stmt->fetchAll(PDO::FETCH_ASSOC);


// iterate over rows
foreach($data as $row) { 
    // iterate over values in each row
    //foreach($row as $v) { 
       // echo $v, "\n ";
   // }

// format dBm to positive if positive
$row["dBm"] = formatNum($row["dBm"]);


// format the various things that nee to be upper case
$row["antStructType"] = strtoupper($row["antStructType"]);
$row["emission_1"] = strtoupper($row["emission_1"]);
$row["emission_2"] = strtoupper($row["emission_2"]);
$row["Repeater_callsign"] = strtoupper($row["Repeater_callsign"]);
$row["Trustee_callsign"] = strtoupper($row["Trustee_callsign"]);

// Check if coordidnated, if not error if -c is set
if ($row["COORDINATED"] == false ) {
echo "ERROR: RECORD {$row["record_ID"]} not coordinated \n";
exit (254);
}
// check if PL/DCS is set if emission is analog (16k0f3e or 11k2f3e)
// if not set, error 
if ( $row["emission_1"] == ('16K0F3E') or $row["emission_1"] == ('11K2F3E') or $row["emission_2"] == ('16K0F3E') or $row["emission_2"] == ('11K2F3E') ) {
//echo "we have a winner\n";
// check if CTCSS is NULL and DCS is set to 0
	if (is_null($row["CTCSS_IN"]) and $row["DCS"] == false) {
	$CTCSS_RX = <<<EOT
Access Tone In : ERROR: TONE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
	$CTCSS_RX = <<<EOT
Access Tone In : {$row["CTCSS_IN"]} Hz\n
EOT;
	}
 
	if (is_null($row["CTCSS_OUT"]) and $row["DCS"] == false) {
$CTCSS_RX = <<<EOT
Access Tone Out: ERROR: TONE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
	$CTCSS_TX = <<<EOT
Access Tone Out: {$row["CTCSS_OUT"]} Hz\n
EOT;
	}
} 


// Check if DCS is true, print it

if ($row["DCS"] == true) { 
	if (is_null($row["DCS_CODE"])) {
	$DCS_CODE = <<<EOT
DCS CODE       : ERROR: CODE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
	$DCS_CODE = <<<EOT
DCS CODE       : {$row["DCS_CODE"]}\n
EOT;
}
}


 
// check if RAN is set if emisson is NXDN
if ( $row["emission_1"] == ('4K00F1E') or $row["emission_2"] == ('4K00F1E') ) {
// Check if RAN is blank
	if (is_null($row["NXDN_RAN"])) {
		$NXDN = <<<EOT
NXDN RAN       : ERROR: CODE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$NXDN = <<<EOT
NXDN RAN       : {$row["NXDN_RAN"]}\n
EOT;
	}
}


// check if cc is set if emisson is DMR
if ( $row["emission_1"] == ('7K60FXE') or $row["emission_2"] == ('7K60FXE') ) {
// Check if code is unset
	if (is_null($row["DMR1_COLOR_CODE"]) or is_null($row["DMR2_COLOR_CODE"])) {
		$DMR = <<<EOT
DMR CC         : ERROR: CC1 or CC2 IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$DMR = <<<EOT
DMR CC         : CC1 = {$row["DMR1_COLOR_CODE"]}, CC2 = {$row["DMR2_COLOR_CODE"]}\n
EOT;
	}
}

// check if NAC is set is emisson is P25 Phase 1
if ( $row["emission_1"] == ('8K10F1E') or $row["emission_2"] == ('8K10F1E') ) {
// Check if code is unset
	if (is_null($row["P25_NAC"])) {
		$P25NAC_TX = <<<EOT
P25 NAC TX     : ERROR: P25 NAC UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$P25NAC_TX = <<<EOT
P25 NAC TX     : 0x{$row["P25_NAC"]}\n
EOT;
	}

	if (is_null($row["P25_NAC_IN"])) {
		$P25NAC_RX = <<<EOT
P25 NAC RX     : ERROR: P25 NAC UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$P25NAC_RX = <<<EOT
P25 NAC RX     : 0x{$row["P25_NAC_IN"]}\n
EOT;
	}
}


echo <<<EOT
====FASMA COORDINATION RECORD {$row["record_ID"]}====

Dear {$row["Trustee_name"]},
Your repeater, Record: {$row['record_ID']}, Callsign: {$row["Repeater_callsign"]}, on {$row["Output_frequency"]} is coordinated as follows:

Record ID      : {$row["record_ID"]}
Holder         : {$row["Holder_name"]}
Holder Address : {$row["Holder_address"]}
               : {$row["Holder_city"]}, {$row["Holder_state"]} {$row["Holder_zip"]}
Holder Phone   : {$row["Holder_phone"]}
Holder Email   : {$row["Holder_phone"]}
Trustee        : {$row["Trustee_name"]}, {$row["Trustee_callsign"]}
Trustee Address: {$row["Trustee_address"]}
               : {$row["Trustee_city"]}, {$row["Trustee_state"]} {$row["Trustee_ZIP"]}
Trustee Phone  : {$row["Trustee_home_phone"]}
Trustee email  : {$row["Trustee_email_address"]}
URL            : {$row["URL"]}
County         : {$row["County"]}
City           : {$row["Repeater_city"]}
Lat, Lon       : {$row["Latitude"]}, {$row["Longitude"]}
Callsign       : {$row["Repeater_callsign"]}
Output Freq    : {$row["Output_frequency"]} MHz
Bandwidth      : {$row["chan_Size_kHz"]} KHz
Emission 1     : {$row["emission_1"]}
Emission 2     : {$row["emission_2"]}
ERP            : {$row["ERP"]} Watts, {$row['dBm']} dBm
Antenna Model  : {$row["antennaModelCode"]}
Antenna Height : {$row["antenna_Height_Meters"]} Meters
Structure      : {$row["antStructType"]}
{$CTCSS_TX}{$CTCSS_RX}{$DCS_CODE}{$NXDN}{$DMR}{$P25NAC_TX}{$P25NAC_RX}Model          : {$row["model_Name"]}
Service        : {$row["Service_Ring_km"]} km
Interference   : {$row["Interference_Ring_km"]} km
Adjacent 1     : {$row["adj1_ring_km"]} km
Adjacent 2     : {$row["adj2_ring_km"]} km

NOTE: any change of antenna height, effective radiated power, modulation, 
frequency, bandwidth, location or callsign must be approved by FASMA, _PRIOR_ to
the change.  Failure to follow this process will void this coordination.  

The coverage model can be loaded in google and is a standard format KML file.  This
is automatically generated based on your location, antenna height, ERP and
frequency.

Florida Amateur Spectrum Mangement Association, Inc.
http://www.fasma.org
EOT;
//Dear $row["Trustee_name"],
//Your repeater, Record: $row['record_ID'], Callsign: $row["Repeater_callsign"], on $row ["Output_frequency"] is coordinated as follows:
//EOT
}







/*
foreach ($data as $row) {
    echo $row['name']."<br />\n";
}
*/


?> 
