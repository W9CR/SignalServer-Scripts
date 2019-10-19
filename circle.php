$lat = '37.029869';
$long = '-76.345222';
$meter = 1000;
 
// Get circle coordinates
$coordinatesList = getCirclecoordinates($lat, $long, $meter);
 
// Output
$kml .= "    <Polygon>\n";
$kml .= "     <outerBoundaryIs>\n";
$kml .= "      <LinearRing>\n";
$kml .= "       <coordinates>".$coordinatesList."</coordinates>\n";
$kml .= "      </LinearRing>\n";
$kml .= "     </outerBoundaryIs>\n";
$kml .= "    </Polygon>\n";
 
function getCirclecoordinates($lat, $long, $meter) {
  // convert coordinates to radians
  $lat1 = deg2rad($lat);
  $long1 = deg2rad($long);
  $d_rad = $meter/6378137;
 
  $coordinatesList = "";
  // loop through the array and write path linestrings
  for($i=0; $i<=360; $i+=3) {
    $radial = deg2rad($i);
    $lat_rad = asin(sin($lat1)*cos($d_rad) + cos($lat1)*sin($d_rad)*cos($radial));
    $dlon_rad = atan2(sin($radial)*sin($d_rad)*cos($lat1), cos($d_rad)-sin($lat1)*sin($lat_rad));
    $lon_rad = fmod(($long1+$dlon_rad + M_PI), 2*M_PI) - M_PI;
    $coordinatesList .= rad2deg($lon_rad).",".rad2deg($lat_rad).",0 ";
  }
  return $coordinatesList;
}

