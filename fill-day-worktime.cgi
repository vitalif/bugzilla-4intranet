#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
# ------------------------------------------------------------------------
# For Bug 12253

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Search;
use Bugzilla::Constants;

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
    if (@idlist)
    {
        foreach my $id (@idlist)
        {
            my $wtime    = $cgi->param("wtime_$id");
            my $newrtime = $cgi->param("newrtime_$id");
            my $comment  = $cgi->param("comm_$id");
            ProcessBug($dbh, $id, $wtime, $comment, $newrtime);
        }
    }
    if (@lines)
    {
        foreach my $line (@lines)
        {
            if ($line =~ m/\s*(\d?\d.\d\d.[1-9]?\d?\d\d\s)?\s*((\d?\d):(\d\d)\s*-\s*(\d?\d):(\d\d)\s+)?([\w\/]+)\s*(-\s*(BUG|\()?\s*([1-9]\d*)(.*))?/iso)
            {
                my $wtime = (($5 * 60 + $6) - ($3 * 60 + $4)) / 60;
                $wtime = 0 if $wtime < 0;
                my $id      = $10;
                my $comment = $line;
                ProcessBug($dbh, $id, $wtime, $comment);
            }
        }
    }
    print $cgi->redirect(-location => "fill-day-worktime.cgi?lastdays=" . $lastdays);
    exit;
}

print $cgi->header();

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

my $bugsquery = "
 SELECT t.bug_id, t.priority, t.short_desc, p.name product, c.name component,
  ROUND(t.remaining_time,1) remaining_time, ROUND(SUM(l.work_time),2) all_work_time,
  ROUND(SUM(IF(l.bug_when > CONCAT(DATE_SUB(CURDATE(),INTERVAL $lastdays DAY),' 23:59:59')
  AND l.who=$userid,l.work_time,0)),2) today_work_time
 FROM (
  SELECT bugs.bug_id, bugs.priority, bugs.short_desc, bugs.remaining_time, bugs.product_id, bugs.component_id FROM longdescs ll, bugs
  WHERE ll.bug_when > CONCAT(DATE_SUB(CURDATE(),INTERVAL $lastdays DAY),' 23:59:59') AND ll.who=$userid AND ll.bug_id=bugs.bug_id
  UNION
  SELECT bugs.bug_id, bugs.priority, bugs.short_desc, bugs.remaining_time, bugs.product_id, bugs.component_id FROM bugs_activity aa, bugs
  WHERE aa.bug_when > CONCAT(DATE_SUB(CURDATE(),INTERVAL $lastdays DAY),' 23:59:59') AND aa.who=$userid AND aa.bug_id=bugs.bug_id
  $sqlquery
 ) t, longdescs l, products p, components c
 WHERE t.bug_id = l.bug_id AND t.product_id=p.id AND t.component_id=c.id
 GROUP BY t.bug_id
 ORDER BY today_work_time DESC, priority ASC
 ";

$vars->{bugs} = $dbh->selectall_arrayref($bugsquery, {Slice=>{}}) || [];

($vars->{timestamp}) = $dbh->selectrow_array("SELECT NOW()");
($vars->{totaltime}) = $dbh->selectrow_array("SELECT ROUND(SUM(work_time),2) FROM longdescs WHERE bug_when > CONCAT(DATE_SUB(CURDATE(),INTERVAL ? DAY),' 23:59:59') AND who=?", undef, $lastdays, $userid);
($vars->{prevdate1}) = $dbh->selectrow_array("SELECT DATE(MAX(bug_when)) FROM longdescs WHERE bug_when < CURDATE() AND who=?", undef, $userid);

$vars->{totaltime} ||= 0;

$template->process('worktime/todaybugs.html.tmpl', $vars)
    || ThrowTemplateError($template->error());

exit;

sub ProcessBug
{
    my ($dbh, $id, $wtime, $comment, $newrtime) = @_;
    return unless $id;
    $dbh->bz_start_transaction();
    my $bug = new Bugzilla::Bug ($id);

    my $remaining_time = $bug->remaining_time;
    $newrtime = $remaining_time - $wtime;
    $newrtime = 0 if $newrtime < 0;

    $bug->add_comment($comment || "Fix worktime", { work_time => $wtime })
        if $comment || $wtime;
    $bug->remaining_time($newrtime) if $newrtime != $remaining_time;
    $bug->update();
    $dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id=?', undef, $bug->id);

    $dbh->bz_commit_transaction();
}
