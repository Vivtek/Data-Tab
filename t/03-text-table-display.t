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
                              
# Table presentation
is ($table1->show(),<<'EOF');
+--+--+--+--+
|f0|f1|f2|f3|
+--+--+--+--+
|0 |1 |2 |3 |
|1 |2 |3 |4 |
|2 |3 |4 |5 |
|3 |4 |5 |6 |
+--+--+--+--+
EOF

# Now replace the default headers.
$table1->set_headers('one', 'two', 'three', 'four');

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

done_testing();
