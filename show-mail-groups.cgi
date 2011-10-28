#!/usr/bin/perl -wT
# CustIS Bug 12253

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::User;
use Bugzilla::Config;
use Bugzilla::Constants;
use Bugzilla::Auth;
use Bugzilla::Util;

Bugzilla->login(LOGIN_REQUIRED);

my $cgi      = Bugzilla->cgi;
my $template = Bugzilla->template;
my $dbh      = Bugzilla->dbh;
my $user     = Bugzilla->user;
my $userid   = $user->id;

my $sql = "SELECT DISTINCT userid, login_name, realname FROM profiles WHERE realname LIKE ? ORDER BY 2";
my @bind = ("Группа%");

my $vars = {};
$vars->{users} = $dbh->selectall_arrayref($sql, {Slice=>{}}, @bind);

$sql =
"SELECT profiles.login_name FROM profiles, watch
WHERE profiles.userid=watch.watcher AND watch.watched=?
ORDER BY
    SUBSTR(profiles.login_name, ".$dbh->sql_position("'\@'", 'profiles.login_name')."+1),
    SUBSTR(profiles.login_name, 1, ".$dbh->sql_position("'\@'", 'profiles.login_name').")";

foreach my $user (@{$vars->{users}})
{
    my $users_in_group = $dbh->selectcol_arrayref($sql, undef, $user->{userid});
    $user->{list} = join ', ', @$users_in_group;
}

$template->process('list-of-mail-groups.html.tmpl', $vars)
    || ThrowTemplateError($template->error());
exit;
