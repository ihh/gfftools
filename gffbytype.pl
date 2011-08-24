#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my $suffix = ".gff";
my %type; # hash to hold gff lines of each type

# Process the command line.
my $outDir = ".";
GetOptions("o=s" => \$outDir);
if(@ARGV == 0) 
{
  help();
  die();
}

# Read lines from file(s) specified on command line. Store in $_.
while (<>) 
{      
  # \S matches non-whitespace.  If not found in $_, skip to next line.
  next unless /\S/;   
  # \s matches whitespace followed by a "#".  If a comment is found in $_ line, skip.
  next if /^\s*\#/;   
  # Split the $_ line into 9 tab separated fields.
  my @f = split /\t/, $_, 9;
  # Save the line in the "type" hash with key of gff type (third field).
  $type{$f[2]} .= $_; 
}

# Create output directory if it doesn't exist.
if (! -e $outDir)
{
  mkdir($outDir) or die("Unable to create output directory $outDir");
}

local *FILE;
# Iterate through the hash.
while (my ($type, $file) = each %type) 
{ 
  my $filename = $outDir . "/" . $type . $suffix;
  open FILE, ">$filename" or die "Couldn't write '$filename'";
  print FILE $file;
  close FILE or die "Couldn't write '$filename'";
  # Sort the output file.
  my $sortCmd = "gffsort.pl $filename";
  my $sortedFile = `$sortCmd` or die "Couldn't sort $filename:$?";
  open FILE, ">$filename" or die "Couldn't write '$filename'";
  print FILE $sortedFile;
  close FILE or die "Couldn't write '$filename'";
}

sub help 
{
  my $prog = basename($0);
  print STDERR <<EOF;

  $prog: 
     Split input gff files into subfiles by gff type. 
     gffsort.pl is called on each subfile.
      
  Usage: $prog [options] <gffFile1> <gffFile2> ...

  Options
    -o <directory>: specify output directory (default is current directory)

EOF
}

