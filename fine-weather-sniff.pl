#!/usr/bin/perl -w strict

# v010 - code rewrite
# v030 - reasonably works for live console output
# pending: database stuff


  $DBHost    = 'cleo.rosner.lokal';
  $database  = 'wetter_sdr';
  $user      = 'wetter_sdr';
  $passwd    = 'VEv3BUS3eMMMmtGV';



# debug printing level 0...3
# $debug = 0;
$debug = 2;

#========================================================
			# required modules:
use DBD::mysql;		# mysql database access
$driver = "mysql";

# use LWP::Simple;	# http retriever
use Data::Dumper;	# for debug

# use Options ;		# evaluate cmd line options

use POSIX qw(strftime);	# time string formatting

#========================================================


@windrose = qw (N NNO NO ONO O OSO SO SSO S SSW SW WSW W WNW NW NNW ); 

# http://perltricks.com/article/37/2013/8/18/Catch-and-Handle-Signals-in-Perl
# $SIG{INT} = sub { die "Caught a sigint $!" };
$SIG{INT}  = \&sig_term_handler;

#========================================================
# interface to local rtl-433 installation 
# to be configured - at least the path

# development dummy
# $inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";

# $inpipe = "rtl_433-master/build/src/" ;

$inpipe = "~/test/sdr/rtl-433/rtl_433/build/src/";	# path to executable
$inpipe .= "rtl_433";		# executable
$inpipe .= " -f 868.250e6";	# center frequ
$inpipe .= " -a";		# analse option
$inpipe .= " 2>&1 ";		# merge stderr

# $inpipe .= " | expect_unbuffer -p ";	# turn off buffering
# $inpipe .= " tee debug.log ";		# turn this off if stuff works!

$inpipe .= " | expect_unbuffer -p ";
$inpipe .= " grep '\\[00\\] {88} 00' ";

$inpipe .= " | expect_unbuffer -p ";
$inpipe .= " cut -b14-42";

$inpipe .= " |";

############################
# debug test dummy source
if (1) { 
  $inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";
  # $inpipe = "cat debug.log ";

  $inpipe .= " | cut -b14-42 ";
  $inpipe .= " |";
}

#=============================================================
# working code starting here

# open database connection

debug_print(2, "\n$0 connecting as user <$user> to database <$database> at host <$DBHost>...\n");

$dsn = "DBI:$driver:$database;$DBHost";
$dbh = DBI->connect($dsn, $user, $passwd) 
	|| die ("Could not connect to database: $DBI::errstr\n");
	# || sqlerror($dbh, "", "Could not connect: $DBI::errstr\n");

debug_print(2,  "\t...connected to database \n\n") ;

# open radio
debug_print (2, sprintf "opening >%s< \n", $inpipe); 

open (INPUT, $inpipe) || die (sprintf "cannot open >%s< \n", $inpipe) ;

while(<INPUT>) {
  chomp;

  # next unless ($_) ; 	# skip empty lines
  unless ($_) {
    debug_print (3, "skipping empty line\n");
    next;
  }

  @bytes_ff = split ' ';
  debug_print (2, join '#', @bytes_ff) ;
  debug_print (2, "\n");

  unless (scalar @bytes_ff ) {
    debug_print (3, "skipping line without data\n");
    next;
  }

  # next unless (scalar @bytes_ff == 10);	# skip bs formats
  unless (scalar @bytes_ff == 10) {
    debug_print (2, sprintf "skipping garbage format >>>%s<<<\n", $_);  
    next;
  }



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
  debug_print (3, sprintf " digest %02x \n ", $crc) ;

  unless ($crc == hex $bytes[9]) {
    debug_print (2, sprintf "skipping crc-error: digest=%02x, checksum=%s\n", $crc, $bytes[9]); 
    debug_print (3, $_);
    next;
  }

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
  $wdir_n = (hex $wdir_h) * 22.5 ;
  $wdir_n = 360 unless ($wdir_n); # N -> 360 deg, not 0  

  # $crc = sprintf "%02x",  (hex $crc ^ 0xff);
  $crc = $crc_h; 

  debug_print (1, sprintf "  CONV: ident: %s T=%s RF=%s WS=%s Gst=%s raincnt=%s lob=%s, wd=%s (%s) crc=%s \n" , 
	$ident, $temp, $hum, $wspeed, $wgust,  $raincnt, $lobat, $wdir_n, $wdir, $crc);
  debug_print (2, "\n");
  # print "\n";

  # database timestamp format:
  # 2011-12-30 00:06:00 	
  $timestamp = strftime "%Y-%m-%d %H:%M:%S", gmtime; 
  debug_print (1, "timestamp: $timestamp \n");


# INSERT INTO `raw` ( `idx` , `hum_out` , `temp_out` , `wind_ave` , `wind_gust` , `wind_dir` , `rain_count` )
# VALUES (
# '2014-02-23 22:05:18', '89', '2.3', '2.38', '3.4', '225', '363.6 ')
  $sql = "INSERT INTO `raw` (";
  $sql .= "`idx` , `hum_out` , `temp_out` , `wind_ave` , `wind_gust` , `wind_dir` , `rain_count`, `lo_batt`";
  $sql .= " ) VALUES ( ";
  $sql .= sprintf ("'%s' , ", $timestamp);
  $sql .= sprintf ("'%3d' , ", $hum);
  $sql .= sprintf ("'%.1f' , ", $temp);
  $sql .= sprintf ("'%.1f' , ", $wspeed);
  $sql .= sprintf ("'%.1f' , ", $wgust);
  $sql .= sprintf ("'%.1f' , ", $wdir_n);
  $sql .= sprintf ("'%.1f' , ", $raincnt);
  $sql .= sprintf ("'%1d'   ", $lobat);
  $sql .= " );" ;

  debug_print (2, "SQL-Statement: $sql \n");

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


# kill the radio before exiting to release tuner port
sub sig_term_handler {
  debug_print (1, "caught TERM signal - $! \n");
  debug_print (1, "doing a >killall -9 rtl_433< \n");
  system "killall -9 rtl_433";
  sleep(5);
  die "now exiting";
}
