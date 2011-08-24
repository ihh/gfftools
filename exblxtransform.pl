#!/usr/bin/perl

use GFFTransform;

$mspindexprog = "mspindex.pl";

$usage .= "$0 -- convert MSPcrunch -d output into new co-ordinate system\n";
$usage .= "\n";
$usage .= "Usage: $0 [-verbose] [-noindex] [-sym|-asym] [-self] <GFF file> [<MSP file>]";
$usage .= "\n";
$usage .= "Use -sym and -asym to symmetrise/asymmetrise MSP data\n";
$usage .= "Use -self to allow self-hits\n";
$usage .= "Use -noindex to suppress lookup/generation of <MSP file>.index\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-verbose") { $verbose = 1 }
    elsif ($opt eq "-noindex") { $noindex = 1 }
    elsif ($opt eq "-sym") { $sym = 1 }
    elsif ($opt eq "-asym") { $asym = 1 }
    elsif ($opt eq "-self") { $self = 1 }
    else { die "$usage\nUnknown option: $opt\n" }
}

$sym = $sym || $asym;

@ARGV==1 or @ARGV==2 or die $usage;
$gfffile = shift;

read_transformation($gfffile);

if (@ARGV && !$noindex) {

    $mspfile = shift;
    $mspindex = "$mspfile.index";
    unless (-e $mspindex) {
	warn "Building index for $mspfile...\n" if $verbose;
	system "$mspindexprog $mspfile";
    }

    open MSPINDEX, $mspindex or die "$0: couldn't open $mspindex: $!";
    open MSPFILE, $mspfile or die "$0: couldn't open $mspfile: $!";

    while ($tell = tell MSPINDEX, $_ = <MSPINDEX>) {
	(@oldname[0,1],$pos) = split;
	$oldnamepair = "@oldname";
	die "$mspindex unsorted" if $oldname[0] ne $lastoldname[0] && $oldname[1] ne $lastoldname[1] && exists $pos{$oldnamepair};
	if ($oldname[0] ne $lastoldname[0]) {
	    warn "Reading index for (@oldname)...\n" if $verbose;
	    $mspindexpos{$oldname[0]} = $tell;
	}
	check_validity($oldname[0]);
	check_validity($oldname[1]);
	@lastoldname = @oldname;
    }

    sort_seqnames();
    
    foreach $newname1 (@newnames) {
	foreach $newname2 (@newnames) {

	    @newname = ($newname1,$newname2);
	    next if $asym && $newname[0] gt $newname[1];

	    warn "Preparing (@newname) output...\n" if $verbose;

	    @oldname1 = sort { $start{$a} <=> $start{$b} } @{$oldnames{$newname[0]}};
	    while (@oldname1) {

		@oldname1_samestart = ();
		while (@oldname1_samestart == 0 || (@oldname1 && $start{$oldname1[0]} == $start{$oldname1_samestart[0]})) {
		    push @oldname1_samestart, shift(@oldname1);
		}

		%mspfilepos = %flip = ();
		foreach $oldname (@oldname1_samestart) {
		    next unless exists $mspindexpos{$oldname};
		    seek MSPINDEX, $mspindexpos{$oldname}, 0;
		    while (<MSPINDEX>) {
			(@oldname[0,1],$pos) = split;
			last if $oldname[0] ne $oldname;
			if ($name{$oldname[1]} eq $newname[1]) {
			    $mspfilepos{"@oldname"} = $pos;
			    $flip{"@oldname"} = 0;
			}
		    }
		}
		if ($sym) {
		    foreach $oldname (@{$oldnames{$newname[1]}}) {
			next unless exists $mspindexpos{$oldname};
			seek MSPINDEX, $mspindexpos{$oldname}, 0;
			while (<MSPINDEX>) {
			    (@oldname[0,1],$pos) = split;
			    last if $oldname[0] ne $oldname;
			    if (grep($_ eq $oldname[1], @oldname1_samestart) && !exists($flip{"@oldname[1,0]"})) {
				$mspfilepos{"@oldname"} = $pos;
				$flip{"@oldname"} = 1;
			    }
			}
		    }
		}
		
		%mspstart = ();
		foreach $oldnamepair (keys %mspfilepos) {
		    @oldname = split /\s+/, $oldnamepair;
		    $flip = $flip{$oldnamepair};
		    seek MSPFILE, $mspfilepos{$oldnamepair}, 0;
		    while (<MSPFILE>) {
			@f = split;
			last unless $f[4] eq $oldname[0] && $f[7] eq $oldname[1];
			@msp = transform_msp(\@f,$flip);
			$mspstart{join("\t",@msp)."\n"} = $msp[2];
			if ($sym && $oldname[0] eq $oldname[1]) {
			    @msp[2..4,5..7] = @msp[5..7,2..4];
			    if ($msp[2] > $msp[3]) { @msp[2,3,5,6] = @msp[3,2,6,5] }
			    $mspstart{join("\t",@msp)."\n"} = $msp[2];
			}
		    }
		}
		warn "Sorting (@{[keys %mspfilepos]}) output...\n" if $verbose && keys(%mspstart);
		foreach (sort { $mspstart{$a} <=> $mspstart{$b} or (split(/\s+/,$a))[5] <=> (split(/\s+/,$b))[5] } keys %mspstart) {
		    @f = split;
		    print unless ($asym && $newname[0] eq $newname[1] && ($f[5] < $f[2] || $f[6] < $f[2])) || (!$self && $f[2] == $f[5] && $f[3] == $f[6] && $f[4] eq $f[7]);
		}
	    }
	}
    }

    close MSPFILE;
    close MSPINDEX;

} else {
    
    while (<>) {
	@f = split;
	print join("\t",transform_msp(\@f))."\n";
    }

}

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
