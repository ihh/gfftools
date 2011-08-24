#!/usr/bin/perl

select STDERR; $| = 1; select STDOUT;

$prefix = $feature = "cluster";
($prog = $0) =~ s/^.*\/([^\/]+)$/$1/;

$usage .= "$0 - make GFF output from single-line cluster input\n";
$usage .= "\n";
$usage .= "Usage: $0 [-prefix prefix] [<cluster files>]\n";
$usage .= "\n";
$usage .= "Default prefix is '$prefix'.\n";
$usage .= "\n";
$usage .= "Each cluster should be a line of space-separated fields like 'name/start-end'.\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-prefix") { defined($prefix = shift) or die $usage }
    else { die "$usage\nUnknown option: $opt" }
}

while (<>) {
    @members = split;
    $group = $prefix.++$n." clustersize=".scalar(@members);
    foreach $nse (@members) {
	die "Bad name/start-end format" unless $nse =~ /^(\S+)\/(\d+)-(\d+)$/;
	($name,$start,$end) = ($1,$2,$3);
	print join("\t",$name,$feature,$prog,$start,$end,".","+",".",$group),"\n";
    }
}
