package SequenceMap;

use vars qw($AUTOLOAD @ISA);
use Exporter;
use Carp;
use strict;
use FileHandle;

use SeqFileIndex;

@ISA = qw(Exporter);

my $nullseqname = "NULL";

my %fields = (
	      seqfileindex => undef,
	      seqmap => undef,
	      case_sensitive => 0
);

sub new {
    my $obj = shift;
    my $mapgff = shift;
    my $seqdb = shift;
    my $case = @_ ? shift : 0;

    my $pkg = ref($obj) || $obj;
    my $self = { _permitted=>\%fields, %fields };
    bless $self, $pkg;

    $self->case_sensitive($case);
    $self->seqfileindex(SeqFileIndex->new($seqdb,1,$case));
    $self->readmapgff($mapgff);

    $self;
}

sub DESTROY {
    my ($self) = @_;
    $self->filehandle->close;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) || confess "AUTOLOAD: object unknown: $self";
    my $name = $AUTOLOAD;

    # don't propagate DESTROY messages...

    $name =~ /::DESTROY/ && return;

    $name =~ s/.*://; # get only the bit we want
    unless (exists $self->{'_permitted'}->{$name} ) { confess "$type: can't access $name" }

    if (@_) { return $self->{$name} = shift }
    else { return $self->{$name} }
}

# init methods

sub readmapgff {
    my ($self,$mapgff) = @_;
    $self->seqmap({});
    open MAPGFF, $mapgff or die $!;
    while (<MAPGFF>) {
	my @f = split /\t/, $_, 9;
	$f[8] =~ s/\s.*//;
	if ($f[6] ne '+') { print; confess "Urk... can't cope with backwards clones yet" }
	$f[0] = uc($f[0]) unless $self->case_sensitive;
	if (exists($self->seqfileindex->index->{$f[8]})) {
	    push @{$self->seqmap->{$f[0]}}, \@f;
	}
    }
    close MAPGFF;
}

# data access methods

sub getseq {
    my ($self,$seqname,$start,$end) = @_;
    $seqname = uc($seqname) unless $self->case_sensitive;
    my ($revcomp,@result);
    if ($start > $end) { ($start,$end,$revcomp) = ($end,$start,1) }
    unless (exists($self->seqmap->{$seqname})) { push @result, [$seqname, $start, $end] }
    else {
	my $f;
	print STDERR grep(/T04D1/,@{$self->seqmap->{$seqname}});
	foreach $f (@{$self->seqmap->{$seqname}}) {
#	    warn "start=$start f=(@$f)\n";
	    next if $start > $f->[4];
	    if ($f->[3] > $start && $start <= $end) {
		push @result, [$nullseqname, 1, min($end+1,$f->[3]) - $start];
		$start = min($end+1,$f->[3]);
	    }
	    last if $start > $end;
	    push @result, [$f->[8], $start - $f->[3] + 1, min($end,$f->[4]) - $f->[3] + 1];
	    $start = min($end,$f->[4]) + 1;
	}
	if ($start <= $end) { push @result, [$nullseqname, 1, $end + 1 - $start] }
    }
    my ($sequence,$nse);
    foreach $nse (@result) {
	$sequence .= $self->seqfileindex->getseq(@$nse);
    }
    if ($revcomp) { $sequence = $self->seqfileindex->revcomp($sequence) }
    $sequence;
}


sub min { my ($a,$b) = @_; $a < $b ? $a : $b }
sub max { my ($a,$b) = @_; $a > $b ? $a : $b }
