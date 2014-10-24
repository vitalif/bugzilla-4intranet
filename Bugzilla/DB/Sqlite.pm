# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
package Bugzilla::DB::Sqlite;
use base qw(Bugzilla::DB);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Install::Util qw(install_string);

use DateTime;
use POSIX ();

# SQLite only supports the SERIALIZABLE and READ UNCOMMITTED isolation
# levels. SERIALIZABLE is used by default and SET TRANSACTION ISOLATION
# LEVEL is not implemented.
use constant ISOLATION_LEVEL => undef;
use constant FOR_UPDATE => '';
use constant FULLTEXT_ID_FIELD => 'docid';

# Since we're literally using Perl's regexes, we can use something
# simpler and more efficient than what Bugzilla::DB uses.
use constant WORD_START => '(?:^|\W)';
use constant WORD_END   => '(?:$|\W)';

# For some reason, dropping the related FKs causes the index to
# disappear early, which causes all sorts of problems.
use constant INDEX_DROPS_REQUIRE_FK_DROPS => 0;

####################################
# Functions Added To SQLite Itself #
####################################

# A case-insensitive, Unicode collation for SQLite. This allows us to
# make all comparisons and sorts case-insensitive (though unfortunately
# not accent-insensitive).
sub _sqlite_collate_ci { lc($_[0]) cmp lc($_[1]) }

sub _sqlite_mod { $_[0] % $_[1] }

sub _sqlite_now
{
    my $now = DateTime->now(time_zone => Bugzilla->local_timezone);
    return $now->ymd . ' ' . $now->hms;
}

# SQL's POSITION starts its values from 1 instead of 0 (so we add 1).
sub _sqlite_position
{
    my ($text, $fragment) = @_;
    if (!defined $text or !defined $fragment)
    {
        return undef;
    }
    my $pos = index $text, $fragment;
    return $pos + 1;
}

sub _sqlite_position_ci
{
    my ($text, $fragment) = @_;
    if (!defined $text or !defined $fragment)
    {
        return undef;
    }
    my $pos = index lc($text), lc($fragment);
    return $pos + 1;
}

# BM25 ranking for SQLite FTS4 fulltext search
# Usage: bm25(matchinfo(table, 'pcnalx'), search_column_number)
sub _sqlite_bm25
{
    my ($matchinfo, $searchTextCol, $K1, $B) = @_;
    $K1 ||= 1.2;
    $B ||= 0.75;
    $matchinfo = [ unpack('V*', $matchinfo) ];
    my $termCount = $matchinfo->[0];
    my $colCount = $matchinfo->[1];
    my $totalDocs = $matchinfo->[2];
    $searchTextCol = $colCount-1 if $searchTextCol >= $colCount;
    $searchTextCol = 0 if $searchTextCol < 0;
    my $avgLength = $matchinfo->[3 + $searchTextCol];
    my $docLength = $matchinfo->[3 + $colCount + $searchTextCol];
    my $sum = 0;
    for (my $i = 0; $i < $termCount; $i++)
    {
        my $termFreq = $matchinfo->[3 + 2*$colCount + 3*($i*$colCount + $searchTextCol)];
        my $docsWithTerm = $matchinfo->[3 + 2*$colCount + 3*($i*$colCount + $searchTextCol) + 2];
        my $idf = log(($totalDocs - $docsWithTerm + 0.5) / ($docsWithTerm + 0.5));
        my $rightSide = ($termFreq * ($K1+1)) / ($termFreq + $K1*(1 - $B + $B*$docLength/$avgLength));
        $sum += $idf * $rightSide if $idf > 0;
    }
    return $sum;
}

###############
# Constructor #
###############

sub new
{
    my ($class, $user, $pass, $host, $db_name, $port, $sock) = @_;

    # Let people specify paths intead of data/ for the DB.
    if ($db_name and $db_name !~ m{[\\/]})
    {
        # When the DB is first created, there's a chance that the
        # data directory doesn't exist at all, because the Install::Filesystem
        # code happens after DB creation. So we create the directory ourselves
        # if it doesn't exist.
        my $datadir = bz_locations()->{datadir};
        if (!-d $datadir)
        {
            mkdir $datadir or warn "$datadir: $!";
        }
        if (!-d "$datadir/db/")
        {
            mkdir "$datadir/db/" or warn "$datadir/db: $!";
        }
        $db_name = bz_locations()->{datadir} . "/db/$db_name";
    }

    # construct the DSN from the parameters we got
    my $dsn = "dbi:SQLite:dbname=$db_name";

    my $attrs = {
        # FIXME Should we just enforce this to be always on?
        sqlite_unicode => Bugzilla->params->{utf8},
    };

    my $self = $class->db_new($dsn, '', '', $attrs);

    # Needed by TheSchwartz
    $self->{private_bz_dsn} = $dsn;

    my %pragmas = (
        # Make sure that the sqlite file doesn't grow without bound.
        auto_vacuum => 1,
        encoding => "'UTF-8'",
        foreign_keys => 'ON',
        # We want the latest file format.
        legacy_file_format => 'OFF',
        # This guarantees that we get column names like "foo"
        # instead of "table.foo" in selectrow_hashref.
        short_column_names => 'ON',
        # The write-ahead log mode in SQLite 3.7 gets us better concurrency,
        # but breaks backwards-compatibility with older versions of
        # SQLite. (Which is important because people may also want to use
        # command-line clients to access and back up their DB.) If you need
        # better concurrency and don't need 3.6 compatibility, then you can
        # uncomment this line.
        journal_mode => "'WAL'",
    );

    while (my ($name, $value) = each %pragmas)
    {
        $self->do("PRAGMA $name = $value");
    }

    $self->sqlite_create_collation('bugzilla', \&_sqlite_collate_ci);
    $self->sqlite_create_function('position', 2, \&_sqlite_position);
    $self->sqlite_create_function('iposition', 2, \&_sqlite_position_ci);
    # SQLite has a "substr" function, but other DBs call it "SUBSTRING"
    # so that's what we use, and I don't know of any way in SQLite to
    # alias the SQL "substr" function to be called "SUBSTRING".
    $self->sqlite_create_function('substring', 3, \&CORE::substr);
    $self->sqlite_create_function('char_length', 1, sub { length($_[0]) });
    $self->sqlite_create_function('mod', 2, \&_sqlite_mod);
    $self->sqlite_create_function('now', 0, \&_sqlite_now);
    $self->sqlite_create_function('localtimestamp', 1, \&_sqlite_now);
    $self->sqlite_create_function('floor', 1, \&POSIX::floor);
    $self->sqlite_create_function('bm25', 4, \&_sqlite_bm25);

    bless ($self, $class);
    return $self;
}

###############
# SQL Methods #
###############

sub sql_position
{
    my ($self, $fragment, $text) = @_;
    return "POSITION($text, $fragment)";
}

sub sql_iposition
{
    my ($self, $fragment, $text) = @_;
    return "IPOSITION($text, $fragment)";
}

# SQLite does not have to GROUP BY the optional columns.
sub sql_group_by
{
    my ($self, $needed_columns, $optional_columns) = @_;
    my $expression = "GROUP BY $needed_columns";
    return $expression;
}

# FIXME SQLite does not support sorting a GROUP_CONCAT, so $sort is unimplemented.
sub sql_group_concat
{
    my ($self, $column, $separator, $sort) = @_;
    $separator = $self->quote(', ') if !defined $separator;
    # In SQLite, a GROUP_CONCAT call with a DISTINCT argument can't
    # specify its separator, and has to accept the default of ",".
    if ($column =~ /^DISTINCT/)
    {
        return "GROUP_CONCAT($column)";
    }
    return "GROUP_CONCAT($column, $separator)";
}

sub sql_istring
{
    my ($self, $string) = @_;
    return $string;
}

sub sql_regexp
{
    my ($self, $expr, $pattern, $nocheck, $real_pattern) = @_;
    $real_pattern ||= $pattern;

    $self->bz_check_regexp($real_pattern) if !$nocheck;

    return "$expr REGEXP $pattern";
}

sub sql_not_regexp
{
    my $self = shift;
    my $re_expression = $self->sql_regexp(@_);
    return "NOT($re_expression)";
}

sub sql_limit
{
    my ($self, $limit, $offset) = @_;
    if (defined($offset))
    {
        return "LIMIT $limit OFFSET $offset";
    }
    else
    {
        return "LIMIT $limit";
    }
}

sub sql_from_days
{
    my ($self, $days) = @_;
    return "DATETIME($days)";
}

sub sql_to_days
{
    my ($self, $date) = @_;
    return "JULIANDAY($date)";
}

sub sql_date_format
{
    my ($self, $date, $format) = @_;
    $format = "%Y.%m.%d %H:%M:%S" if !$format;
    $format =~ s/\%i/\%M/g;
    return "STRFTIME(" . $self->quote($format) . ", $date)";
}

sub sql_date_math
{
    my ($self, $date, $operator, $interval, $units) = @_;
    # We do the || thing (concatenation) so that placeholders work properly.
    return "DATETIME($date, '$operator' || $interval || ' $units')";
}

# Fulltext search using SQLite
sub sql_fulltext_search
{
    my $self = shift;
    my ($column, $text) = @_;
    $text = $self->quote_fulltext($text);
    my $ncol = $column;
    $ncol =~ s/^.*\.//so;
    $ncol = { short_desc => 0, comments => 1, comments_private => 2 } -> { lc $ncol };
    return ("$column MATCH $text", "COALESCE((SELECT bm25(matchinfo(bugs_fulltext, 'pcnalx'), $ncol, 1.2, 0.75)".
        " FROM bugs_fulltext WHERE docid=bugs.bug_id AND $column MATCH $text), 0)");
}

sub sql_fulltext_relevance_sum
{
    my $self = shift;
    my ($bits) = @_;
    return "(".join("+", @$bits).")";
}

sub bz_explain
{
    my $self = shift;
    my ($sql) = @_;
    my $rows = $self->selectall_arrayref("EXPLAIN QUERY PLAN $sql");
    my @seq;
    my $subq = [];
    foreach my $row (@$rows)
    {
        if (!$subq->[$row->[0]])
        {
            $subq->[$row->[0]] = "Subquery ".$row->[0]."\n";
            push @seq, $row->[0];
        }
        $subq->[$row->[0]] .= "  ".("  " x $row->[1]).$row->[3]."\n";
    }
    return join '', @$subq[@seq];
}

sub bz_table_list_real
{
    my $self = shift;
    my @tables = $self->SUPER::bz_table_list_real(@_);
    # SQLite includes a sqlite_sequence table in every database that isn't
    # one of our real tables. We exclude any table that starts with sqlite_,
    # just to be safe.
    @tables = grep { $_ !~ /^sqlite_/ } @tables;
    return @tables;
}

sub bz_add_fk
{
    my $self = shift;
    my ($table, $column, $def) = @_;
    return if $table eq 'bugs_fulltext';
    $self->SUPER::bz_add_fk(@_);
}

sub bz_setup_foreign_keys
{
    my $self = shift;
    $self->SUPER::bz_setup_foreign_keys();
    print "Running ANALYZE to rebuild statistics for all tables\n";
    $self->do("ANALYZE main");
}

1;

__END__

=head1 NAME

Bugzilla::DB::Sqlite - Bugzilla database compatibility layer for SQLite

=head1 DESCRIPTION

This module overrides methods of the Bugzilla::DB module with a
SQLite-specific implementation. It is instantiated by the Bugzilla::DB module
and should never be used directly.

For interface details see L<Bugzilla::DB> and L<DBI>.
