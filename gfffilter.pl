#!/usr/bin/perl

@fields = qw(seqname source feature start end score strand frame group);

$usage .= "$0 - filter GFF files\n";
$usage .= "\n";
$usage .= "Usage: $0 [-not] [-near <distance>] <filter expression> [<GFF files>]\n";
$usage .= "\n";
$usage .= "Only allows through GFF's that match the filter expression (or not, if -not switch selected).\n";
$usage .= "Use (".join(" ",map("\$gff$_",@fields)).") to refer to GFF fields, e.g. '\$gfffeature eq \"gene\"'.\n";
$usage .= "Alternatively you can use (".join(" ",map("\$$_",@fields))."), e.g. '\$feature eq \"gene\"'.\n";
$usage .= "Use -near to let through (or not let through) all GFFs that are closer than a certain distance to matching GFFs.\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-not") { $not = 1 }
    elsif ($opt eq "-near") { defined($near = shift) or die $usage }
    else { die "$usage\nUnknown option: $opt\n" }
}

@ARGV>=1 or die $usage;
$filter = shift;
for ($i=0;$i<@fields;$i++) {
    $filter =~ s/\$$fields[$i]/\$gff->[$i]/g;
    $filter =~ s/\$gff$fields[$i]/\$gff->[$i]/g;
}

while (<>) {
    s/#.*//;
    next unless /\S/;
    chomp;
    $gff = [split(/\t/,$_,9)];
    
    ($seqname,$start,$end) = @{$gff}[0,3,4];

    if (!defined $near) {

	if ($not) { print "$_\n" unless eval $filter }
	else { print "$_\n" if eval $filter }

    } else {
	if ($seqname ne $lastseqname || (defined($lasthit) && $start > $lasthit + $near)) {
	    printbuffer();
	    @buffer = ();
	    undef $firsthit;
	    undef $lasthit;
	    $lastseqname = $seqname;
	}
	
	if (eval $filter) {
	    $firsthit = $start unless defined $firsthit;
	    $lasthit = $end unless $lasthit > $end;
	}
	
	for ($i=0;$i<@buffer;$i++) { last if ($buffer[$i]->[4] > $end) }
	splice @buffer, $i, 0, $gff;

	$cursor = defined($firsthit) ? $firsthit : $start;
	while (@buffer && $buffer[0]->[4] < $cursor - $near) {
	    $deadgff = shift @buffer;
	    if ($not) { print join("\t",@$deadgff)."\n" }
	}

    }

}

if (defined $near) { printbuffer() }

sub printbuffer {
    return unless ($not && !defined($lasthit)) || (!$not && defined($lasthit));
    my $gff;
    foreach $gff (@buffer) { print join("\t",@$gff)."\n" }
}
