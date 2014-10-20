# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Andrew Dunstan <andrew@dunslane.net>,
#                 Edward J. Sabol <edwardjsabol@iname.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

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
        BIGSERIAL =>    'bigserial unique',

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
    else
    {
        $index_fields = [ @$index_fields ];
        for (@$index_fields)
        {
            /^\s*(\w+)(?:\s*\((\d+)\))?\s*$/so;
            my ($f, $l) = ($1, $2);
            if ($l)
            {
                # Support MySQL-like prefix indexes (used on bugs_activity.{added,removed})
                $_ = "substr($f, 1, $l)";
            }
            # Support *_pattern_ops
            my $t = $self->get_column_abstract($table, $f);
            $t = $t && $t->{TYPE};
            if ($t =~ /varchar/is)
            {
                $_ .= ' varchar_pattern_ops';
            }
            elsif ($t =~ /text/is)
            {
                $_ .= ' text_pattern_ops';
            }
            elsif ($t =~ /char/is)
            {
                $_ .= ' bpchar_pattern_ops';
            }
        }
    }
    return $self->SUPER::_get_create_index_ddl($table, $name, $index_fields, $index_type);
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
        # We have to rename the series also, and fix the default of the series.
        push(@sql, "ALTER TABLE ${table}_${old_name}_seq 
                      RENAME TO ${table}_${new_name}_seq");
        push(@sql, "ALTER TABLE $table ALTER COLUMN $new_name 
                    SET DEFAULT NEXTVAL('${table}_${new_name}_seq')");
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
    return ("ALTER TABLE $old_name RENAME TO $new_name");
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
                              TYPE $type USING $column\:\:$type");

    if ($new_def->{TYPE} =~ /serial/i && $old_def->{TYPE} !~ /serial/i) {
        push(@statements, "CREATE SEQUENCE ${table}_${column}_seq");
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
        # XXX Pg actually won't let us drop the sequence, even though it's
        #     no longer in use. So we harmlessly leave behind a sequence
        #     that does nothing.
        #push(@statements, "DROP SEQUENCE ${table}_${column}_seq");
    }

    return @statements;
}

1;
