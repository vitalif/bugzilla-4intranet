#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
# ------------------------------------------------------------------------
# For Bug 16210

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Search;

use POSIX qw(strftime);

my $user      = Bugzilla->login(LOGIN_REQUIRED);
my $userid    = $user->id;
my $vars      = {};

my $cgi       = Bugzilla->cgi;
my $template  = Bugzilla->template;
my $dbh       = Bugzilla->dbh;

$vars->{selfurl} = $cgi->canonicalise_query();
$vars->{escapetags} = $cgi->param('escapetags');
$vars->{buginfo} = $cgi->param('buginfo');

my $title = $cgi->param('namedcmd');
if ($title)
{
    my $storedquery = Bugzilla::Search::LookupNamedQuery($title, $userid);
    $cgi = new Bugzilla::CGI($storedquery);
}

$title ||= $cgi->param('query_based_on') || "Bugs";

my $queryparams = new Bugzilla::CGI($cgi);
$vars->{urlquerypart} = $queryparams->canonicalise_query('order', 'cmdtype', 'query_based_on');

my $search = new Bugzilla::Search(
    params => $queryparams,
    fields => [ "bug_id" ],
    user   => $user
);

my $sqlquery = $search->getSQL();
$sqlquery =~ s/GROUP\s+BY\s+`?bugs`?.`?bug_id`?//so;

my $tz = strftime('%z', localtime);

# Monstrous query
# first query gets new bugs' descriptions, and any comments added (not including duplicate
# information).
# second query gets any changes to the fields of a bug (eg assignee, status etc)

my $bugsquery = "
 SELECT
    b.bug_id, b.short_desc, pr.name product, cm.name component, b.bug_severity, b.bug_status,
    l.work_time, l.thetext, DATE_FORMAT(l.bug_when,'%Y%m%d%H%i%s') AS commentlink,
    DATE_FORMAT(l.bug_when,'%Y-%m-%dT%H:%iZ') AS bug_when,
    DATE_FORMAT(l.bug_when,'%a, %d %b %Y %H:%i:%s $tz') AS datetime_rfc822,
    l.bug_when AS `when`, p.login_name, p.realname,
    NULL AS fieldname, NULL AS fielddesc, NULL AS attach_id, NULL AS old, NULL AS new,
    (b.creation_ts=l.bug_when) as is_new
 FROM bugs b, longdescs l, profiles p, products pr, components cm
 WHERE l.isprivate=0 AND b.bug_id IN ($sqlquery) AND b.bug_id=l.bug_id
    AND l.who=p.userid AND pr.id=b.product_id AND cm.id=b.component_id

 UNION ALL

 SELECT
    b.bug_id, b.short_desc, pr.name AS product, cm.name AS component, b.bug_severity, b.bug_status,
    0 AS work_time, '' AS thetext, DATE_FORMAT(a.bug_when,'%Y%m%d%H%i%s') AS commentlink,
    DATE_FORMAT(a.bug_when,'%Y-%m-%dT%H:%iZ') bug_when,
    DATE_FORMAT(a.bug_when,'%a, %d %b %Y %H:%i:%s $tz') datetime_rfc822,
    a.bug_when AS `when`, p.login_name, p.realname,
    f.name AS fieldname, f.description AS fielddesc, a.attach_id, a.removed AS old, a.added AS new,
    0 as is_new
 FROM bugs b
 JOIN bugs_activity a ON a.bug_id=b.bug_id
 JOIN profiles p ON p.userid=a.who
 JOIN products pr ON pr.id=b.product_id
 JOIN components cm ON cm.id=b.component_id
 JOIN fielddefs f ON f.id=a.fieldid
 LEFT JOIN attachments at ON at.attach_id=a.attach_id
 WHERE b.bug_id IN ($sqlquery) AND (at.isprivate IS NULL OR at.isprivate=0)

 ORDER BY `when` DESC
 LIMIT 100
";

$vars->{events} = $dbh->selectall_arrayref($bugsquery, {Slice => {}});

my ($t, $o, $n);
foreach (@{$vars->{events}})
{
    if ($_->{fieldname})
    {
        # this is not a comment; this is bugs_activity
        $_->{fielddesc} =~ s/^(Attachment\s+)?/Attachment #$_->{attach_id} /
            if $_->{attach_id};
        if ($_->{fieldname} eq 'estimated_time' ||
            $_->{fieldname} eq 'remaining_time')
        {
            $_->{old} = format_time_decimal($_->{old});
            $_->{new} = format_time_decimal($_->{new});
        }
        $o = 1 && length $_->{old};
        $n = 1 && length $_->{new};
        $t = "Changed '$_->{fielddesc}' from '$_->{old}' to '$_->{new}'" if $o && $n;
        $t = "Added to '$_->{fielddesc}': '$_->{new}'" if !$o && $n;
        $t = "Removed '$_->{fielddesc}': '$_->{old}'" if $o && !$n;
        $_->{thetext} = $t;
    }
}

$vars->{title} = $title;
($vars->{builddate}) = $dbh->selectrow_array("SELECT DATE_FORMAT(NOW(),'%a, %d %b %Y %H:%i:%s $tz')");

print $cgi->header(-type => 'text/xml');
$template->process('list/comments.rss.tmpl', $vars)
    || ThrowTemplateError($template->error());

exit;
