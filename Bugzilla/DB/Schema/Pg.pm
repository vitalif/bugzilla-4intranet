# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::DB::Schema::Pg;

###############################################################################
#
# DB::Schema implementation for PostgreSQL
#
###############################################################################

use strict;
use base qw(Bugzilla::DB::Schema);
use Storable qw(dclone);

#------------------------------------------------------------------------------
sub _initialize {

    my $self = shift;

    $self = $self->SUPER::_initialize(@_);

    $self->{db_specific} = {

        BOOLEAN =>      'smallint',
        FALSE =>        '0', 
        TRUE =>         '1',

        INT1 =>         'integer',
        INT2 =>         'integer',
        INT3 =>         'integer',
        INT4 =>         'integer',

        SMALLSERIAL =>  'serial unique',
        MEDIUMSERIAL => 'serial unique',
        INTSERIAL =>    'serial unique',

        TINYTEXT =>     'varchar(255)',
        MEDIUMTEXT =>   'text',
        LONGTEXT =>     'text',

        LONGBLOB =>     'bytea',

        DATETIME =>     'timestamp(0) without time zone',

    };

    $self->_adjust_schema;

    return $self;

} #eosub--_initialize
#--------------------------------------------------------------------

sub _get_create_table_ddl
{
    my ($self, $table) = @_;

    my $thash = $self->{schema}{$table};
    die "Table $table does not exist in the database schema."
        unless ref $thash;

    # Find fulltext fields
    my %is_ft;
    for (my $i = 1; $i < @{$thash->{INDEXES}}; $i += 2)
    {
        if ($thash->{INDEXES}->[$i]->{TYPE} eq 'FULLTEXT')
        {
            $is_ft{$_} = 1 for @{$thash->{INDEXES}->[$i]->{FIELDS}};
        }
    }

    my $create_table = "CREATE TABLE $table \(\n";

    my @fields = @{ $thash->{FIELDS} };
    while (@fields)
    {
        my $field = shift @fields;
        my $finfo = shift @fields;
        $create_table .= "\t$field\t";
        if ($is_ft{$field})
        {
            # Don't store the contents of fulltext fields in PostgreSQL,
            # just store the real tsvector's. This allows optimal performance
            # while ranking results.
            $create_table .= 'tsvector';
        }
        else
        {
            $create_table .= $self->get_type_ddl($finfo);
        }
        $create_table .= "," if @fields;
        $create_table .= "\n";
    }

    $create_table .= "\)";

    return $create_table;
}

sub _get_create_index_ddl
{
    my $self = shift;
    my ($table, $name, $index_fields, $index_type) = @_;
    if ($index_type && $index_type eq 'FULLTEXT')
    {
        # Override fulltext index creation clause
        $index_fields = join(" || ", @$index_fields);
        return "CREATE INDEX $name ON $table USING gin($index_fields)";
    }
    return $self->SUPER::_get_create_index_ddl(@_);
}

sub get_rename_column_ddl {
    my ($self, $table, $old_name, $new_name) = @_;
    if (lc($old_name) eq lc($new_name)) {
        # if the only change is a case change, return an empty list, since Pg
        # is case-insensitive and will return an error about a duplicate name
        return ();
    }
    my @sql = ("ALTER TABLE $table RENAME COLUMN $old_name TO $new_name");
    my $def = $self->get_column_abstract($table, $old_name);
    if ($def->{TYPE} =~ /SERIAL/i) {
        # We have to rename the series also.
        push(@sql, "ALTER SEQUENCE ${table}_${old_name}_seq 
                         RENAME TO ${table}_${new_name}_seq");
    }
    return @sql;
}

sub get_rename_table_sql {
    my ($self, $old_name, $new_name) = @_;
    if (lc($old_name) eq lc($new_name)) {
        # if the only change is a case change, return an empty list, since Pg
        # is case-insensitive and will return an error about a duplicate name
        return ();
    }

    my @sql = ("ALTER TABLE $old_name RENAME TO $new_name");

    # If there's a SERIAL column on this table, we also need to rename the
    # sequence.
    # If there is a PRIMARY KEY, we need to rename it too.
    my @columns = $self->get_table_columns($old_name);
    foreach my $column (@columns) {
        my $def = $self->get_column_abstract($old_name, $column);
        if ($def->{TYPE} =~ /SERIAL/i) {
            my $old_seq = "${old_name}_${column}_seq";
            my $new_seq = "${new_name}_${column}_seq";
            push(@sql, "ALTER SEQUENCE $old_seq RENAME TO $new_seq");
            push(@sql, "ALTER TABLE $new_name ALTER COLUMN $column
                             SET DEFAULT NEXTVAL('$new_seq')");
        }
        if ($def->{PRIMARYKEY}) {
            my $old_pk = "${old_name}_pkey";
            my $new_pk = "${new_name}_pkey";
            push(@sql, "ALTER INDEX $old_pk RENAME to $new_pk");
        }
    }

    return @sql;
}

sub get_set_serial_sql {
    my ($self, $table, $column, $value) = @_;
    return ("SELECT setval('${table}_${column}_seq', $value, false)
               FROM $table");
}

sub _get_alter_type_sql {
    my ($self, $table, $column, $new_def, $old_def) = @_;
    my @statements;

    my $type = $new_def->{TYPE};
    $type = $self->{db_specific}->{$type} 
        if exists $self->{db_specific}->{$type};

    if ($type =~ /serial/i && $old_def->{TYPE} !~ /serial/i) {
        die("You cannot specify a DEFAULT on a SERIAL-type column.") 
            if $new_def->{DEFAULT};
    }

    $type =~ s/\bserial\b/integer/i;

    # On Pg, you don't need UNIQUE if you're a PK--it creates
    # two identical indexes otherwise.
    $type =~ s/unique//i if $new_def->{PRIMARYKEY};

    push(@statements, "ALTER TABLE $table ALTER COLUMN $column
                              TYPE $type");

    if ($new_def->{TYPE} =~ /serial/i && $old_def->{TYPE} !~ /serial/i) {
        push(@statements, "CREATE SEQUENCE ${table}_${column}_seq
                                  OWNED BY $table.$column");
        push(@statements, "SELECT setval('${table}_${column}_seq',
                                         MAX($table.$column))
                             FROM $table");
        push(@statements, "ALTER TABLE $table ALTER COLUMN $column 
                           SET DEFAULT nextval('${table}_${column}_seq')");
    }

    # If this column is no longer SERIAL, we need to drop the sequence
    # that went along with it.
    if ($old_def->{TYPE} =~ /serial/i && $new_def->{TYPE} !~ /serial/i) {
        push(@statements, "ALTER TABLE $table ALTER COLUMN $column 
                           DROP DEFAULT");
        push(@statements, "ALTER SEQUENCE ${table}_${column}_seq 
                           OWNED BY NONE");
        push(@statements, "DROP SEQUENCE ${table}_${column}_seq");
    }

    return @statements;
}

1;
