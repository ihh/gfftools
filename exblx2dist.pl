#!/usr/bin/perl

$usage .= "$0 - convert MSPcrunch output to a PHYLIP distance matrix\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    die "$usage\nUnknown option: $opt";
}

while (<>) {
    @f = split;
    $f[4] = uc $f[4];
    $f[7] = uc $f[7];
    if ($f[4] gt $f[7]) { @f[2..4,5..7] = @f[5..7,2..4] }
    $tag = "@f[4,7]";
    if (!defined($score{$tag}) || $f[0] > $score{$tag}) {
	$score{$tag} = $f[0];
	$dist{$tag} = $dist{"@f[7,4]"} = (100 - $f[1]) / 100;
    }
    $seq{$f[4]} = $seq{$f[7]} = 1;
}

@seq = sort keys %seq;

$maxdist = 2 * max(values %dist);
if ($maxdist > 1) { $maxdist = 1 }

print scalar(@seq)."\n";
foreach $seq (@seq) {
    print join(" ",$seq,map(exists($dist{"$seq $seq[$_]"}) ? $dist{"$seq $seq[$_]"} : $maxdist,0..$#seq))."\n";
}


sub min {
    my ($min,$x);
    foreach $x (@_) { if (!defined($min) || $x < $min) { $min = $x } }
    $min;
}

sub max {
    my ($max,$x);
    foreach $x (@_) { if (!defined($max) || $x > $max) { $max = $x } }
    $max;
}

