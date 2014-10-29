#!/usr/bin/perl -w
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
# The Initial Developer of the Original Code is Everything Solved.
# Portions created by Everything Solved are Copyright (C) 2006
# Everything Solved. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Vitaliy Filippov <vitalif@mail.ru>

use strict;
use lib qw(. lib);
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::DB;
use Bugzilla::Install::Util qw(indicate_progress);
use Bugzilla::Util;

my $db = {
    source => {
        type => '',
        name => 'bugs',
        user => 'bugs',
        password => '',
        host => 'localhost',
    },
    target => {
        type => '',
        name => 'bugs',
        user => 'bugs',
        password => '',
        host => 'localhost',
    },
};

# Read parameters
while (@ARGV)
{
    my $a = shift @ARGV;
    if ($a =~ /--(\w+)-(\w+)/)
    {
        $db->{lc $1}->{lc $2} = shift @ARGV;
    }
}

if (!$db->{source}->{type} || !$db->{target}->{type})
{
    print STDERR "Bugzilla database copy script

USAGE: perl contrib/bzdbcopy.pl --source-type mysql --source-host localhost \\
  --source-name bugs --source-user bugs --source-password bugs \\
  --target-type pg --target-host localhost \\
  --target-name bugs --target-user bugs --target-password bugs

Here, --source-* are the type, host, database name, user and password
for the source database, and --target-* are the same for the target one.
";
    exit;
}

print "Connecting to the '" . $db->{source}->{name} . "' source database on " . $db->{source}->{type} . "...\n";
my $source_db = Bugzilla::DB::_connect(
    $db->{source}->{type}, $db->{source}->{host}, $db->{source}->{name},
    undef, undef, $db->{source}->{user}, $db->{source}->{password}
);
# Don't read entire tables into memory.
if (lc($db->{source}->{type}) eq 'mysql')
{
    $source_db->{mysql_use_result} = 1;
    # MySQL cannot have two queries running at the same time. Ensure the schema
    # is loaded from the database so bz_column_info will not execute a query
    $source_db->_bz_real_schema;
}

print "Connecting to the '" . $db->{target}->{name} . "' target database on " . $db->{target}->{type} . "...\n";
my $target_db = Bugzilla::DB::_connect(
    $db->{target}->{type}, $db->{target}->{host}, $db->{target}->{name},
    undef, undef, $db->{target}->{user}, $db->{target}->{password}
);
my $ident_char = $target_db->get_info(29); # SQL_IDENTIFIER_QUOTE_CHAR

my @src_tables = $source_db->_bz_real_schema->get_table_list;

# We don't want to touch the schema storage and the full-text index
@src_tables = grep { $_ ne 'bz_schema' && $_ ne 'bugs_fulltext' } @src_tables;

foreach my $table (@src_tables)
{
    my $st = $source_db->bz_table_info($table);
    my $tt = $target_db->bz_table_info($table);
    if (!$tt)
    {
        # Create tables that do not exist in the target DB (usually custom field tables)
        $target_db->_bz_schema->{schema}->{$table} = $st;
        $target_db->_bz_schema->{abstract_schema}->{$table} = $st;
        $target_db->bz_add_table($table);
    }
    else
    {
        # Create fields that do not exist in the target DB (usually custom fields in 'bugs')
        my %tf = @{$tt->{FIELDS}};
        my %sf = @{$st->{FIELDS}};
        for (keys %sf)
        {
            if (!$tf{$_})
            {
                push @{$target_db->_bz_schema->{schema}->{$table}->{FIELDS}}, $_, $sf{$_};
                push @{$target_db->_bz_schema->{abstract_schema}->{$table}->{FIELDS}}, $_, $sf{$_};
                $target_db->bz_add_column($table, $_);
            }
        }
        %tf = @{$tt->{INDEXES} || []};
        %sf = @{$st->{INDEXES} || []};
        for (keys %sf)
        {
            my $n = $_;
            $n = 'PRIMARY' if lc($n) eq $table.'_primary_idx';
            if (!$tf{$n})
            {
                $target_db->bz_add_index($table, $n, $sf{$_});
            }
        }
    }
}

# Intersect source and target table sets
my %st = map { $_ => 1 } @src_tables;
my @table_list = grep { $st{$_} } $target_db->_bz_real_schema->get_table_list;

# Instead of figuring out some fancy algorithm to insert data in the right
# order and not break FK integrity, we just drop them all.
$target_db->bz_drop_foreign_keys();
# We start a transaction on the target DB, which helps when we're doing
# so many inserts.
$target_db->bz_start_transaction();
foreach my $table (@table_list)
{
    my @serial_cols;
    print "Reading data from the source '$table' table on " . $db->{source}->{type} . "...\n";
    my @table_columns = $target_db->bz_table_columns_real($table);
    # The column names could be quoted using the quote identifier char
    # Remove these chars as different databases use different quote chars
    @table_columns = map { s/^\Q$ident_char\E?(.*?)\Q$ident_char\E?$/$1/; $_ } @table_columns;

    my ($total) = $source_db->selectrow_array("SELECT COUNT(*) FROM $table");
    my $select_query = "SELECT " . join(',', @table_columns) . " FROM $table";
    my $select_sth = $source_db->prepare($select_query);
    $select_sth->execute();

    my $insert_query = "INSERT INTO $table ( " . join(',', @table_columns) . " ) VALUES (";
    $insert_query .= '?,' foreach @table_columns;
    # Remove the last comma.
    chop($insert_query);
    $insert_query .= ")";
    my $insert_sth = $target_db->prepare($insert_query);

    print "Clearing out the target '$table' table on " . $db->{target}->{type} . "...\n";
    $target_db->do("DELETE FROM $table");

    # Oracle doesn't like us manually inserting into tables that have
    # auto-increment PKs set, because of the way we made auto-increment
    # fields work.
    if ($target_db->isa('Bugzilla::DB::Oracle'))
    {
        foreach my $column (@table_columns)
        {
            my $col_info = $source_db->bz_column_info($table, $column);
            if ($col_info && $col_info->{TYPE} =~ /SERIAL/i)
            {
                print "Dropping the sequence + trigger on $table.$column...\n";
                $target_db->do("DROP TRIGGER ${table}_${column}_TR");
                $target_db->do("DROP SEQUENCE ${table}_${column}_SEQ");
            }
        }
    }

    print "Writing data to the target '$table' table on " . $db->{target}->{type} . "...\n";
    my $count = 0;
    while (my $row = $select_sth->fetchrow_arrayref)
    {
        # Each column needs to be bound separately, because
        # many columns need to be dealt with specially.
        my $colnum = 0;
        foreach my $column (@table_columns)
        {
            # bind_param args start at 1, but arrays start at 0.
            my $param_num = $colnum + 1;
            my $already_bound;

            # Certain types of columns need special handling.
            my $col_info = $source_db->bz_column_info($table, $column);
            if ($col_info && $col_info->{TYPE} eq 'LONGBLOB')
            {
                $insert_sth->bind_param($param_num, $row->[$colnum], $target_db->BLOB_TYPE);
                $already_bound = 1;
            }
            elsif ($col_info && $col_info->{TYPE} =~ /decimal/)
            {
                # In MySQL, decimal cols can be too long.
                my $col_type = $col_info->{TYPE};
                $col_type =~ /decimal\((\d+),(\d+)\)/;
                my ($precision, $decimals) = ($1, $2);
                # If it's longer than precision + decimal point
                if (length $row->[$colnum] > $precision + 1)
                {
                    # Truncate it to the highest allowed value.
                    my $orig_value = $row->[$colnum];
                    $row->[$colnum] = '';
                    my $non_decimal = $precision - $decimals;
                    $row->[$colnum] .= '9' while ($non_decimal--);
                    $row->[$colnum] .= '.';
                    $row->[$colnum] .= '9' while ($decimals--);
                    print "Truncated value $orig_value to " . $row->[$colnum] . " for $table.$column.\n";
                }
            }
            elsif ($col_info && $col_info->{TYPE} =~ /DATETIME/i)
            {
                my $date = $row->[$colnum];
                # MySQL can have strange invalid values for Datetimes.
                if ($date && $date eq '0000-00-00 00:00:00')
                {
                    $row->[$colnum] = '1901-01-01 00:00:00';
                }
            }

            $insert_sth->bind_param($param_num, $row->[$colnum]) unless $already_bound;
            $colnum++;
        }

        $insert_sth->execute();
        $count++;
        indicate_progress({ current => $count, total => $total, every => 100 });
    }

    # For some DBs, we have to do clever things with auto-increment fields.
    foreach my $column (@table_columns)
    {
        next if $target_db->isa('Bugzilla::DB::Mysql');
        my $col_info = $source_db->bz_column_info($table, $column);
        if ($col_info && $col_info->{TYPE} =~ /SERIAL/i)
        {
            my ($max_val) = $target_db->selectrow_array("SELECT MAX($column) FROM $table");
            # Set the sequence to the current max value + 1.
            $max_val = 0 if !defined $max_val;
            $max_val++;
            print "\nSetting the next value for $table.$column to $max_val.";
            if ($target_db->isa('Bugzilla::DB::Pg'))
            {
                # PostgreSQL doesn't like it when you insert values into
                # a serial field; it doesn't increment the counter automatically.
                $target_db->bz_set_next_serial_value($table, $column);
            }
            elsif ($target_db->isa('Bugzilla::DB::Oracle'))
            {
                # Oracle increments the counter on every insert, and *always*
                # sets the field, even if you gave it a value. So if there
                # were already rows in the target DB (like the default rows
                # created by checksetup), you'll get crazy values in your
                # id columns. So we just dropped the sequences above and
                # we re-create them here, starting with the right number.
                my @sql = $target_db->_bz_real_schema->_get_create_seq_ddl($table, $column, $max_val);
                $target_db->do($_) foreach @sql;
            }
        }
    }

    print "\n\n";
}

print "Committing changes to the target database...\n";
$target_db->bz_commit_transaction();
$target_db->bz_setup_foreign_keys();

print "All done! Make sure to run checksetup.pl on the new DB.\n";
$source_db->disconnect;
$target_db->disconnect;

1;

__END__

=head1 NAME

bzdbcopy.pl - Copies data from one Bugzilla database to another.

=head1 USAGE

=over

=item 1. Setup the 'localconfig' for the target database

=item 2. Run ./checksetup.pl inside your Bugzilla installation directory
         on the target database to populate it with empty tables

=item 3. Run contrib/bzdbcopy.pl

 cd <bugzilla_installation_dir>
 perl contrib/bzdbcopy.pl --source-type mysql --source-host localhost \
   --source-name bugs --source-user bugs --source-password bugs \
   --target-type pg --target-host localhost \
   --target-name bugs --target-user bugs --target-password bugs

Here, --source-* are the type, host, database name, user and password
for the source database, and --target-* are the same for the target one.

=back

=head1 DESCRIPTION

The intended use of this script is to copy data from an installation
running on one DB platform to an installation running on another
DB platform.

Note: Both schemas must already exist and both must be created/updated
by the B<SAME> version of checksetup.pl. B<No custom fields> must exist
in the target database. This script will B<DESTROY ALL CURRENT DATA> in
the target database.
