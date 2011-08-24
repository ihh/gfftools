#!/usr/bin/perl -w

use strict;
use File::Basename;

my $prog = basename($0);
my $usage .= "$prog - sort one or many GFF files, using a specified sort method.";
$usage .= "  Default sort is by Name, Start, and End fields, in ascending order.\n";
$usage .= "\n";
$usage .= "Usage: $prog [options] <file1> <file2> ...";
$usage .= "\n";
$usage .= "Options:\n";
$usage .= "   -maxSc: sort by maximum score, in descending order\n";
$usage .= "   -minSc: sort by minimum score, in ascending order\n";
$usage .= "   -flen: sort by feature length, in ascending order\n";
$usage .= "   -userdef: sort by user defined expression; use single quotes\n"; 

my $sortMethod = "byNSE";
my $sortExpr = undef;

while (@ARGV) 
{
    last unless $ARGV[0] =~ /^-./;      # Loop thru all the command line options.
    my $opt = shift;
    if ($opt eq "-maxSc") 
    { 
      $sortMethod = "byMaxScore"; 
    }
    elsif ($opt eq "-minSc") 
    { 
      $sortMethod = "byMinScore"; 
    }
    elsif ($opt eq "-flen") 
    { 
      $sortMethod = "byFeatureLen"; 
    }
    elsif ($opt eq "-userdef") 
    { 
      $sortMethod = "byexpr";
      $sortExpr = shift || die "$usage\nMissing sort expression.\n";
    }
    else 
    { 
      die "$usage\nUnknown option: $opt\n" 
    }
}
 
if (@ARGV==0)
{
  die $usage;
}

my (@line, @name, @type, @start, @end, @score);

while (<>) { # Read lines from file(s) specified on command line. Store in $_.
    s/#.*//; # Remove comments from $_.
    next unless /\S/; # \S matches non-whitespace.  If not found in $_, skip to next line.
    my @f = split /\t/; # split $_ at tabs separating fields.
    push @line, $_;    # complete line
    push @name, $f[0]; # name field
    push @type, $f[2]; # type field
    push @start, $f[3]; # start field
    push @end, $f[4]; # end field
    push @score, $f[5]; # score field
}

foreach my $i (sort $sortMethod 0..$#line) 
{ 
  print $line[$i] 
}

# Sort by name, start, then end, from low to high.
sub byNSE
{
  $name[$a] cmp $name[$b] or $start[$a] <=> $start[$b] or $end[$a] <=> $end[$b]; 
}

sub byMinScore 
{
  $score[$a] <=> $score[$b] or $name[$a] cmp $name[$b] or $start[$a] <=> $start[$b] 
      or $end[$a] <=> $end[$b]; 
}

sub byMaxScore 
{
  $score[$b] <=> $score[$a] or $name[$a] cmp $name[$b] or $start[$a] <=> $start[$b] 
      or $end[$a] <=> $end[$b]; 
}

sub byFeatureLen 
{
  $end[$a]-$start[$a] <=> $end[$b]-$start[$b] or $name[$a] cmp $name[$b] or $start[$a] <=> $start[$b] 
      or $end[$a] <=> $end[$b]; 
}

sub byexpr {
    eval $sortExpr;
}
