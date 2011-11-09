#!/usr/bin/perl -wT
# CustIS Bug 16210 - Bug comments and activity RSS feed

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::User;
use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Search;
use Bugzilla::Search::Saved;

use POSIX;

my $user      = Bugzilla->login(LOGIN_REQUIRED);
my $vars      = {};

my $cgi       = Bugzilla->cgi;
my $template  = Bugzilla->template;
my $dbh       = Bugzilla->dbh;

$vars->{selfurl} = $cgi->canonicalise_query();
$vars->{buginfo} = $cgi->param('buginfo');

# See http://lib.custis.ru/ShowTeamWork for &ctype=showteamwork
our %FORMATS = map { $_ => 1 } qw(rss showteamwork);

my $who = $cgi->param('who');

my $limit;
my $format = $cgi->param('ctype');
trick_taint($format);
$FORMATS{$format} or $format = 'rss';

# Determine activity limit (100 by default)
$limit = int($cgi->param('limit')) if $format eq 'showteamwork';
$limit = 100 if !$limit || $limit < 1;

my $title = $cgi->param('namedcmd');
if ($title)
{
    my $storedquery = Bugzilla::Search::LookupNamedQuery($title, $user->id);
    $cgi = new Bugzilla::CGI($storedquery);
}

$title ||= $cgi->param('query_based_on') || "Bugs";

my $queryparams = new Bugzilla::CGI($cgi);
$vars->{urlquerypart} = $queryparams->canonicalise_query('order', 'cmdtype', 'query_based_on');

# Create Bugzilla::Search
my $search = new Bugzilla::Search(
    params => $queryparams,
    fields => [ "bug_id" ],
);

my $sqlquery = $search->bugid_query;

my $tz = POSIX::strftime('%z', localtime);

# Get feed build date BEFORE reading items
($vars->{builddate}) = $dbh->selectrow_array('SELECT '.$dbh->sql_date_format('NOW()', '%a, %d %b %Y %H:%i:%s '.$tz));

if ($who)
{
    if ($who =~ /^(\d+)$/so)
    {
        $who = Bugzilla::User->new($1);
    }
    else
    {
        $who = Bugzilla::User->new({ name => $who });
    }
}

my ($join, $subq, $lhint) = ("($sqlquery)", "=i.bug_id", "");
if ($dbh->isa('Bugzilla::DB::Mysql'))
{
    # Help MySQL to select the optimal way of calculating (bug_id IN (...)):
    # "From inside to outside" or vice versa
    # Plus, wrap the inner query into a temp table, as it's calculated nevertheless
    $join = "_rssc1";
    $lhint = $who ? "USE INDEX (longdescs_who_bug_when_idx)" : "USE INDEX (longdescs_bug_when_idx)";
    $dbh->do("CREATE TEMPORARY TABLE _rssc1 AS $sqlquery");
    $dbh->do("CREATE INDEX _rssc1_bug_id ON _rssc1 (bug_id)");
    if ($who)
    {
        my ($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM $join i");
        if ($count > 500)
        {
            $subq = $join eq '_rssc1' ? " IN (SELECT * FROM $join)" : " IN $join";
            $join = "";
        }
    }
}

# Monstrous queries
$join = "INNER JOIN $join i" if $join;

# First query gets new bugs' descriptions, and any comments added (not including duplicate information)
# Worktime-only comments are excluded
my $longdescs = $dbh->selectall_arrayref(
"SELECT
    b.bug_id, b.short_desc, pr.name product, cm.name component, b.bug_severity, b.bug_status,
    l.work_time, l.thetext,
    ".$dbh->sql_date_format('l.bug_when', '%Y%m%d%H%i%s')." commentlink,
    ".$dbh->sql_date_format('l.bug_when', '%a, %d %b %Y %H:%i:%s '.$tz)." datetime_rfc822,
    l.bug_when,
    p.login_name, p.realname,
    '' AS fieldname, '' AS fielddesc, '' AS attach_id, '' AS old, '' AS new,
    (b.creation_ts=l.bug_when) as is_new, l.who
 FROM longdescs l $lhint
 $join
 LEFT JOIN bugs b ON b.bug_id=l.bug_id
 LEFT JOIN profiles p ON p.userid=l.who
 LEFT JOIN products pr ON pr.id=b.product_id
 LEFT JOIN components cm ON cm.id=b.component_id
 WHERE l.isprivate=0 ".($who ? " AND l.who=".$who->id : "")."
    AND l.bug_id$subq AND l.type!=".CMT_WORKTIME." AND l.type!=".CMT_BACKDATED_WORKTIME."
 ORDER BY l.bug_when DESC
 LIMIT $limit", {Slice=>{}});

# Second query gets any changes to the fields of a bug (eg assignee, status etc)
my $activity = $dbh->selectall_arrayref(
"SELECT
    b.bug_id, b.short_desc, pr.name product, cm.name component, b.bug_severity, b.bug_status,
    0 AS work_time, '' thetext,
    ".$dbh->sql_date_format('a.bug_when', '%Y%m%d%H%i%s')." commentlink,
    ".$dbh->sql_date_format('a.bug_when', '%a, %d %b %Y %H:%i:%s '.$tz)." datetime_rfc822,
    a.bug_when,
    p.login_name, p.realname,
    f.name AS fieldname, f.description AS fielddesc, a.attach_id, a.removed AS old, a.added AS new,
    0=1 as is_new, a.who
 FROM bugs_activity a
 $join
 LEFT JOIN bugs b ON b.bug_id=a.bug_id
 LEFT JOIN profiles p ON p.userid=a.who
 LEFT JOIN products pr ON pr.id=b.product_id
 LEFT JOIN components cm ON cm.id=b.component_id
 LEFT JOIN fielddefs f ON f.id=a.fieldid
 LEFT JOIN attachments at ON at.attach_id=a.attach_id
 WHERE at.isprivate=0 ".($who ? " AND a.who=".$who->id : "")." AND a.bug_id$subq
 ORDER BY a.bug_when DESC, f.name ASC
 LIMIT $limit", {Slice=>{}});

my $events = [ sort {
    ($b->{bug_when} cmp $a->{bug_when}) ||
    ($a->{fieldname} cmp $b->{fieldname})
} @$longdescs, @$activity ];

if ($dbh->isa('Bugzilla::DB::Mysql'))
{
    $dbh->do("DROP TABLE IF EXISTS _rssc1");
}

my ($t, $o, $n, $k);
my $gkeys = [];
my $group = {};
foreach (@$events)
{
    # Group changes by bug_id, bug_when and who
    $k = $_->{bug_id}.$_->{bug_when}.$_->{who};
    if (!$group->{$k})
    {
        push @$gkeys, $k;
        $group->{$k} = [];
    }
    push @{$group->{$k}}, $_;
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

# Concatenate comments with activity information
$vars->{events} = [];
foreach $k (@$gkeys)
{
    my $ev;
    foreach (sort { ($a->{fieldname}?1:0) cmp ($b->{fieldname}?1:0) } @{$group->{$k}})
    {
        $ev = $_, next if !$ev;
        $ev->{work_time} += $_->{work_time};
        if ($_->{fieldname})
        {
            push @{$ev->{changes}}, {
                name => $_->{fieldname},
                desc => $_->{fielddesc},
                old  => $_->{old},
                new  => $_->{new},
            };
            $ev->{changetext} .= "\n" . $_->{thetext};
        }
        else
        {
            $ev->{thetext} .= "\n" . $_->{thetext};
        }
    }
    push @{$vars->{events}}, $ev;
}

# Output feed title
$vars->{title} = $title;

Bugzilla->cgi->send_header(-type => 'text/xml');
$template->process('list/comments.'.$format.'.tmpl', $vars)
    || ThrowTemplateError($template->error());

exit;
