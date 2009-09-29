#!/usr/bin/perl

use strict;
use warnings;

# Autoflush!
$| = 1;

use constant ROCK		=> 0;
use constant PAPER		=> 1;
use constant SCISSORS	=> 2;

use constant WIN	=> 0;
use constant DRAW	=> 1;
use constant LOSS	=> 2;

# [your move, their move, outcome], each [012]
my @history;

# Incremented once for each use by opponent.
my @opponent_count = (0, 0, 0);

# The maximum deviation from the max to be considered.
my $freq_threshold = 0.1;

### It's what you think it is.
#
sub max {
	my $max;
	foreach my $x (@_) {
		$max = $x if ! defined $max || $max < $x;
	}
	return $max;
}

### Determine what hand beats a particular hand.
#
sub will_beat {
	my $a = shift;
	return ($a + 1) % 3;
}

### iO
## Uses the history to determine the next move
#
sub out {
	# Frequency analysis of opponent's throws.
	my $max = max (@opponent_count);
	my @pool;
	foreach my $a (ROCK, PAPER, SCISSORS) {
		push @pool, $a if $max == 0 || abs ($opponent_count[$a] - $max) / $max < $freq_threshold;
	}
	return will_beat($pool[int (@pool * rand)]);
}

### Io
## Takes the outcome of the last throw and records it
## Args: my move; opponent's move; outcome ([wdl])
#
sub in {
	my ($a, $b, $r) = @_;

	my $o;
	if ($r =~ /^w/i) {
		$o = WIN;
	} elsif ($r =~ /^d/i) {
		$o = DRAW;
	} else { # Assume loss
		$o = LOSS;
	}
	push @history, [$a, $b, $o];

	++$opponent_count[$b];
}

### Main loop.
## 3 possible inputs:
# done			=> Exit
# go			=> Make a move
# outcome X Y Z	=> You played X, opponent played Y, outcome for you was Z;
#				   where X and Y are [012] and Z is (WIN|DRAW|LOSS)
## 1 possible output:
# X				=> The move to make, where X is [012]
#
while (<STDIN>) {
	last if /^done/i;
	print out (),"\n" and next if /^go/i;
	in ($1, $2, $3) and next if /^outcome ([012]) ([012]) ([wdl])/i;
}
