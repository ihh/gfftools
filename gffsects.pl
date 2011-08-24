#!/usr/bin/perl -w

my $usage = "Usage: $0 [-v] <GFF file 1> [<GFF file 2>]\n";
my $verbose;

my @argv;
while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq "-v") { $verbose = 1 }
    else {
	push @argv, $arg;
    }
}
die $usage unless @argv == 1 || @argv == 2;
push @argv, "-" if @argv == 1;
my ($filename1, $filename2) = @argv;

warn "# reading files\n" if $verbose;
my ($file1, $node1) = QuadNode::readGFF ($filename1);
my ($file2, $node2) = QuadNode::readGFF ($filename2);
my $intersect = QuadNode::intersect ($node1, $node2);

warn "# finding intersect\n" if $verbose;
my @i2;
while (my ($name2, $root2) = each %$node2) {
    $root2->iterate (1, 1, $root2->size, $root2->size,
		     sub {
			 my ($leaf2) = @_;
			 if (exists $intersect->{$leaf2}) {
			     push @i2, @{$leaf2->{'child'}};
			 }
		     });
}
warn "# sorting\n" if $verbose;
@i2 = sort { $a <=> $b } @i2;
QuadNode::printLines ($filename2, $file2, \@i2);

exit;

# subroutines

package QuadNode;

sub new {
    my ($class, $x, $y, $size) = @_;
    $size = 1 unless defined $size;
    $x = $y = 1 unless defined $x;
    $class = ref ($class) if ref ($class);
    my $self = { 'xmin' => $x,
		 'ymin' => $y,
		 'size' => $size,
		 'child' => ($size == 1 ? [] : [undef, undef, undef, undef])
		 };
    bless $self, $class;
    return $self;
}

sub childIndex {
    my ($self, $x, $y) = @_;
    my $halfSize = $self->{'size'} / 2;
    my $c = ($x >= $self->{'xmin'} + $halfSize ? 1 : 0)
	+ ($y >= $self->{'ymin'} + $halfSize ? 2 : 0);
    return $c;
}

# accessors
sub getChild {
    my ($self, $i) = @_;
    return $self->{'child'}->[$i];
}

sub setChild {
    my ($self, $i, $c) = @_;
    $self->{'child'}->[$i] = $c;
}

sub children { my ($self) = @_; return @{$self->{'child'}} + 0 }

sub size { my ($self) = @_; return $self->{'size'} }
sub xmin { my ($self) = @_; return $self->{'xmin'} }
sub ymin { my ($self) = @_; return $self->{'ymin'} }
sub xmax { my ($self) = @_; return $self->{'xmin'} + $self->{'size'} - 1 }
sub ymax { my ($self) = @_; return $self->{'ymin'} + $self->{'size'} - 1 }
sub xmid { my ($self) = @_; return $self->{'xmin'} + $self->{'size'} / 2 }
sub ymid { my ($self) = @_; return $self->{'ymin'} + $self->{'size'} / 2 }

# addLeaf adds a leaf datum to the quad tree and returns the new root
sub addLeaf {
    my ($node, $x, $y, $datum) = @_;
    # make space at the top of the tree, if necessary
    while ($x > $node->xmax || $y > $node->ymax) {
	my $newroot = $node->new ($node->xmin, $node->ymin, $node->size * 2);
	$newroot->setChild ($newroot->childIndex ($node->xmin, $node->ymin), $node);
	$node = $newroot;
    }
    my $root = $node;
    # work down to the bottom of the tree
    my $size;
    while (($size = $node->size) > 1) {
	my $i = $node->childIndex ($x, $y);
	my $c;
	if (!defined ($cnode = $node->getChild ($i))) {
	    # create new nodes as necessary
	    my $halfSize = $size / 2;
	    $node->setChild ($i, $cnode = $node->new ($node->xmin + ($i & 1 ? $halfSize : 0),
						      $node->ymin + ($i & 2 ? $halfSize : 0),
						      $halfSize));
	}
	$node = $cnode;
    }
    # store, and return the new root
    push @{$node->{'child'}}, $datum;
    return $root;
}

# iterate calls a visitor subroutine on every leaf node in a given range
sub iterate {
    my ($self, $xmin, $ymin, $xmax, $ymax, $visitor) = @_;
    my $size = $self->size;
    if ($size == 1) {
	if ($xmin <= $self->xmin && $xmax >= $self->xmax && $ymin <= $self->ymin && $ymax >= $self->ymax) {
	    &$visitor ($self) if $self->children;
	}
    } else {
	my $imin = $xmin < $self->xmid ? 0 : ($xmin <= $self->xmax ? 1 : 2);
	my $imax = $xmax >= $self->xmid ? 1 : ($xmax >= $self->xmin ? 0 : -1);
	my $jmin = $ymin < $self->ymid ? 0 : ($ymin <= $self->ymax ? 1 : 2);
	my $jmax = $ymax >= $self->ymid ? 1 : ($ymax >= $self->ymin ? 0 : -1);
	for (my $i = $imin; $i <= $imax; ++$i) {
	    for (my $j = $jmin; $j <= $jmax; ++$j) {
		my $ci = $i + 2*$j;
		my $child = $self->getChild($ci);
		$child->iterate ($xmin, $ymin, $xmax, $ymax, $visitor) if defined $child;
	    }
	}
    }
}

# readGFF reads a GFF file into a hash of quad trees, one per seqname
sub readGFF {
    my ($filename) = @_;
    my %node;
    local *FILE;
    open FILE, "<$filename" or die "Can't open GFF file '$filename': $!";
    my @file;
    for (my $i = 0; 1; ++$i) {
	warn "# read $i lines of '$filename'\n" if $verbose && $i > 0 && ($i % 1000 == 0);
	my $gff = <FILE>;
	last unless defined $gff;
	push @file, $gff if $filename eq '-';  # only cache file if on a pipe
	# parse GFF line
	next if $gff =~ /^\s*\#/ || $gff !~ /\S/;  # skip blank lines, comments
	chomp $gff;
	my @gff = split /\t/, $gff, 9;
	my ($name, $start, $end) = @gff[0,3,4];
	$node{$name} = QuadNode->new() unless exists $node{$name};
	$node{$name} = $node{$name}->addLeaf ($start, $end, $i);
    }
    close FILE;
    return (\@file, \%node);
}

# intersect returns hash of GFF features from %node2 to arrays of intersecting features in %node1
sub intersect {
    my ($node1, $node2) = @_;
    my %intersect;
    while (my ($seqname, $root1) = each %$node1) {
	if (exists $node2->{$seqname}) {
	    my $root2 = $node2->{$seqname};
	    my $size2 = $root2->size;
	    $root1->iterate (1, 1, $root1->size, $root1->size,
			     sub {
				 my ($leaf1) = @_;
				 my $x1 = $leaf1->xmin;
				 my $y1 = $leaf1->ymin;
				 # (x1,y1) = (start,end) for feature 1
				 # (x2,y2) = (start,end) for feature 2
				 # Intersection occurs unless y2<x1 or y1<x2
				 # i.e. intersection occurs if x2<=y1 and y2>=x1
				 $root2->iterate (1, $x1, $y1, $size2,
						  sub {
						      my ($leaf2) = @_;
						      $intersect{$leaf2} = [] unless exists $intersect{$leaf2};
						      push @{$intersect{$leaf2}}, $leaf1;
						  });
			     });
	}
    }
    return \%intersect;
}

# printLines prints selected lines of a file
sub printLines {
    my ($filename, $file, $lines) = @_;
    if (@$file) {
	foreach my $line (@$lines) {
	    print $file->[$line];
	}
    } else {
	if (@$lines) {
	    @$lines = reverse @$lines;
	    local *FILE;
	    open FILE, "<$filename" or die "Can't reopen GFF '$filename': $!";
	    my $n = 0;
	    while (my $gff = <FILE>) {
		if ($n == $lines->[@$lines-1]) {
		    print $gff;
		    pop @$lines;
		    last unless @$lines;
		}
		++$n;
	    }
	    close FILE;
	}
    }
}


1;
