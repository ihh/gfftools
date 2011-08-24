#!/usr/bin/perl

while (<>) {
    if (/^Bits/) {
	$_ = <>;
	@f = split;
	if ($f[5] > $f[6]) {
	    @f[5,6] = @f[6,5];
	    $s = "-";
	} else {
	    $s = "+";
	}
	print "$f[4]\tspcwise\t$f[1]\t$f[5]\t$f[6]\t$f[0]\t$s\t0\t@f[1,2,3] indels: $f[7] introns: $f[8]\n";
    }
}
