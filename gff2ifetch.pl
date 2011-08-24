#!/usr/bin/perl

@fields = qw(seqname source feature start end score strand frame group);

$usage = "Usage: $0 <expr>\n";

@ARGV==1 or die $usage;

$expr = substitute(shift);

while (<>) {
    @gff = split /\t/, $_, 9;
    warn "ifetch ".eval($expr)."\n";
    system "ifetch ".eval($expr);
}
warn "DONE\n";


sub substitute {
    my ($s) = @_;
    my $i;
    for ($i=0;$i<@fields;$i++) {
	$s =~ s/\$gff$fields[$i]/\$gff[$i]/g;
    }
    $s;
}
