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

is_deeply ( $table1->indexed_getrow ('c'), ['c', 'George', 'Harrison'] );
is_deeply ( $table1->indexed_getrowhash ('c'), { num => 'c', first => 'George', last => 'Harrison' } );

# 2025-06-07 - let's try setting a value - which means setting a value and then its meta values
$table1->indexed_set_or_add ('e', 'Steve');
is_deeply ( $table1->indexed_getrow ('e'), ['e', 'Steve'] );
$table1->indexed_setmeta ('e', 'last', 'Stevenson');
is_deeply ( $table1->indexed_getrow ('e'), ['e', 'Steve', 'Stevenson'] );

done_testing();
