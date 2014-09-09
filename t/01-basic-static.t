#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

plan tests => 35;

# Here we go.
use Data::Tab;

# First, let's build a really simple static table and play around with it.

my $table1 = Data::Tab->new ([ [0, 1, 2, 3],
                                       [1, 2, 3, 4],
                                       [2, 3, 4, 5],
                                       [3, 4, 5, 6] ]);
                              
# Basic creation and access    
isa_ok ($table1, "Data::Tab");
is ($table1->get(0,0), 0);
is ($table1->get(1,1), 2);
is_deeply ($table1->get(0), [0, 1, 2, 3]);
is_deeply ($table1->get(2), [2, 3, 4, 5]);
is_deeply ($table1->get(undef, 1), [1, 2, 3, 4]);
is_deeply ($table1->get(undef, 3), [3, 4, 5, 6]);

# Iterator access and rewind
is_deeply ($table1->get(), [0, 1, 2, 3]);
is_deeply ($table1->get(), [1, 2, 3, 4]);
is_deeply ($table1->get(), [2, 3, 4, 5]);
is_deeply ($table1->get(), [3, 4, 5, 6]);
is ($table1->get(), undef);
$table1->rewind();
is_deeply ($table1->get(), [0, 1, 2, 3]);
is_deeply ($table1->get(), [1, 2, 3, 4]);

# Table presentation
is ($table1->show(), <<'EOF');
0 1 2 3
1 2 3 4
2 3 4 5
3 4 5 6
EOF

# Now add some headers.
$table1->headers('one', 'two', 'three', 'four');
is ($table1->show(),<<'EOF');
+---+---+-----+----+
|one|two|three|four|
+---+---+-----+----+
|0  |1  |2    |3   |
|1  |2  |3    |4   |
|2  |3  |4    |5   |
|3  |4  |5    |6   |
+---+---+-----+----+
EOF

is ($table1->show_generic('', 0, 0), <<'EOF');
0 1 2 3
1 2 3 4
2 3 4 5
3 4 5 6
EOF

is ($table1->show_generic('|', ['one', 'two', 'thr'], 0), <<'EOF');
|one|two|thr|
|0  |1  |2  |
|1  |2  |3  |
|2  |3  |4  |
|3  |4  |5  |
EOF

# Now an iterating table!  First, a pure iterator using a simple coderef - yes, this is an infinite repeater.
sub itergen {
   my $counter = 0;
   return sub { return $counter++; }
}
my $table2 = Data::Tab->new (itergen(), "result");
is_deeply ($table2->get(), [0]);
is_deeply ($table2->get(), [1]);
is_deeply ($table2->get(), [2]);
$table2->rewind();
is_deeply ($table2->get(), [3]);   # rewind has no effect on a non-buffered table.

# Now let's start buffering.
$table2->buffer();
is_deeply ($table2->get(), [4]);
is_deeply ($table2->get(), [5]);
$table2->rewind();
is_deeply ($table2->get(), [4]);   # rewind restarts from the start of the buffer.
is_deeply ($table2->get(), [5]);
is_deeply ($table2->get(), [6]);   # then it continues with the iterator after the buffer is exhausted.

# Now let's stop buffering.
$table2->unbuffer();
is_deeply ($table2->get(), [7]);
is_deeply ($table2->get(), [8]);
$table2->rewind();
is_deeply ($table2->get(), [9]);   # rewind has no effect again.

# Resume buffering, build a little buffer, then truncate.
$table2->buffer();
is_deeply ($table2->get(), [10]);
is_deeply ($table2->get(), [11]);
$table2->truncate();
$table2->rewind();
is_deeply ($table2->get(), [10]);
is_deeply ($table2->get(), [11]);
is ($table2->get(), undef);


