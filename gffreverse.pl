#!/usr/bin/perl

while (<>) {
    s/#.*//;
    next unless /\S/;
    @f = split /\t/, $_, 9;

    $f[8] =~ s/-(\d+)(.)-(\d+)/$3$2$1/g;
    if ($f[8] =~ /^(\S+)\s+(\d+)\s+(\d+)/) {
	($pn,$ps,$pe) = ($oldpn,$oldps,$oldpe) = ($1,$2,$3);
	(@f[0,3,4],$pn,$ps,$pe) = ($pn,-$pe,-$ps,$f[0],-$f[4],-$f[3]);
	if ($f[3] > $f[4]) { (@f[3,4],$ps,$pe) = (@f[4,3],$pe,$ps) }
	if ($ps > $pe) { $f[6] = $f[6] eq '-' ? '+' : '-'; ($ps,$pe) = ($pe,$ps) }
	$f[8] =~ s/$oldpn(\s+)$oldps(\s+)$oldpe/$pn$1$ps$2$pe/;
    } else {
	@f[3,4] = (-$f[4],-$f[3]);
	$f[6] = $f[6] eq '-' ? '+' : '-';
    }
    
    push @a, join("\t",@f);
    push @n, $f[0];
    push @s, $f[3];
    push @e, $f[4];
}

foreach $i (sort { $n[$a] cmp $n[$b] or $s[$a] <=> $s[$b] or $e[$a] <=> $e[$b] } 0..$#a) { print $a[$i] }
