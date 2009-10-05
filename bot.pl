#!/usr/bin/perl

### ^_^

### TODO
# Implement history frequency threshold

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


###
### Global vars
###

### History
## latest is always $history[0]
#
my @history;

### Throw counters
## used by alg_freq
#
my @self_count = (0, 0, 0);
my @opponent_count = (0, 0, 0);

### Temporary save of alg_pattern's internal state
#
my $alg_pattern_match_last;
my $alg_pattern_len;


###
### Helper routines
###

### It's what you think it is
#
sub max {
	my $max;
	foreach my $x (@_) {
		$max = $x if ! defined $max || $max < $x;
	}
	return $max;
}

### Determine what hand beats a particular hand
#
sub will_beat {
	my $a = shift;
	return ($a + 1) % 3;
}

### Determine what hand loses to a particular hand
#
sub will_lose {
	my $a = shift;
	return ($a - 1) % 3;
}

### Return [012] for a random throw
#
sub random_throw {
	return int (3 * rand ());
}

### Compare two given histories
#
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

### Reset per-throw values
#
sub throw_reset {
	$alg_pattern_match_last = 1;
	$alg_pattern_len = 1;
}


###
### Magic
###

### Frequency analysis of throws
#
sub alg_freq {
	my ($rev, $threshold) = @_;
	my $max = max ($rev ? @self_count : @opponent_count);
	my @pool;
	foreach my $a (ROCK, PAPER, SCISSORS) {
		if ($max == 0 || abs (($rev ? $self_count[$a] : $opponent_count[$a]) - $max) / $max <= $threshold) {
			push @pool, $a;
#print STDERR "($rev) $a!\n";
		}
	}

	return $pool[int (@pool * rand)];
}

### Pattern matching of history
#
sub alg_pattern {
	return random_throw () if @history <= 0;

	my ($rev, $history_distance) = @_;
	my $max_history = $history_distance < scalar @history ? $history_distance : scalar @history;

	# load
	my $match_last = $alg_pattern_match_last;
	my $len = $alg_pattern_len;

	for (; 2 * $len <= $max_history; ++$len) {
		my $match;
		for (my $x = max ($match_last, $len); $len + $x <= $max_history; ++$x) {
			if (compare_history ([@history[0..$len-1]], [@history[$x..$x+$len-1]])) {
				$match = $x;
				last;
			}
		}
		last if ! defined $match;
		$match_last = $match;
	}

	# save
	$alg_pattern_match_last = $match_last;
	$alg_pattern_len = $len;

	return will_beat ($history[$match_last-1]->[$rev ? YOUR : THEIR]);
}

### When all else fails...
#
sub alg_random {
	return random_throw ();
}


###
### Meta-magic
###

### Algorithms hash
# code		=> reference to sub; args: rev?, value
# values	=> array of values to try
# success	=> foreach value, success rate: [normal, reversed],
#              and each is [normal, 1 ahead, 2 ahead]
# notest	=> do not check success rate (for random)
my %algorithms = (
	freq		=> {
		code	=> \&alg_freq,
		values	=> [0, 0.001, 0.01], # threshold
		success	=> [],
	},
	pattern		=> {
		code	=> \&alg_pattern,
		values	=> [1, 5, 10, 25, 50, 100], # history_distance
		success	=> [],
	},
	random		=> {
		code	=> \&alg_random,
		values	=> [0],
		success	=> [],
		notest	=> 1,
	},
);

### Choose best strategy
#
sub choose {
	my ($max_alg, $max_val, $max_rev, $max_ahd, $max_suc);
	foreach my $a (keys %algorithms) {
		for (my $i = 0; $i < @{$algorithms{$a}->{values}}; ++$i) {
			foreach my $rev (0, 1) {
				foreach my $j (0..2) {
#print STDERR join " ", ($a, $algorithms{$a}->{values}->[$i], ($rev ? 'R' : ' '), $algorithms{$a}->{success}->[$i]->[$rev]->[$j], "\n");
					if (! defined $max_suc || $algorithms{$a}->{success}->[$i]->[$rev]->[$j] > $max_suc) {
						($max_alg, $max_val, $max_rev, $max_ahd, $max_suc) =
							($a, $i, $rev, $j, $algorithms{$a}->{success}->[$i]->[$rev]->[$j]);
					}
				}
			}
		}
	}

#print STDERR "\tUsing $max_alg ", $algorithms{$max_alg}->{values}->[$max_val], ($max_rev ? ' R ' : '   '), "$max_ahd\n";
	return ($max_alg, $max_val, $max_rev, $max_ahd);
}

### Return the result of throwing with the given parameters
#
sub throw {
	my ($alg, $val, $rev, $ahd) = @_;
	my $throw = $algorithms{$alg}->{code}->($rev, $algorithms{$alg}->{values}->[$val]);
	if ($ahd == 0) {
		$throw = will_beat($throw);
	} elsif ($ahd == 2) {
		$throw = will_lose($throw);
	}
	return ($rev ? will_beat($throw) : $throw);
}

### Grade how the algorithms would have performed
#
sub grade {
	my $b = shift;

	foreach my $a (keys %algorithms) {
		next if $algorithms{$a}->{notest};
		for (my $i = 0; $i < @{$algorithms{$a}->{values}}; ++$i) {
			foreach my $rev (0, 1) {
				foreach my $j (0..2) {
					my $r = throw ($a, $i, $rev, $j);
#					$r = will_beat ($r) if $rev;
					if ($r == will_beat ($b)) {
#print STDERR "$a PLUS cause $r $b\n";
						++$algorithms{$a}->{success}->[$i]->[$rev]->[$j];
					} elsif ($r != $b) {
#print STDERR "$a MINUS cause $r $b\n";
						--$algorithms{$a}->{success}->[$i]->[$rev]->[$j];
					}
				}
			}
		}
	}
}


###
### Low-level stuff
###

### Determine the next move and return it for output
#
sub out {
	return throw (choose ());
}

### Record the outcome of the last throw
#
sub in {
	my ($a, $b) = @_;

	grade ($b);

	unshift @history, [$a, $b];

	++$self_count[$a];
	++$opponent_count[$b];
}

### Init
#
foreach my $alg (keys %algorithms) {
	foreach my $n (@{$algorithms{$alg}->{values}}) {
		# One for normal, one for reverse mode
		# Each has 3 values for 0, 1, 2 ahead
		push @{$algorithms{$alg}->{success}}, [[0,0,0],[0,0,0]];
	}
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
	# Reset per-throw values
	throw_reset ();

	# Parse input
	last if /^done/i;
	print out (),"\n" and next if /^go/i;
	in ($1, $2) and next if /^outcome\s+([012])\s+([012])/i;
}
