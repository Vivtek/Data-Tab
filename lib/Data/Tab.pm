package Data::Tab;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Iterator::Records;
use List::MoreUtils qw(first_index);
use Module::Load 'none';
use Carp;
use Data::Dumper;

=head1 NAME

Data::Tab - Tables for the Decl data ecosystem

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';


=head1 SYNOPSIS

The primary purpose of C<Data::Tab> is to provide a tabular buffer for record streams produced by L<Iterator::Records>, but it can be used for
any other tabular data as well. The datatab is more akin to a dataframe than to a relational table; its rows are ordered and can optionally
be named with unique key values. It can, however, be used as the underlying storage structure for an SQLite instance to get the best of both
worlds.

=head1 CREATING A DATATAB

A datatab can be created whole cloth, but is probably more frequently going to be created by loading a record stream.

=head2 new (parameters)

Parameters come in a hashref, with the following keys available:

 key           purpose
 ---           -------
 data          either an arrayref of arrayrefs, an Iterator::Records factory, or a coderef that returns arrayrefs
 headers       an arrayref of field names; if the data is an itrecs factory and "headers" is not specified, it will be taken from the itrecs
 types         an arrayref of type names; same caveat for itrecs factories. A type of "9" or "num" will be treated as numeric for comparisons
 sort          a sort specification; see sort()
 aggregates    an aggregate specification; see aggregate()
 hashkey       the name of the field to be used as the key, if this is a hashtab
 primary       the name of the primary value field, if this is a hashtab
 

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    
    # Read the first parm as input data if it's not a string (and thus a key)
    my $data;
    if (scalar @_ and ref $_[0]) {
       $data = shift;
    }

    while (@_) {
       my $parm = shift;
       last unless @_;
       my $value = shift;
       if ($parm eq 'headers' and ref $value eq 'ARRAY') {
          $self->set_headers(@$value);
       } else {
          $self->{$parm} = $value;
       }
    }
    
    if ($self->{hashkey}) {
       $self->{hashtab} = {};
    }
    
    if (defined $data) {
       my $type = ref($data);
       if ($type eq 'ARRAY') {
          $data = Iterator::Records->new ($data);
       } else { # Blithely assume it's an itrecs.
          croak "data is not an arrayref or a record stream" unless $data->can('fields') and $data->can('iter');
          $self->{data_source} = $data;
          $self->{headers} = [ $data->fields ];
          $self->{types}   = [ $data->types ] if $data->can('types');
       }
       $self->load($data);
    } else {
       $self->{dim} = [0, 0];
    }
    
    $self;
}

=head2 load (datasource)

Loads records from the datasource, which should be compatible in terms of number of columns. This same method is called by ->new.

=cut

sub load {
   my ($self, $data) = @_;

   my $iter = $data->iter;
   $self->{data} = undef;
   $self->{hashkeycol} = undef;
   $self->{primarycol} = undef;
   while (my $record = $iter->()) {
      $self->add_row ($record);
   }
   
   $self;
}

=head2 add_row (arrayref of data)

This handles actually adding a row of data to the table. If it's the first row ever added, we'll do some recordkeeping (coming up with a header if one isn't already defined, etc.)

=cut

sub add_row {
   my ($self, $record) = @_;
   croak 'null record' unless defined $record;
   croak 'record not array' unless ref $record eq 'ARRAY';
   
   if (not defined $self->{data}) {
      $self->{data} = [];
      unless (defined $self->{headers}) {
         $self->set_headers( map { "f$_" } ( 0 .. scalar(@$record)-1 ) );
      }
      if (defined $self->{dim}) {
         $self->{dim}->[1] = scalar @{$self->{headers}} unless $self->{dim}->[1];
      } else {
         $self->{dim} = [ 0, scalar @{$self->{headers}} ];
      }
      unless (defined $self->{types}) {
         $self->{types} = [ map {'A'} ( 0 .. scalar @{$self->{headers}}-1 ) ];
      }
      unless (defined $self->{maxlen}) {
         $self->{maxlen} = [ map {0} ( 0 .. scalar @{$self->{headers}}-1 ) ];
      }
      unless (defined $self->{multiline}) {
         $self->{multiline} = [ map {0} ( 0 .. scalar @{$self->{headers}}-1 ) ];
      }
   }

   $self->{dim}->[0] += 1;
   for (my $i=0; $i<@$record; $i++) {
      $record->[$i] = '' unless defined $record->[$i];
      if ($record->[$i] =~ /\n/) {
         $self->{multiline}->[$i] = 1;
         foreach my $line (split /\n/, $record->[$i]) {
            $self->{maxlen}->[$i] = length($line) if length($line) > $self->{maxlen}->[$i];
         }
      } else {
         $self->{maxlen}->[$i] = length($record->[$i]) if not defined $self->{maxlen}->[$i] or length($record->[$i]) > $self->{maxlen}->[$i];
      }
   }
   push @{$self->{data}}, $record;
   if ($self->{hashkey}) {
      $self->{hashkeycol} = first_index {$_ eq $self->{hashkey}} @{$self->{headers}} unless defined $self->{hashkeycol};
      $self->{primarycol} = first_index {$_ eq $self->{primary}} @{$self->{headers}} unless defined $self->{primarycol};
      
      #$self->{hashtab}->{$record->[$self->{hashkeycol}]} = scalar @{$self->{data}} - 1;
      $self->{hashtab}->{$record->[$self->{hashkeycol}]} = $record;
   }
}

=head1 CREATING A DATATAB FROM A CATALOG DEFINITION

We can also accept a Decl-notation definition of the table from a L<Data::Catalog> object.

=head2 catalog (catalog, name, tag, type, id, lno, node)

This is called by the catalog with the initial definition; we just build an appropriate catalog entry and return it. This is actually a class method;
the catalog doesn't build a Data::Tab object until activation.

=cut

sub catalog {
   my ($class, $catalog, $name, $tag, $type, $id, $lno, $node) = @_;
   my $ref = $node->getp ('ref') || '';
   $catalog->add_entry ([$name, $tag, $type, '', $ref, $id, $lno, $node]) if $name;
}

=head2 activate (definition)

The C<definition> method is a catalog-specific table loader, but we'll also accept a node by itself. This allows us to load tables quickly even if we don't have
a catalog in the mix. If this method is given a string, it will just parse it as a single node. If L<Decl::Node> isn't installed, then this will just fail, but
in that case all of this will fail.

Any Decl node passed in must have its content in the DeclTable format parsed by L<Iterator::Records::DataTable>. Metadata for the table (the hashkey and primary values,
especially) are expected to be provided as parameters on the node. There might be more data later, depending on use cases.

=cut

sub activate {
   my ($class, $definition) = @_;
   
   if (not ref $definition) {
      Module::Load->load ("Decl::Node") || croak "Decl::Node not installed";
      $definition = Decl::Node->make_node ($definition);
   }
   if (ref $definition eq 'Decl::Node') {
      $definition = { node => $definition };
      $definition->{name} = $definition->{node}->name;
      $definition->{tag} = $definition->{node}->tag;
   }
   
   Module::Load->load ("Iterator::Records::DeclTable");
   #eval { use Iterator::Records::DeclTable; 1 };
   #croak "Iterator::Records::DeclTable not installed: $@" if $@;
   my $iterator = Iterator::Records::DeclTable->new ($definition->{node});
   
   my $datatab = $class->new ($iterator);
   $datatab->{decl} = $definition->{node};
   $datatab;
}

=head1 BASIC PARAMETER ACCESS

Once loaded, the table can report various parameters about its data

=head2 headers, types, maxlen, rows, cols, dim, multiline

=cut

sub rows      { $_[0]->{dim}->[0] }
sub cols      { $_[0]->{dim}->[1] }
sub dim       { $_[0]->{dim} }
sub headers   { @{$_[0]->{headers}} }
sub types     { @{$_[0]->{types}} }
sub maxlen    { @{$_[0]->{maxlen}} }
sub multiline { @{$_[0]->{multiline}} }

=head2 set_headers

=cut

sub set_headers {
   my $self = shift;
   $self->{headers} = [ @_ ];
   foreach (my $i = 0; $i < scalar (@_); $i++) {
      $self->{hdr_idx}->{$_[$i]} = $i;
   }
}

=head2 can_reload, reload

If the table was originally loaded from a record iterator, it can re-initiate the iterator to reload data. Check C<can_reload> if you're not sure whether it can.

=cut

sub can_reload { defined ($_[0]->{data_source}) }

=head1 GETTING DATA

Data can be retrieved in a number of different ways, basically single elements as scalars (or, well, whatever they are), rows and columns as lists, iterators
over all or part of the content, or a segment of the table as an arrayref of arrayrefs or as a new Data::Tab.

=head2 get (field, row)

By default, we use field names (column names) for column access, plus a numeric row starting with 0.

=cut

sub get {
   my ($self, $col, $row) = @_;
   croak 'table has no headers' unless $self->{headers};
   my $colnum = first_index {$_ eq $col} @{$self->{headers}};
   croak "table does not have field $col" unless defined $colnum;
   $self->get_xy ($colnum, $row);
}

=head2 get_xy (col, row)

For numeric access, use C<get_xy>, which takes the column number.

=cut

sub get_xy {
   my ($self, $col, $row) = @_;
   return undef unless defined $self->{data};
   return undef unless defined $self->{data}->[$row];
   return $self->{data}->[$row]->[$col];
}

=head2 get_cell (excel_cell_name)

Excel-style cell names are also supported, e.g. "B2".

=cut

sub get_cell {
   my ($self, $cell) = @_;
   croak "badly formed cell name $cell" unless $cell =~ /^([A-Za-z]+)(\d+)$/;
   $self->get_xy (_b26_to_b10 ($1)-1, $2-1);
}
sub _b26_to_b10 {  # Credit to Christopher E. Stith, https://www.perlmonks.org/?node_id=270361
   my @digits = reverse split //, shift;
   my $i = 1;
   my $result = 0;
   for ( @digits ) {
       $result += ( ord(lc($_)) - ord('a') + 1 ) * $i;
       $i *= 26;
   }
   return $result;
}

=head2 get_row (row number), get_col (field name or column number)

We can get arrayrefs back for any row or column in the table. For column references, we can either use the field name or a numeric column offset.

=cut

sub get_row {
   my ($self, $row) = @_;
   return undef unless defined $self->{data};
   return $self->{data}->[$row];
}

sub get_col {
   my ($self, $col) = @_;
   return undef unless defined $self->{data};
   if ($col =~ /[^0-9]/) {
      croak 'table has no headers' unless $self->{headers};
      my $idx = $self->{hdr_idx}->{$col};
      croak "no such field '$col'" unless defined $idx;
      $col = $idx;
   }
   my @vals = map {$_->[$col]} @{$self->{data}};
   return \@vals;
}

=head2 get_slice (from_row, to_row, from_col, to_col) or get_slice (excel cell range)

To get a subtable (an arrayref of arrayrefs) we can either use the coordinates of the corners, or specify it with an Excel cell range of the form A2:C6.

=cut

sub get_slice {
   my $self = shift;
   my ($row_from, $row_to, $col_from, $col_to);
   if (scalar(@_) == 1) {
      my ($from, $to) = split /:/, shift;
      croak 'cell range malformed' unless defined $to;
      croak "badly formed cell name $from" unless $from =~ /^([A-Za-z]+)(\d+)$/;
      ($col_from, $row_from) = (_b26_to_b10 ($1)-1, $2-1);
      croak "badly formed cell name $to" unless $to =~ /^([A-Za-z]+)(\d+)$/;
      ($col_to, $row_to) = (_b26_to_b10 ($1)-1, $2-1);
   } else {
      ($row_from, $row_to, $col_from, $col_to) = @_;
      $row_from = 0 unless defined $row_from;
      $row_to   = $self->rows() - 1 unless defined $row_to;
      $col_from = 0 unless defined $col_from;
      $col_to   = scalar ($self->headers) - 1 unless defined $col_to;
   }
   
   my @rows = map {
      [ @$_[ $col_from .. $col_to ] ]
   } @{$self->{data}} [ $row_from .. $row_to ];
   return \@rows;
}

=head2 take_row (row)

Especially if the table is being used for a queue, you can get a row and remove it from the table in a single step, by row number.

=cut

sub take_row {
   my ($self, $rownum) = @_;
   
   my $row = splice (@{$self->{data}}, $rownum, 1);
   if (defined $self->{hashtab} and defined $row) {
      delete $self->{hashtab}->{$row->[$self->{hashkeycol}]};
   }
   $row;
}


=head1 GETTING DATA BY INDEX

If the datatab is a hashtab (if it has a hashkey column identified), then it maintains a hashref from the value of the hashkey column to the record.
A hashtab can thus be used for efficient key-value lookup for anything in the table; it's effectively a way to name each row for retrieval.

=head2 indexed_get (key), indexed_getmeta (key, column)

The C<indexed_getmeta> method retrieves a named column from the row named by the key (it's basically C<get_xy> with named rows and columns). If you've defined a primary
column (by specifying a C<primary> parameter) you can also use C<indexed_get> to retrieve that primary value.

=cut

sub indexed_get {
   my $self = shift;
   croak 'no primary value defined' unless defined $self->{primary};
   $self->indexed_getmeta (shift, $self->{primary});
}
sub indexed_getmeta {
   my ($self, $key, $column) = @_;
   croak 'not a hashtab' unless defined $self->{hashtab};
   return unless defined $self->{hashtab}->{$key};   # 2022-09-06 - "defined" because a key of 0 is legit. I'll keep making this mistake for eternity, apparently.
   my $idx = $self->{hdr_idx}->{$column};
   croak "no such field '$column'" unless defined $idx;
   #$self->get_xy ($idx, $self->{hashtab}->{$key});
   return $self->{hashtab}->{$key}->[$idx];
}

=head2 indexed_getrow (key), indexed_getrowhash (key)

Get the entire row indexed by C<key>, either in its native arrayref form or in a hashref form keyed by the field names.

=cut

sub indexed_getrow {
   my ($self, $key) = @_;
   croak 'not a hashtab' unless defined $self->{hashtab};
   #return $self->{data}->[$self->{hashtab}->{$key}];
   return $self->{hashtab}->{$key};
}
sub indexed_getrowhash {
   my ($self, $key) = @_;
   my $row = $self->indexed_getrow ($key);
   return unless $row;
   my $ret = {};
   for (my $i = 0; $i < scalar (@{$self->{headers}}); $i++) {
      $ret->{$self->{headers}->[$i]} = $row->[$i];
   }
   return $ret;
}



=head1 ITERATING OVER DATA

A common use I have for datatabs is as a buffer for record streams - a place to put them, sort them, slice and dice them, and then get a record stream back
out. This is where we do that.

=head2 iterate or iterate (row_from, row_to) or iterate (row_from, row_to, col_from, col_to) or iterate (excel_slice)

The C<iterate> method either iterates over the entire table contents or over a subtable using the same semantics as the C<get_slice> method.

=cut

sub iterate {
   my $self = shift;
   
   if (not scalar @_) {   # Non-restricted iterator, dead easy
      return Iterator::Records->new ( sub {
         my $i = 0;
         sub {
            return unless defined $self->{data};
            $i += 1;
            return if $i > scalar @{$self->{data}};
            return $self->{data}->[$i-1];
         }
      }, [ $self->headers ]);
   }

   my ($row_from, $row_to, $col_from, $col_to);
   if (scalar(@_) == 1) {
      my ($from, $to) = split /:/, shift;
      croak 'cell range malformed' unless defined $to;
      croak "badly formed cell name $from" unless $from =~ /^([A-Za-z]+)(\d+)$/;
      ($col_from, $row_from) = (_b26_to_b10 ($1)-1, $2-1);
      croak "badly formed cell name $to" unless $to =~ /^([A-Za-z]+)(\d+)$/;
      ($col_to, $row_to) = (_b26_to_b10 ($1)-1, $2-1);
   } else {
      ($row_from, $row_to, $col_from, $col_to) = @_;
      $row_from = 0 unless defined $row_from;
      $row_to   = $self->rows() - 1 unless defined $row_to;
      $col_from = 0 unless defined $col_from;
      $col_to   = scalar ($self->headers) - 1 unless defined $col_to;
   }

   my @headers = $self->headers;
   @headers = @headers[$col_from .. $col_to];
      
   return Iterator::Records->new ( sub {
      my $i = $row_from;
      sub {
         return unless defined $self->{data};
         return if $i > $row_to;
         $i += 1;
         return if $i > scalar @{$self->{data}};

         my @data = @{$self->{data}->[$i-1]};
         return [ @data[ $col_from .. $col_to ] ];
      }
   }, \@headers);
   
}

=head1 DISPLAYING TABULAR DATA

This section is here for historical reasons, but should be considered deprecated. Once I've written Iterator::Records::Write::DeclTab, it will be rewritten.

=head2 show, show_decl, show_generic

Calling C<show> returns the table as text, with C<+-----+> type delineation.  (This method only works if
Text::Table is installed.)  This only shows the rows actually in the buffer; it will not retrieve iterator
rows; this allows you to set up a paged display.

The column delimiters only appear for a table with headers; this is because Text::Table is easier to
use this way - but think of a table with headers as a database table, and one without as a simple
matrix.

The C<show> method is actually implemented using C<show_generic>, which takes as parameters the separator, a flag
whether the headers should be shown (if the 'flag' is an arrayref, you can simply specify your own headers here),
and a flag whether a rule should be shown at the top and bottom of the table and between the header and body - by 
default, this rule is of the form +----+----+, but again, the 'flag' can be an arrayref of any two other characters
to be used instead (in the order '-' and '+' in the example).

The C<show> method is thus C<show_generic('|', 1, 1)>.

Unfortunately, C<show_generic> isn't generic enough to express an HTML table, and I considered putting a show_html
method here as well (L<Data::Table> has one) - but honestly, it's rare to use undecorated HTML these days, so I
elected to remove temptation from your path.  To generate HTML, you should use a template engine to generate
I<good> HTML.  Eventually I'll write one that works with Data::Tab out of the box - drop me a line if you'd like me
to accelerate that.

For use in Decl-embedded quotes, I use "tabulated" data, which simply uses the field names to align the fields on
individual rows. This is actually dead easy to generate in this generic framework, so it's implemented here.

=cut

sub show { shift->show_generic ('|', 1, 1); }
sub show_decl { shift->show_generic ('', 1, 0); }
sub show_generic {
   eval { require Text::Table; };
   croak "Text::Table not installed" if $@;

   my $self = shift;
   return '' unless defined $self->{data};
   my $sep = shift;
   my $headers = shift;
   my $rule = shift;
   
   my @headers = ();
   if ($headers) {
      if (ref $headers eq 'ARRAY') {
         @headers = @$headers;
      } else {
         @headers = $self->headers;
      }
   }
   my @c = ();
   if (defined $sep and @headers) {
      push @c, \$sep if defined $sep;
      foreach my $h (@headers) {
         push @c, $h, \$sep;
      }
   }
   my $t = Text::Table->new($sep ? @c : @headers);
   $t->load (@{$self->{data}});
   
   my @rule_p = ('-', '+');
   @rule_p = @$rule if $rule and ref $rule eq 'ARRAY';
   my $rule_text = '';
   $rule_text = $t->rule(@rule_p) if @headers and $rule;

   my $text = '';
   $text .= $rule_text;
   $text .= $t->title() if @headers;
   $text .= $rule_text;
   $text .= $t->body();
   $text .= $rule_text;
   return $text;
}

=head2 report (not yet implemented)

The C<report> method is a little different from C<show> - it's essentially good for formatting things with a sprintf
and suppressing repeat values, making it useful for simple presentation of things like dated entries (the date appears
only when it changes).  I use this kind of thing a lot in my everyday utilities, so it's convenient to bundle it
here in generalized form.

=cut

sub report {
}


=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Data-Tab at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Tab>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Tab


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Tab>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Tab>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Tab>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Tab/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Michael Roberts.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Data::Tab
