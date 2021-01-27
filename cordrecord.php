#!/usr/bin/env php
<?php

/* 
This program will generate a plain text formated record of FASMA coordination
records for a record ID.  There are mutiple options presented:
* Private Coordination Record - for sending to the trustee
* Public Record for posting to website
* PCN record for sending to adjacent states

Copyright (C) 2020 Bryan Fields
Bryan@bryanfields.net
+1-727-409-1194

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License Version 3, 
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

--------------------------- Revision History ----------------------------------
2020-08-15	bfields		Inital prototype, Private record only
2021-01-26	bfields		public and private records working
2021-01-27	bfields		PCN working
*/

include('config.php');

require 'vendor/autoload.php';
use GetOptionKit\OptionCollection;
use GetOptionKit\OptionParser;
use GetOptionKit\OptionPrinter\ConsoleOptionPrinter;

// Specs needed here
// Should 
$specs = new OptionCollection;
$specs->add('i|id:', 'Record ID' )
    ->isa('number');

$specs->add('c|coord', 'Print only coordinated repeaters')
	->isa('boolean') 
	->defaultValue('false');

$specs->add('p|public', 'Print public coordination record')
        ->isa('boolean')
        ->defaultValue('false');

$specs->add('n|pcn', 'Print PCN coordination record')
        ->isa('boolean')
        ->defaultValue('false');

$parser = new OptionParser($specs);
$result = $parser->parse($argv);

//var_dump($result);

$id = $result->id;
$private = $result->coord;
$public = $result->public;
$pcn = $result->pcn;

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
// however don't do this if null, as strtoupper make is not null after.

if (is_null($row["antStructType"]) == false) {$row["antStructType"] = strtoupper($row["antStructType"]);}
if (is_null($row["emission_1"]) == false) {$row["emission_1"] = strtoupper($row["emission_1"]);}
if (is_null($row["emission_2"]) == false) {$row["emission_2"] = strtoupper($row["emission_2"]);}
if (is_null($row["Repeater_callsign"]) == false) {$row["Repeater_callsign"] = strtoupper($row["Repeater_callsign"]);}
if (is_null($row["Trustee_callsign"]) == false) {$row["Trustee_callsign"] = strtoupper($row["Trustee_callsign"]);}

// Define the vars
$row["CTCSS_RX_text"] = NULL;
$row["CTCSS_TX_text"] = NULL;
$row["DCS_CODE_text"] = NULL;
$row["NXDN_text"] = NULL;
$row["DMR_text"] = NULL;
$row["P25NAC_TX_text"] = NULL;
$row["P25NAC_RX_text"] = NULL;
$row["ADJ1_text"] = NULL;
$row["ADJ2_text"] = NULL;


echo "$private\n";

// Check if coordidnated, if not error if -c is set
if ($row["COORDINATED"] == false ) {
echo "ERROR: RECORD {$row["record_ID"]} not coordinated \n";
	if ( ($private == true) || ($pcn == false) ){
		exit (254);
	}
}
// check if PL/DCS is set if emission is analog (16k0f3e or 11k2f3e)
// if not set, error 
if ( $row["emission_1"] == ('16K0F3E') or $row["emission_1"] == ('11K2F3E') or $row["emission_2"] == ('16K0F3E') or $row["emission_2"] == ('11K2F3E') ) {
//echo "we have a winner\n";
// check if CTCSS is NULL and DCS is set to 0
	if (is_null($row["CTCSS_IN"]) and $row["DCS"] == false) {
	$row["CTCSS_RX_text"] = <<<EOT
Access Tone In : ERROR: TONE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} elseif (is_null($row["CTCSS_IN"]) and $row["DCS"] == true) {
		unset($row["CTCSS_RX_text"]);
	} else {
	$row["CTCSS_RX_text"] = <<<EOT
Access Tone In : {$row["CTCSS_IN"]} Hz\n
EOT;
	}
 
	if (is_null($row["CTCSS_OUT"]) and $row["DCS"] == false) {
$row["CTCSS_TX_text"] = <<<EOT
Access Tone Out: ERROR: TONE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} elseif (is_null($row["CTCSS_OUT"]) and $row["DCS"] == true) {
		unset($$row["CTCSS_TX_text"]);
	} else {
	$row["CTCSS_TX_text"] = <<<EOT
Access Tone Out: {$row["CTCSS_OUT"]} Hz\n
EOT;
	}
} 

// Check if DCS is true, print it
if ($row["DCS"] == true) { 
	if (is_null($row["DCS_CODE"])) {
	$row["DCS_CODE_text"] = <<<EOT
DCS CODE       : ERROR: CODE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
	$row["DCS_CODE_text"] = <<<EOT
DCS CODE       : {$row["DCS_CODE"]}\n
EOT;
}
}
 
// check if RAN is set if emisson is NXDN
if ( $row["emission_1"] == ('4K00F1E') or $row["emission_2"] == ('4K00F1E') ) {
// Check if RAN is blank
	if (is_null($row["NXDN_RAN"])) {
		$row["NXDN_text"] = <<<EOT
NXDN RAN       : ERROR: CODE IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$row["NXDN_text"] = <<<EOT
NXDN RAN       : {$row["NXDN_RAN"]}\n
EOT;
	}
}

// check if cc is set if emisson is DMR
if ( $row["emission_1"] == ('7K60FXE') or $row["emission_2"] == ('7K60FXE') ) {
// Check if code is unset
	if (is_null($row["DMR1_COLOR_CODE"]) or is_null($row["DMR2_COLOR_CODE"])) {
		$row["DMR_text"] = <<<EOT
DMR CC         : ERROR: CC1 or CC2 IS UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$row["DMR_text"] = <<<EOT
DMR CC         : CC1 = {$row["DMR1_COLOR_CODE"]}, CC2 = {$row["DMR2_COLOR_CODE"]}\n
EOT;
	}
}

// check if NAC is set is emisson is P25 Phase 1
if ( $row["emission_1"] == ('8K10F1E') or $row["emission_2"] == ('8K10F1E') ) {
// Check if code is unset
	if (is_null($row["P25_NAC"])) {
		$row["P25NAC_TX_text"] = <<<EOT
P25 NAC TX     : ERROR: P25 NAC UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$row["P25NAC_TX_text"] = <<<EOT
P25 NAC TX     : 0x{$row["P25_NAC"]}\n
EOT;
	}

	if (is_null($row["P25_NAC_IN"])) {
		$row["P25NAC_RX_text"] = <<<EOT
P25 NAC RX     : ERROR: P25 NAC UNSET, PLEASE UPDATE RECORD!\n
EOT;
	} else {
		$row["P25NAC_RX_text"] = <<<EOT
P25 NAC RX     : 0x{$row["P25_NAC_IN"]}\n
EOT;
	}
}


// Check that various required fields are set

if (is_null($row["Coordination_date"])) {$row["Coordination_date"] = "ERROR: COORD DATE";}
if (is_null($row["update_date"])) {$row["update_date"] = "ERROR: UPDATE DATE";}

if (is_null($row["Holder_name"])) { $row["Holder_name"] = "ERROR: HOLDER NAME";}
if (is_null($row["Holder_address"])) { $row["Holder_address"] = "ERROR: HOLDER ADDRESS";}
if (is_null($row["Holder_city"])) { $row["Holder_city"] = "ERROR: HOLDER CITY";}
if (is_null($row["Holder_state"])) { $row["Holder_state"] = "ERROR: STATE";}
if (is_null($row["Holder_zip"])) { $row["Holder_zip"] = "ERROR: ZIP";}
if (is_null($row["Holder_phone"])) { $row["Holder_phone"] = "ERROR: HOLDER PHONE";}
if (is_null($row["Holder_email"])) { $row["Holder_email"] = "Not on File";}

if (is_null($row["Trustee_name"])) { $row["Trustee_name"] = "ERROR: TRUSTEE NAME";}
if (is_null($row["Trustee_callsign"])) { $row["Trustee_callsign"] = "ERROR: TRUSTEE CALL";}
if (is_null($row["Trustee_address"])) { $row["Trustee_address"] = "ERROR: TRUSTEE ADDRESS";}
if (is_null($row["Trustee_city"])) { $row["Trustee_city"] = "ERROR: TRUSTEE CITY";}
if (is_null($row["Trustee_state"])) { $row["Trustee_state"] = "ERROR: TRUSTEE STATE";}
if (is_null($row["Trustee_ZIP"])) { $row["Trustee_ZIP"] = "ERROR: TRUSTEE ZIP";}
if (is_null($row["Trustee_home_phone"])) { $row["Trustee_home_phone"] = "ERROR: TRUSTEE PHONE";}
if (is_null($row["Trustee_email_address"])) { $row["Trustee_email_address"] = "ERROR: TRUSTEE EMAIL";}

if (is_null($row["URL"])) { $row["URL"] = "No URL On File";}

if (is_null($row["County"])) { $row["County"] = "ERROR: COUNTY";}
if (is_null($row["Repeater_city"])) { $row["Repeater_city"] = "ERROR: CITY";}
if (is_null($row["Repeater_callsign"])) { $row["Repeater_callsign"] = "ERROR: CALLSIGN";}
if (is_null($row["Input_frequency"])) { $row["Input_frequency"] = "Input not defined";}
if (is_null($row["Output_frequency"])) { $row["Output_frequency"] = "ERROR: OUTPUT FREQUENCY";}
if (is_null($row["chan_Size_kHz"])) { $row["chan_Size_kHz"] = "ERROR: CHANNEL SIZE";}
if (is_null($row["emission_1"])) { $row["emission_1"] = "ERROR: EMISSION";}
if (is_null($row["ERP"])) { $row["ERP"] = "ERROR: ERP";}
if (is_null($row["antennaModelCode"])) { $row["antennaModelCode"] = "Not on File";}
if (is_null($row["antenna_Height_Meters"])) { $row["antenna_Height_Meters"] = "ERROR: AGL";}
if (is_null($row["antStructType"])) { $row["antStructType"] = "Not on File";}
if (is_null($row["model_Name"])) { $row["model_Name"] = "ERROR: MODEL MISSING";}
if (is_null($row["Service_Ring_km"])) { $row["Service_Ring_km"] = "ERROR: SERVICE MISSING";}
if (is_null($row["Interference_Ring_km"])) { $row["Interference_Ring_km"] = "ERROR: INTERFERENCE MISSING";}

// Only set the next two if needed for the adjacent channels
if (is_null($row["adj1_ring_km"]) == false) {  
	$row["ADJ1_text"] = <<<EOT
Adjacent 1     : {$row["adj1_ring_km"]} km\n
EOT;
}
// only print adj2 if adj1 is set
if ((is_null($row["adj1_ring_km"]) == false) and (is_null($row["adj2_ring_km"]) == false)) {
        $row["ADJ2_text"] = <<<EOT
Adjacent 2     : {$row["adj2_ring_km"]} km\n
EOT;
}

function PrivateRecord($row) {

// need to add in DATE in here too.
echo <<<EOT
====FASMA COORDINATION RECORD {$row["record_ID"]}====

Dear {$row["Trustee_name"]},
Your repeater, Record: {$row['record_ID']}, Callsign: {$row["Repeater_callsign"]}, on {$row["Output_frequency"]} is coordinated as follows:

Record ID      : {$row["record_ID"]}
Coord Date     : {$row["Coordination_date"]}
Update Date    : {$row["update_date"]}
Holder         : {$row["Holder_name"]}
Holder Address : {$row["Holder_address"]}
               : {$row["Holder_city"]}, {$row["Holder_state"]} {$row["Holder_zip"]}
Holder Phone   : {$row["Holder_phone"]}
Holder Email   : {$row["Holder_email"]}
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
Input Freq     : {$row["Input_frequency"]} MHz
Bandwidth      : {$row["chan_Size_kHz"]} KHz
Emission 1     : {$row["emission_1"]}
Emission 2     : {$row["emission_2"]}
ERP            : {$row["ERP"]} Watts, {$row['dBm']} dBm
Antenna Model  : {$row["antennaModelCode"]}
Antenna Height : {$row["antenna_Height_Meters"]} Meters
Structure      : {$row["antStructType"]}
{$row["CTCSS_TX_text"]}{$row["CTCSS_RX_text"]}{$row["DCS_CODE_text"]}{$row["NXDN_text"]}{$row["DMR_text"]}{$row["P25NAC_TX_text"]}{$row["P25NAC_RX_text"]}Model          : {$row["model_Name"]}
Service        : {$row["Service_Ring_km"]} km
Interference   : {$row["Interference_Ring_km"]} km
{$row["ADJ1_text"]}{$row["ADJ2_text"]}
NOTE: any change of antenna height, effective radiated power, modulation, 
frequency, bandwidth, location or callsign must be approved by FASMA, _PRIOR_ to
the change.  Failure to follow this process will void this coordination.  

The coverage model is a standard KML format and may be viewed in google earth.  
This is automatically generated based on your location, antenna height, ERP and
frequency.

Florida Amateur Spectrum Management Association, Inc.
http://www.fasma.org

EOT;
}

if ($private == true){ 
	PrivateRecord ($row);
}



function PublicRecord($row){ 
echo <<<EOT
====FASMA COORDINATION RECORD {$row["record_ID"]}====

Record ID      : {$row["record_ID"]}
Coord Date     : {$row["Coordination_date"]}
Update Date    : {$row["update_date"]}
Holder         : {$row["Holder_name"]}
Trustee        : {$row["Trustee_name"]}, {$row["Trustee_callsign"]}
URL            : {$row["URL"]}
County         : {$row["County"]}
City           : {$row["Repeater_city"]}
Lat, Lon       : {$row["Latitude"]}, {$row["Longitude"]}
Callsign       : {$row["Repeater_callsign"]}
Output Freq    : {$row["Output_frequency"]} MHz
Input Freq     : {$row["Input_frequency"]} MHz
Bandwidth      : {$row["chan_Size_kHz"]} KHz
Emission 1     : {$row["emission_1"]}
Emission 2     : {$row["emission_2"]}
ERP            : {$row["ERP"]} Watts, {$row['dBm']} dBm
Antenna Height : {$row["antenna_Height_Meters"]} Meters
{$row["CTCSS_TX_text"]}{$row["CTCSS_RX_text"]}{$row["DCS_CODE_text"]}{$row["NXDN_text"]}{$row["DMR_text"]}{$row["P25NAC_TX_text"]}{$row["P25NAC_RX_text"]}Model          : {$row["model_Name"]}
Service        : {$row["Service_Ring_km"]} km
Interference   : {$row["Interference_Ring_km"]} km
{$row["ADJ1_text"]}{$row["ADJ2_text"]}
The coverage model is a standard KML format and may be viewed in google earth.  
This is automatically generated based on your location, antenna height, ERP and
frequency.

Florida Amateur Spectrum Management Association, Inc.
http://www.fasma.org

EOT;
} 

if ($public == true) {
	PublicRecord($row);
}

function PriorCoordinationNotice($row){
echo <<<EOT
Greetings,

I'm with FASMA and we are sending notice of proposed coordination for this repeater below.  

As this is <200 km from the state line we are making a PCN notice regarding this repeater.  You may find the models for the service contour and interference contour below.  The kmz can be loaded natively in google earth.

If more than one frequency is listed, you may respond with one which works best of multiple listed.  Your prompt response is requested.  

Barring no objections in 15 business days, we will consider the notice approved

=====BEGIN PCN DATA=====
Record ID          : {$row["record_ID"]}
City               : {$row["Repeater_city"]}
Proposed frequency : PROPOSED FREQ
Channel Bandwidth  : {$row["chan_Size_kHz"]} KHz
Emission 1         : {$row["emission_1"]} 
Emission 2         : {$row["emission_2"]}
Antenna Model      : {$row["antennaModelCode"]}
Antenna Height AGL : {$row["antenna_Height_Meters"]} Meters
ERP                : {$row["ERP"]} Watts, {$row['dBm']} dBm
Service Contour    : {$row["Service_Ring_km"]} km
Interferer Contour : {$row["Interference_Ring_km"]} km
{$row["ADJ1_text"]}{$row["ADJ2_text"]}Model              : {$row["model_Name"]}
=====END PCN DATA=====

Thank you for your assistance and 73,
EOT;
}

if ($pcn == true) {
        PriorCoordinationNotice($row);
}



}
?> 
