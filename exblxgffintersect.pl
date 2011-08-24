#!/usr/bin/perl

$usage .= "$0 - find intersection of MSPcrunch & GFF files\n";
$usage .= "\n";
$usage .= "Usage: $0 [-mingffrac xxx] [-minmspfrac xxx] [-near xxx] [-verbose] [-not] [-x|-y|-xy] [-keepcase] <GFF file> [<MSPcrunch files>]\n";
$usage .= "\n";
$usage .= "Prints lines from <MSPcrunch files> that intersect (or do not intersect) <GFF file>\n";
$usage .= "\n";
$usage .= "MSPcrunch data don't *have* to be sorted by name-pair, but it helps\n";
$usage .= "\n";
$usage .= "Use -x, -y, -xory, -xandy, -xeory to test for intersection only on x-sequence\n";
$usage .= " (or y-sequence, or both, or either-or) (default is -xory)\n";
$usage .= "Use -not to print lines that don't intersect rather than lines that do\n";
$usage .= "Use -keepcase if you don't want sequence names to be converted to upper case\n";
$usage .= "Use -mingfffrac & -minmspfrac to specify minimum overlap fraction for GFF & MSP respectively (default is 0 for both)\n";
$usage .= "Use -near to extend definition of intersection to near-neighbours\n";
$usage .= "Use -trim to trim according to GFF hits\n";
$usage .= "Use -env to use envelope information from field 9 of MSPcrunch file in '[x1-x2,y1-y2];[x1-x2,y1-y2];...' format\n";
$usage .= "\n";

$testx = $testy = 1;
$and = 0;

while (@ARGV) {
    last unless $ARGV[0] =~ /^-./;
    $opt = lc shift;
    if ($opt eq "-not") { $not = 1 }
    elsif ($opt eq "-x") { ($testx,$testy) = (1,0); $and = 0 }
    elsif ($opt eq "-y") { ($testx,$testy) = (0,1); $and = 0 }
    elsif ($opt eq "-xory") { ($testx,$testy) = (1,1); $and = 0 }
    elsif ($opt eq "-xandy") { ($testx,$testy) = (1,1); $and = 1 }
    elsif ($opt eq "-xeory") { ($testx,$testy) = (1,1); $and = -1 }
    elsif ($opt eq "-verbose") { $verbose = 1 }
    elsif ($opt eq "-keepcase") { $keepcase = 1 }
    elsif ($opt eq "-mingfffrac") { defined($mingfffrac = shift) or die $usage }
    elsif ($opt eq "-minmspfrac") { defined($minmspfrac = shift) or die $usage }
    elsif ($opt eq "-near") { defined($near = shift) or die $usage }
    elsif ($opt eq "-trim") { $trim = 1 }
    elsif ($opt eq "-env") { $env = 1 }
    else { die "$usage\nUnknown option: $opt\n" }
}

@ARGV > 0 or die $usage;
($gfffile,@ARGV) = @ARGV;

warn "Reading $gfffile ...\n" if $verbose;

open GFF, $gfffile or die "Can't open $gfffile: $!";
while (<GFF>) {
    my @f = split /\t/, $_, 9;
    die "Not GFF format" if @f != 9;
    die "Bad GFF" if $f[3] > $f[4];
    unless ($keepcase) { $f[0] = uc $f[0] }
    push @{$gffstartlist_byname{$f[0]}}, $f[3];
    push @{$gffendlist_byname{$f[0]}}, $f[4];
}
close GFF;

# sort gffstartlists & gffendlists by startpoint
# & make lists describing the endpoint rank

warn "Sorting $gfffile ...\n" if $verbose;

foreach $seqname (keys %gffstartlist_byname) {
    $gffstartlist = $gffstartlist_byname{$seqname};
    $gffendlist = $gffendlist_byname{$seqname};
    @startrank = sort { $gffstartlist->[$a] <=> $gffstartlist->[$b] } (0..@$gffstartlist-1);
    @$gffstartlist = @$gffstartlist[@startrank];
    @$gffendlist = @$gffendlist[@startrank];
    $maxgfflen = 0;
    for ($i=0;$i<@$gffstartlist;$i++) { if (($temp = $gffendlist->[$i] - $gffstartlist->[$i]) > $maxgfflen) { $maxgfflen = $temp } }
    $maxgfflen_byname{$seqname} = $maxgfflen;
}

warn "Processing MSPcrunch data\n" if $verbose;

while (<>) {
    @f = split;
    if (@f < 8) { warn "Line has @{[scalar@f]} fields; skipping\n"; next }
    if ($f[2] > $f[3]) { @f[2,3,5,6] = @f[3,2,6,5] }
    unless ($keepcase) { $f[4] = uc $f[4]; $f[7] = uc $f[7] }

    if ($f[4] ne $lastx || $f[7] ne $lasty) {
	warn "Scanning MSPs for $f[4] vs $f[7] ...\n" if $verbose;

	$xgffstartlist = $gffstartlist_byname{$f[4]};
	$xgffendlist = $gffendlist_byname{$f[4]};
	$xmaxgfflen = $maxgfflen_byname{$f[4]};

	$ygffstartlist = $gffstartlist_byname{$f[7]};
	$ygffendlist = $gffendlist_byname{$f[7]};
	$ymaxgfflen = $maxgfflen_byname{$f[7]};

	($lastx,$lasty) = @f[4,7];
    }

    my ($xtrue,$ytrue,$print,@newseg,$oldlen);

    if ($env) {
	foreach $envsegtext (split /;/, $f[8]) {
	    my @g = ($envsegtext =~ /\[(\d+)-(\d+),(\d+)-(\d+)\]/);
	    die "Bad envelope format" unless @g == 4;
	    push @newseg, trim(@g,$xgffstartlist,$xgffendlist,$xmaxgfflen,$ygffstartlist,$ygffendlist,$ymaxgfflen,\$xtrue,\$ytrue);
	    $oldlen += $g[1] - $g[0];
	}
    } else {
	@newseg = trim(@f[2,3,5,6],$xgffstartlist,$xgffendlist,$xmaxgfflen,$ygffstartlist,$ygffendlist,$ymaxgfflen,\$xtrue,\$ytrue);
	$oldlen = $f[3] - $f[2];
    }

    if ($trim) { $print = @newseg }
    else {
	if ($and == 1) { $print = $xtrue && $ytrue }
	elsif ($and == -1) { $print = ($xtrue || $ytrue) && !($xtrue && $ytrue) }
	else { $print = $xtrue || $ytrue }
	if ($not) { $print = !$print }
    }
    
    if ($print && $trim) {
	if ($env) {
	    $f[8] = join(";",map("[$_->[0]-$_->[1],$_->[2]-$_->[3]]",@newseg));
	    $f[2] = $newseg[0]->[0];
	    $f[3] = $newseg[$#newseg]->[1];
	    $f[5] = $newseg[0]->[2];
	    $f[6] = $newseg[$#newseg]->[3];
	    my $newlen;
	    foreach $seg (@newseg) { $newlen += $seg->[1] + 1 - $seg->[0] }
	    $f[0] = int($f[0]*$newlen/$oldlen);
	    $_ = join("\t",@f)."\n";
	} else {
	    $_ = join("",map(join("\t",(int($f[0]*($_->[1]+1-$_->[0])/$oldlen),$f[1],@$_[0,1],$f[4],@$_[2,3],$f[7]))."\n",@newseg));
	}
    }
    
    print if $print;
}

sub trim {
    my ($mspx1,$mspx2,$mspy1,$mspy2,$xgffstartlist,$xgffendlist,$xmaxgfflen,$ygffstartlist,$ygffendlist,$ymaxgfflen,$xtrue,$ytrue) = @_;
    die "Not a diagonal segment" if $trim && abs($mspy2-$mspy1) != $mspx2-$mspx1;
    my (@xhitflag,@yhitflag,@hitflag,@hitseg,$i);
    if ($testx) { $$xtrue ||= intersect($mspx1,$mspx2,$xgffstartlist,$xgffendlist,$xmaxgfflen,$trim ? \@xhitflag : undef) }
    if ($testy) { $$ytrue ||= intersect($mspy1,$mspy2,$ygffstartlist,$ygffendlist,$ymaxgfflen,$trim ? \@yhitflag : undef) }
    if ($trim && ($$xtrue || $$ytrue || $not)) {
	my $mspydir = $mspy2 <=> $mspy1;
	for ($i=0;$i<=$mspx2-$mspx1;$i++) {
	    if ($and == 1) { $hitflag[$i] = $xhitflag[$i] && $yhitflag[$i] }
	    elsif ($and == -1) { $hitflag[$i] = ($xhitflag[$i] || $yhitflag[$i]) && !($xhitflag[$i] && $yhitflag[$i]) }
	    else { $hitflag[$i] = $xhitflag[$i] || $yhitflag[$i] }
	    if ($not) { $hitflag[$i] = !$hitflag[$i] }
#	    $xhitflag[$i] += 0; $yhitflag[$i] += 0; $hitflag[$i] += 0;
	}
#	warn "xhitflag=(@xhitflag) yhitflag=(@yhitflag) hitflag=(@hitflag)\n";
	for ($i=0;$i<@hitflag;) {
	    unless ($hitflag[$i]) { while (++$i < @hitflag) { last if $hitflag[$i] } }
	    if ($i < @hitflag) {
		my $i0 = $i;
		while (++$i < @hitflag) { last unless $hitflag[$i] }
		push @hitseg, [$mspx1+$i0, $mspx1+$i-1, $mspy1+$i0*$mspydir, $mspy1+($i-1)*$mspydir];
	    }
	}
#	$i=0; foreach (@hitseg) { print STDERR "hitseg[",$i++,"]=(@$_) " } print STDERR "\n";
    }
    @hitseg;
}

sub intersect {
    my ($mspstart,$mspend,$gffstartlist,$gffendlist,$maxgfflen,$hitflag) = @_;
    my $mspdir = +1;
    if ($mspstart > $mspend) { ($mspstart,$mspend,$mspdir) = ($mspend,$mspstart,-1) }
    my $intersectflag = 0;

    # find index of first segment whose endpoint might overlap with region of interest
    my $gfflistlen = @$gffstartlist;
    my $i = -1;
    my $step = $gfflistlen - 1 - $i;
    my ($temp,$step_ok);
    while ($step > 0) {
	$step_ok = (($temp = $i + $step) >= $gfflistlen) ? 0 : ($gffendlist->[$temp] < $mspstart - $maxgfflen);
	if ($step_ok) { $i = $temp }
	else { $step = int($step/2) }
    }

    # slurp through segments until past region of interest
    while (++$i < $gfflistlen) {
	my ($gffstart,$gffend) = ($gffstartlist->[$i],$gffendlist->[$i]);
	last if $gffstart - $near > $mspend;
	next if $gffend + $near < $mspstart;
	my $overlap = min($mspend,$gffend) + 1 - max($mspstart,$gffstart) + $near;
	next if defined($mingfffrac) && $overlap < $mingfffrac * ($gffend + 1 - $gffstart);
	next if defined($minmspfrac) && $overlap < $minmspfrac * ($mspend + 1 - $mspstart);
	return 1 unless defined $hitflag;
	$intersectflag = 1;
#	warn "intersecting ($mspstart,$mspend) with ($gffstart,$gffend)\n";
	my $k;
	for ($k=max($gffstart,$mspstart)-$mspstart;$k<=min($gffend,$mspend)-$mspstart;$k++) { $hitflag->[$k]++ }
    }
    if (defined($hitflag) && $intersectflag && $mspdir < 0) {
	$hitflag->[$mspend-$mspstart] += 0;
	@$hitflag = reverse @$hitflag;
    }
    return $intersectflag;
}

sub min { my ($a,$b) = @_; $a < $b ? $a : $b }
sub max { my ($a,$b) = @_; $a > $b ? $a : $b }
