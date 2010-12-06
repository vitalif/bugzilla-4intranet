#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
# ------------------------------------------------------------------------
# For Bug 12253

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Search;
use Bugzilla::Search::Saved;
use Bugzilla::Constants;

use BugWorkTime; # extensions/custis/lib/

my $user     = Bugzilla->login(LOGIN_REQUIRED);
my $userid   = $user->id;

my $cgi      = Bugzilla->cgi;
my $template = Bugzilla->template;
my $dbh      = Bugzilla->dbh;
my $vars     = {};

# Read buglist from query params
my @idlist;
foreach my $i ($cgi->param())
{
    if ($i =~ /^wtime_([1-9][0-9]*)/)
    {
        push @idlist, $1;
    }
}

my ($lastdays) = $cgi->param('lastdays') =~ /^(\d+)$/;
$vars->{lastdays} = $lastdays ||= '1';

my %changedbugs;
foreach my $id (@idlist)
{
    if (scalar($cgi->param("wtime_$id")) != 0 || $cgi->param("comm_$id") ||
        scalar($cgi->param("oldrtime_$id")) != scalar($cgi->param("newrtime_$id")))
    {
        Bugzilla::Bug->check($id);
        $changedbugs{$id} = 1;
    }
}

@idlist = keys %changedbugs;
my @lines = split("\n", $cgi->param("worktime"));

if (@idlist || @lines)
{
    foreach my $id (@idlist)
    {
        $dbh->bz_start_transaction();
        BugWorkTime::FixWorktime($id, scalar $cgi->param("wtime_$id"), scalar $cgi->param("comm_$id"));
        $dbh->bz_commit_transaction();
    }
    if (@lines)
    {
        foreach my $line (@lines)
        {
            if ($line && $line =~ m/\s*(\d?\d.\d\d.[1-9]?\d?\d\d\s)?\s*((\d?\d):(\d\d)\s*-\s*(\d?\d):(\d\d)\s+)?([\w\/]+)\s*(-\s*(BUG|\()?\s*([1-9]\d*)(.*))/iso)
            {
                my $wtime = (($5 * 60 + $6) - ($3 * 60 + $4)) / 60;
                $wtime = 0 if $wtime < 0;
                my $id      = $10;
                my $comment = $line;
                if (!$id)
                {
                    ThrowUserError('object_not_specified', { class => 'Bugzilla::Bug' });
                }
                $dbh->bz_start_transaction();
                BugWorkTime::FixWorktime($id, $wtime, $comment);
                $dbh->bz_commit_transaction();
            }
        }
    }
    print $cgi->redirect(-location => "fill-day-worktime.cgi?lastdays=" . $lastdays);
    exit;
}

$cgi->send_header();

my ($query, $query_id) = Bugzilla::Search::LookupNamedQuery('MyWorktimeBugs', undef, undef, 0);

my $sqlquery = "";
if ($query_id)
{
    my $queryparams = new Bugzilla::CGI($query);
    my $search      = new Bugzilla::Search(
        params => $queryparams,
        fields => [ "bugs.bug_id", "bugs.priority", "bugs.short_desc", "bugs.remaining_time", "bugs.product_id", "bugs.component_id" ],
        user   => $user,
    );
    $sqlquery = $search->getSQL();
}

$sqlquery = " UNION ($sqlquery)" if $sqlquery;

my $tm = "CURRENT_DATE - ".$dbh->sql_interval($lastdays-1, 'DAY');

my $bugsquery = "
 SELECT b.bug_id, b.priority, b.short_desc, p.name product, c.name component,
  ROUND(b.remaining_time,1) remaining_time,
  ROUND(SUM(l.work_time),2) all_work_time,
  ROUND(SUM(
   CASE WHEN l.bug_when >= $tm AND l.who=$userid
   THEN l.work_time
   ELSE 0 END
  ),2) today_work_time
 FROM bugs b, longdescs l, products p, components c
 WHERE b.bug_id IN
 (
  SELECT bugs.bug_id FROM longdescs ll, bugs
  WHERE ll.bug_when >= $tm AND ll.who=? AND ll.bug_id=bugs.bug_id
  UNION
  SELECT bugs.bug_id FROM bugs_activity aa, bugs
  WHERE aa.bug_when >= $tm AND aa.who=? AND aa.bug_id=bugs.bug_id
  $sqlquery
 )
 AND b.product_id=p.id AND b.component_id=c.id
 GROUP BY b.bug_id, b.priority, b.short_desc, p.name, c.name, b.remaining_time
 ORDER BY today_work_time DESC, priority ASC
 ";

$vars->{bugs} = $dbh->selectall_arrayref($bugsquery, {Slice=>{}}, $userid, $userid) || [];

($vars->{timestamp}) = $dbh->selectrow_array("SELECT NOW()");
($vars->{totaltime}) = $dbh->selectrow_array("SELECT ROUND(SUM(work_time),2) FROM longdescs WHERE bug_when >= CURRENT_DATE - ".$dbh->sql_interval('?', 'DAY')." AND who=?", undef, $lastdays-1, $userid);
($vars->{prevdate1}) = $dbh->selectrow_array("SELECT DATE(MAX(bug_when)) FROM longdescs WHERE bug_when < CURRENT_DATE AND who=?", undef, $userid);

$vars->{totaltime} ||= 0;

$template->process('worktime/todaybugs.html.tmpl', $vars)
    || ThrowTemplateError($template->error());

exit;
