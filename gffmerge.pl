#!/usr/bin/perl

use FileHandle;

$usage = "Usage: $0 [-stdin] <sorted GFF files>\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-stdin") { $stdin = 1 }
    else { die "$usage\nUnknown option: $opt\n" }
}

if ($stdin) { push @ARGV, '-' }
@ARGV > 0 or die $usage;
@file = @ARGV;

for ($i=0;$i<@file;$i++) {
    $fh[$i] = new FileHandle;
    $fh[$i]->open($file[$i]) or die "$0: couldn't open $file[$i]: $!\n";
}

while (1) {
    for ($i=$active_handles=0;$i<@fh;$i++) {
	if (defined($fh[$i]) && !defined($nextline[$i])) {
	    do {
		$nextline[$i] = $fh[$i]->getline;
		$nextline[$i] =~ s/#.*//;
	    } while (defined($nextline[$i]) && $nextline[$i] !~ /\S/);
	    if (defined $nextline[$i]) {
		@gff = split /\t/, $nextline[$i];
		$name[$i] = $gff[0];
		$start[$i] = $gff[3];
		$end[$i] = $gff[4];
	    } else {
		$fh[$i]->close;
		undef $fh[$i];
	    }
	}
	if (defined $nextline[$i]) { ++$active_handles }
    }
    last unless $active_handles;
    @n = sort { (!defined($nextline[$a])) <=> (!defined($nextline[$b]))
		    or $name[$a] cmp $name[$b]
			or $start[$a] <=> $start[$b]
			    or $end[$a] <=> $end[$b] } 0..$#fh;
    print $nextline[$n[0]];
    undef $nextline[$n[0]];
}
