#!/usr/bin/perl -w strict

use Digest::CRC;

@windrose = qw (N NNO NO ONO O OSO SO SSO S SSW SW WSW W WNW NW NNW ); 

# $inpipe = "grep '\[00\] {88} 00' test868_250_01.dump";
# $inpipe = "echo foobartralalal";
$inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";
$inpipe .= " | cut -b14-42";
$inpipe .= " |";

open (INPUT, $inpipe);

while(<INPUT>) {
  chomp;

  @bytes = split ' ';
  print join ':', @bytes ;
  print "\n";

  s/ //g;	# remove all space
  $raw = $_;

  print $raw;
  print "\n";

  # check CRC  The CRC-8 polynomial used is x^8 + x^5 + x^4 + 1
  $crx = pop @bytes;
  
  # $chksum = 0;

  # cmp http://rants.dyer.com.hk/rpi/humidity_1w.html
  $ctx = Digest::CRC->new(width => 8, poly => 0x31, init => 0x00, xorout => 0x00, 
		refin => 1, refout => 1, cont=>0);

  $chkstr ="";
  foreach $byte (@bytes) {
    $byte_ = hex $byte ^ 0xff;
    printf "%s - %02x : " ,  $byte, $byte_;
    # $ctx->add(chr ($byte_) );
    # $ctx->add(chr ( hex $byte ^ 0xff));
    $chkstr .= chr ($byte_);
  }
  $ctx->add($chkstr);
  print "\n";
  $crout = $ctx->digest;
  printf " digest %02x - check vs %s\n", $crout, $crx;

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

