#!/usr/bin/perl

select STDERR; $| = 1; select STDOUT;

$usage .= "$0 - build clusters stupidly on-the-fly from an exblx stream\n";
$usage .= "\n";
$usage .= "Usage: $0 [-verbose] [-minclustersize size] [-maxclustersize size] [-minoverlap frac] <MSPcrunch files>\n";
$usage .= "\n";
$usage .= "Input must be sorted by x-sequence name then by x-sequence startpoint.\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-minclustersize") { defined($minclustersize = shift) or die $usage }
    elsif ($opt eq "-maxclustersize") { defined($maxclustersize = shift) or die $usage }
    elsif ($opt eq "-minoverlap") { defined($minoverlap = shift) or die $usage }
    elsif ($opt eq "-verbose") { $verbose = 1 }
    elsif ($opt eq "-debug") { $debug = 1 }
    else { die "$usage\nUnknown option: $opt" }
}

while (<>) {
    next if /^BLAST ERROR/ || !/\S/;

    @f = split;
    next if $f[2] == $f[5] && $f[3] == $f[6] && $f[4] eq $f[7];

    %clusterflag = ();
    ($xseg,$xnewflag) = newsegindex(@f[4,2,3],\%clusterflag);
    ($yseg,$ynewflag) = newsegindex(@f[7,5,6],\%clusterflag);

    @clusters_to_merge = keys %clusterflag;
    if (@clusters_to_merge == 0) {
	push @cluster, [];
	$thiscluster = $#cluster;

    } elsif (@clusters_to_merge == 1) {
	$thiscluster = $clusters_to_merge[0];

    } elsif (@clusters_to_merge > 1) {
	$thiscluster = $clusters_to_merge[0];
	my @newcluster;
	foreach $i (@clusters_to_merge) {
	    foreach $seg (@{$cluster[$i]}) {
		if (defined $segcluster[$seg]) {
		    $segcluster[$seg] = $thiscluster;
		    push @newcluster, $seg;
		}
	    }
	    undef $cluster[$i];
	}
	$cluster[$thiscluster] = \@newcluster;
	
	$deadclusters += @clusters_to_merge - 1;
    }
    if ($xnewflag) { push @{$cluster[$segcluster[$xseg] = $thiscluster]}, $xseg }
    if ($ynewflag) { push @{$cluster[$segcluster[$yseg] = $thiscluster]}, $yseg }

#    warn "xseg=$xseg yseg=$yseg\n";

    print STDERR "Read $n lines; seen ",@segname-$deadsegments," segments (wastage ",int(100*$deadsegments/@segname),"%); made ",@cluster-$deadclusters," clusters (wastage ",int(100*$deadclusters/@cluster),"%); just did $f[4]/$f[2]-$f[3]\n" if ++$n % 100 == 0 && $verbose;
}

foreach $cluster (sort { @$b <=> @$a } grep(defined($_),@cluster)) {
    last if defined($maxclustersize) && @$cluster > $maxclustersize;
    next if @$cluster < $minclustersize;
    @sorted_cluster = sort { $segname[$a] cmp $segname[$b] or $segstart[$a] <=> $segstart[$b] } @$cluster;
    my ($n,$s,$e,@nse);
    foreach $seg (@sorted_cluster) {
	next unless defined $segcluster[$seg];   # some segments will not get trimmed from cluster list until here... that's OK
	if (!defined($n) || $segname[$seg] ne $n || $segstart[$seg] > $e) {
	    push @nse, "$n/$s-$e" if defined $n;
	    ($n,$s,$e) = ($segname[$seg],$segstart[$seg],$segend[$seg]);
	} else {
	    $e = max($e,$segend[$seg]);
	}
    }
    push @nse, "$n/$s-$e" if defined $n;
    print "@nse\n";
}


sub newsegindex {
    my ($n,$s,$e,$clusterflagref) = @_;
    if ($s > $e) { ($s,$e) = ($e,$s) }

    $seglist{$n} = [] unless defined $seglist{$n};
    my $seglist = $seglist{$n};
    my %hitindex = intersect($s,$e,$seglist,$maxseglen{$n});
    my @hits = keys %hitindex;
    
    my $hitcount = @hits;
    my $newsegflag = $hitcount == 0;
    my $newseg = $newsegflag ? @segstart : $hits[0];
    foreach $i (@hits) {
	$s = min($s,$segstart[$i]);
	$e = max($e,$segend[$i]);
	$clusterflagref->{$segcluster[$i]}++;
	undef $segcluster[$i] unless $i == $newseg;
    }
    $segname[$newseg] = $n;
    $segstart[$newseg] = $s;
    $segend[$newseg] = $e;
    
    # keep seglist sorted
    if ($hitcount == 0) {
	my $i = -1;
	my $step = @$seglist - 1 - $i;
	my ($temp,$step_ok);
	while ($step > 0) {
	    $step_ok = (($temp = $i + $step) >= @$seglist) ? 0 : ($segstart[$seglist->[$temp]] < $s);
	    if ($step_ok) { $i = $temp }
	    else { $step = int($step/2) }
	}
	splice @$seglist, $i+1, 0, $newseg;

    } elsif ($hitcount > 1) {
	my @splicepoint = sort { $a <=> $b } values %hitindex;
	if ($debug) { print STDERR "splicing indices (@splicepoint) from (",join(" ",map("$segstart[$_]-$segend[$_]",@$seglist)),")\n" }
	splice @$seglist, $splicepoint[0], 1 + $splicepoint[$#splicepoint] - $splicepoint[0], $newseg;
	$deadsegments += $hitcount - 1;
    }
    
    if ($e + 1 - $s > $maxseglen{$n}) { $maxseglen{$n} = $e + 1 - $s }

    if ($debug) {
	my $i;
	for ($i=1;$i<@$seglist;$i++) {
	    if ($segstart[$seglist->[$i]] < $segend[$seglist->[$i-1]]) {
		print STDERR "$n/$s-$e hits=(@hits) seglist=(@$seglist) startend=(",join(" ",map("$segstart[$_]-$segend[$_]",@$seglist)),")\n";
		die "seglist out of order";
	    }
	}
	$prev = $segstart[$i];
    }
    
    ($newseg,$newsegflag);
}

sub intersect {
    my ($mspstart,$mspend,$seglist,$maxseglen) = @_;
    if ($mspstart > $mspend) { ($mspstart,$mspend) = ($mspend,$mspstart) }

    my %hitindex;

    # find index of first segment whose endpoint might overlap with region of interest
    my $i = -1;
    my $step = @$seglist - 1 - $i;
    my ($temp,$step_ok);
    while ($step > 0) {
	$step_ok = (($temp = $i + $step) >= @$seglist) ? 0 : ($segend[$seglist->[$temp]] < $mspstart - $maxseglen);
	if ($step_ok) { $i = $temp }
	else { $step = int($step/2) }
    }
    
    # slurp through segments until past region of interest
    while (++$i < @$seglist) {
	my $segindex = $seglist->[$i];
	my ($segstart,$segend) = ($segstart[$segindex],$segend[$segindex]);
	last if $segstart > $mspend;
	next if $segend < $mspstart;
	my $overlap = min($mspend,$segend) + 1 - max($mspstart,$segstart);
	next if defined($minoverlap) && $overlap < $minoverlap * max($segend + 1 - $segstart, $mspend + 1 - $mspstart);
	$hitindex{$segindex} = $i;
    }
    %hitindex;
}

sub min { my ($a,$b) = @_; $a < $b ? $a : $b }
sub max { my ($a,$b) = @_; $a > $b ? $a : $b }

