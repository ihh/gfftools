#!/usr/bin/perl -w

sub nameonly { my $path = shift; $path =~ s/.*\/([^\/]+)$/$1/; return $path }

#require glob("~ihh/perl/standard.pl");

my $usage = "";
$usage .= "$0 -- convert hmmsearch output to GFF\n";
$usage .= "\n";
$usage .= "Usage: $0 [-m hmmfile] [-r rndfile] [-p program] [-f feature] [files...]\n";
$usage .= "\n";
$usage .= "hmmfile, rndfile, program, feature used for labelling purposes only\n";
$usage .= "\n";

my $program = "HMMer";
my $feature = "similarity";
my $hmmfile = "unknown";
my $rndfile;

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    my $arg = shift;
    if ($arg eq "-m") { $hmmfile = nameonly(shift) }
    elsif ($arg eq "-r") { $rndfile = nameonly(shift) }
    elsif ($arg eq "-p") { $program = nameonly(shift) }
    elsif ($arg eq "-f") { $feature = shift }
    else { die "Unknown option $arg\n\n$usage" }
}

$group = ($rndfile) ? "$hmmfile;$rndfile" : $hmmfile;

while (<>) {
    last if /Parsed for domains/;
}
my $dummy;
$dummy = <>;
$dummy = <>;

while (<>) {
    last unless /\S/;
    my ($seqname,$domain,$start,$end,$dummy1,$hmmstart,$hmmend,$dummy2,$score,$evalue) = split;
    if ($end>=$start) { $strand = "+" }
    else { $strand = "-"; ($start,$end) = ($end,$start) }
    print "$seqname\t$program\t$feature\t$start\t$end\t$score\t$strand\t.\t$group $hmmstart $hmmend\n";
}


