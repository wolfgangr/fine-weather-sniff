#!/usr/bin/perl -w strict

# $inpipe = "grep '\[00\] {88} 00' test868_250_01.dump";
# $inpipe = "echo foobartralalal";
$inpipe = "grep '\\[00\\] {88} 00' test868_250_01.dump";
$inpipe .= " | cut -b14-42";
$inpipe .= " |";

open (INPUT, $inpipe);

while(<INPUT>) {
  chomp;
  s/ //g;       # remove all space
  # $_ = "0x" . $_;
  # print ">>>";
  print $_;
  print "\n";
  # print "<<<\n";

  $sxor = hex $_ ^ 0xffffffffffffffffffff;

  print $sxor;
  print "\n\n";


}

close (INPUT);
