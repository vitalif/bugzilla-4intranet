#!/usr/bin/perl

use strict;
use POSIX qw(strftime mktime);

$| = 1;

my $start = $ARGV[0] || die "USAGE: ./recollect.pl <start_date> [end_date]\nDates are in format YYYY-MM-DD\n";
my $end = $ARGV[1] || strftime('%Y-%m-%d', localtime);

my $ts = [ split /\D+/, $start ];
$end = [ split /\D+/, $end ];
$ts = mktime(0, 0, 0, $ts->[2], $ts->[1]-1, $ts->[0]-1900);
$end = mktime(0, 0, 0, $end->[2], $end->[1]-1, $end->[0]-1900);
while ($ts < $end)
{
    my $d = strftime("%Y-%m-%d", localtime($ts));
    print strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Collecting stats for $d\n";
    system("nice perl collectstats.pl $d");
    $ts += 86400;
}
