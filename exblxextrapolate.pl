#!/usr/bin/perl

$usage .= "Usage: $0 [-flip] <min> <max> [<files...>]\n";

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    $arg = lc shift;
    if ($arg eq "-flip") { $flip = 1 }
    else { die "Unknown option $arg\n\n$usage" }
}

@ARGV>=2 or die $usage;
($min,$max,@ARGV) = @ARGV;

while (<>) {
    @f = split;
    if ($flip) { @f[2..4,5..7] = @f[5..7,2..4] }
    if (!defined $n1) { $n1 = $f[4] }
    elsif ($n1 ne $f[4]) { die "Can't cope with more than one primary sequence" }
    if ($f[2] > $f[3]) { @f[2,3,5,6] = @f[3,2,6,5] }
    if ($f[5] > $f[6]) {
	$oldlen = $f[5] - $f[6];
	$f[6] -= $f[2] - $min;
	$f[5] += $max - $f[3];
	$f[0] *= ($f[5] - $f[6]) / $oldlen;
    } else {
	$oldlen = $f[6] - $f[5];
	$f[5] -= $f[2] - $min;
	$f[6] += $max - $f[3];
	$f[0] *= ($f[6] - $f[5]) / $oldlen;
    }
    @f[2,3] = ($min,$max);
    print join("\t",@f)."\n";
}
