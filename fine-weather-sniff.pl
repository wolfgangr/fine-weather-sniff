#!/usr/bin/perl -w strict

# v010 - code rewrite
@windrose = qw (N NNO NO ONO O OSO SO SSO S SSW SW WSW W WNW NW NNW ); 

# development dummy
# $inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";

# $inpipe = "rtl_433-master/build/src/" ;

$inpipe = "~/test/sdr/rtl-433/rtl_433/build/src/";	# path to executable
$inpipe .= "rtl_433";		# executable
$inpipe .= " -f 868.250e6";	# center frequ
$inpipe .= " -a";		# analse option
$inpipe .= " 2>&1 ";		# merge stderr

$inpipe .= " | expect_unbuffer -p ";	# turn off buffering
$inpipe .= " tee debug.log ";

# debug test dummy source
# $inpipe = "cat test868_250_01.dump";
# $inpipe = "cat debug.log ";

$inpipe .= " | expect_unbuffer -p ";
$inpipe .= " grep '\\[00\\] {88} 00' ";

$inpipe .= " | expect_unbuffer -p ";
$inpipe .= " cut -b14-42";

$inpipe .= " |";

# debug printing level 0...3 
# $debug = 0;
$debug = 3;


debug_print (2, sprintf "opening >%s< \n", $inpipe); 

open (INPUT, $inpipe) || die (sprintf "cannot open >%s< \n", $inpipe) ;

while(<INPUT>) {
  chomp;

  @bytes_ff = split ' ';
  debug_print (2, join '#', @bytes_ff) ;
  debug_print (2, "\n");


  @bytes = ();
  foreach $byte_h (@bytes_ff) {
    push ( @bytes, ( sprintf "%02x" , (hex $byte_h ^ 0xff) ) );
  }

  debug_print (3, join ':', @bytes );
  debug_print (3, "\n");

  s/ //g;	# remove all space
  $rawFF = $_;

  debug_print (3, $rawFF);
  debug_print (3, "\n");

  $raw = join '', @bytes ;
  
  debug_print (3, $raw);
  debug_print (3, "\n");

  # calculate checsum
  # adapted from
  # http://www.susa.net/wordpress/wp-content/uploads/2012/08/wh1080_rf_v0.3.tgz
  $crc = 0x0 ;
  foreach $byte_h  (@bytes[0 .. 8]) {
    $byte = hex $byte_h ;
    # printf "%s-%02x:" ,  $byte_h, $byte;
    for ($i = 8; $i  ; $i--) {
      $mix = ($crc ^ $byte) & 0x80 ;
      $crc  <<= 1;
      $crc &=  0xff ; # stay within 8 bits )
      if ($mix) {
        $crc  ^= 0x31; 
      }
      $byte <<= 1 ;
    }
    # printf " crc:%02x  ", $crc;  
  }
  

  # print "\n";
  # printf " digest %02x - check vs %s\n", $crc, $crx;
  debug_print (1, sprintf " digest %02x \n ", $crc) ;

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

  debug_print(2, sprintf "  RAW:  ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s \n" ,
        $ident_h, $temp_h, $hum_h, $wspeed_h, $wgust_h,  $raincnt_h, $lobat_h, $wdir_h, $crc_h);
  # print "\n";

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

  debug_print (1, sprintf "  CONV: ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s crc=%s \n" , 
	$ident, $temp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir, $crc);
  debug_print (2, "\n");
  # print "\n";

}


close (INPUT);


exit ;

#============================================

# debug_print($level, $content)
sub debug_print {
  $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
  # print  @_ if $debug ;
}
