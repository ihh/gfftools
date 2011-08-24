#!/usr/bin/perl

$blastn_pS = .2684;

$name = undef;
$source = "BLAST";
$feature = "similarity";

$usage .= "$0 -- convert exblx format to GFF\n";
$usage .= "\n";
$usage .= "Usage: $0 [-flip] [-prob <pS>|-bprob] [-name <name>] [-source <source>] [-feature <feature>] [-evalsource expr] [-evalfeature expr] [files...]\n";
$usage .= "\n";
$usage .= "-flip option flips seq1 and seq2\n";
$usage .= "-source and -feature options used for labelling purposes only\n";
$usage .= "-prob option converts scores to log-odds (bits) with substitution probability pS (DNA) (NB pS=$blastn_pS is closest to default blastn scores; a shorthand for this is the -bprob option)\n";
$usage .= "\n";

while (@ARGV) {
    last unless ($ARGV[0] =~ /^-/);
    $arg = lc shift;
    if ($arg eq "-name") { defined($name = shift) or die $usage }
    elsif ($arg eq "-source") { defined($source = shift) or die $usage }
    elsif ($arg eq "-feature") { defined($feature = shift) or die $usage }
    elsif ($arg eq "-evalsource") { defined($evalsource = shift) or die $usage }
    elsif ($arg eq "-evalfeature") { defined($evalfeature = shift) or die $usage }
    elsif ($arg eq "-flip") { $flip = 1 }
    elsif ($arg eq "-prob") { defined($pS = shift) or die $usage }
    elsif ($arg eq "-bprob") { $pS = $blastn_pS }
    else { die "Unknown option $arg\n\n$usage" }
}

if (defined $pS) {
    $match = log(1 + 3*((1-$pS)**2)) / log(2);
    $mismatch = log(1 - ((1-$pS)**2)) / log(2);
}

while (<>) {
    @f = split;
    if (defined $pS) {
	$frac = $f[1] / 100;
	$len = abs($f[3] - $f[2]) + 1;
	$f[0] = $match*$frac*$len + $mismatch*(1-$frac)*$len;
	$f[0] = int($f[0]*10)/10;
    }
    if ($flip) { @f[2..4,5..7] = @f[5..7,2..4] }
    if ($f[2] > $f[3]) { @f[2,3,5,6] = @f[3,2,6,5] }
    if ($f[5] > $f[6]) { $strand = "-"; @f[5,6] = @f[6,5] }
    else { $strand = "+" }
    if (defined $name) { $f[4] = $name }
    if (defined $evalsource) { $source = eval $evalsource }
    if (defined $evalfeature) { $feature = eval $evalfeature }
    print "$f[4]\t$source\t$feature\t$f[2]\t$f[3]\t$f[0]\t$strand\t.\t@f[7,5,6] id=$f[1]\n";
}

