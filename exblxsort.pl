#!/usr/bin/perl

$usage .= "$0 -- sort MSPcrunch output\n";
$usage .= "\n";
$usage .= "Usage: $0 [-unsorted|-sortedname|-sortedpair] [-sortname|-sortpair] [<MSPcrunch files...>]\n";
$usage .= "\n";
$usage .= "Use -sortedname switch if input is pre-sorted by first seqname (default)\n";
$usage .= "Use -sortedpair switch if input is pre-sorted by first & second seqnames\n";
$usage .= "Use -byname switch if output is to be sorted by first seqname (default)\n";
$usage .= "Use -bypair switch if output is to be sorted by first & second seqname\n";
$usage .= "\n";
$usage .= "Output is *always* sorted by first (then second) seq startpos, but name sorting takes precedence.\n";
$usage .= "\n";

sub by_name { $n1[$a] cmp $n1[$b] or $s1[$a] <=> $s1[$b] or $n2[$a] cmp $n2[$b] or $s2[$a] <=> $s2[$b] }
sub by_pair { $n1[$a] cmp $n1[$b] or $n2[$a] cmp $n2[$b] or $s1[$a] <=> $s1[$b] or $s2[$a] <=> $s2[$b] }

($sortedname,$sortedpair) = (1,0);
($sortname,$sortpair) = (1,0);
$sortsub = "by_name";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-sortedname") { ($sortedname,$sortedpair) = (1,0) }
    elsif ($opt eq "-sortedpair") { ($sortedname,$sortedpair) = (0,1) }
    elsif ($opt eq "-unsorted") { ($sortedname,$sortedpair) = (0,0) }
    elsif ($opt eq "-sortname") { ($sortname,$sortpair) = (1,0); $sortsub = "by_name" }
    elsif ($opt eq "-sortpair") { ($sortname,$sortpair) = (0,1); $sortsub = "by_pair" }
    else { die "$usage\nUnknown option: $opt\n" }
}

while (<>) {
    @f = split;
    if (@g && ($sortedname || $sortedpair) && ($f[4] ne $g[4] || ($f[7] ne $g[7] && $sortpair))) { flush() }
    @f[2,3,5,6] = @f[3,2,6,5] if $f[2] > $f[3];
    push @a, join("\t",@f)."\n";
    push @n1, uc $f[4];
    push @s1, $f[2];
    push @n2, $f[7];
    push @s2, $f[5];
    @g = @f;
}
flush();

sub flush {
    foreach $i (sort $sortsub 0..$#a) { print $a[$i] }
    @a = @n1 = @s1 = @n2 = @s2 = ();
}
