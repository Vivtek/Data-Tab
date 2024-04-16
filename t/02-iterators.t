#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Let's test iterators.
use Data::Tab;

# First, let's build a really simple static table and play around with it.

my $table1 = Data::Tab->new ([ [0, 1, 2, 3],
                               [1, 2, 3, 4],
                               [2, 3, 4, 5],
                               [3, 4, 5, 6] ]);

my $iterator = $table1->iterate->iter;

is_deeply ($iterator->(), [0, 1, 2, 3]);
is_deeply ($iterator->(), [1, 2, 3, 4]);

$iterator = $table1->iterate (2, 3)->load;
is_deeply ($iterator, [ [2, 3, 4, 5], [3, 4, 5, 6] ]);

$iterator = $table1->iterate (2, 3, 0, 1)->load;
#diag Dumper ($iterator);
is_deeply ($iterator, [ [2, 3], [3, 4] ]);

$iterator = $table1->iterate ("B1:D1")->load;
is_deeply ($iterator, [ [1, 2, 3] ]);




done_testing();
