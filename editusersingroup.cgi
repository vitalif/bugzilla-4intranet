#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Constants;
use Bugzilla::User;
use Bugzilla::Util;

my $vars;
my $cgi      = Bugzilla->cgi;
my $dbh      = Bugzilla->dbh;
my $user     = Bugzilla->login(LOGIN_REQUIRED);
my $template = Bugzilla->template;
my $userid   = $user->id;

unless ($user->in_group('creategroups'))
{
    ThrowUserError("auth_failure", {
        group  => "creategroups",
        action => "edit",
        object => "groups",
    });
}

# CheckGroupID checks that a positive integer is given and is
# actually a valid group ID. If all tests are successful, the
# trimmed group ID is returned.
sub CheckGroupID
{
    my ($group_id) = @_;
    $group_id = trim($group_id || 0);
    ThrowUserError("group_not_specified") unless $group_id;
    unless (detaint_natural($group_id) &&
        Bugzilla->dbh->selectrow_array("SELECT id FROM groups WHERE id = ?", undef, $group_id)
    ) {
        ThrowUserError("invalid_group_ID");
    }
    return $group_id;
}

sub get_users_from_group
{
    my ($group_id) = @_;
    my %users;

    my $dbh = Bugzilla->dbh;
    my $sql =
        "SELECT p.userid, p.login_name, p.realname, m.isbless, m.grant_type" .
        " FROM user_group_map m, profiles p" .
        " WHERE m.user_id = p.userid AND m.group_id = ?" .
        " AND trim(p.disabledtext) = '' ORDER BY p.login_name";

    my $rows = $dbh->selectall_arrayref($sql, {Slice=>{}}, $group_id);
    foreach my $g (@$rows)
    {
        my $gg = ($users{$g->{login_name}} ||= $g);
        if ($g->{grant_type} == GRANT_DIRECT)
        {
            $gg->{direct_char} = '.' unless exists $gg->{direct_char};
            $gg->{direct_char} = 'S' if $g->{isbless};
        }
        if ($g->{grant_type} == GRANT_REGEXP)
        {
            $gg->{regexp_char} = '.' unless exists $gg->{regexp_char};
            $gg->{regexp_char} = 'S' if $g->{isbless};
        }
    }

    return [ sort { $a->{login_name} cmp $b->{login_name} } values %users ];
}

my $group_id = CheckGroupID($cgi->param('group'));
my @users = split /(\s+,?\s*)/, $cgi->param('addusers');

if (@users)
{
    my @added;
    foreach my $user (@users)
    {
        my $userid = login_to_id($user);
        if ($userid)
        {
            $dbh->do(
                "INSERT IGNORE INTO user_group_map SET user_id=?, group_id=?, grant_type=?, isbless=?",
                undef, $userid, $group_id, GRANT_DIRECT, 0
            );
            push @added, $userid;
        }
    }
    Bugzilla::Hook::process('editusersingroup-post_add', { added_ids => \@added, group_id => $group_id });
    my $url = "editusersingroup.cgi?group=$group_id";
    print $cgi->redirect(-location => $url);
    exit;
}

my ($name, $description, $regexp, $isactive, $isbuggroup) =
    $dbh->selectrow_array(
        "SELECT name, description, userregexp, isactive, isbuggroup" .
        " FROM groups WHERE id=?", undef, $group_id
    );

$vars->{group_id}    = $group_id;
$vars->{name}        = $name;
$vars->{description} = $description;
$vars->{regexp}      = $regexp;
$vars->{isactive}    = $isactive;
$vars->{isbuggroup}  = $isbuggroup;
$vars->{users}       = get_users_from_group($group_id);
$vars->{user}        = $user;

$template->process("admin/groups/usersingroup.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
$template->process("global/footer.html.tmpl", $vars)
    || ThrowTemplateError($template->error());

1;
__END__
