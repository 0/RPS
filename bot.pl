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

### iO
## Uses the history to determine the next move

sub out {
print @{$history[$#history]},"\n" if @history;
	return int (3 * rand);
}

### Io
## Takes the outcome of the last throw and records it
## Args: my move; opponent's move; outcome ([wdl])

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
}

### Main loop.
## 3 possible inputs:
# done			=> Exit
# go			=> Make a move
# outcome X Y Z	=> You played X, opponent played Y, outcome for you was Z;
#				   where X and Y are [012] and Z is (WIN|DRAW|LOSS)
## 1 possible output:
# X				=> The move to make, where X is [012]

while (<STDIN>) {
	last if /^done$/i;
	print out (),"\n" and next if /^go$/i;
	in ($1, $2, $3) and next if /^outcome ([012]) ([012]) ([wdl])/i;
}
