package BraceParser;

use vars qw($AUTOLOAD @ISA);
use Exporter;
use Carp;
use strict;

@ISA = qw(Exporter);

sub new {
    my ($obj,$string) = @_;
    my $pkg = ref($obj) || $obj;
    my ($self,$dummystring) = get_contents("$string}");
    bless $self,$pkg;
    $self;
}

sub new_from_file {
    my ($obj,$file) = @_;
    local *FILE;
    open FILE, $file or confess "Couldn't open $file: $!";
    my $sep = $/;
    undef $/;
    my $string = <FILE>;
    close FILE;
    $/ = $sep;
    new($obj,$string);
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) || carp "Don't know about $self";
    my $name = $AUTOLOAD;

    # don't propagate DESTROY messages...

    $name =~ /::DESTROY/ && return;

    $name =~ s/.*://; #get only the bit we want

    if (@_) { return $self->{$name} = shift }
    else { return $self->{$name} }
}

sub name_contents_next {
    my ($string) = @_;
    $string =~ s/\n/ /g;
    unless ($string =~ /\S/) { return () }
    unless ($string =~ /\s*([^\{\}\s]+)\s*\{\s*(.*)/) { confess "Can't parse $string" }
    my ($name,$contents);
    ($name,$string) = ($1,$2);
    if ($string =~ /^\s*([^\{\}]*?)\s*\}(.*)/) {
	($contents,$string) = ($1,$2);
    } else {
	($contents,$string) = get_contents($string);
    }
    ($name,$contents,$string);
}

sub get_contents {
    my ($string) = @_;
    my ($contents,$subname,$subcontents);
    $contents = {};
    while (defined $string) {
	($subname,$subcontents,$string) = name_contents_next($string);
	push @{$contents->{$subname}}, $subcontents;
	last if $string =~ s/^\s*\}\s*//;
    }
    ($contents,$string);
}

sub print {
    my ($self,$tree,$indent) = @_;
    $tree = $self unless defined $tree;
    $indent = 0 unless defined $indent;
    my $firstline = 1;
    my ($name,$contentslist,$contents);
    while (($name,$contentslist) = each %$tree) {
	foreach $contents (@$contentslist) {
	    unless ($firstline) { print " " x $indent }
	    else { $firstline = 0 }
	    if (ref $contents) {
		my $text = "$name { ";
		print $text;
		my $oneline = $self->print($contents,$indent + length $text);
		print " " x ($indent + length($text) - 2) unless $oneline;
		print "}\n";
	    } else {
		print "$name { $contents }\n";
	    }
	}
    }
    $firstline;
}

1;
