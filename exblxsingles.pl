#!/usr/bin/perl

$maxoverlap = .1;

$usage .= "$0 -- filter out multiple hits from MSPcrunch data\n";
$usage .= "\n";
$usage .= "Usage: $0 [-maxoverlap frac] [<MSPcrunch files ...>]\n";
$usage .= "\n";
$usage .= "Default maxoverlap is $maxoverlap\n";
$usage .= " (i.e. anything overlapping more than ".int(100*$maxoverlap)."% of its length is considered a multiple hit)\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = shift;
    if ($opt eq "-maxoverlap") { defined($maxoverlap = shift) or die $usage }
    else { die "$usage\nUnknown option: $opt\n" }
}

while (<>) {
    @f = split;
    if (!defined($g[4]) || $f[4] ne $g[4]) {
	print $g if defined $g;
	@g = @f;
	$g = $_;
	$max_xend = $g[3];
    } else {
	if (defined $g) {
	    if ($g[3] - $f[2] <= $maxoverlap * ($g[3] - $g[2])) { print $g }
	    undef $g;
	}
	if ($max_xend - $f[2] <= $maxoverlap * ($f[3] - $f[2])) { ($g,@g) = ($_,@f) }
	if ($f[3] > $max_xend) { $max_xend = $f[3] }
    }
}
print $g if defined $g;

