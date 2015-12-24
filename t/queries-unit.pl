#!/usr/bin/perl
# Script for testing Bugzilla Search engine and comparing query results

use utf8;
use strict;
no warnings 'utf8';

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Encode;
use Time::HiRes qw(gettimeofday);

BEGIN {
    my ($a) = abs_path($0) =~ /^(.*)$/;
    chdir dirname($a);
}

use lib qw(..);
use Bugzilla;
use Bugzilla::CGI;
use Bugzilla::User;
use Bugzilla::Search;

*Bugzilla::Search::split_order_term = *split_order_term;

my $SLOW_QUERY = 2;

my $IN = 'queries.txt';
my $RES = '';
my $LOG = '';
my $OLDRES = '';

for my $i (0..$#ARGV)
{
    local $_ = $ARGV[$i];
    if ($_ eq '-h' || $_ eq '--help')
    {
        print STDERR
"Script for testing Bugzilla Search engine and comparing query results
USAGE: perl $0 [-i queries.txt] [-r result.txt] [-l log.txt] [-o old-results-to-compare.txt]

Input 'queries.txt' file contains tested queries, one per a line, in the following format:
| userid | name | query string

When run with '-o' option, this script compares query results and performance
to the ones written into 'old-results-to-compare.txt' from previous run.

Example usage:
1) Connect to Bugzilla database, run 'SELECT * FROM namedqueries' and save results into a file
2) Get a 'reference' Bugzilla version into different folder with same localconfig
3) Run: 'perl queries-unit.pl -l log-ref.txt -r res-ref.txt' inside the reference Bugzilla
4) Run: 'perl queries-unit.pl -l log-new.txt -r res-new.txt -o <path_to_ref_bugzilla>/t/res-ref.txt'
";
        exit;
    }
    elsif ($_ eq '-i') { $IN = $ARGV[++$i]; }
    elsif ($_ eq '-r') { $RES = $ARGV[++$i]; }
    elsif ($_ eq '-l') { $LOG = $ARGV[++$i]; }
    elsif ($_ eq '-o') { $OLDRES = $ARGV[++$i]; }
}

if (!$RES)
{
    $RES = $IN;
    $RES =~ s/\./-result\./so;
}

# Read queries
my $queries = [];
open FD, '<', $IN or die "Cannot open '$IN'";
while (<FD>)
{
    Encode::_utf8_on($_);
    if (/^[^\|]*\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*(\S+)/s)
    {
        push @$queries, {
            userid => $1,
            name   => $2,
            query  => $3,
        };
    }
}
close FD;

my $logfd;
if ($LOG)
{
    open $logfd, '>', $LOG or die "Cannot open log '$LOG'";
}

my $old;
if ($OLDRES)
{
    # Read old results
    $old = do $OLDRES;
    die $@ if $@;
}

$SIG{INT} = \&finish;

$| = 1;
my $results = {};
my (@lq, $maxl);
my $l;
my $bad;
my $i = 0;
for my $q (@$queries)
{
    my $key = $q->{userid}.':'.$q->{name};
    my $user = Bugzilla::User->new({ id => $q->{userid} });
    print("Invalid user $q->{userid}!\n"), next unless $user;
    next if $user->disabledtext;
    my $s = "Testing $q->{userid}'s $q->{name}... ";
    $l = length $s;
    # $maxl is streaming maximum over last 10 lengths
    $maxl = $lq[1] || $l;
    pop(@lq), pop(@lq) while @lq && $lq[$#lq] < $l;
    shift(@lq), shift(@lq) if $lq[0] <= $i-10;
    push @lq, $i, $l;
    $i++;
    print $s;
    print $logfd $s if $logfd;
    # Generate query
    my $t_start = gettimeofday();
    Encode::_utf8_off($q->{query});
    my $params = Bugzilla::CGI->new($q->{query});
    my $search = Bugzilla::Search->new(
        params => $params,
        fields => [ 'bug_id' ],
        user   => $user,
        order  => make_order($params->param('order')),
    );
    my $sql = $search->getSQL();
    $sql =~ s/^\s*SELECT/SELECT SQL_NO_CACHE/ if Bugzilla->dbh->isa('Bugzilla::DB::Mysql');
    $q->{sql} = $sql;
    my $result;
    # Execute query
    eval { $result = Bugzilla->dbh->selectcol_arrayref($sql) };
    if ($@)
    {
        $q->{error} = $@;
        $s = "Query error: $@\n";
        print $s;
        print $logfd $s if $logfd;
    }
    else
    {
        my $t_query = gettimeofday();
        # Save results
        $q->{result} = join(',', @$result);
        $q->{time} = $t_query-$t_start;
        $s = sprintf("%.2f sec, ", $q->{time}).@$result." bugs\n";
        # Check results
        $bad = 0;
        if ($q->{time} > $SLOW_QUERY)
        {
            $s = "SLOW $s";
            $bad = 'SLOW';
        }
        if ($old && $old->{$key})
        {
            if ($old->{$key}->{result} ne $q->{result})
            {
                if (join(',', sort split ',', $old->{$key}->{result}) ne
                    join(',', sort split ',', $q->{result}))
                {
                    $bad = 'INVALID';
                    $s = "[!] INVALID [!] $s";
                }
                else
                {
                    $bad = 'INVALID ORDER';
                    $s = "[!] INVALID ORDER [!] $s";
                }
            }
            elsif ($q->{time} > $old->{$key}->{time}/0.8)
            {
                $bad = 'WORSE';
                $s = sprintf("WORSE(by %.2f sec) ", $q->{time} - $old->{$key}->{time}).$s;
            }
            elsif ($old->{$key}->{time} > 0.1 && $q->{time}/$old->{$key}->{time} < 0.8)
            {
                $s = sprintf("BETTER(by %.2f sec) ", $old->{$key}->{time} - $q->{time}).$s;
            }
        }
        $s = (' ' x ($maxl-$l)).$s;
        if ($bad)
        {
            my $sql = $q->{sql};
            $sql =~ s/^/  /gmo;
            $s .= "$sql\n";
            $s .= "$bad | $q->{userid} | $q->{name} | $q->{query}\n";
        }
        print $s;
        print $logfd $s if $logfd;
    }
    $results->{$key} = $q;
}

finish();

sub dumper_simple
{
    my ($h, $l) = @_;
    $l ||= 0;
    if (ref $h && $h =~ /ARRAY/)
    {
        my $s = "[\n";
        for (@$h)
        {
            $s .= ('  ' x ($l+1)).dumper_simple($_, $l+1).",\n";
        }
        $h = $s.('  ' x $l).']';
    }
    elsif (ref $h && $h =~ /HASH/)
    {
        my $s = "{\n";
        for my $k (keys %$h)
        {
            $k =~ s/([\'\\])/\\$1/gso;
            $s .= ('  ' x ($l+1))."'$k' => ".dumper_simple($h->{$k}, $l+1).",\n";
        }
        $h = $s.('  ' x $l).'}';
    }
    else
    {
        $h = "$h";
        $h =~ s/([\'\\])/\\$1/gso;
        $h = "'$h'";
    }
    return $h;
}

sub finish
{
    close $logfd if $logfd;
    print "Terminating and saving results into '$RES'\n";
    open FD, '>', $RES or die "Cannot write into '$RES'";
    print FD dumper_simple($results);
    close FD;
    exit;
}

# Splits out "asc|desc" from a sort order item.
sub split_order_term
{
    my $fragment = shift;
    my ($col, $dir) = split /\s+/, $fragment, 2;
    $col = lc $col;
    $dir = uc $dir;
    $dir = '' if $dir ne 'DESC' && $dir ne 'ASC';
    return wantarray ? ($col, $dir) : $col;
}

sub make_order
{
    my ($order) = @_;
    my $old_orders = {
        '' => 'bug_status,priority,assigned_to,bug_id', # Default
        'bug number' => 'bug_id',
        'importance' => 'priority,bug_severity,bug_id',
        'assignee' => 'assigned_to,bug_status,priority,bug_id',
        'last changed' => 'delta_ts,bug_status,priority,assigned_to,bug_id',
    };
    $order = '' if $order =~ /reuse same/is;
    $order = $old_orders->{lc $order} || $order || $old_orders->{''};
    $order .= ',bug_id' if $order !~ /bug_id/;
    $order = [ split /\s*,\s*/, $order ];
    for (@$order)
    {
        my ($c, $d) = split_order_term($_);
        $c = translate_old_column($c);
        $_ = $c.' '.$d;
    }
    return $order;
}
