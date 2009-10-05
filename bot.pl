#!/usr/bin/perl

### ^_^

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


###
### Helper routines
###

### It's what you think it is
#
sub max {
	my $max = shift;
	$max < $_ and $max = $_ foreach (@_);
	return $max;
}

### And again
#
sub min {
	my $min = shift;
	$min > $_ and $min = $_ foreach (@_);
	return $min;
}

### Determine what hand beats a particular hand
#
sub will_beat {
	return ($_[0] + 1) % 3;
}

### Determine what hand loses to a particular hand
#
sub will_lose {
	return ($_[0] - 1) % 3;
}

### Return [012] for a random throw
#
sub random_throw {
	return int (rand (3));
}

### Compare two given histories
#
sub compare_history {
	my ($a, $b, $threshold) = @_;
	my ($unmatched, $total) = (0, min (scalar @{$a}, scalar @{$b}));
	for (my $i = 0; $i < $total; ++$i) {
		if ($a->[$i]->[YOUR] != $b->[$i]->[YOUR] ||
				$a->[$i]->[THEIR] != $b->[$i]->[THEIR]) {
			++$unmatched;
		}
		if ($unmatched / $total > $threshold) {
			return 0;
		}
	}
	return 1;
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

	my ($rev, $history_distance, $threshold) = @_;
	my $max_history = $history_distance < scalar @history ? $history_distance : scalar @history;

	my $match_last = 1;

	for (my $len = 1; 2 * $len <= $max_history; ++$len) {
		my $match;
		for (my $x = max ($match_last, $len); $len + $x <= $max_history; ++$x) {
			if (compare_history ([@history[0..$len-1]], [@history[$x..$x+$len-1]], $threshold)) {
				$match = $x;
				last;
			}
		}
		last if ! defined $match;
		$match_last = $match;
	}

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
		values	=> [[0, 0.001, 0.01]], # threshold
		success	=> [],
	},
	pattern		=> {
		code	=> \&alg_pattern,
		values	=> [[1, 5, 10, 25, 50, 100], # history_distance
					[0, 0.001, 0.01]], # threshold
		success	=> [],
	},
	random		=> {
		code	=> \&alg_random,
		values	=> [[0]],
		success	=> [],
		notest	=> 1,
	},
);

sub next_permutation {
	my ($alg, @cur) = @_;

	for (my $i = 0; $i < @{$algorithms{$alg}->{values}}; ++$i) {
		++$cur[$i];
		if ($cur[$i] < @{$algorithms{$alg}->{values}->[$i]}) {
			return @cur;
		} else {
			$cur[$i] = 0;
		}
	}

	return ();
}

sub do_permutation {
	my ($something, @permutation) = @_;

	for (my $i = 0; $i < @permutation; ++$i) {
		if (! defined $something->[$permutation[$i]]) {
			$something->[$permutation[$i]] = [];
		}
		$something = $something->[$permutation[$i]];
	}

	return $something;
}

### Choose best strategy
#
sub choose {
	my ($max_alg, $max_val, $max_rev, $max_ahd, $max_suc);
	foreach my $a (keys %algorithms) {
		my @permutation = (0) x @{$algorithms{$a}->{values}};
		do {
			my $permed_alg = do_permutation ($algorithms{$a}->{success}, @permutation);
			foreach my $rev (0, 1) {
				foreach my $ahd (0..2) {
#print STDERR join " ", ($a, @permutation, ($rev ? 'R' : ' '), $ahd, $permed_alg->[$rev]->[$ahd], "\n");
					if (! defined $max_suc || $permed_alg->[$rev]->[$ahd] > $max_suc) {
						($max_alg, $max_val, $max_rev, $max_ahd, $max_suc) =
							($a, [@permutation], $rev, $ahd, $permed_alg->[$rev]->[$ahd]);
					}
				}
			}
		} while (@permutation = next_permutation ($a, @permutation));
	}

#print STDERR "\tUsing $max_alg ", join (',' @{$max_val}), ($max_rev ? ' R ' : '   '), "$max_ahd\n";
	return ($max_alg, $max_val, $max_rev, $max_ahd);
}

### Return the result of throwing with the given parameters
#
sub throw {
	my ($alg, $val, $rev, $ahd) = @_;

	my @args;
	for (my $i = 0; $i < @{$val}; ++$i) {
		push @args, $algorithms{$alg}->{values}->[$i]->[$val->[$i]];
	}

	my $throw = $algorithms{$alg}->{code}->($rev, @args);

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
		my @permutation = (0) x @{$algorithms{$a}->{values}};
		do {
			my $permed_alg = do_permutation ($algorithms{$a}->{success}, @permutation);
			foreach my $rev (0, 1) {
				foreach my $ahd (0..2) {
					my $r = throw ($a, [@permutation], $rev, $ahd);
					if ($r == will_beat ($b)) {
#print STDERR "$a PLUS cause $r $b\n";
						++$permed_alg->[$rev]->[$ahd];
					} elsif ($r != $b) {
#print STDERR "$a MINUS cause $r $b\n";
						--$permed_alg->[$rev]->[$ahd];
					}
				}
			}
		} while (@permutation = next_permutation ($a, @permutation));
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
	my @permutation = (0) x @{$algorithms{$alg}->{values}};
	do {
		my $permed_alg = do_permutation ($algorithms{$alg}->{success}, @permutation);
		# One for normal, one for reverse mode
		# Each has 3 values for 0, 1, 2 ahead
		$permed_alg->[0] = [0,0,0];
		$permed_alg->[1] = [0,0,0];
	} while (@permutation = next_permutation ($alg, @permutation));
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
	# Parse input
	last if /^done/i;
	print out (),"\n" and next if /^go/i;
	in ($1, $2) and next if /^outcome\s+([012])\s+([012])/i;
}
