#!/usr/bin/perl

$usage .= "$0 -- asymmetrise MSPcrunch output\n";
$usage .= "\n";
$usage .= "Usage: $0 [MSPcrunch files...]\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    die "$usage\nUnknown option: $opt\n";
}

while (<>) {
    my @f = split;
    next if /^BLAST/ || !/\S/;
    if (@f < 8) { warn "Line has @{[scalar@f]} fields; skipping\n"; next }
    next if $f[2]=~/\D/ || $f[3]=~/\D/ || $f[5]=~/\D/ || $f[6]=~/\D/;
    next if $f[2] == $f[5] && $f[3] == $f[6] && $f[4] eq $f[7];
    if ($f[2] > $f[3]) { warn "Wrong way round - \@f=(@f) -"; next }
    next if $f[4] gt $f[7] || ($f[4] eq $f[7] && $f[2] > $f[5]);
    
    print;
}
