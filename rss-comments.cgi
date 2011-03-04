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
    user   => $user
);

my $sqlquery = $search->getSQL();
$sqlquery =~ s/ORDER\s+BY\s+`?bugs`?.`?bug_id`?//so;

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

# Monstrous query
# first query gets new bugs' descriptions, and any comments added (not including duplicate information)
# second query gets any changes to the fields of a bug (eg assignee, status etc)

my ($join1, $join2) = ("($sqlquery)", "($sqlquery)");
if ($dbh->isa('Bugzilla::DB::Mysql'))
{
    # MySQL query optimizer is stupid and often fails
    # to execute complex queries optimally, so help it with a temporary table
    $join1 = '_rss_comments_1';
    $join2 = '_rss_comments_2';
    $dbh->do("CREATE TEMPORARY TABLE $join1 AS $sqlquery");
    $dbh->do("CREATE TEMPORARY TABLE $join2 AS SELECT * FROM $join1");
}

my $bugsquery = "
 (SELECT
    b.bug_id, b.short_desc, pr.name product, cm.name component, b.bug_severity, b.bug_status,
    l.work_time, l.thetext,
    ".$dbh->sql_date_format('l.bug_when', '%Y%m%d%H%i%s')." commentlink,
    ".$dbh->sql_date_format('l.bug_when', '%a, %d %b %Y %H:%i:%s '.$tz)." datetime_rfc822,
    l.bug_when,
    p.login_name, p.realname,
    NULL AS fieldname, NULL AS fielddesc, NULL AS attach_id, NULL AS old, NULL AS new,
    (b.creation_ts=l.bug_when) as is_new, l.who
 FROM longdescs l
 INNER JOIN $join1 bugids ON l.bug_id=bugids.bug_id
 LEFT JOIN bugs b ON b.bug_id=l.bug_id
 LEFT JOIN profiles p ON p.userid=l.who
 LEFT JOIN products pr ON pr.id=b.product_id
 LEFT JOIN components cm ON cm.id=b.component_id
 WHERE l.isprivate=0 ".($who ? " AND l.who=".$who->id : "")."
 ORDER BY l.bug_when DESC
 LIMIT $limit)

 UNION ALL

 (SELECT
    b.bug_id, b.short_desc, pr.name product, cm.name component, b.bug_severity, b.bug_status,
    0 AS work_time, '' thetext,
    ".$dbh->sql_date_format('a.bug_when', '%Y%m%d%H%i%s')." commentlink,
    ".$dbh->sql_date_format('a.bug_when', '%a, %d %b %Y %H:%i:%s '.$tz)." datetime_rfc822,
    a.bug_when,
    p.login_name, p.realname,
    f.name AS fieldname, f.description AS fielddesc, a.attach_id, a.removed AS old, a.added AS new,
    0=1 as is_new, a.who
 FROM bugs_activity a
 INNER JOIN $join2 bugids ON a.bug_id=bugids.bug_id
 LEFT JOIN bugs b ON b.bug_id=a.bug_id
 LEFT JOIN profiles p ON p.userid=a.who
 LEFT JOIN products pr ON pr.id=b.product_id
 LEFT JOIN components cm ON cm.id=b.component_id
 LEFT JOIN fielddefs f ON f.id=a.fieldid
 LEFT JOIN attachments at ON at.attach_id=a.attach_id
 WHERE (at.isprivate IS NULL OR at.isprivate=0) ".($who ? " AND a.who=".$who->id : "")."
 ORDER BY a.bug_when DESC, f.name ASC
 LIMIT $limit)

 ORDER BY bug_when DESC
 LIMIT $limit
";

my $events = $dbh->selectall_arrayref($bugsquery, {Slice => {}});

if ($dbh->isa('Bugzilla::DB::Mysql'))
{
    $dbh->do("DROP TABLE $join1");
    $dbh->do("DROP TABLE $join2");
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
