# GFF transform stuff

sub check_validity {
    my $seqname = uc shift;
    unless (defined $name{$seqname}) {
	warn "Warning: no mapping for $seqname in $transformation_file\n";
	$name{$seqname} = $seqname;
	$start{$seqname} = 1;
	$dir{$seqname} = 1;
    }
}

sub transform {
    my ($seqname,@oldpos) = @_;
    $seqname = uc $seqname;
    check_validity($seqname);
    my @newpos;
    foreach (@oldpos) { push @newpos, ($_ - 1) * $dir{$seqname} + $start{$seqname} }
    ($name{$seqname}, @newpos);
}

sub back_transform {
    my ($seqname,$start,$end) = @_;
    unless (exists $oldnames{$seqname}) { return ([$seqname,$start,$end]) }
    my (@result,$oldname);
    foreach $oldname (@{$oldnames{$seqname}}) {
	die "Can't cope with backwards-oriented sequences" if $end{$oldname} < $start{$oldname};
	next if $end{$oldname} < $start;
	my $effend = $end <= $end{$oldname} ? $end : $end{$oldname};
	push @result, [$oldname,$start+1-$start{$oldname},$effend+1-$start{$oldname}];
	$start = $effend + 1;
	last if $start > $end;
    }
    if ($start <= $end) { return () }
    @result;
}

sub read_transformation {
    my ($file) = @_;
    $transformation_file = $file;
    local *TRANSFORM;
    open TRANSFORM, $file or die "Couldn't open $file: $!";
    while (<TRANSFORM>) {
	chomp;
	my ($seqname,$source,$feature,$start,$end,$score,$strand,$frame,$group) = split /\t/, $_, 9;
	my ($oldname,$oldstart,$oldend) = split /\s+/, $group;
	$oldname = uc $oldname;
	$name{$oldname} = $seqname;
	$start{$oldname} = $start;
	$end{$oldname} = $end;
	$dir{$oldname} = $end > $start ? 1 : -1;
    }
    close TRANSFORM;
}

sub sort_seqnames {
    my ($oldname,$newname);
    while (($oldname,$newname) = each %name) { push @{$oldnames{$newname}}, $oldname }
    @newnames = sort keys %oldnames;
    foreach $newname (@newnames) { @{$oldnames{$newname}} = sort { $start{$a} <=> $start{$b} } @{$oldnames{$newname}} }
}



1;
