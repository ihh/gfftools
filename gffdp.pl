#!/usr/bin/perl -w

use BraceParser;
# BEGIN { require glob("~ihh/perl/BraceParser.pm"); import BraceParser }

$| = 1;

@fields = qw(seqname source feature start end score strand frame group id count);

@dummygffcache = (["dummy",".",".",0,0,0,".",".","",-1]);

$infinity = 10**9;

($progname = $0) =~ s#.*/(\S+)#$1#;

$usage .= "$progname - assemble GFF segments by dynamic programming using a pushdown automaton\n";
$usage .= "\n";
$usage .= "Usage: $progname [-d<flags>] [-eval expr] <model file> [<GFF files>]\n";
$usage .= "\n";
$usage .= "GFF files must be sorted by seqname and startpoint (use gffsort.pl for this)\n";
$usage .= "\n";
$usage .= "Model file format: too busy to document fully - sorry... email ihh\@sanger.ac.uk\n";
$usage .= "In brief: format looks like \"tag { subtag1 { property1 } subtag2 { property2 } subtag3 { subsubtag1 { ... } } }\"\n";
$usage .= "Top-level tags include (name begin end flushlen gffcachelen states startstate endstate link eval)\n";
$usage .= "Compulsory link tags include (from to)\n";
$usage .= "Optional link tags include (maxlen endfilter startfilter popfilter push score insertgff display)\n";
$usage .= " (this is also pretty much the conceptual order of precedence of link tags)\n";
$usage .= "Use (".join(" ",map("\$gff$_",@fields)).") to refer to GFF fields, and (\$linkstart \$linkend \$linklen) for link co-ords (NB typically \$linkend == \$end + 1)\n";
$usage .= "Can also use (".join(" ",map("\$grepgff$_",@fields)).") to refer to GFF fields within a grep(expr,\@gffcache) expression\n";
$usage .= "score tag can use \$gfffragmentscore to auto-calculate GFF overlap (this is the default value for the score tag)\n";
$usage .= "display tag can use \$gfftext, \$modelname and \$progname as a shorthand\n";
$usage .= "Can have multiple push & popfilter tags (NB not true for other link tags). push tag pushes its argument onto the stack, popfilter tag pops an argument into \$_ and must then evaluate to true\n";
$usage .= "push and popfilter tags may use \$insertgffid and pseudo-GFF field \$gffid to keep in sync - in fact these are the default push and popfilter settings (non-inserted GFFs have \$gffid==0)\n";
$usage .= "Put \"insertgff { }\" (i.e. blank) to auto-insert other half of inverted repeats etc (assumes second & third words in GFF group field are co-ords of other half) - use with \"push { }\" and \"popfilter { }\"\n";
$usage .= "Use built-in combine_strands('-','+',...) function to flip strand directions\n";
$usage .= "\n";
$usage .= "PITFALLS to BEWARE: ignoring effects of (i) GFF cache (default gffcachelen==0, i.e. GFFs flushed ASAP) (ii) greedy optimisation; inadvertently re-reading inserted GFFs (several ways to avoid this, e.g. check strand (if appropriate) or check that \$gffid==0)\n";
$usage .= "There are implicit \"padding\" links (1) from the start state to itself and (2) from the end state to itself. By default, these states are flushed immediately, so don't look backwards and expect them to be there.\n";
$usage .= "If you want a looping model (for multiple hits) you have to put the loop in yourself.\n";
$usage .= "\n";
$usage .= "Use -d<flags> to set debug flags - most usefully -dp or -dn to show progress by position or name; or at a slightly deeper debug level:\n";
$usage .= " -du (updatestates) to show updatestates calls\n";
$usage .= " -db (checkpoint bravo) to show endfilter checks\n";
$usage .= " -dc (checkpoint charlie) to show startfilter checks\n";
$usage .= " -ds (stack) to show what links & stack data are being stored\n";
$usage .= "\n";
$usage .= "For best results pre-filter incoming GFFs as much as possible!\n";
$usage .= "\n";

while (@ARGV) {
    last unless $ARGV[0] =~ /^-/;
    $opt = lc shift;
    if ($opt =~ s/^-d//) { while (($c = chop $opt) ne "") { $debug{$c} = 1 } }
    elsif ($opt eq "-eval") { defined($eval = shift) or die $usage; eval $eval }
    else { die "$usage\nUnknown option: $opt\n" }
}

@ARGV>=1 or die $usage;
$modelfile = shift;

$model = new_from_file BraceParser($modelfile);

if (defined $model->{"begin"}) { foreach (@{$model->{"begin"}}) { eval $_ } }

if (defined $model->flushlen) { $flushlen = $model->flushlen->[0] }
else { $flushlen = $infinity }

if (defined $model->gffcachelen) { $gffcachelen = $model->gffcachelen->[0] }
else { $gffcachelen = 0 }

$declaredstates = 0;
if (defined $model->states) {
    foreach $tag (split /\s+/,"@{$model->states}") { taglookup($tag,\%statenumber,\@statename) }
    $declaredstates = 1;
}

if (defined($eval = $model->{"eval"})) { foreach (@$eval) { $_ = substitute($_) } }

foreach $link (@{$model->link}) {
    
    defined($fromtag = $link->{"from"}->[0]) or die "All links must have a <from> field";
    defined($totag = $link->{"to"}->[0]) or die "All links must have a <to> field";

    $from = taglookup(lc $fromtag,\%statenumber,\@statename);
    $to = taglookup(lc $totag,\%statenumber,\@statename);
    
    if (defined($score = $link->{"score"}->[0])) { $score = substitute($score) }
    if (defined($endfilter = $link->{"endfilter"}->[0])) { $endfilter = substitute($endfilter) }
    if (defined($startfilter = $link->{"startfilter"}->[0])) { $startfilter = substitute($startfilter) }
    if (defined($push = $link->{"push"})) { foreach (@$push) { $_ = substitute($_) } }
    if (defined($popfilter = $link->{"popfilter"})) { foreach (@$popfilter) { $_ = substitute($_) } }
    if (defined($insertgff = $link->{"insertgff"}->[0])) { $insertgff = substitute($insertgff) }

    $usegff = defined($endfilter) || defined($startfilter);
    
    if (defined($maxlen = $link->{"maxlen"}->[0])) {
	if (!defined($maxlenfrom[$from]) || $maxlen > $maxlenfrom[$from]) { $maxlenfrom[$from] = $maxlen }
    } else {
	die "Must specify a maximum length for GFF-using links" if $usegff;
	$maxlen = $infinity;
    }
    
    if (defined($link->{"display"})) { foreach (@{$link->{"display"}}) { $_ = substitute($_) } }
    
    push @links, [$from,
		  $to,
		  $usegff,
		  $score,
		  $maxlen,
		  $endfilter,
		  $startfilter,
		  $push,
		  $popfilter,
		  $insertgff,
		  $link];
    
    $numberoflinks{$from,$to}++;

}

defined($starttag = $model->{"startstate"}->[0]) or $starttag = "start";
$startstate = taglookup($starttag,\%statenumber,\@statename);

defined($endtag = $model->{"endstate"}->[0]) or $endtag = "end";
unless (exists $statenumber{$endtag}) { $endtag = $starttag }
$endstate = taglookup($endtag,\%statenumber,\@statename);

unless ($numberoflinks{$startstate,$startstate}) {      # check that start state is padded
    unshift @links, [$startstate, $startstate, 0, 0, $infinity, undef, undef, undef, undef, undef, undef];
}

unless ($numberoflinks{$endstate,$endstate}) {          # check that end state is padded
    unshift @links, [$endstate, $endstate, 0, 0, $infinity, undef, undef, undef, undef, undef, undef];
}

$links = @links;
$states = keys %statenumber;

if ($debug{'m'}) {
    warn "* model: states=(@statename)\n";
    foreach $link (@links) { warn "* model: @$link\n" }
}

for ($state=0;$state<$states;$state++) {
    if (defined($ml = $maxlenfrom[$state])) {
	$maxlenfrom[$state] = $flushlen if $ml > $flushlen;
    } else {
	$maxlenfrom[$state] = 0;
    }
}

@stateinfo = map([],1..$states);

$insertgffid = 0;

$gfftotal = 0;
while (<>) {
    s/#.*//;
    next unless /\S/;
    chomp;
    $gff = [split(/\t/,$_,9)];
    @$gff == 9 or die "Not a GFF file";
    $gff->[9] = 0;
    $gff->[10] = ++$gfftotal;
    
    ($seqname,$start,$end) = @{$gff}[0,3,4];
    if (!defined($lastseqname) || $seqname ne $lastseqname || $start > $laststart + $flushlen) {
	flushgffcache();
	flushstates();
	$lastseqname = $gff->[0];
	if ($debug{'n'}) { warn "* name: $lastseqname\n" }
    }
    $laststart = $start;
    
    if ($debug{'p'}) { warn "* position: $lastseqname/$start-$end\n" }
    addtogffcache($gff);
    updatestack($start);
    updategffcache($start);
    updatestates($start);
}

flushgffcache();
flushstates();

if (defined $model->{"end"}) { foreach (@{$model->{"end"}}) { eval $_ } }

###################################################################################
# subroutines
###################################################################################

sub taglookup {
    my ($tag,$lookup,$name) = @_;
    unless (exists $lookup->{$tag}) {
	if ($declaredstates) { die "Undeclared state: $tag" }
	$name->[$lookup->{$tag} = keys %$lookup] = $tag;
    }
    $lookup->{$tag};
}

sub addtogffcache {
    my ($gff) = @_;
    if ($debug{'g'}) { warn "* addgff: ".join("\t",@$gff)."\n" }
    my $end = $gff->[4];
    my $i;
    for ($i=0;$i<@gffcache;$i++) { last if ($gffcache[$i]->[4] > $end) }
    splice @gffcache, $i, 0, $gff;
}

sub updategffcache {
    my ($pos) = @_;
    return if defined($lastupdategffpos) && $pos <= $lastupdategffpos;
    my ($gff,%cutpoint,$cutpoint);
    foreach $gff (@gffcache) {
	++$cutpoint{$gff->[4]};
	++$cutpoint{$gff->[4] + $gffcachelen};
    }
    foreach $cutpoint (sort {$a<=>$b} keys %cutpoint) {
	last if $cutpoint >= $pos - 1;
	next if defined($lastupdategffpos) && $cutpoint < $lastupdategffpos;
	updatestates($cutpoint + 1);
    }
    while (@gffcache && $gffcache[0]->[4] + $gffcachelen < $pos - 1) {
	$gff = shift(@gffcache);
	if ($debug{'l'}) { warn "* gffcache_remove: (@$gff)\n" }
    }
    $lastupdategffpos = $pos;
    if ($debug{'l'}) { foreach $gff (@gffcache) { warn "* gffcache: (@$gff)\n" } }
}

sub updatestates {
    my ($linkend) = @_;
    die unless defined $linkend;
    return if defined($lastupdatestatespos) && $linkend <= $lastupdatestatespos;
    $lastupdatestatespos = $linkend;
    if ($debug{'u'}) { warn "* updatestates: linkend=$linkend\n" }
    if (defined $eval) { foreach (@$eval) { eval $_ } }
    my ($link,$state,$gff,@path);
    for ($state=0;$state<$states;$state++) {
	my $path = {};
	push @path, $path;
	push @{$stateinfo[$state]}, [$linkend,$path];
    }
    foreach $link (@links) {
	my ($from,$to,$usegff,$score,$maxlen,$endfilter,$startfilter,$push,$popfilter,$insertgff) = @$link;
	my $topath = $path[$to];
	my $effectivegffcache = \@gffcache;
	unless ($usegff) { $effectivegffcache = \@dummygffcache }
      GFF: foreach $gff (@$effectivegffcache) {
	  if ($debug{'b'}) {
	      my $text = "* bravo: from=$statename[$from] to=$statename[$to] linkend=$linkend";
	      $text .= " endfilter=\"$endfilter\"" if defined $endfilter;
	      $text .= " gff=(@$gff)" if $usegff;
	      warn "$text\n";
	  }
	  if (defined($endfilter) && !eval($endfilter)) { next GFF }
	  my $pos_stacks;
	LINKSTART: foreach $pos_stacks (@{$stateinfo[$from]}) {
	    my ($linkstart,$fromstacks) = @$pos_stacks;
	    last LINKSTART if $from == $to && $linkstart == $linkend;
	    my $linklen = $linkend - $linkstart;
	    if ($debug{'c'}) {
		my $text = "* charlie: from=$statename[$from] to=$statename[$to] linkstart=$linkstart linkend=$linkend";
		$text .= " startfilter=\"$startfilter\"" if defined $startfilter;
		$text .= " gff=(@$gff)" if $usegff;
		warn "$text\n";
	    }
	    if ($linkend - $linkstart > $maxlen) { next LINKSTART }
	    if (defined($startfilter) && !eval($startfilter)) { next LINKSTART }
	    my ($gfflen,$gfffragmentscore);
	    my $minend = $linkend < $gff->[4] + 1 ? $linkend : $gff->[4] + 1;
	    my $maxstart = $linkstart > $gff->[3] ? $linkstart : $gff->[3];
	    if (!$usegff) {
		$gff = [$lastseqname,"gap","gap",$linkstart,$linkend-1,0,"+",".","",0];   # pseudo-GFF for gaps
		$gfflen = $linkend - $linkstart;
		$gfffragmentscore = 0;
	    } else {
		$gfflen = $gff->[4] + 1 - $gff->[3];
		$gfffragmentscore = $gff->[5] * ($minend - $maxstart) / $gfflen;
	    }
	    my $linkscore = defined($score) ? eval($score) : $gfffragmentscore;
	    my $newgff;
	    if (defined($insertgff) && $gff->[9] == 0) {
		if ($insertgff eq "") {
		    my ($pairseqname,$pairstart,$pairend) = ($gff->[8] =~ /(\S+)\s+(-?\d+)\s+(-?\d+)/);
		    die "Can't auto-insert pairs with a different seqname" if $pairseqname ne $gff->[0];
		    $newgff = [@$gff];
		    $newgff->[3] = $pairstart + int(($pairend - $pairstart) * ($maxstart - $gff->[3]) / $gfflen);
		    $newgff->[4] = $pairstart + int(($pairend - $pairstart) * ($minend - $gff->[3]) / $gfflen);
		    if ($newgff->[3] > $newgff->[4]) {
			@{$newgff}[3,4] = @{$newgff}[4,3];
			$newgff->[6] = $gff->[6] eq '-' ? '+' : '-';
			$newgff->[8] =~ s/(\S+)\s+(-?\d+)\s+(-?\d+)/$1 $gff->[4] $gff->[3]/;
		    } else {
			$newgff->[6] = $gff->[6] eq '-' ? '-' : '+';
			$newgff->[8] =~ s/(\S+)\s+(-?\d+)\s+(-?\d+)/$1 $gff->[3] $gff->[4]/;
		    }
		    $newgff->[5] = 0;
		} else {
		    $newgff = eval $insertgff;
		}
		$newgff->[9] = ++$insertgffid;
		$newgff->[10] = 0;
		addtogffcache($newgff);
		my $i;
		for ($i=0;$i<@insertedstart;$i++) { last if ($insertedstart[$i] > $newgff->[3]) }
		splice @insertedstart, $i, 0, $newgff->[3];
		if ($debug{'i'}) { warn "* insertgff: newgff=(@$newgff) insertedstart=(@insertedstart)\n" }
	    }
	    my ($stackstring,$frompath);
	  FROMSTACK: while (($stackstring,$frompath) = each %$fromstacks) {
	      next FROMSTACK if ($frompath->[5]==$linkend && $frompath->[6]==$gff);   # don't go round in circles
	      my @stack = split /#/, $stackstring;
	      if (defined $popfilter) {
		  my $popexpr;
		  foreach $popexpr (@$popfilter) {
		      $_ = shift @stack;
		      if ($popexpr eq "") { next FROMSTACK if ($_ != $gff->[9]) }
		      else { next FROMSTACK unless eval($popexpr) }
		  }
	      }
	      my $newscore = $frompath->[0] + $linkscore;
	      if ($debug{'f'}) { warn "* fromstack: stackstring=($stackstring) newscore=$newscore\n" }
	      if (defined $push) {
		  my $pushexpr;
		  foreach $pushexpr (@$push) {
		      if ($pushexpr eq "") { unshift @stack, $insertgffid }
		      else { unshift @stack, eval $pushexpr }
		  }
	      }
	      $stackstring = join("#",@stack);
	      if (!defined($topath->{$stackstring}) || $newscore >= $topath->{$stackstring}->[0]) {
		  if ($debug{'s'}) { warn "* stack: from=$statename[$from] to=$statename[$to] stack=(@stack) newscore=$newscore linkscore=$linkscore linkstart=$linkstart linkend=$linkend gff=(@$gff) topath=$topath\n" }
		  $topath->{$stackstring} = [$newscore,$frompath,$linkscore,$link,$linkstart,$linkend,$gff];
	      }
	  }
	}
      }
    }
    for ($state=0;$state<$states;$state++) {
	while ($stateinfo[$state]->[0]->[0] < $linkend - $maxlenfrom[$state]) { shift @{$stateinfo[$state]} }
    }
}

sub updatestack {
    my $pos = shift;
    while (@insertedstart && $insertedstart[0] <= $pos) {
	$insertedstart = shift @insertedstart;
	updategffcache($insertedstart);
	updatestates($insertedstart);
    }
}

sub flushgffcache {
    if ($debug{'f'}) { warn "* flushgffcache\n" }
    while (@gffcache) {
	my ($gff,$pos,@pos);
	foreach $gff (@gffcache) { push @pos, $gff->[4] + 1 }
	push @pos, $pos[-1] + $gffcachelen;
	foreach $pos (@pos) {
	    updatestack($pos);
	    updatestates($pos);
	    updategffcache($pos+1);
	}
    }
    undef $lastupdategffpos;
}

sub flushstates {
    my $s;
    if (@{$stateinfo[$endstate]}) {
	if (exists $stateinfo[$endstate]->[-1]->[1]->{""}) {
	    printpath($stateinfo[$endstate]->[-1]->[1]->{""});
	}
    }
    for ($s=0;$s<$states;$s++) { $stateinfo[$s] = [] }
    push @{$stateinfo[$startstate]}, [0, { "" => [0,undef,undef,undef,undef,0,0] }];
    undef $lastupdatestatespos;
}

sub printpath {
    my ($path) = @_;
    my @path;
    while (defined $path->[1]) { push @path, $path; $path = $path->[1] }
    if (defined $model->name) { $modelname = $model->name->[0] }
    else { $modelname = $progname }
    my $i;
    for ($i=$#path;$i>=0;$i--) {
	my ($score,$dummypath,$linkscore,$link,$linkstart,$linkend,$gff) = @{$path[$i]};
	$modellink = $link->[10];
	$fromtag = $statename[$link->[0]];
	$totag = $statename[$link->[1]];
	if (defined($modellink) && defined($display = $modellink->{"display"})) {
	    $gfftext = join("\t",@$gff[0..7],"$gff->[8] $modelname($fromtag->$totag)");
	    unless (exists $gffprinted{$gfftext}) { $gffprinted{$gfftext} = 0 }
	    $gffprinted = $gffprinted{$gfftext};
	    foreach $dispexpr (@$display) {
		if ($dispexpr eq "" && !$gffprinted) { print "$gfftext\n"; $gffprinted++ }
		else { eval $dispexpr }
	    }
	    $gffprinted{$gfftext} = $gffprinted;
	}
    }
}

sub substitute {
    my ($s) = @_;
    my $i;
    for ($i=0;$i<@fields;$i++) {
	$s =~ s/\$gff$fields[$i]/\$gff->[$i]/g;
	$s =~ s/\$grepgff$fields[$i]/\$_->[$i]/g;
    }
    $s;
}

sub min { my $min = shift; foreach my $x (@_) { $min = $x if $x < $min } return $min }
sub max { my $max = shift; foreach my $x (@_) { $max = $x if $x > $max } return $max }

sub combine_strands {
    my ($a,$b,@x) = @_;
    if (@x > 0) { return combine_strands(combine_strands($a,$b),@x) }
    if ($a eq '-') { return $b eq '-' ? '+' : '-' }
    return $b eq '-' ? '-' : '+';
}

