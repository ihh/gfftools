#!/usr/bin/perl

$usage .= "$0 -- tidy up sorted MSPcrunch output\n";
$usage .= "\n";
$usage .= "Usage: $0 [-asym] [-diag] [<MSPcrunch files...>]\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-verbose") { $verbose = 1 }
    elsif ($opt eq "-asym") { $asym = 1 }
    elsif ($opt eq "-diag") { $diagonalise = 1 }
    else { die "$usage\nUnknown option: $opt\n" }
}

while (<>) {
    my @f = split;
    next if /^BLAST/ || !/\S/;
    next if @f != 8;
    next if $f[2]=~/\D/ || $f[3]=~/\D/ || $f[5]=~/\D/ || $f[6]=~/\D/;

    if ($diagonalise) { $f[6] = $f[5] + sgn($f[6]-$f[5]) * ($f[3]-$f[2]) }
    next if $f[2] == $f[5] && $f[3] == $f[6] && $f[4] eq $f[7];
    if ($f[2] > $f[3]) { warn "Wrong way round - \@f=(@f) -"; next }
    next if $asym && ($f[4] gt $f[7] || ($f[4] eq $f[7] && $f[2] > $f[5]));

    if (@g == 0 || $f[4] ne $g[4] || $f[7] ne $g[7]) { flush_cache(\@cache,\$lastpos) }
    else { next if check_unsorted(\@f,$lastpos) }

    if (defined($i = cache_intersect_index(\@cache,\@f))) { $cache[$i] = merge($cache[$i],\@f) }
    else { push @cache, \@f }

    update_cache(\@cache,$f[2],\$lastpos);

    @g = @f;
}
flush_cache(\@cache,\$lastpos);


sub flush_cache {
    my ($cache,$lastpos) = @_;
    foreach (@$cache) { print_cache_entry($_) }
    @$cache = ();
    $$lastpos = 0;
}

sub print_cache_entry {
    my ($f) = @_;
    print join("\t",@$f)."\n";
}

sub check_unsorted {
    my ($msp,$lastpos) = @_;
    if ($msp->[2] < $lastpos) { warn "Unsorted (msp=[@$msp], lastpos=$lastpos)"; return 1 }
    return 0;
}

sub update_cache {
    my ($cache,$pos,$lastpos) = @_;
    my $i;
    for ($i=0;$i<@$cache;$i++) { last if $cache->[$i]->[3] >= $pos - 1 }
    for (;$i>0;$i--) { print_cache_entry(shift @$cache) }
    $$lastpos = $pos;
}

sub cache_intersect_index {
    my ($cache,$f) = @_;
    my $dir = $f->[5] <= $f->[6] ? +1 : -1;
    my $diag = $f->[2] - $f->[5] * $dir;
    my $i;
    for ($i=0;$i<@$cache;$i++) {
	my $msp = $cache->[$i];
	last if $msp->[3] < $f->[2] - 1;
	next unless ($msp->[6] - $msp->[5]) * $dir > 0;
	next unless ($msp->[2] - $msp->[5] * $dir) == $diag;
	return $i;
    }
    undef;
}

sub merge {
    my ($a,$b) = @_;
    my $forward = ($a->[5] < $a->[6]);
    if (($forward && $a->[5] > $b->[5]) || (!$forward && $a->[5] < $b->[5])) { ($a,$b) = ($b,$a) }
    my @f = @$a;
    my ($alen,$blen) = ($a->[3] - $a->[2], $b->[3] - $b->[2]);
    my $overlap = $a->[3] - $b->[2] + 1;
    if ($overlap == $alen + $blen) { return $a }
    $f[0] = $a->[0] + $b->[0] - ($overlap/2) * ($a->[0]/$alen + $b->[0]/$blen);
    $f[1] = ($a->[1] * $alen + $b->[1] * $blen - ($overlap/2) * ($a->[1] + $b->[1])) / ($alen + $blen - $overlap);
    $f[3] = $b->[3];
    $f[6] = $b->[6];
    warn "Merging MSPs -- overlap = $overlap\n" if $verbose;
    \@f;
}

sub sgn { $_[0] <=> 0 }
