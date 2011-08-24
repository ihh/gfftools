#!/usr/bin/perl -w

my $progname = $0;
$progname =~ s!^.*/!!;

my $usage = "$progname: cut out everything in one GFF file that overlaps with a second\n";
$usage .= "\n";
$usage .= "Usage: $progname <file1> <file2>\n";
$usage .= "\n";
$usage .= "Example (returns all chromosome regions that are NOT in genes):\n";
$usage .= " $progname CHROMOSOMES.gff GENES.gff\n";
$usage .= "\n";

die $usage unless @ARGV == 2;
my ($file1, $file2) = @ARGV;
my ($byname1, $byname2) = map (load_GFF($_), $file1, $file2);

# GFF field 3 = start
# GFF field 4 = end
for my $seqname (sort keys %$byname1) {
    next unless exists $byname2->{$seqname};
    my @gff2 = sort { $a->[3] <=> $b->[3] || $a->[4] <=> $b->[4] } @{$byname2->{$seqname}};
    for my $gff1 (@{$byname1->{$seqname}}) {
	my $start = $gff1->[3];
	for my $gff2 (@gff2) {
	    next if $gff2->[4] < $gff1->[3];
	    last if $gff2->[3] > $gff1->[4];
	    if ($gff2->[3] > $start) {
		print join ("\t", @{$gff1}[0..2], $start, $gff2->[3] - 1, @{$gff1}[5..8]), "\n";
	    }
	    $start = $gff2->[4] + 1;
	}
	if ($start <= $gff1->[4]) {
	    print join ("\t", @{$gff1}[0..2], $start, @{$gff1}[4..8]), "\n";
	}
    }
}


sub load_GFF {
    my ($file) = @_;
    my %byname;
    local *FILE;
    open FILE, "<$file";
    while (my $gff = <FILE>) {
	chomp $gff;
	my @f = split /\t/, $gff, 9;
	push @{$byname{$f[0]}}, \@f;
    }
    return \%byname;
}
