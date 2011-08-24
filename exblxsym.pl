#!/usr/bin/perl

use FileIndex;

$usage .= "$0 -- symmetrise asymmetric MSPcrunch data\n";
$usage .= "\n";
$usage .= "Usage: $0 <MSPcrunch file>\n";
$usage .= "\n";
$usage .= "Output is sorted by first sequence name *only*\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = shift;
    die "$usage\nUnknown option: $opt\n";
}

@ARGV==1 or die $usage;
($filename) = @ARGV;

$mspfile = FileIndex->new($filename);
$lines = $mspfile->lines();

for ($i=0;$i<$lines;$i++) {
    $_ = $mspfile->getline($i);
    @f = split;
    push @{$indices{$f[4]}}, $i+1;
    push @{$indices{$f[7]}}, -$i-1;
}

foreach $name (sort keys %indices) {
    foreach $i (@{$indices{$name}}) {
	if ($i > 0) {
	    $_ = $mspfile->getline($i-1);
	    print;
	} else {
	    $_ = $mspfile->getline(-$i-1);
	    @f = split;
	    print join("\t",@f[0,1,5..7,2..4,8..$#f]),"\n";
	}
    }
}

