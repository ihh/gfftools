#!/usr/bin/perl -w

my $progname = $0;
$progname =~ s!^.*/!!;

my $usage = "$progname: find spanning regions for a GFF file\n";
$usage .= "\n";
$usage .= "Usage: $progname [-h|--help] <file(s)>\n";
$usage .= "\n";

die $usage if grep (/^-{1,2}(h|help)$/, @ARGV);

my (%min, %max);
while (<>) {
    my @f = split /\t/, $_, 9;
    my ($name, $start, $end) = @f[0,3,4];
    $min{$name} = $start if !defined($min{$name}) || $start < $min{$name};
    $max{$name} = $end if !defined($max{$name}) || $end > $max{$name};
}

for my $name (sort keys %min) {
    print join ("\t", $name, $progname, "region", $min{$name}, $max{$name}, '.', '.', '.', ""), "\n";
}
