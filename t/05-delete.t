#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Here we go.
use Data::Tab;

# First, let's build a really simple static table and play around with it.

my $table1 = Data::Tab->new ([ ['a', 'John', 'Lennon'],
                               ['b', 'Paul', 'McCartney'],
                               ['c', 'George', 'Harrison'],
                               ['d', 'Ringo', 'Starr'] ],
                             headers => ['num', 'first', 'last'],
                             hashkey => 'num',
                             primary => 'first' );

is ( $table1->indexed_get ('b'), 'Paul' );
is ( $table1->indexed_getmeta ('b', 'last'), 'McCartney');

my $row = $table1->take_row (2);
is_deeply ($row, ['c', 'George', 'Harrison']);
is ( $table1->indexed_get ('c'), undef);
is ( $table1->indexed_get ('b'), 'Paul' );

is_deeply ($table1->get_col ('first'), ['John', 'Paul', 'Ringo']);

done_testing();
