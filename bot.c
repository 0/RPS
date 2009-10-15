#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define beat(x)		"\x01\x02\x00"[(x)]
#define unbeat(x)	"\x02\x00\x01"[(x)]

#define max(x,y)	((x) > (y) ? (x) : (y))
#define min(x,y)	((x) < (y) ? (x) : (y))

#define throws		100000
#define algos_n		3
#define vals_n		10

#define choose(x,y,z,r,a)	(vals_n * vals_n * 2 * 3 * x + vals_n * 2 * 3 * y + 2 * 3 * z + 3 * r + a)


typedef struct {
	int (*fx)(int, int, int, int);
	int success[vals_n * vals_n * vals_n * 2 * 3];
} alg_t;


char in[100];

int t = 0;

unsigned int hands_a[3] = {0, 0, 0};
unsigned int hands_b[3] = {0, 0, 0};

unsigned int *history_a, *history_b;
alg_t algos[algos_n];

int best_alg = 0;
int best_x = 0, best_y = 0, best_z = 0;
int best_rev = 0, best_ahd = 0;


double alg_freq_t[]		= {0, 0.001, 0.01};
int alg_freq_i[]		= {0, 1};

int alg_pattern_d[]		= {1, 5, 10, 25, 50, 100, 1000, 10000, 50000, 100000};
double alg_pattern_t[]	= {0, 0.001, 0.01};
int alg_pattern_w[]		= {-1, 0, 1};


int random_throw () {
	return random () % 3;
}

int comp_hist (unsigned int a, unsigned int b, unsigned int len, double threshold, int which) {
	unsigned int i;
	double unmatched = 0;
	for (i = 0; i < len; ++i) {
		if ((which <= 0 && history_a[a+i] != history_a[b+i]) ||
				(which >= 0 && history_b[a+i] != history_b[b+i])) {
			++unmatched;
		}
		if (unmatched / len > threshold) {
			return 1;
		}
	}
	return 0;
}

int min_freq (unsigned int *hands, double threshold) {
	unsigned int i;
	double min = min (min (hands[0], hands[1]), hands[2]);

	for (i = 0; i < 3; ++i) {
		if (0 == min || abs (min - hands[i]) / min <= threshold) {
			return i;
		}
	}
	return random_throw ();
}

int max_freq (unsigned int *hands, double threshold) {
	unsigned int i;
	double max = max (max (hands[0], hands[1]), hands[2]);

	for (i = 0; i < 3; ++i) {
		if (0 == max || abs (max - hands[i]) / max <= threshold) {
			return i;
		}
	}
	return random_throw ();
}


int alg_freq (int t_x, int i_x, int xyzzz, int rev) {
	if (t_x >= 3 || i_x >= 2 || xyzzz)
		return -1;

	int ret;

	if (alg_freq_i[i_x]) {
		if (rev) {
			ret = min_freq (hands_a, alg_freq_t[t_x]);
		} else {
			ret = min_freq (hands_b, alg_freq_t[t_x]);
		}
	} else {
		if (rev) {
			ret = max_freq (hands_a, alg_freq_t[t_x]);
		} else {
			ret = max_freq (hands_b, alg_freq_t[t_x]);
		}
	}

	return beat (ret);
}

int alg_pattern (int d_x, int t_x, int w_x, int rev) {
	if (d_x >= 10 || t_x >= 3 || w_x >= 3)
		return -1;

	unsigned int max, len, last = 1;

	int ret;

	max = min (alg_pattern_d[d_x], t);

	for (len = 1; 2 * len <= max; ++len) {
		unsigned int x, match = 0;
		for (x = max (last, len); len + x <= max; ++x) {
			if (0 == comp_hist (0, x, len, alg_pattern_t[t_x], alg_pattern_w[w_x])) {
				match = x;
				break;
			}
		}
		if (! match)
			break;
		last = match;
	}

	if (rev)
		ret = history_a[last - 1];
	else
		ret = history_b[last - 1];

	return beat (ret);
}

int alg_random (int xyzzx, int xyzzy, int xyzzz, int rev) {
	if (xyzzx || xyzzy || xyzzz || rev)
		return -1;
	return random_throw ();
}


int throw (int alg, int x, int y, int z, int rev, int ahd) {
	int a = algos[alg].fx (x, y, z, rev);

	if (0 == ahd)
		a = beat (a);
	else if (2 == ahd)
		a = unbeat (a);

	if (rev)
		a = beat (a);

	return a;
}


void alloc_fail_die () {
	if (NULL == history_a || NULL == history_b) {
		fprintf (stderr, "I NEED MEMORY!!!\n");
		exit (1);
	}
}

void grade (int b) {
	int i, j, k, l;
	int rev, ahd;

	best_alg = best_x = best_y = best_z = best_rev = best_ahd = 0;
	int best_suc;
	int best_suc_undef = 1;

	for (i = 0; i < algos_n; ++i) {
		for (j = 0; j < vals_n; ++j) {
			for (k = 0; k < vals_n; ++k) {
				for (l = 0; l < vals_n; ++l) {
					for (rev = 0; rev < 2; ++rev) {
						for (ahd = 0; ahd < 3; ++ahd) {
							int ret = throw (i, j, k, l, rev, ahd);
							int* suc = algos[i].success + choose (j, k, l, rev, ahd);
							if (ret >= 0) {
								if (ret == beat (b)) {
									*(suc) += 1;
								} else if (b == beat (ret)) {
									*(suc) -= 1;
								}
							}
							if (best_suc_undef || *(suc) > best_suc) {
								best_suc_undef = 0;
								best_alg = i;
								best_x = j;
								best_y = k;
								best_z = l;
								best_rev = rev;
								best_ahd = ahd;
								best_suc = *(suc);
							}
						}
					}
				}
			}
		}
	}
}

int fire () {
	if (0 == t)
		return random_throw ();

	return throw (best_alg, best_x, best_y, best_z, best_rev, best_ahd);
}

int main () {
	int a, b;
	int i, j, k, l;
	int rev, ahd;

	srand (time (0));
	setvbuf (stdin, NULL, _IONBF, 0);
	setvbuf (stdout, NULL, _IONBF, 0);

	history_a = calloc (throws + 1, sizeof (*history_a));
	history_b = calloc (throws + 1, sizeof (*history_b));

	alloc_fail_die ();

	algos[0].fx = &alg_freq;
	algos[1].fx = &alg_pattern;
	algos[2].fx = &alg_random;

	for (i = 0; i < algos_n; ++i) {
		for (j = 0; j < vals_n; ++j) {
			for (k = 0; k < vals_n; ++k) {
				for (l = 0; l < vals_n; ++l) {
					for (rev = 0; rev < 2; ++rev) {
						for (ahd = 0; ahd < 3; ++ahd) {
							*(algos[i].success + choose (j, k, l, rev, ahd)) = 0;
						}
					}
				}
			}
		}
	}

	while (NULL != fgets (in, sizeof (in), stdin)) {
		if (0 == strncmp (in, "d", 1)) {
			break;
		} else if (0 == strncmp (in, "g", 1)) {
			printf ("%d\n", fire());
		} else if (0 == strncmp (in, "o", 1)) {
			in[9] = in[11] = 0;
			a = atoi (&in[8]);
			b = atoi (&in[10]);

			grade (b);

			memmove (history_a + 1, history_a, throws * sizeof(*history_a));
			memmove (history_b + 1, history_b, throws * sizeof(*history_b));
			alloc_fail_die ();

			history_a[0] = a;
			history_b[0] = b;

			++hands_a[a];
			++hands_b[b];

			if (t < throws) {
				++t;
			}
		}
	}

	free (history_a);
	free (history_b);
	history_a = NULL;
	history_b = NULL;

	return 0;
}
