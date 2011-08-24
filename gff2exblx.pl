#!/usr/bin/perl

$blastn_pS = .2684;

$source = "BLAST";
$feature = "similarity";

$usage .= "$0 -- convert GFF pairs to exblx format\n";
$usage .= "\n";
$usage .= "Usage: $0 [-flip] [files...]\n";
$usage .= "\n";
$usage .= "-flip option flips seq1 and seq2\n";
$usage .= "\n";

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    $arg = lc shift;
    if ($arg eq "-flip") { $flip = 1 }
    else { die "Unknown option $arg\n\n$usage" }
}

while (<>) {
    s/#.*//;
    next unless /\S/;
    @f = split /\t/, $_, 9;
    if (@f < 9) { warn "Not GFF format"; next }

    unless ($f[8] =~ /^(\S+)\s+(\d+)\s+(\d+)/) { warn "Not a GFF pair"; next }
    ($n2,$s2,$e2) = ($1,$2,$3);
    if ($f[6] eq '-') { ($s2,$e2) = ($e2,$s2) }

    if ($f[8] =~ /\bid=(\S+)/) { $id = $1 }
    else { $id = "-" }

    if ($flip) { (@f[0,3,4],$n2,$s2,$e2) = ($n2,$s2,$e2,@f[0,3,4]) }

    print join("\t",($f[5],$id,@f[3,4,0],$s2,$e2,$n2)),"\n";
}
