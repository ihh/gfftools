#!/usr/bin/perl

sub nameonly { my $path = shift; $path =~ s/.*\/([^\/]+)$/$1/; return $path }

$seqname = ".";
$dbfile = ".";

$usage .= "$0 -- convert tandem output to GFF\n";
$usage .= "\n";
$usage .= "Usage: $0 [-n seqname] [-d dbfile] [-l label] [files...]\n";
$usage .= "\n";
$usage .= "Default seqname=\"$seqname\", dbfile=\"$dbfile\" (used for labelling only)\n";
$usage .= "[group] field of GFF is used for repeat consensus\n";
$usage .= "\n";

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    $arg = shift;
    if ($arg eq "-n") { $seqname = shift; }
    elsif ($arg eq "-d") { $dbfile = shift; }
    else { die "Unknown option $arg\n\n$usage"; }
}

while (<>) {
    ($score,$start,$end,$len,$copies,$id,$seq) = split;
    print "$seqname\t$dbfile\ttandem\t$start\t$end\t$score\t+\t.\t$seq\n";
}


