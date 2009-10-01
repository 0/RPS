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

use constant YOUR	=> 0;
use constant THEIR	=> 1;
use constant RESULT	=> 2;

# [your move, their move, outcome], each [012]
# newest <=> oldest
my @history;

# Incremented once for each use by opponent.
# used by alg_freq
my @opponent_count = (0, 0, 0);

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

### Returns [012] for a random throw
#
sub random_throw {
	return int (3 * rand ());
}

sub compare_history {
	my ($a, $b) = @_;
	for (my $i = 0; $i < @{$a} && $i < @{$b}; ++$i) {
		foreach my $p (YOUR, THEIR) {
			if ($a->[$i]->[$p] != $b->[$i]->[$p]) {
				return 0;
			}
		}
	}
	return 1;
}

#### Algorithms:

# Frequency analysis of opponent's throws.
sub alg_freq {
	my $freq_threshold = shift;
	my $max = max (@opponent_count);
	my @pool;
	foreach my $a (ROCK, PAPER, SCISSORS) {
		push @pool, $a if $max == 0 || abs ($opponent_count[$a] - $max) / $max < $freq_threshold;
	}
	return will_beat($pool[int (@pool * rand)]);
}

# Pattern matching.
sub alg_pattern {
	return random_throw () if @history <= 0;

	my $history_distance = shift;
	my $max_history = $history_distance < scalar @history ? $history_distance : scalar @history;

	my $match_last = 1;
	for (my $len = 1; 2 * $len <= $max_history; ++$len) {
		my $match;
		for (my $x = max ($match_last, $len); $len + $x <= $max_history; ++$x) {
			if (compare_history ([@history[0..$len-1]], [@history[$x..$x+$len-1]])) {
				$match = $x;
			}
		}
		last if ! defined $match;
		$match_last = $match;
	}
	return will_beat ($history[$match_last-1]->[THEIR]);
}

# When all else fails...
sub alg_random {
	return random_throw ();
}

my %algorithms = (
	freq		=> {
		code	=> \&alg_freq,
		values	=> [0.01, 0.05, 0.1, 0.2, 0.5], #freq_threshold
		success	=> [0, 0, 0, 0, 0],
	},
	pattern		=> {
		code	=> \&alg_pattern,
		values	=> [1, 5, 10, 25], #history_distance
		success	=> [0, 0, 0, 0],
	},
	random		=> {
		code	=> \&alg_random,
		values	=> [0],
		success	=> [0],
	},
);

### iO
## Uses the history to determine the next move
#
sub out {
	my ($max_alg, $max_val, $max_suc);
	foreach my $a (keys %algorithms) {
		for (my $i = 0; $i < @{$algorithms{$a}->{values}}; ++$i) {
#print STDERR join " ", ($a, $algorithms{$a}->{values}->[$i], $algorithms{$a}->{success}->[$i], "\n");
			if (! defined $max_suc || $algorithms{$a}->{success}->[$i] > $max_suc) {
				($max_alg, $max_val, $max_suc) = ($a, $i, $algorithms{$a}->{success}->[$i]);
			}
		}
	}
#print STDERR "\tUsing $max_alg ", $algorithms{$max_alg}->{values}->[$max_val], "\n";
	return $algorithms{$max_alg}->{code}->($algorithms{$max_alg}->{values}->[$max_val]);
}

### Io
## Takes the outcome of the last throw and records it
## Args: my move; opponent's move; outcome ([wdl])
#
sub in {
	my ($a, $b, $r) = @_;

	# Grade how the algorithms would have performed
	foreach my $a (keys %algorithms) {
		for (my $i = 0; $i < @{$algorithms{$a}->{values}}; ++$i) {
			my $r = $algorithms{$a}->{code}->($algorithms{$a}->{values}->[$i]);
			if ($r == will_beat ($b)) {
#print STDERR "$a PLUS cause $r $b\n";
				++$algorithms{$a}->{success}->[$i];
			} elsif ($r != $b) {
#print STDERR "$a MINUS cause $r $b\n";
				--$algorithms{$a}->{success}->[$i];
			}
		}
	}

	my $o;
	if ($r =~ /^w/i) {
		$o = WIN;
	} elsif ($r =~ /^d/i) {
		$o = DRAW;
	} else { # Assume loss
		$o = LOSS;
	}
	unshift @history, [$a, $b, $o];

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
	in ($1, $2, $3) and next if /^outcome\s+([012])\s+([012])\s+([wdl])/i;
}
