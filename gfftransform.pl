#!/usr/bin/perl

require GFFTransform;

$usage .= "$0 - transform GFF file co-ordinate system\n";
$usage .= "\n";
$usage .= "Usage: $0 [-sortedname] [-pair] [-pairfeature <regexp>] <transformation file> [<input file>]\n";
$usage .= "\n";
$usage .= "Use -sortedname to sort output by <seqname> and <start> (input file must be specified and sorted by <seqname> field)\n";
$usage .= "Use -pair switch to also transform first three words of <group> field as though they were co-ords\n";
$usage .= "Use -pairfeature to selectively transform fields with a match to <regexp> in the <feature> field\n";
$usage .= "\n";
$usage .= "WARNING - currently assumes a many=>one mapping from oldseqname=>newseqname\n";
$usage .= "\n";

$| = 1;

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-sortedname") { $sortedname = 1 }
    elsif ($opt eq "-pair") { $pair = 1 }
    elsif ($opt eq "-pairfeature") { defined($pairfeature = shift) or die $usage; push @pairfeature, $pairfeature }
    else { die "$usage\nUnknown option: $opt\n" }
}

if (@ARGV==1 && !$sortedname) { push @ARGV, '-' }

@ARGV==2 or die $usage;
($transformation,$transformee) = @ARGV;

read_transformation($transformation);

open transformee or die "$0: couldn't open $transformee: $!";

if ($sortedname) {

    undef $lines;
    while ($tell = tell(transformee), $_ = <transformee>) {
	s/#.*//;
	next unless /\S/;
	@f = split /\t/, $_, 9;
	unless (exists $pos{$f[0]}) {
	    if (defined $lines) { print STDERR "\t$lines lines\n"; $lines = 0 }
	    print STDERR "Indexing $f[0]\tat $transformee pos $tell...";
	    $pos{$f[0]} = $tell;
	}
	check_validity($f[0]);
	if ($pair || (@pairfeature && grep($f[2] =~ /$_/,@pairfeature))) {
	    @g = split /\s+/, $f[8], 4;
	    check_validity($g[0]);
	}
	++$lines;
    }
    if (defined $lines) { print STDERR "\t$lines lines\n" }
    print STDERR "Indexing done; sorting sequence list ...\n";
    
    @seqname = sort { $name{$a} cmp $name{$b} or $start{$a} <=> $start{$b} or $end{$a} <=> $end{$b} } keys %name;
    
    warn "Sorting done.\n";
    
    foreach $seqname (@seqname) {
	print STDERR "Reading $seqname ...\n";
	next unless exists $pos{$seqname};
	seek transformee, $pos{$seqname}, 0;
	%start1 = %name2 = %start2 = ();
	while (<transformee>) {
	    last unless /^$seqname\t/;
	    ($text,$start1,$name2,$start2) = transform_gff($_);
	    $start1{$text} = $start1;
	    $name2{$text} = $name2;
	    $start2{$text} = $start2;
	}
	if (!defined($lastname1) || $name{$seqname} ne $lastname1) {
	    $lastname1 = $name{$seqname};
	    undef $laststart1;
	    undef $lastname2;
	    undef $laststart2;
	}
	foreach (sort { $start1{$a}<=>$start1{$b} || $name2{$a} cmp $name2{$b} || $start2{$a}<=>$start2{$b} } keys %start1) {
	    if (!defined($laststart1) || ($start1{$_} >= $laststart1 && $name2{$_} ge $lastname2 && $start2{$_} >= $laststart2)) {
		print;
		$laststart1 = $start1{$_};
		$lastname2 = $name2{$_};
		$laststart2 = $start2{$_};
	    }
	}
    }

} else {

    while (<transformee>) {
	($text,$start1,$name2,$start2) = transform_gff($_);
	print $text;
    }

}

sub transform_gff {
    my ($gfftext) = @_;
    chomp $gfftext;
    my @f = split /\t/, $gfftext, 9;
    my @g = split /\s+/, $f[8], 4;
    my ($name2,$start2);
    @f[0,3,4] = transform(@f[0,3,4]);
    if ($pair || (@pairfeature && grep($f[2] =~ /$_/,@pairfeature))) {
	@g[0,1,2] = transform(@g[0,1,2]);
	if ($f[3] > $f[4]) { @g[1,2] = @g[2,1] }
	$f[8] = "@g";
	($name2,$start2) = @g[0,1];
    }
    if ($f[3] > $f[4]) {
	@f[3,4] = @f[4,3];
	if ($f[6] eq "+") { $f[6] = "-" }
	elsif ($f[6] eq "-") { $f[6] = "+" }
    }

    (join("\t",@f)."\n", $f[3], $name2, $start2);
}
