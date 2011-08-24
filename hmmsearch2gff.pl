#!/usr/bin/perl

$source = "hmmsearch";
$feature = "similarity";

$usage .= "$0 - converts hmmsearch output into GFF\n";
$usage .= "\n";

while (<>) { last if  /^Sequence\s+Domain/ }
    
while (<>) {
    last unless /\S/;
    ($name,$domain,$start,$end,$dots,$hmmstart,$hmmend,$brackets,$score,$evalue) = split;
    print "$name\t$source\t$feature\t$start\t$end\t$score\t?\t.\t$start $end\n";
}
