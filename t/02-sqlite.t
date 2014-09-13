#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

plan tests => 4;

# Here we go.
use Data::Tab;

my $dbh;
eval { use DBI; $dbh = DBI->connect('dbi:SQLite:dbname=t/test.sqlt'); };
SKIP: {
    skip "SQLite does not appear to be installed; not testing SQLite integration", 4 if $@;
    my $query1 = Data::Tab->query ($dbh, "select * from my_table");
    is ($query1->read->show, <<'EOF');
+-------+-------+
|name   |points |
+-------+-------+
|Michael|1000000|
|Bob    |  40324|
|George | 789723|
+-------+-------+
EOF

    is (Data::Tab->query ($dbh, "select * from my_table where points>?", 100000)->read->show, <<'EOF');
+-------+-------+
|name   |points |
+-------+-------+
|Michael|1000000|
|George | 789723|
+-------+-------+
EOF

    is (Data::Tab->query ($dbh, "select sum(points) from my_table")->read->get(0, 0), 1830047);
    
    my $db = Data::Tab::db->connect('dbi:SQLite:dbname=t/test.sqlt');
    is ($db->query ("select * from my_table")->read->show, <<'EOF');
+-------+-------+
|name   |points |
+-------+-------+
|Michael|1000000|
|Bob    |  40324|
|George | 789723|
+-------+-------+
EOF

}