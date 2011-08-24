package FileIndex;

use vars qw($AUTOLOAD @ISA);
use Exporter;
use Carp;
use strict;
use FileHandle;

@ISA = qw(Exporter);

my $suffix = ".FileIndex";

my %fields = (
	      filename => undef,
	      verbose => undef,
	      filehandle => undef,
	      index => undef
);

sub new {
    my $obj = shift;
    my $filename = shift;
    my $verbose = @_ ? shift : 1;
    my $separator = @_ ? shift : $/;

    my $pkg = ref($obj) || $obj;
    my $self = { _permitted=>\%fields, %fields };
    bless $self, $pkg;

    $self->filename($filename);
    $self->verbose($verbose);

    $self->filehandle(new FileHandle);
    $self->filehandle->open("< $filename") or confess ref($self).": couldn't open $filename for reading: $!";
    $self->filehandle->input_record_separator($separator);

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
    my $indexfilename = "$filename$suffix";
    my @fstat;
    my @istat;
    local *INDEX;
    if (-e $indexfilename and @fstat=stat($filename), @istat=stat($indexfilename), $istat[9] > $fstat[9]) {
	my $indexdata;
	open INDEX, $indexfilename or confess ref($self).": couldn't open $indexfilename for reading: $!";
	read INDEX, $indexdata, $istat[7];
	close INDEX;
	$self->index([unpack("I*",$indexdata)]);
    } else {
	carp ref($self).": building index for $filename" if $self->verbose;
	my ($n,$fpos,@index);
	$n = $fpos = 0;
	while ($fpos = $self->filehandle->tell, $_ = $self->filehandle->getline) { push @index, $fpos }
	open INDEX, ">$indexfilename" or confess ref($self).": couldn't open $indexfilename for writing: $!";
	print INDEX pack("I*",@index);
	close INDEX;
	$self->index(\@index);
    }
}

# data access methods

sub lines {
    my ($self) = @_;
    scalar(@{$self->index});
}

sub getline {
    my ($self,@n) = @_;
    my @result;
    my $index = $self->index;
    my $n;
    foreach $n (@n) {
	if ($n < 0 || $n >= @$index) {
	    carp ref($self).": tried to access line $n of ".$self->filename." (only ".$self->lines." lines long)" if $self->verbose;
	    push @result, undef;
	} else {
	    $self->filehandle->seek($index->[$n],0);
	    push @result, $self->filehandle->getline;
	}
    }
    @n==1 ? shift(@result) : @result;    # return scalar if possible
}


1;
