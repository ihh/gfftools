#!/usr/bin/perl

use SequenceIterator qw(iterate);

($prog = $0) =~ s#.*/(\S+)#$1#;

$tempseq = "$ENV{HOME}/tmp/$prog.$$.seqfile";
$tempblast = "$ENV{HOME}/tmp/$prog.$$.blast";

END {
    if (-e $tempseq) { unlink $tempseq or warn "$0: couldn't unlink $tempseq" }
    if (-e "$tempseq.csq") { unlink "$tempseq.csq" or warn "$0: couldn't unlink $tempseq.csq" }
    if (-e "$tempseq.nhd") { unlink "$tempseq.nhd" or warn "$0: couldn't unlink $tempseq.nhd" }
    if (-e "$tempseq.ntb") { unlink "$tempseq.ntb" or warn "$0: couldn't unlink $tempseq.ntb" }
    if (-e "$tempseq.bsq") { unlink "$tempseq.bsq" or warn "$0: couldn't unlink $tempseq.bsq" }
    if (-e "$tempseq.ahd") { unlink "$tempseq.ahd" or warn "$0: couldn't unlink $tempseq.ahd" }
    if (-e "$tempseq.atb") { unlink "$tempseq.atb" or warn "$0: couldn't unlink $tempseq.atb" }
    if (-e $tempblast) { unlink $tempblast or warn "$0: couldn't unlink $tempblast" }
}
$SIG{INT} = $SIG{KILL} = sub { die "\n" };

$usage .= "$0 - generalised blastdb-MSPcrunch-type-thing\n";
$usage .= "\n";
$usage .= "Usage: $0 <BLAST executable> <sequence file 1> <sequence file 2> <BLAST options>\n";
$usage .= "\n";

@ARGV>=3 or die $usage;

($executable,$file1,$file2,@blastopts) = @ARGV;

$dna = grep($executable eq $_,qw(blastn tblastn tblastx));

system "cp $file2 $tempseq";
if ($dna) { system "pressdb $tempseq >/dev/null" }
else { system "setdb $tempseq >/dev/null" }

iterate ($file1, sub {
    my $query = shift;
    system "$executable $tempseq $query @blastopts > $tempblast";
    foreach (`MSPcrunch -w -d $tempblast`) { print unless /^BLAST/ || !/\S/ }
});

