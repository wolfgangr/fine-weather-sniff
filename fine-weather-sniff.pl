#!/usr/bin/perl -w strict

# v010 - code rewrite
@windrose = qw (N NNO NO ONO O OSO SO SSO S SSW SW WSW W WNW NW NNW ); 

$inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";
$inpipe .= " | cut -b14-42";
$inpipe .= " |";

open (INPUT, $inpipe);

while(<INPUT>) {
  chomp;

  @bytes_ff = split ' ';
  print join '#', @bytes_ff ;
  print "\n";

  @bytes = qw( );
  foreach $byte_h (@bytes_ff) {
    push ( @bytes, ( sprintf "%02x" , (hex $byte_h ^ 0xff) ) );

  }

  print join ':', @bytes ;
  print "\n";

# exit ; # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


  s/ //g;	# remove all space
  $rawFF = $_;

  print $rawFF;
  print "\n";

  $raw = join '', @bytes ;
  
  print $raw;
  print "\n";

exit ; # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # $chksum = 0;
  $crc = 0b00000000;

  foreach $byte_h (@bytes) {
    $byte = hex $byte_h ^ 0xff;
    printf "%s - %02x : " ,  $byte_h, $byte;
    # see http://qs343.pair.com/~monkperl/index.pl?node_id=1064732
    for ($n = 0; $n <= 7; $n++) {
      $bit = $byte & 0b00000001;
      $test = $crc ^ $bit;
      $test = $test & 0b00000001;      
      if ($test) {
        $crc = $crc ^ 0b00011000;
        $crc = $crc >> 1;
        $crc = $crc | 0b10000000;
      } else {
        $crc = $crc >> 1;
      }
      $byte = ( $byte >> 1 );
    }  
  }
  

  print "\n";
  printf " digest %02x - check vs %s\n", $crc, $crx;

	# http://www.susa.net/wordpress/2012/08/
	# 	raspberry-pi-reading-wh1081-weather-sensors-using-an-rfm01-and-rfm12b/#comment-1138
	# Byte     0  1  2  3  4  5  6  7  8  9
	# Nibble  ab cd ef gh ij kl mn op qr st
	#    abc: device identifier
	#    def: temperature
	#    gh: humidity
	#    ij: average wind speed low byte
	#    kl: gust wind speed low byte
	#    m: unknown
	#    n: rainfall counter high nibble
	#    op: rainfall counter
	#    q: battery-low indicator
	#    r: wind direction
	#    st: checksum
  # ($ident, $tmp, $hum, $wspeed, $gust,  $raincnt, $lobat, $wdir, $crc) 
  # @list
  #	= ( $_ =~ /(...)(...)(..)(..)(..).(...)(.)(.)(..)/ ); 

  ($ident, $tmp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir, $crc) 
	= ( $raw =~ /(...)(...)(..)(..)(..).(...)(.)(.)(..)/ );

  # print join " - " , @list;
  # print "\n";


  printf "  RAW:  ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s " ,
        $ident, $tmp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir, $crc;
  print "\n";

  $ident = hex $ident ^ 0xfff;
  $tmp = ((hex $tmp ^ 0xfff) - 400) / 10 ; 
  $hum = hex $hum ^ 0xff;
  $wspeed = (hex $wspeed ^ 0xff) * 0.34 ;
  $wgust  = (hex $wgust  ^ 0xff) * 0.34 ;
  $raincnt  = (hex $raincnt  ^ 0xfff) * 0.3 ;
  $lobat = hex $lobat ^ 0xf; 
  $wdir = $windrose[hex $wdir ^ 0xf];

  $crc = sprintf "%02x",  (hex $crc ^ 0xff);
 
  printf "  CONV: ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s " , 
	$ident, $tmp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir, $crc;
  print "\n";
  print "\n";

}


close (INPUT);

