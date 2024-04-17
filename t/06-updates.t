#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Here we go.
use Data::Tab;

# First, let's build a really simple static table and play around with it.

my $table1 = Data::Tab->new ([ [0, 1, 2, 3],
                               [1, 2, 3, 4],
                               [2, 3, 4, 5],
                               [3, 4, 5, 6] ]);
                              
# Basic set methods
is ($table1->get ('f2', 1), 3);
$table1->set ('f2', 1, 2);
is ($table1->get ('f2', 1), 2);
$table1->set_xy (3, 1, 1);
is ($table1->get ('f3', 1), 1);
$table1->set_cell ("B2", 3);
is ($table1->get ('f1', 1), 3);

is_deeply ($table1->get_row (1), [1, 3, 2, 1]);

# Now the 
$table1 = Data::Tab->new ([ ['a', 'John', 'Lennon'],
                            ['b', 'Paul', 'McCartney'],
                            ['c', 'George', 'Harrison'],
                            ['d', 'Ringo', 'Starr'] ],
                             headers => ['num', 'first', 'last'],
                             hashkey => 'num',
                             primary => 'first' );

$table1->indexed_set ('b', 'Paula' );
$table1->indexed_setmeta ('b', 'last', 'McCarthy');

is_deeply ( $table1->indexed_getrow ('b'), ['b', 'Paula', 'McCarthy'] );


done_testing();
