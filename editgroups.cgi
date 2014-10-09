#!/usr/bin/perl -wT
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Dave Miller <justdave@syndicomm.com>
#                 Joel Peshkin <bugreport@peshkin.net>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 Vlad Dascalu <jocuri@softhome.net>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Constants;
use Bugzilla::Config qw(:admin);
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Product;
use Bugzilla::User;
use Bugzilla::Token;
use Bugzilla::Views;

use constant SPECIAL_GROUPS => ('chartgroup', 'insidergroup', 'timetrackinggroup', 'querysharegroup');

my $ARGS = Bugzilla->input_params;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $action = trim($ARGS->{action} || '');
my $token  = $ARGS->{token};

# CheckGroupRegexp checks that the regular expression is valid
# (the regular expression being optional, the test is successful
# if none is given, as expected). The trimmed regular expression
# is returned.

sub CheckGroupRegexp
{
    my ($regexp) = @_;
    $regexp = trim($regexp || '');
    trick_taint($regexp);
    ThrowUserError("invalid_regexp") unless (eval {qr/$regexp/});
    return $regexp;
}

# A helper for displaying the edit.html.tmpl template.
sub get_current_and_available
{
    my ($group, $vars) = @_;

    my @all_groups         = Bugzilla::Group->get_all;
    my $members_current    = { map { $_->id => $_ } @{$group->grant_direct(GROUP_MEMBERSHIP)} };
    my $member_of_current  = { map { $_->id => $_ } @{$group->granted_by_direct(GROUP_MEMBERSHIP)} };
    my $bless_from_current = { map { $_->id => $_ } @{$group->grant_direct(GROUP_BLESS)} };
    my $bless_to_current   = { map { $_->id => $_ } @{$group->granted_by_direct(GROUP_BLESS)} };
    my ($visible_from_current, $visible_to_me_current);
    if (Bugzilla->params->{usevisibilitygroups})
    {
        $visible_from_current  = { map { $_->id => $_ } @{$group->grant_direct(GROUP_VISIBLE)} };
        $visible_to_me_current = { map { $_->id => $_ } @{$group->granted_by_direct(GROUP_VISIBLE)} };
    }

    # Figure out what groups are not currently a member of this group,
    # and what groups this group is not currently a member of.
    my (@members_available, @member_of_available,
        @bless_from_available, @bless_to_available,
        @visible_from_available, @visible_to_me_available);
    foreach my $group_option (@all_groups)
    {
        if (Bugzilla->params->{usevisibilitygroups})
        {
            push @visible_from_available, $group_option if !$visible_from_current->{$group_option->id};
            push @visible_to_me_available, $group_option if !$visible_to_me_current->{$group_option->id};
        }

        push @bless_from_available, $group_option if !$bless_from_current->{$group_option->id};

        # The group itself should never show up in the membership lists,
        # and should show up in only one of the bless lists (otherwise
        # you can try to allow it to bless itself twice, leading to a
        # database unique constraint error).
        next if $group_option->id == $group->id;

        push @members_available, $group_option if !$members_current->{$group_option->id};
        push @member_of_available, $group_option if !$member_of_current->{$group_option->id};
        push @bless_to_available, $group_option if !$bless_to_current->{$group_option->id};
    }

    $vars->{members_current}     = [ values %$members_current ];
    $vars->{members_available}   = \@members_available;
    $vars->{member_of_current}   = [ values %$member_of_current ];
    $vars->{member_of_available} = \@member_of_available;

    $vars->{bless_from_current}   = [ values %$bless_from_current ];
    $vars->{bless_from_available} = \@bless_from_available;
    $vars->{bless_to_current}     = [ values %$bless_to_current ];
    $vars->{bless_to_available}   = \@bless_to_available;

    if (Bugzilla->params->{usevisibilitygroups})
    {
        $vars->{visible_from_current}    = [ values %$visible_from_current ];
        $vars->{visible_from_available}  = \@visible_from_available;
        $vars->{visible_to_me_current}   = [ values %$visible_to_me_current ];
        $vars->{visible_to_me_available} = \@visible_to_me_available;
    }
}

# If no action is specified, get a list of groups the current user can bless
# so he can enter 'editusersingroup' for them, or the list of all groups
# available if he has 'creategroups' permissions.

$vars->{allow_edit} = $user->in_group('creategroups');

unless ($action)
{
    ListGroups($vars);
    exit;
}

# All other actions are protected by the 'creategroups' permission.

$vars->{allow_edit} || ThrowUserError("auth_failure", {
    group  => "creategroups",
    action => "edit",
    object => "groups",
});

#
# action='changeform' -> present form for altering an existing group
#
# (next action will be 'postchanges')
#
if ($action eq 'changeform')
{
    # Check that an existing group ID is given
    my $group = Bugzilla::Group->check({ id => $ARGS->{group} });

    get_current_and_available($group, $vars);
    $vars->{group} = $group;
    $vars->{token} = issue_session_token('edit_group');

    $template->process("admin/groups/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='add' -> present form for parameters for new group
#
# (next action will be 'new')
#
if ($action eq 'add')
{
    $vars->{token} = issue_session_token('add_group');
    $template->process("admin/groups/create.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='new' -> add group entered in the 'action=add' screen
#
if ($action eq 'new')
{
    check_token_data($token, 'add_group');
    my $group = Bugzilla::Group->create({
        name        => $ARGS->{name},
        description => $ARGS->{desc},
        userregexp  => $ARGS->{regexp},
        isactive    => $ARGS->{isactive},
        icon_url    => $ARGS->{icon_url},
        isbuggroup  => 1,
    });

    # Permit all existing products to use the new group.
    if ($ARGS->{insertnew})
    {
        $dbh->do(
            'INSERT INTO group_control_map (group_id, product_id, membercontrol, othercontrol)'.
            ' SELECT ?, products.id, ?, ? FROM products',
            undef, $group->id, CONTROLMAPSHOWN, CONTROLMAPNA
        );
    }

    Bugzilla::Hook::process('editgroups-post_create', { group => $group });

    delete_token($token);

    $vars->{message} = 'group_created';
    $vars->{group} = $group;
    get_current_and_available($group, $vars);
    $vars->{token} = issue_session_token('edit_group');

    $template->process("admin/groups/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='del' -> ask if user really wants to delete
#
# (next action would be 'delete')
#
if ($action eq 'del')
{
    # Check that an existing group ID is given
    my $group = Bugzilla::Group->check({ id => $ARGS->{group} });
    $group->check_remove({ test_only => 1 });
    $vars->{shared_queries} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM namedquery_group_map WHERE group_id = ?', undef, $group->id
    );

    $vars->{group} = $group;
    $vars->{token} = issue_session_token('delete_group');

    $template->process("admin/groups/delete.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='delete' -> really delete the group
#
if ($action eq 'delete')
{
    check_token_data($token, 'delete_group');
    # Check that an existing group ID is given
    my $group = Bugzilla::Group->check({ id => $ARGS->{group} });
    $vars->{name} = $group->name;
    $group->remove_from_db({
        remove_from_users => $ARGS->{removeusers},
        remove_from_bugs  => $ARGS->{removebugs},
        remove_from_flags => $ARGS->{removeflags},
        remove_from_products => $ARGS->{unbind},
    });
    delete_token($token);

    Bugzilla::Hook::process('editgroups-post_delete', { group => $group });
    Bugzilla::Views::refresh_some_views();

    $vars->{message} = 'group_deleted';
    ListGroups($vars);
    exit;
}

#
# action='postchanges' -> update the groups
#
if ($action eq 'postchanges')
{
    check_token_data($token, 'edit_group');
    my $changes = doGroupChanges();

    Bugzilla::Hook::process('editgroups-post_edit', {});
    Bugzilla::Views::refresh_some_views();

    delete_token($token);

    my $group = Bugzilla::Group->check({ id => $ARGS->{group_id} });
    get_current_and_available($group, $vars);
    $vars->{message} = 'group_updated';
    $vars->{group}   = $group;
    $vars->{changes} = $changes;
    $vars->{token} = issue_session_token('edit_group');

    $template->process("admin/groups/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

if ($action eq 'confirm_remove')
{
    my $group = Bugzilla::Group->check({ id => $ARGS->{group_id} });
    $vars->{group} = $group;
    $vars->{regexp} = CheckGroupRegexp($ARGS->{regexp});
    $vars->{token} = issue_session_token('remove_group_members');
    $template->process('admin/groups/confirm-remove.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

if ($action eq 'remove_regexp')
{
    check_token_data($token, 'remove_group_members');
    # remove all explicit users from the group with
    # gid = $ARGS->{group} that match the regular expression
    # stored in the DB for that group or all of them period

    my $group  = Bugzilla::Group->check({ id => $ARGS->{group_id} });
    my $regexp = CheckGroupRegexp($ARGS->{regexp});

    $dbh->bz_start_transaction();

    my $users = $group->members_direct();
    my $sth_delete = $dbh->prepare("DELETE FROM user_group_map WHERE user_id = ? AND isbless = 0 AND group_id = ?");

    my @deleted;
    foreach my $member (@$users)
    {
        if ($regexp eq '' || $member->login =~ m/$regexp/i)
        {
            $sth_delete->execute($member->id, $group->id);
            push @deleted, $member;
        }
    }
    $dbh->bz_commit_transaction();

    $vars->{users}  = \@deleted;
    $vars->{regexp} = $regexp;

    Bugzilla::Hook::process('editgroups-post_remove_regexp', { deleted => \@deleted });
    Bugzilla::Views::refresh_some_views();

    delete_token($token);

    $vars->{message} = 'group_membership_removed';
    $vars->{group} = $group->name;

    ListGroups($vars);
    exit;
}

#
# No valid action found
#

ThrowCodeError("action_unrecognized", $vars);

# Helper sub to handle the making of changes to a group
sub doGroupChanges
{
    my $ARGS = Bugzilla->input_params;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    # Check that the given group ID is valid and make a Group.
    my $group = Bugzilla::Group->check({ id => $ARGS->{group_id} });

    if (defined $ARGS->{regexp})
    {
        $group->set_user_regexp($ARGS->{regexp});
    }

    if ($group->is_bug_group)
    {
        if (defined $ARGS->{name})
        {
            $group->set_name($ARGS->{name});
        }
        if (defined $ARGS->{desc})
        {
            $group->set_description($ARGS->{desc});
        }
        # Only set isactive if we came from the right form.
        if (defined $ARGS->{regexp})
        {
            $group->set_is_active($ARGS->{isactive});
        }
    }

    if (defined $ARGS->{icon_url})
    {
        $group->set_icon_url($ARGS->{icon_url});
    }

    my $changes = $group->update();

    my $sth_insert = $dbh->prepare(
        'INSERT INTO group_group_map (member_id, grantor_id, grant_type) VALUES (?, ?, ?)'
    );
    my $sth_delete = $dbh->prepare(
        'DELETE FROM group_group_map WHERE member_id = ? AND grantor_id = ? AND grant_type = ?'
    );

    # First item is the type, second is whether or not it's "reverse"
    # (granted_by) (see _do_add for more explanation).
    my %fields = (
        members       => [GROUP_MEMBERSHIP, 0],
        bless_from    => [GROUP_BLESS, 0],
        visible_from  => [GROUP_VISIBLE, 0],
        member_of     => [GROUP_MEMBERSHIP, 1],
        bless_to      => [GROUP_BLESS, 1],
        visible_to_me => [GROUP_VISIBLE, 1]
    );
    while (my ($field, $data) = each %fields)
    {
        _do_add($group, $changes, $sth_insert, "${field}_add", $data->[0], $data->[1]);
        _do_remove($group, $changes, $sth_delete, "${field}_remove", $data->[0], $data->[1]);
    }

    $dbh->bz_commit_transaction();
    return $changes;
}

sub _do_add
{
    my ($group, $changes, $sth_insert, $field, $type, $reverse) = @_;

    my $current;
    # $reverse means we're doing a granted_by--that is, somebody else
    # is granting us something.
    if ($reverse)
    {
        $current = $group->granted_by_direct($type);
    }
    else
    {
        $current = $group->grant_direct($type);
    }

    my $add_items = Bugzilla::Group->new_from_list([ list Bugzilla->input_params->{$field} ]);

    foreach my $add (@$add_items)
    {
        next if grep($_->id == $add->id, @$current);

        $changes->{$field} ||= [];
        push @{$changes->{$field}}, $add->name;
        # They go this direction for a normal "This group is granting
        # $add something."
        my @ids = ($add->id, $group->id);
        # But they get reversed for "This group is being granted something
        # by $add."
        @ids = reverse @ids if $reverse;
        $sth_insert->execute(@ids, $type);
    }
}

sub _do_remove
{
    my ($group, $changes, $sth_delete, $field, $type, $reverse) = @_;
    my $remove_items = Bugzilla::Group->new_from_list([ list Bugzilla->input_params->{$field} ]);

    foreach my $remove (@$remove_items)
    {
        my @ids = ($remove->id, $group->id);
        # See _do_add for an explanation of $reverse
        @ids = reverse @ids if $reverse;
        # Deletions always succeed and are harmless if they fail, so we
        # don't need to do any checks.
        $sth_delete->execute(@ids, $type);
        $changes->{$field} ||= [];
        push @{$changes->{$field}}, $remove->name;
    }
}

sub ListGroups
{
    my ($vars) = @_;
    my $groups = $vars->{allow_edit}
        ? [ Bugzilla::Group->get_all ]
        : Bugzilla->user->bless_groups;
    $vars->{all_groups} = $groups;
    $vars->{pergroup} = Bugzilla::Group->get_per_group_permissions;

    Bugzilla->template->process("admin/groups/list.html.tmpl", $vars)
        || ThrowTemplateError(Bugzilla->template->error());
    exit;
}
