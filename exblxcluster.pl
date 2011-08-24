#!/usr/bin/perl

select STDERR; $| = 1; select STDOUT;

$singleline = 1;

$usage .= "$0 - build clusters from MSPcrunch output\n";
$usage .= "\n";
$usage .= "Usage: $0 [-verbose] [-singleline|-multiline] [-minclustersize size] [-maxclustersize size] [-minoverlap frac] [-minmaxoverlap frac] <MSPcrunch files>\n";
$usage .= "\n";
$usage .= "Use -singleline or -multiline to force single- or multiple-line output of clusters (default is -singleline)\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-minclustersize") { defined($minclustersize = shift) or die $usage }
    elsif ($opt eq "-maxclustersize") { defined($maxclustersize = shift) or die $usage }
    elsif ($opt eq "-singleline") { $singleline = 1; $multiline = 0 }
    elsif ($opt eq "-multiline") { $singleline = 0; $multiline = 1 }
    elsif ($opt eq "-minoverlap") { defined($minoverlap = shift) or die $usage }
    elsif ($opt eq "-minmaxoverlap") { defined($minmaxoverlap = shift) or die $usage }
    elsif ($opt eq "-verbose") { $verbose = 1 }
    else { die "$usage\nUnknown option: $opt" }
}

print STDERR "Reading MSPs ...\n" if $verbose;

$sets = 0;
while (<>) {
    next if /^BLAST ERROR/ || !/\S/;

    @f = split;
    next if $f[2] == $f[5] && $f[3] == $f[6] && $f[4] eq $f[7];

    push @msp, $_;
    addseg(@f[2..4],@msp+0);
    addseg(@f[5..7],-@msp);

    if ($verbose) {
	if ($f[4] ne $g[4] || $f[7] ne $g[7]) {
	    print STDERR "Reading $f[4] vs $f[7]\n";
	}
    }
    @g = @f;
}

# sort segstartlists & segendlists by startpoint

print STDERR "Sorting segments ...\n" if $verbose;

foreach $seqname (keys %segstartlist_byname) {
    print STDERR "$seqname: sorting; " if $verbose;

    $segstartlist = $segstartlist_byname{$seqname};
    $segendlist = $segendlist_byname{$seqname};
    $segmspindexlist = $segmspindexlist_byname{$seqname};

    @startrank = sort { $segstartlist->[$a] <=> $segstartlist->[$b] } (0..@$segstartlist-1);

    @$segstartlist = @$segstartlist[@startrank];
    @$segendlist = @$segendlist[@startrank];
    @$segmspindexlist = @$segmspindexlist[@startrank];

    $maxseglen = 0;
    for ($i=0;$i<@$segstartlist;$i++) { if (($temp = $segendlist->[$i] - $segstartlist->[$i]) > $maxseglen) { $maxseglen = $temp } }
    $maxseglen_byname{$seqname} = $maxseglen;

    # find intersecting segments
    $seglistlen = @$segstartlist;
    print STDERR "clustering[$seglistlen]; " if $verbose;
    for ($i=0; $i<$seglistlen; $i++) {
	next unless defined getmsp($segmspindexlist->[$i]);
	($segistart,$segiend) = ($segstartlist->[$i],$segendlist->[$i]);
	$segkey = "$seqname $i";
	$segcluster{$segkey} = "$i";
	$segclustersize{$segkey} = 1;
	
	# find index of first segment whose endpoint might overlap with this one
	$j = -1;
	$step = $seglistlen - 1 - $j;
	while ($step > 0) {
	    $step_ok = (($temp = $j + $step) >= $seglistlen) ? 0 : ($segendlist->[$temp] < $segistart - $maxseglen);
	    if ($step_ok) { $j = $temp }
	    else { $step = int($step/2) }
	}
	
	# slurp through segments until past endpoint of this segment
	while (++$j < $seglistlen) {
	    next if $j == $i;
	    next unless defined getmsp($segmspindexlist->[$j]);
	    ($segjstart,$segjend) = ($segstartlist->[$j],$segendlist->[$j]);
	    last if $segjstart > $segiend;
	    next if $segjend < $segistart;
	    $overlap = min($segiend,$segjend) + 1 - max($segistart,$segjstart);
	    next if defined($minoverlap) && $overlap < $minoverlap * max(($segiend + 1 - $segistart),($segjend + 1 - $segjstart));
	    next if defined($minmaxoverlap) && $overlap < $minoverlap * min(($segiend + 1 - $segistart),($segjend + 1 - $segjstart));
	    $segcluster{$segkey} .= " $j";
	    ++$segclustersize{$segkey};
	}
    }
}

print STDERR "\n" if $verbose;
print STDERR "Estimating optimal cluster set ...\n" if $verbose;

@oldmsp = @msp;
@segkeys = keys %segclustersize;
while (@segkeys) {
    @segkeys = sort { $segclustersize{$b} <=> $segclustersize{$a} or $a cmp $b } @segkeys unless $sorted;
    $sorted = 1;

    $segkey = shift @segkeys;
#    warn "segkey=$segkey\n";

    $clustersize = $segclustersize{$segkey};
    next unless $clustersize;
    last if defined($minclustersize) && $clustersize < $minclustersize;
    next if defined($maxclustersize) && $clustersize > $maxclustersize;

    ($seqname,$i) = split /\s+/, $segkey;
    next unless defined(getmsp($segmspindexlist_byname{$seqname}->[$i]));
    @mspindex = map($segmspindexlist_byname{$seqname}->[$_], split(/\s+/, $segcluster{$segkey}));
#    warn "segkey=($segkey) segcluster=($segcluster{$segkey})\n";
    $output = "";
    $count = $clustersize;
    foreach $mspindex (@mspindex) {
	next unless defined($_ = getmsp($mspindex));
	@f = split;
	if ($multiline) { $output .= $_ }
	else { $output .= "$f[4]/$f[2]-$f[3] $f[7]/$f[5]-$f[6] " }
	--$count;
	undef $msp[abs($mspindex) - 1];
	
	%neighbourflag = ();
	@neighbourindex = ();

	foreach $k (split(/\s+/,$segcluster{seg2key(@f[2..4])})) { ++$neighbourflag{"$f[4] $k"} }
	foreach $k (split(/\s+/,$segcluster{seg2key(@f[5..7])})) { ++$neighbourflag{"$f[7] $k"} }
	foreach $neighbourkey (keys %neighbourflag) { if (--$segclustersize{$neighbourkey}) { $sorted = 0 } }
#	warn "Using (@{[seg2key(@f[2..4])]})-(@{[seg2key(@f[5..7])]}) depletes ".join(" ",map("($_)",keys %neighbourflag))."\n";
    }
    if ($count != 0) { @msp = @oldmsp; foreach $i (@mspindex) { $_=getmsp($i); @f=split; print "oldmsp: (@{[seg2key(@f[2..4])]})-(@{[seg2key(@f[5..7])]})\n" } }
    die "($segkey): clustersize=$clustersize count=$count" unless $count==0;
    if ($singleline) { chop $output; $output .= "\n" }
    print $output if length($output) > 1;
}

sub addseg {
    my ($start,$end,$seqname,$mspindex) = @_;
    push @{$segstartlist_byname{$seqname}}, $start;
    push @{$segendlist_byname{$seqname}}, $end;
    push @{$segmspindexlist_byname{$seqname}}, $mspindex;
}

sub min { my ($a,$b) = @_; $a < $b ? $a : $b }
sub max { my ($a,$b) = @_; $a > $b ? $a : $b }

sub seg2key {
    my ($start,$end,$seqname,$mspindex) = @_;
    my $segstartlist = $segstartlist_byname{$seqname};
    my $segendlist = $segendlist_byname{$seqname};
    my $seglistlen = @$segstartlist;
    my $i = -1;
    my $step = $seglistlen - 1 - $i;
    my $temp;
    while ($step > 0) {
	my $step_ok = (($temp = $i + $step) >= $seglistlen) ? 0 : ($segstartlist->[$temp] < $start);
	if ($step_ok) { $i = $temp }
	else { $step = int($step/2) }
    }
    while (++$i < $seglistlen) { last if $segstartlist->[$i] == $start && $segendlist->[$i] == $end }
    "$seqname $i";
}

sub getmsp {
    my $index = shift;
    $_ = $msp[abs($index) - 1];
    if (defined($_) && $index < 0) {
	my @f = split;
	$_ = "@f[0,1] @f[5..7] @f[2..4]\n";
    }
    $_;
}
