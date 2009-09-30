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

# The maximum deviation from the max to be considered.
my $freq_threshold = 0.1;

#### Algorithms:

sub alg_freq {
	# Frequency analysis of opponent's throws.
	my $max = max (@opponent_count);
	my @pool;
	foreach my $a (ROCK, PAPER, SCISSORS) {
		push @pool, $a if $max == 0 || abs ($opponent_count[$a] - $max) / $max < $freq_threshold;
	}
	return will_beat($pool[int (@pool * rand)]);
}

sub random {
	return int (3 * rand ());
}

my %algorithms = (
	alg_freq	=> {
		code	=> \&alg_freq,
		success	=> 0,
	},
	random		=> {
		code	=> \&random,
		success	=> 0,
	}
);

### iO
## Uses the history to determine the next move
#
sub out {
	my ($max_a, $max_v);
	foreach my $a (keys %algorithms) {
#print STDERR join " ", ($a, $algorithms{$a}->{success}, "\n");
		($max_a, $max_v) = ($a, $algorithms{$a}->{success}) if ! defined $max_v || $algorithms{$a}->{success} > $max_v;
	}
#print STDERR "\tUsing $max_a\n";
	return &{$algorithms{$max_a}->{code}};
}

### Io
## Takes the outcome of the last throw and records it
## Args: my move; opponent's move; outcome ([wdl])
#
sub in {
	my ($a, $b, $r) = @_;

	# Grade how the algorithms would have performed
	foreach my $alg (keys %algorithms) {
		my $r = &{$algorithms{$alg}->{code}};
		if ($r == will_beat ($b)) {
#print STDERR "$a PLUS cause $r $b\n";
			++$algorithms{$alg}->{success};
		} elsif ($r != $b) {
#print STDERR "$a MINUS cause $r $b\n";
			--$algorithms{$alg}->{success};
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
	in ($1, $2, $3) and next if /^outcome\s+([012])\s+([012])\s+([wdl])/i;
}
