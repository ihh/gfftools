#!/usr/bin/perl

$usage .= "$0 - index large MSPcrunch files\n";
$usage .= "\n";
$usage .= "Usage: $0 <MSPcrunch file>\n";
$usage .= "\n";

@ARGV==1 or die $usage;
($mspfile) = @ARGV;

open MSPFILE, $mspfile or die "$0: couldn't open $mspfile: $!";
open MSPINDEX, ">$mspfile.index" or die "$0: couldn't open $mspfile.index: $!";

while ($tell = tell(MSPFILE), $_ = <MSPFILE>) {
    @f = split;
    $key = "$f[4]\t$f[7]";
    if (!defined($lastkey) || $lastkey ne $key) {
	$lastkey = $key;
	print STDERR "$0: MSPcrunch file not sorted by name\n" if $seen{$key};
	$seen{$key} = 1;
	print MSPINDEX "$key\t$tell\n";
    }
}

close MSPINDEX;
close MSPFILE;

