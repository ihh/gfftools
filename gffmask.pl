#!/usr/bin/perl

# $maskchar = "x";
$maskchar = "n";       #  HACK so that prog defaults to DNA - should really use "-c n" when masking nucleotides

$width = 50;

$usage .= "$0 -- mask GFF-denoted segments out of a FASTA format file\n";
$usage .= "\n";
$usage .= "Usage: $0 [-c maskchar] <GFF files...>\n";
$usage .= "\n";
$usage .= "Acts as a filter on STDIN\n";
$usage .= "\n";
$usage .= "Default maskchar=\"$maskchar\"\n";
$usage .= "\n";

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    $arg = shift;
    if ($arg eq "-c") { $maskchar = substr(shift,0,1) }
    else { die "Unknown option $arg\n\n$usage" }
}

(@ARGV>=1) or die "$usage\nInsufficient number of GFF files specified\n";

foreach $gff (@ARGV) {
    open gff or die "Couldn't open $gff: $!";
    while (<gff>) {
	s/#.*//;
	next unless /\S/;
	($seqname,$from,$label,$start,$end,$score,$strand,$frame,$group) = split /\t/;
	push @{$gff{uc $seqname}},"$start $end";
    }
    close gff;
}

sub mask {
    my $array;
	print $tagline;
}

$/ = ">";
$dummy = <STDIN>;

while (($/="\n",$_=<STDIN>)[1]) {
    ($seqname) = split;

    $/ = ">";
    $sequence = <STDIN>;
    chomp $sequence;
    $sequence =~ s/\s//g;

    foreach (@{$gff{uc $seqname}}) {
	($start,$end) = split;
	substr($sequence,$start-1,$end+1-$start) = $maskchar x ($end+1-$start);
    }

    print ">$seqname\n";
    for ($i=0;$i<length $sequence;$i+=$width) { print substr($sequence,$i,$width)."\n" }
}
