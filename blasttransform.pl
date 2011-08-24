#!/usr/bin/perl

use GFFTransform;

($prog = $0) =~ s#.*/(\S+)#$1#;
$tempprefix = "/tmp/$prog$$";
$tempdbprefix = $tempprefix."_db";
$tempquery = $tempprefix."_seq";
$tempblast = $tempprefix."_blast";

chomp($hostname = `hostname`);

END {
    foreach $tempdb (values %tempdb) {
	if (-e $tempdb) { unlink $tempdb or warn "$0: couldn't unlink $tempdb" }
	if (-e "$tempdb.csq") { unlink "$tempdb.csq" or warn "$0: couldn't unlink $tempdb.csq" }
	if (-e "$tempdb.nhd") { unlink "$tempdb.nhd" or warn "$0: couldn't unlink $tempdb.nhd" }
	if (-e "$tempdb.ntb") { unlink "$tempdb.ntb" or warn "$0: couldn't unlink $tempdb.ntb" }
    }
    if (-e $tempquery) { unlink $tempquery or warn "$0: couldn't unlink $tempquery" }
    if (-e $tempblast) { unlink $tempblast or warn "$0: couldn't unlink $tempblast" }
}
$SIG{INT} = $SIG{KILL} = sub { system "rm $tempprefix*"; die "\n" };

$blast = "blastn";
$blastopts = "-warnings -hspmax 20000";
$pressdb = "pressdb";
$fetch = "ifetch -under -file";
$mspcrunch = "MSPcrunch -w -d";

$usage .= "$prog -- BLAST a database against itself, and transform output into new co-ordinate system\n";
$usage .= "\n";
$usage .= "Usage: $prog [-verbose] [-mailprogress count address] [-minscore score] <GFF file> <FASTA file>\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-verbose") { $verbose = 1 }
    elsif ($opt eq "-minscore") { defined($minscore = shift) or die $usage }
    elsif ($opt eq "-mailprogress") { defined($mailcount = shift) && defined($mailaddress = shift) or die $usage }
    else { die "$usage\nUnknown option: $opt\n" }
}

@ARGV==2 or die $usage;
($gfffile,$fastafile) = @ARGV;

read_transformation($gfffile);

# make temporary sequence files

open FASTA, $fastafile or die "Couldn't open $fastafile: $!";
$sep = $/;
$/ = ">";
$dummy = <FASTA>;
while ($/ = "\n", $oldname = <FASTA>) {
    chomp $oldname;

    $/ = ">";
    $seq = <FASTA>;
    chomp $seq;

    check_validity($oldname);
    $newname = $name{uc $oldname};
    unless (exists $tempdb{$newname}) { $tempdb{$newname} = $tempdbprefix.++$tempdbindex }

    warn "Adding $oldname to temporary sequence file for $newname ($tempdb{$newname})\n" if $verbose;

    open TEMPDB, ">>$tempdb{$newname}" or die "Couldn't open $tempdb{$newname}: $!";
    print TEMPDB ">$oldname\n$seq";
    close TEMPDB;
}
$/ = $sep;
close FASTA;

sort_seqnames();

foreach $tempdb (values %tempdb) {
    warn "Pressing $tempdb...\n" if $verbose;
    system "$pressdb $tempdb >/dev/null";
}

# do the BLASTing

foreach $newname1 (@newnames) {
    next if $newname1 lt "CHROMOSOME_X";
    foreach $newname2 (@newnames) {
	next if $newname1 eq "CHROMOSOME_X" && $newname2 lt "K02B12";
	foreach $oldname1 (@{$oldnames{$newname1}}) {
	    system "$fetch $fastafile $oldname1 > $tempquery";
	
	    warn "$blast $oldname1 $newname2 $blastopts > $tempblast\n" if $verbose;
	    system "$blast $tempdb{$newname2} $tempquery $blastopts > $tempblast";

	    warn "$mspcrunch $tempblast\n" if $verbose;
	    %mspstart = @g = ();
	    open MSPCRUNCH, "$mspcrunch $tempblast |" or die "Couldn't execute $mspcrunch: $!";
	    while (<MSPCRUNCH>) {
		@f = transform_msp([split]);
		next if defined($minscore) && $f[0] < $minscore;
		$mspstart{join("\t",@f)."\n"} = $f[2];
	    }
	    close MSPCRUNCH;
	    warn "Sorting MSPcrunch output...\n" if $verbose;
	    print sort { $mspstart{$a} <=> $mspstart{$b} } keys %mspstart;

	    if (defined $mailaddress) {
		if (($outcount += keys %mspstart) >= $mailcount) {
		    $outcount = 0;
		    system "echo \"$prog on $hostname -- $blast $oldname1 $newname2 $blastopts\" | mail $mailaddress";
		}
	    }

	}
    }
}

system "rm $tempprefix*";

sub transform_msp {
    my ($g,$flip) = @_;
    my @f = @$g;
    check_validity($g->[4]);
    check_validity($g->[7]);
    @f[4,2] = transform(@$g[4,2]);
    @f[4,3] = transform(@$g[4,3]);
    @f[7,5] = transform(@$g[7,5]);
    @f[7,6] = transform(@$g[7,6]);
    if ($flip) { @f[2..4,5..7] = @f[5..7,2..4] }
    if ($f[2] > $f[3]) { @f[2,3,5,6] = @f[3,2,6,5] }
    @f;
}
