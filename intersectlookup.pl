#!/usr/bin/perl

$usage .= "$0 - look up GFF intersect tags\n";
$usage .= "\n";
$usage .= "Usage: $0 [-self] [-image] [-unique] [-evalfile expr] [-quiet] [-showtogether] [-maxscore|-minscore] [-first|-maxlen|-minpairdistance|-maxsort expr] [<GFF files with intersect tags>]\n";
$usage .= "\n";
$usage .= "group field in <GFF file> should have intersect tags of the form \"intersect(filename)=(1 5 6 19)\"\n";
$usage .= " ... this will print lines 1, 5, 6 and 19 of <filename>\n";
$usage .= "\n";
$usage .= "Use the -evalfile switch to perform operations (eg substitutions) on <filename> before printing;\n";
$usage .= "one of these expressions must evaluate to 1 or the intersect tag will be discarded,\n";
$usage .= "so -evalfile can also be used for tests.\n";
$usage .= "\n";
$usage .= "Use the -self switch in conjunction with \"gffintersect.pl -self\" (equivalent to \"-quiet -evalfile s/^self&//\")\n";
$usage .= "\n";
$usage .= "Use the -image switch to find the \"image\" of <filename>'s GFFs, assuming this is a GFF-pair\n";
$usage .= "\n";
$usage .= "Use the -quiet switch to suppress the addition of intersect()=() information to the output\n";
$usage .= "\n";
$usage .= "Use the -showtogether switch to show the input GFF lines as well (some lines may appear more than once)\n";
$usage .= "\n";
$usage .= "Use the -maxscore switch to only print the highest-scoring hit for a line,\n";
$usage .= "Use -minscore to only print the lowest-scoring hit for a line,\n";
$usage .= "Use -first to only print the max-starting-position hit for a line,\n";
$usage .= "Use -maxlen to only print the longest hit for a line,\n";
$usage .= "Use -minpairdistance to only print the closest-pair hit for a line,\n";
$usage .= "Use the more generic -maxsort to specify a sorting criterion, with \@a and \@b holding the GFF fields\n";
$usage .= " e.g. -maxscore is equivalent to \"-maxsort '\$b[5]<=>\$a[5]'\"\n";
$usage .= "Use -unique to entirely reject intersect sets larger than one\n";
$usage .= "\n";
$usage .= "EXAMPLE: How to prune a GFF file of the lowest-scoring redundant entries:\n";
$usage .= "  gffintersect.pl -self <filename> | intersectlookup.pl -self -maxscore\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt eq "-evalfile") { defined($evalfile = shift) or die $usage; push @evalfile, $evalfile }
    elsif ($opt eq "-self") { push @evalfile, "s/^self&//"; $quiet = 1; $self = 1 }
    elsif ($opt eq "-image") { $image = 1 }
    elsif ($opt eq "-unique") { $unique = 1 }
    elsif ($opt eq "-first") { $sort = "bystartpos" }
    elsif ($opt eq "-maxscore") { $sort = "bymaxscore" } 
    elsif ($opt eq "-minscore") { $sort = "byminscore" } 
    elsif ($opt eq "-maxlen") { $sort = "bylen" }
    elsif ($opt eq "-mergeset") { $mergeSet = 1 }
    elsif ($opt eq "-minpairdistance") { $sort = "bypairdistance" }
    elsif ($opt eq "-maxsort") { defined($sortexpr = shift) or die $usage; $sort = "byexpr" }
    elsif ($opt eq "-quiet") { $quiet = 1 }
    elsif ($opt eq "-showtogether") { $showtogether = 1 }
    elsif ($opt eq "-h") {die "$usage\n"}
    else { die "$usage\nUnknown option: $opt\n" }
}

@ARGV>=1 or @ARGV = ("-");

foreach $file1 (@ARGV) {
    open file1, $file1 or die "$0: couldn't open $file1: $!";
    $line1 = 0;
    while (<file1>) {
	++$line1;
	$lineText{$line1} = $_;
	@f = split /\t/;
	my @pair = split(/\s+/,$f[8]);
	if ($f[6] eq "-") { @pair[1,2] = @pair[2,1] }
	$set = undef;
	while ((($file2,$lines2) = ($f[8] =~ /intersect\(([^\)]+)\)=\(([^\)]+)\)/)) && $file2 ne "") {
	    $f8sub = quotemeta "intersect($file2)=($lines2)"; # Backslash all non-alphanumeric characters
	    $f[8] =~ s/$f8sub//;
	    if (@evalfile) {
		$_ = $file2;
		$print = 0;
		foreach $evalfile (@evalfile) {
		    #warn "Evaluating $evalfile on $_\n";
		    if (eval $evalfile) { $print = 1 }
		}
		next unless $print;
		$file2 = $_;
	    }
	    next unless -r $file2;
	    #$tmpf8 = $f[8]; chomp $tmpf8; warn "file1=$file1 line1=$line1 file2=$file2 lines2=($lines2) \$f[8]='$tmpf8'\n";
	    @line2 = split /\s+/, $lines2;
	    foreach $line2 (@line2) {
	      # If the unique flag is specified and intersect set is larger than 1, set the tainted flag.
		if ($unique && @line2 > 1) { $tainted{$file2}->{$line2} = 1 }
		else {
		  # Keep track of the relation from each member of the intersect set to line1
		    push @{$backlookup{$file2}->{$line2}->{$file1}}, $line1;
		    # If flag is set, show input GFF lines too
		    if ($showtogether) { $keep{$file1}->{$line1} = $_ }
		    if ($image) { $transform{$file1}->{$line1} = [@f[0,3,4],@pair[0..2]] }
		}
	    }
	    if (defined $sort || $mergeSet) {
	      # Initially, %set, $set, $sets,and $thisset are all undefined.
	      # $thisset = contains the intersection set number for line2
	      # %set = hash that relates each line2 to an intersection set
	      # $sets = stores the number of intersection sets found
		foreach $line2 (@line2) {
		    $thisset = $set{$file2}->{$line2};
		    $file2line2 = "$file2\t$line2";
		    # Note that the $set scalar will always be undefined 
		    # on the initial pass thru this loop.
		    if (defined $set) { 
			if (defined $thisset) {
			    if ($thisset != $set) {
				foreach (@{$members[$thisset]}) {
				    ($thisfile2,$thisline2) = split /\t/;
				    $set{$thisfile2}->{$thisline2} = $set;
				}
				undef $members[$thisset];
			    }
			} else {
			    $set{$file2}->{$line2} = $set;
			    undef $gfftext[$set]->{$file2line2};
			}
		    } else {
			if (defined $thisset) {
			    $set = $thisset;
			} else {
			  $set = $sets++;
			    $set{$file2}->{$line2} = $set;
			    $gfftext[$set]->{$file2line2} = undef;  # mark a place in this hash
			}
		    }
		  }
	      } 
	  } # while ($file2, $line2)
    } # while (<file1>)
    close file1;
}

# Merge intersect set lines into one line per set.
if ($mergeSet && $self)
{
  @file2list = keys %set; #print "file2list=[@file2list]\n";
  $file2 = $file2list[0];
  @line2list = keys %{$set{$file2}}; #print "line2list=[@line2list]\n";
  @set2list = values %{$set{$file2}}; #print "set2list=[@set2list]\n";
  $pSetNum = undef;
  foreach $setNum (sort bynum @set2list)
  {
    if (defined($pSetNum) && $setNum == $pSetNum) { next;}
    $minStart = undef; $maxEnd = undef;
    foreach $lineNum (@line2list)
    {
      if ($set{$file2}->{$lineNum} == $setNum)
      {
	$line = $lineText{$lineNum};
	@fields = split /\t/, $line;
	$start = $fields[3];
	$end = $fields[4];
	$name = $fields[0];
	$strand = $fields[6];
	if (defined($minStart))
	{
	  if ($start < $minStart) {$minStart = $start;}
	}
	else {$minStart = $start;}
	if (defined($maxEnd))
	{
	  if ($end > $maxEnd) {$maxEnd = $end;}
	}
	else {$maxEnd = $end;}
      }
    }
    print "$name\t.\t.\t$minStart\t$maxEnd\t.\t$strand\t.\t$setNum\n";
    $pSetNum = $setNum;
  }
  exit;
}

while (($file2,$line2ref) = each %backlookup) {
    unless (open file2, $file2) {
	warn "$0: couldn't open $file2: $!\n";
	next;
    }
    @line2 = sort {$a<=>$b} keys %$line2ref; # sort in ascending order
    $line2 = 0;
    while (@line2 && defined($_ = <file2>)) {
	if (++$line2 == $line2[0] && !$tainted{$file2}->{shift @line2}) {
	    if (defined $sort) {
	      $set = $set{$file2}->{$line2}; 
		@f = split /\t/;
	      $gfftext[$set]->{"$file2\t$line2"} = $_; 
		if (++$count[$set] == keys %{$gfftext[$set]}) {
		    %member = ();
		    while (($member,$gfftext) = each %{$gfftext[$set]}) { $member{$gfftext} = $member }
		    #warn "Set $set:\n";
		    #while (($member,$gfftext) = each %{$gfftext[$set]}) { warn " member=\"$member\" gfftext=$gfftext" }
		    $maxgfftext = (sort $sort keys %member)[0];
		    #warn " maxmember=\"$member{$maxgfftext}\"\n";
		    ($maxfile2,$maxline2) = split /\t/, $member{$maxgfftext};
		    show($maxfile2,$maxline2,$maxgfftext);
		    undef $gfftext[$set];
		}
	    }
	    else {
		show($file2,$line2,$_);
	    }
	}
    }
    close file2;
}

sub show {
    my ($file2,$line2,$gfftext) = @_;
    my $fileref = $backlookup{$file2}->{$line2};
    if ($showtogether) {
	while (($file1,$lineref1) = each %$fileref) {
	    foreach $line1 (@$lineref1) { print $keep{$file1}->{$line1} }
	}
    }
    my @f = split /\t/, $gfftext;
    chomp $f[8];
    if ($image) {
	while (($file1,$lineref1) = each %$fileref) {
	    my $line1;
	    foreach $line1 (@$lineref1) {
		my @transform = @{$transform{$file1}->{$line1}};
		my $dir = $transform[4] > $transform[5] ? -1 : +1;
#		print "file1=$file1 line1=$line1 transform=(@transform) f=(@f)\n";
		my $start = ($f[3] - $transform[1]) * $dir + $transform[4];
		my $end = ($f[4] - $transform[1]) * $dir + $transform[4];
		my $strand = $f[6];
		if ($start > $end) {
		    ($start,$end) = ($end,$start);
		    if ($strand eq "+") { $strand = "-" }
		    elsif ($strand eq "-") { $strand = "+" }
		}
		print join("\t",$transform[3],$f[1],"$f[2]-homology",$start,$end,$f[5],$strand,@f[7,8]);
		unless ($quiet) { print " original($file2)=$line2" }
		print "\n";
	    }
	}
    } elsif ($quiet) {
	print $gfftext;
    } else {
	while (($file1,$lineref1) = each %$fileref) {
	    $f[8] .= ' ' unless $f[8] =~ / $/;
	    $f[8] .= "intersect($file1)=(@$lineref1)";
	}
	print join("\t",@f)."\n";
    }
    if ($showtogether) { print "\n" }
}


sub bystartpos {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    $b[3] <=> $a[3];
}

sub bymaxscore {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    $b[5] <=> $a[5]; # descending order
}

sub byminscore {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    $a[5] <=> $b[5]; # ascending order
}

sub bylen {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    $b[4]-$b[3] <=> $a[4]-$a[3];
}

sub bypairdistance {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    my ($apair) = ($a[8] =~ /(\d+)/);
    my ($bpair) = ($b[8] =~ /(\d+)/);
    abs($apair-$a[3]) <=> abs($bpair-$b[3]);
}

sub byexpr {
    my @a = split /\t/, $a;
    my @b = split /\t/, $b;
    eval $sortexpr;
}

sub bynum { $a <=> $b }

