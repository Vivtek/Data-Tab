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
                              
# Basic creation and access    
isa_ok ($table1, "Data::Tab");
is ($table1->rows, 4);
is ($table1->cols, 4);
is_deeply ([ $table1->headers ], ['f0', 'f1', 'f2', 'f3']);
is_deeply ([ $table1->types   ], ['A',  'A',  'A',  'A' ]);
is_deeply ([ $table1->maxlen  ], [1, 1, 1, 1 ]);

is ($table1->get ('f2', 1), 3);
is ($table1->get_xy (1, 2), 3);
is ($table1->get_cell ("B1"), 1);

is_deeply ($table1->get_row (1), [1, 2, 3, 4]);
is_deeply ($table1->get_col ('f1'), [1, 2, 3, 4]);
is_deeply ($table1->get_col ('0'), [0, 1, 2, 3]);

#diag Dumper ($table1->get_slice (1, 2, 0, 2));
is_deeply ($table1->get_slice (1, 2, 0, 2), [[1, 2, 3], [2, 3, 4]]);
#diag Dumper ($table1->get_slice ("B1:C3"));
is_deeply ($table1->get_slice ("B1:C3"), [[1, 2], [2, 3], [3, 4]]);

# Let's make an empty table and add stuff by hand.
$table1 = Data::Tab->new ();
is ($table1->rows, 0);
is ($table1->cols, 0);

$table1->add_row (['this', 'that']);
is ($table1->rows, 1);
is ($table1->cols, 2);
is_deeply ([ $table1->headers ], ['f0', 'f1']);
is_deeply ([ $table1->types   ], ['A',  'A' ]);
is_deeply ([ $table1->maxlen  ], [4, 4]);

$table1->add_row (['other', 'thing']);
is ($table1->rows, 2);
is ($table1->cols, 2);
is_deeply ([ $table1->headers ], ['f0', 'f1']);
is_deeply ([ $table1->types   ], ['A',  'A' ]);
is_deeply ([ $table1->maxlen  ], [5, 5]);

is_deeply ([ $table1->multiline  ], [0, 0]);

$table1->add_row (['thing', <<EOF ]);
This is a longer
multilined text
value for testing.
EOF

is_deeply ([ $table1->multiline  ], [0, 1]);
is_deeply ([ $table1->maxlen     ], [5, 18]);  # Maxlen tracks the maximum line length for multilined values (it's for formatting the column).

done_testing();
