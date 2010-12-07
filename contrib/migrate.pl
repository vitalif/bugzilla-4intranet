#!/usr/bin/perl
# Alternative Bugzilla database copy script
# Correctly handles custom fields and does no foreign key removal

# See help below $USAGE = ... or run this with --help
# Lines marked with "#!" comment in the end modify the DB

use strict;

# Runs before any 'uses'
BEGIN {

my $USAGE = <<EOF;
Bugzilla database copy script

USAGE: perl $0 --from DSN -u USER -p PASSWORD [--ignore TABLE]
DSN help: see perldoc DBI, perldoc DBD::mysql, perldoc DBD::Pg

Use --ignore TABLE only for some garbage tables.
Run this from contrib/ subdirectory of your Bugzilla installation.
Apply to a virgin Bugzilla database created by checksetup.pl of same Bugzilla version
Then run checksetup.pl again to populate bugs_fulltext.

Does the following:
1) Redefine existing fields with IDs taken from old database
2) Create custom fields with IDs taken from old database using Bugzilla classes
3) Copy table data in the correct order, ignoring garbage columns
4) Copy AUTOINCREMENT (MySQL) or SEQUENCE (PostgreSQL) values
EOF

# Parse command-line arguments
my ($from, $from_user, $from_password);
my @ignore_tables;

while ($_ = shift @ARGV)
{
    if ($_ eq '--from')
    {
        $from = shift @ARGV;
    }
    elsif ($_ eq '--from-user' || $_ eq '-u')
    {
        $from_user = shift @ARGV;
    }
    elsif ($_ eq '--from-password' || $_ eq '-p')
    {
        $from_password = shift @ARGV;
    }
    elsif ($_ eq '--help' || $_ eq '-h')
    {
        print $USAGE;
        exit;
    }
    elsif ($_ eq '--ignore')
    {
        push @ignore_tables, shift @ARGV;
    }
}

unless ($from && $from_user)
{
    print $USAGE;
    exit;
}
$from_password ||= '';

}

use lib qw(..);
use DBI;
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Extension;

# Pre-load all extensions
$Bugzilla::extension_packages = Bugzilla::Extension->load_all();

my %seen_tables = (
    # Copied manually:
    'fielddefs'     => 1,
    # Ignored:
    'series_data'   => 1,
    'bz_schema'     => 1,
    'attach_data'   => 1,
    'bugs_fulltext' => 1,
    'logincookies'  => 1,
    'tokens'        => 1,
    'globalauth'    => 1,
    'series1'       => 1,
    'bug_user_map'  => 1,
    'old_profiles'  => 1,
    'qwe'           => 1,
);

# Ignore more tables
$seen_tables = 1 for @ignore_tables;

my %field_exclude = (
    'fieldvaluecontrol' => 'field_id',
    'bugs_activity'     => 'fieldid',
    'profiles_activity' => 'fieldid',
);

my $from = DBI->connect('DBI:mysql:database=bugs3new', 'bugzilla3', 'bugzilla3') || die "Can't connect to source DB";
my $to = Bugzilla->dbh || die "Can't connect to destination DB";

# Get table dependencies and autoincrement columns
my $table_depends = {};
my $autoincrement = {};
my ($bz_schema) = $from->selectrow_array('SELECT schema_data FROM bz_schema');
$bz_schema =~ s/^\$VAR1 = //;
$bz_schema = eval $bz_schema;
die $@ if $@;

for my $t (keys %$bz_schema)
{
    for (my $i = 0; $i < @{$bz_schema->{$t}->{FIELDS}}; $i += 2)
    {
        my $f = $bz_schema->{$t}->{FIELDS}->[$i+1];
        if ($f->{REFERENCES})
        {
            $table_depends->{$t}->{$f->{REFERENCES}->{TABLE}} = 1;
        }
        elsif ($f->{TYPE} =~ /serial/i)
        {
            $autoincrement->{$t} = $bz_schema->{$t}->{FIELDS}->[$i];
        }
    }
}

# All tables except ones for custom fields
my @copy_tables = getseq([ sort keys %$bz_schema ], \%seen_tables, $table_depends);

my $fielddefs = $from->selectall_hashref('SELECT * FROM fielddefs', 'name');
my $fieldsnew = $to->selectall_hashref('SELECT * FROM fielddefs WHERE name IN (\''.join('\',\'', keys %$fielddefs).'\')', 'name');

for (values %$fielddefs)
{
    if ($_->{custom})
    {
        if ($_->{type} == FIELD_TYPE_SINGLE_SELECT ||
            $_->{type} == FIELD_TYPE_MULTI_SELECT)
        {
            push @copy_tables, $_->{name};
        }
        if ($_->{type} == FIELD_TYPE_MULTI_SELECT)
        {
            push @copy_tables, 'bug_'.$_->{name};
        }
    }
}

print "Redefine existing fields\n";
$to->do('DELETE FROM profiles_activity'); #!
$to->do('DELETE FROM fielddefs WHERE name IN (\''.join('\',\'', keys %$fieldsnew).'\')'); #!
insertall_hashref($to, 'fielddefs', [ map { $fielddefs->{$_} } keys %$fieldsnew ]); #!

delete $fielddefs->{$_} for keys %$fieldsnew;

my @skip_fields;

for (keys %$fielddefs)
{
    if ($fielddefs->{$_}->{obsolete})
    {
        print "Skip field $_ (y/n)? ";
        if (<STDIN> =~ /^\s*y/is)
        {
            push @skip_fields, $_;
            next;
        }
    }
    if (/^cf_/)
    {
        print "Creating field $_\n";
        my $field = Bugzilla::Field->create($fielddefs->{$_}); #!
    }
    else
    {
        insertall_hashref($to, 'fielddefs', [ $fielddefs->{$_} ]); #!
    }
}

# Alter fielddefs autoincrement value manually
my ($maxkey) = $to->selectrow_array('SELECT MAX(id) FROM fielddefs');
alter_sequence($to, 'fielddefs', 'id', $maxkey);

for my $table (@copy_tables)
{
    print "Selecting $table\n";
    my $data = $from->selectall_arrayref(
        'SELECT * FROM '.$from->quote_identifier($table).
        ' WHERE '.($field_exclude{$table} ? $field_exclude{$table}.' NOT IN ('.join(',', map { $fielddefs->{$_}->{id} } @skip_fields).')' : '1'),
        {Slice=>{}}
    );
    print "Erasing $table\n";
    $to->do('DELETE FROM '.$to->quote_identifier($table)); #!
    @$data || next;
    my %from_keys = %{$data->[0]};
    my @to_cols = @{ $to->selectcol_arrayref(
        "SELECT column_name FROM information_schema.columns".
        " WHERE table_catalog=current_database() and table_schema=current_schema() and table_name=?",
        undef, $table
    ) };
    delete $from_keys{$_} for @to_cols;
    for my $bad_key (keys %from_keys)
    {
        print "Removing column $bad_key\n";
        delete $_->{$bad_key} for @$data;
    }
    $maxkey = 0;
    if (my $ai = $autoincrement->{$table})
    {
        for (@$data)
        {
            $maxkey = $_->{$ai} if $_->{$ai} > $maxkey;
        }
    }
    my @buf;
    my $n = 0;
    my $total = @$data;
    while (@$data)
    {
        @buf = splice @$data, 0, 1024;
        insertall_hashref($to, $table, \@buf); #!
        $n += @buf;
        print "\rInserting $table: $n/$total...";
    }
    print "\n";
    # Initialize auto-increment values
    if (my $ai = $autoincrement->{$table})
    {
        alter_sequence($to, $table, $ai, $maxkey); #!
    }
}

sub alter_sequence
{
    my ($dbh, $table, $field, $maxkey) = @_;
    $maxkey = int($maxkey)+1;
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        $dbh->do("ALTER TABLE `$table` AUTOINCREMENT=$maxkey");
    }
    elsif ($dbh->isa('Bugzilla::DB::Pg'))
    {
        $dbh->do("ALTER SEQUENCE ${table}_${field}_seq RESTART WITH $maxkey");
    }
}

# Insert an array of hashes into a database table
sub insertall_hashref
{
    my ($dbh, $table, $rows) = @_;
    return 0 unless
        $dbh && $table &&
        $rows && ref($rows) eq 'ARRAY' && @$rows;
    my $q = substr($dbh->quote_identifier('a'), 0, 1);
    my @f = keys %{$rows->[0]};
    my $sql = "INSERT INTO $q$table$q ($q".join("$q,$q",@f)."$q) VALUES ".
        join(',',('('.(join(',', ('?') x scalar(@f))).')') x scalar(@$rows));
    my @bind = map { @$_{@f} } @$rows;
    return $dbh->do($sql, undef, @bind);
}

# Get node sequence from a dependency graph
sub getseq
{
    my ($seq, $seen, $dep) = @_;
    my @r;
    for (@$seq)
    {
        if (!$seen->{$_})
        {
            $seen->{$_} = 1;
            push @r, getseq([ sort keys %{$dep->{$_} || {}} ], $seen, $dep);
            push @r, $_;
        }
    }
    return @r;
}
