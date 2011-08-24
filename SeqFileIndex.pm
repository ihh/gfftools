package SeqFileIndex;

use vars qw($AUTOLOAD @ISA);
use Exporter;
use Carp;
use strict;
use FileHandle;

@ISA = qw(Exporter);

my $suffix = ".SeqFileIndex";

my %fields = (
	      filename => undef,
	      verbose => undef,
	      filehandle => undef,
	      index => undef,
	      bufname => undef,
	      bufseq => undef,
	      case_sensitive => 0,
	      suffix => undef
);

sub new {
    my $obj = shift;
    my $filename = shift;
    my $verbose = @_ ? shift : 1;
    my $case_sens = @_ ? shift : 0;

    my $pkg = ref($obj) || $obj;
    my $self = { _permitted=>\%fields, %fields };
    bless $self, $pkg;

    $self->filename($filename);
    $self->verbose($verbose);
    $self->case_sensitive($case_sens);

    $self->suffix ($case_sens ? $suffix . "_cs" : $suffix);

    $self->filehandle(new FileHandle);
    $self->filehandle->open("< $filename") or confess ref($self).": couldn't open $filename for reading: $!";

    $self->buildindex($filename);
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

sub buildindex {
    my ($self,$filename) = @_;
    unless (-r $filename) { confess ref($self).": can't read $filename" }
    my $sep = $/;
    my $indexfilename = "." . $filename . $self->suffix;
    my @fstat;
    my @istat;
    $self->index({});
    local *INDEX;
    if (-e $indexfilename and @fstat=stat($filename), @istat=stat($indexfilename), $istat[9] > $fstat[9]) {
	open INDEX, $indexfilename or confess ref($self).": couldn't open $indexfilename for reading: $!";
	while (<INDEX>) {
	    my ($name,$pos) = split;
	    $name = uc($name) unless $self->case_sensitive;
	    $self->index->{$name} = $pos;
	}
	close INDEX;
    } else {
	carp ref($self).": building index for $filename" if $self->verbose;
	my $sep = $/;
	$/ = ">";
	my $dummy = $self->filehandle->getline;
	my ($name,$pos);
	while ($/ = "\n", $name = $self->filehandle->getline) {
	    ($name) = split /\s+/, $name;
	    $self->index->{$name} = $self->filehandle->tell;
	    $/ = ">";
	    $dummy = $self->filehandle->getline;
	}
	$/ = $sep;
	open INDEX, ">$indexfilename" or confess ref($self).": couldn't open $indexfilename for writing: $!";
	while (($name,$pos) = each %{$self->index}) { print INDEX "$name $pos\n" }
	close INDEX;
	unless ($self->case_sensitive) {
	    my $oldindex = $self->index;
	    $self->index({});
	    while (($name,$pos) = each %$oldindex) { $self->index->{uc $name} = $pos }
	}
	carp ref($self).": index built" if $self->verbose;
    }
    $/ = $sep;
}

# data access methods

sub getseq {
    my ($self,$seqname,$start,$end) = @_;
    warn "Sequence name contains whitespace: $seqname\n" if $seqname =~ /\s/;
    $seqname = uc($seqname) unless $self->case_sensitive;
    my $sequence;
    if ($seqname eq $self->bufname) {
	$sequence = $self->bufseq;
    } else {
	my $sep = $/;
	if (exists($self->index->{$seqname})) {
	    $self->filehandle->seek($self->index->{$seqname},0);
	    $/ = ">";
	    $sequence = $self->filehandle->getline;
	    $sequence =~ s/>$//;
	    $sequence =~ s/\s//g;
	    $/ = $sep;
	    $self->bufname($seqname);
	    $self->bufseq($sequence);
	} else {
	    if (defined($start) && defined($end)) { $sequence = 'n' x (abs($end-$start) + 1) }
	    else { $sequence = 'n' }
	    warn "Sequence not found: $seqname\n";
	}
    }
    if (defined $start) {
	if (defined $end) {
	    my $revcomp;
	    if ($end < $start) { ($start,$end,$revcomp) = ($end,$start,1) }
	    $sequence = substr($sequence,$start - 1,$end + 1 - $start);
	    if ($revcomp) { $sequence = $self->revcomp($sequence) }
	}
	else { $sequence = substr($sequence,$start - 1) }
    }
    $sequence;
}

sub revcomp {
    my ($self,$sequence) = @_;
    $sequence = join("",reverse(split(//,$sequence)));
    $sequence =~ tr/acgtACGT/tgcaTGCA/;
    $sequence;
}

1;
