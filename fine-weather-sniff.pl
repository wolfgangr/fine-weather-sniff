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



  @bytes = ();
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

# exit ; # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # $chksum = 0;
  $crc = 0b00000000;

  # while (0) {
  foreach $byte_h  (@bytes[0 .. 8]) {
    $byte = hex $byte_h ;
    printf "%s-%02x:" ,  $byte_h, $byte;
    # see http://qs343.pair.com/~monkperl/index.pl?node_id=1064732
    for ($i = 8; $i  ; $i--) {
      # $bit = $byte & 0x80 ; # 0b00000001;
      # $test = $crc ^ $bit;
      $mix = ($crc ^ $byte) & 0x80 ;
      # $test = $test & 0b00000001;      
      # if ($test) {
      #   $crc = $crc ^ 0b00011000;
      #   $crc = $crc | 0b100000000;
      # }
      $crc  <<= 1;
      $crc &=  0xff ; # stay within 8 bits )
      if ($mix) {
        $crc  ^= 0x31; # 0b00011000;
        # $crc = $crc | 0b100000000;
      }


      $byte <<= 1 ;
    }
    printf " crc:%02x  ", $crc;  

  }
  

  print "\n";
  # printf " digest %02x - check vs %s\n", $crc, $crx;
  printf " digest %02x \n ", $crc ;

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

  # extract the fields
  ($ident_h, $temp_h, $hum_h, $wspeed_h, $wgust_h,  $raincnt_h, $lobat_h, $wdir_h, $crc_h) 
	= ( $raw =~ /(...)(...)(..)(..)(..).(...)(.)(.)(..)/ );

  printf "  RAW:  ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s " ,
        $ident_h, $temp_h, $hum_h, $wspeed_h, $wgust_h,  $raincnt_h, $lobat_h, $wdir_h, $crc_h;
  print "\n";

# exit ; # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # numerize and renorm as required
  # use unpack instead ? looks like a biest.....
  $ident = hex $ident_h ;
  $temp = ((hex $temp_h ) - 400) / 10 ; 
  $hum = hex $hum_h ;
  $wspeed = (hex $wspeed_h ) * 0.34 ;
  $wgust  = (hex $wgust_h  ) * 0.34 ;
  $raincnt  = (hex $raincnt_h ) * 0.3 ;
  $lobat = hex $lobat_h ; 
  $wdir = $windrose[hex $wdir_h ];

  # $crc = sprintf "%02x",  (hex $crc ^ 0xff);
  $crc = $crc_h; 

  printf "  CONV: ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s " , 
	$ident, $temp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir, $crc;
  print "\n";
  print "\n";

}


close (INPUT);

