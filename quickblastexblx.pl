#!/usr/bin/perl

use SequenceIterator qw(iterate);

($prog = $0) =~ s#.*/(\S+)#$1#;

$tempblast = "$ENV{HOME}/tmp/$prog.$$.blast";

END {
    if (-e $tempblast) { unlink $tempblast or warn "$0: couldn't unlink $tempblast" }
}
$SIG{INT} = $SIG{KILL} = sub { die "\n" };

$usage .= "$0 - generalised blastdb-MSPcrunch-type-thing\n";
$usage .= "\n";
$usage .= "Usage: $0 <BLAST executable> <query file> <database file> <BLAST options>\n";
$usage .= "\n";

@ARGV>=3 or die $usage;

($executable,$file1,$file2,@blastopts) = @ARGV;

$dna = grep($executable eq $_,qw(blastn tblastn tblastx));

iterate ($file1, sub {
    my $query = shift;
    system "$executable $file2 $query @blastopts > $tempblast";
    system "MSPcrunch -w -d $tempblast";
});

