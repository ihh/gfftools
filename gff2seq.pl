#!/usr/bin/perl

@fields = qw(seqname source feature start end score strand frame group);

$width = 50;

use SeqFileIndex;
use GFFTransform;

$usage .= "$0 - extract GFF-specified sequences from a sequence database\n";
$usage .= "\n";
$usage .= "Usage: $0 [-ucname] [-prefix prefix|-name expr|-nametag] [-trans <GFF transformation file>] <sequence file> [<GFF file(s)>]\n";
$usage .= "\n";
$usage .= "Use '\$name' within name expression to access original name\n";
$usage .= "\n";

$ucname = $nametag = 0;
while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-prefix") { defined($prefix = shift) or die $usage }
    elsif ($opt eq "-ucname") { $ucname = 1 }
    elsif ($opt eq "-name") { defined($nameexpr = shift) or die $usage }
    elsif ($opt eq "-nametag") { $nametag = 1 }
    elsif ($opt eq "-trans") { defined($trans = shift) or die $usage }
    else { die "$usage\nUnknown option: $opt\n" }
}

if (defined $nameexpr) { for ($i=0;$i<@fields;$i++) { $nameexpr =~ s/\$gff$fields[$i]/\$gff->[$i]/g } }

if (defined $trans) { read_transformation($trans); sort_seqnames() }

@ARGV>=1 or die $usage;
$seqfile = shift;

$index = new SeqFileIndex($seqfile, 0, !$ucname);

while (<>) {
    s/\#.*//;
    next unless /\S/;
    chomp;
    @f = split /\t/;
    $gff = \@f;
    ++$count;
    $f[0] = uc($f[0]) if $ucname;
    if ($f[4] < $f[3]) { warn "WARNING - malformed GFF: start/end co-ords reversed - skipping line\n"; next }
    if (defined $trans) { @nse = back_transform(@f[0,3,4]) }
    else { @nse = ([@f[0,3,4]]) }
    if (@nse) {
	$reversed = $f[6] eq '-';
	$name = undef;
	if (defined $prefix) { $name = "$prefix$count" }
	elsif (defined $nameexpr) { $name = eval $nameexpr }
	elsif ($nametag) { %tag = map {/^([^=]+)=(.*)/;($1,$2)} split (/\s+/, $f[8]); $name = $tag{'name'} }
	if (!defined $name) { $name = "$f[0]/$f[3]-$f[4]"; $name .= "/rev" if $reversed }
	$seq = "";
	foreach $nse (@nse) { $seq .= $index->getseq(@$nse) }
	$seq = revcomp($seq) if $reversed;
	if (length $seq) {
	    print ">$name\n";
	    for ($i=0;$i<length $seq;$i+=$width) {
		print substr($seq,$i,$width), "\n";
	    }
	}
    }
}

sub revcomp {
    my ($seq) = @_;
    $seq = lc $seq;
    $seq =~ tr/acgt/tgca/;
    $seq = join ("", reverse split (//, $seq));
    $seq;
}
