#!/usr/bin/perl

$progname = $0;
$progname =~ s/.*\/(\S+)$/$1/;

$windowsize = 12;
$windowstep = 1;
$minentropy = 0.721;
$wordlen = 1;

$maskchar = "x";
$linelen = 50;

$usage .= "$0 -- low-complexity filter for FASTA-format sequence data\n";
$usage .= "\n";
$usage .= "Usage: $0 [-w windowsize] [-s windowstep] [-e minentropy] [-n wordlen] [-m <maskchar>] [-s[tatsonly]] [-gff] [files...]\n";
$usage .= "\n";
$usage .= "Defaults: windowsize = $windowsize\n";
$usage .= "          windowstep = $windowstep\n";
$usage .= "          minentropy = $minentropy bits\n";
$usage .= "          wordlen    = $wordlen (i.e. entropy calculated from distribution of $wordlen-mers within window)\n";
$usage .= "          maskchar   = $maskchar\n";
$usage .= "\n";
$usage .= "*** WARNING ***  --  windowstep and wordlen features not completely tested!\n";
$usage .= "\n";

$log2 = log(2);
sub entropy {
    my ($string) = @_;
    my %freq = ();
    my $total = 0;
    my $i;
    my $word;
    for ($i=0;$i<=(length($string) - $wordlen);$i++) {
	$word = substr $string,$i,$wordlen;
	$freq{$word}++;
	$total++;
    }
    my $entropy = 0;
    foreach $word (keys %freq) { $entropy -= ($freq{$word}/$total) * log($freq{$word}/$total); }
    return $entropy / $log2;
}

sub gffprint {
    my ($seqname,$start,$end,$label,$group) = @_;
    my $e = entropy(substr $sequence,$start,$end+1-$start);
    ++$start;
    ++$end;
    print "$seqname\t$progname\t$label\t$start\t$end\t$e\t.\t.\t$group\n";
}

sub mask {
    $linepos = 0;
    if ($sequence) {
	$maskstart = $unmaskstart = -1;
	for ($wpos=0;$wpos<length $sequence;$wpos++) {
	    if ($wpos % $windowstep == 0) {
		if ($wpos<=length($sequence)-$windowsize || $wpos==0) {
		    $entropy = entropy(substr($sequence,$wpos,$windowsize));
		    $ecount{$entropy}++;
		    if ($entropy<$minentropy) {
			if ($gff && $wpos>$unmaskstart) {
			    if ($unmaskstart<0) { $unmaskstart = 0; }
			    if ($wpos>$unmaskstart) { gffprint($seqname,$unmaskstart,$wpos-1,$highcomplexitylabel,$highcomplexitygroup); }
			    $maskstart = $wpos;
			}
			$unmaskstart = $wpos + $windowsize;
		    }
		}
	    }
	    if ($gff) {
		if ($wpos==$unmaskstart) {
		    gffprint($seqname,$maskstart,$wpos-1,$lowcomplexitylabel,$lowcomplexitygroup);
		}
	    } else {
		unless ($statsonly) {
		    if ($wpos>=$unmaskstart) { print substr($sequence,$wpos,1); }
		    else { print $maskchar; }
		    if (++$linepos >= $linelen) { print "\n"; $linepos=0; }
		}
	    }
	}
	if ($gff) {
	    if ($wpos<=$unmaskstart) {
		gffprint($seqname,$maskstart,$wpos-1,$lowcomplexitylabel,$lowcomplexitygroup);
	    } else {
		if ($unmaskstart<0) { $unmaskstart = 0; }
		gffprint($seqname,$unmaskstart,$wpos-1,$highcomplexitylabel,$highcomplexitygroup);
	    }
	}
	unless ($statsonly || $gff || ($linepos==0)) { print "\n"; }
    }
    print unless ($statsonly || $gff);
    s/^>//;
    ($seqname,@dummy) = split;
    undef $sequence;
}

while (@ARGV) {
    last unless ($ARGV[0] =~ /-/);
    $arg = shift;
    if ($arg eq "-w") { $windowsize = shift; }
    elsif ($arg eq "-e") { $minentropy = shift; }
    elsif ($arg eq "-n") { $wordlen = shift; }
    elsif ($arg eq "-s" || $arg eq "-statsonly") { $statsonly = 1; }
    elsif ($arg eq "-g" || $arg eq "-gff") { $gff = 1; }
    elsif ($arg eq "-m" || $arg eq "-maskchar") { $maskchar = shift; }
    else { die "Unknown option: $arg\n\n$usage"; }
}

$highcomplexitylabel = "high";
$highcomplexitygroup = "S>=$minentropy";
$lowcomplexitylabel = "low";
$lowcomplexitygroup = "S<$minentropy";

unless (@ARGV) { @ARGV = ("-"); }
foreach $file (@ARGV) {
    open file or die "Couldn't open $file: $!";
    while (<file>) {
	if (/>/) {
	    mask();
	} else {
	    if (/\S/) {
		s/\s//g;
		$sequence .= $_;
	    }
	}
    }
    close file;
    mask();
}

if ($statsonly) {
    print STDERR "Frequency distribution of window entropies\n";
    print STDERR "==========================================\n\n";
    print STDERR "Entropy\tFrequency\n";
    foreach $entropy (sort {$a<=>$b} keys %ecount) {
	printf "%.4f\t%d\n", $entropy, $ecount{$entropy};
    }
}
