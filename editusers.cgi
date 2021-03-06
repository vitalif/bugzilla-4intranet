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
# Contributor(s): Marc Schumann <wurblzap@gmail.com>
#                 Lance Larsh <lance.larsh@oracle.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 David Lawrence <dkl@redhat.com>
#                 Vlad Dascalu <jocuri@softhome.net>
#                 Gavin Shelley  <bugzilla@chimpychompy.org>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Bug;
use Bugzilla::BugMail;
use Bugzilla::Flag;
use Bugzilla::Field;
use Bugzilla::Group;
use Bugzilla::Token;
use Bugzilla::Views;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $ARGS = Bugzilla->input_params;
my $template  = Bugzilla->template;
my $dbh       = Bugzilla->dbh;
my $userid    = $user->id;
my $editusers = $user->in_group('editusers');
local our $vars = {};

# Reject access if there is no sense in continuing.
$editusers || $user->can_bless() || ThrowUserError("auth_failure", {
    group  => "editusers",
    reason => "cant_bless",
    action => "edit",
    object => "users",
});

# Common params
my $action      = $ARGS->{action} || 'search';
my $otherUserID = $ARGS->{userid};
my $token       = $ARGS->{token};

# Prefill template vars with data used in all or nearly all templates
$vars->{editusers} = $editusers;
mirrorListSelectionValues();

if ($action eq 'search')
{
    # Allow to restrict the search to any group the user is allowed to bless.
    $vars->{restrictablegroups} = $user->bless_groups();
    $template->process('admin/users/search.html.tmpl', $vars)
       || ThrowTemplateError($template->error());
}
elsif ($action eq 'list')
{
    my $matchvalue    = $ARGS->{matchvalue} || '';
    my $matchstr      = $ARGS->{matchstr};
    my $matchtype     = $ARGS->{matchtype};
    my $grouprestrict = $ARGS->{grouprestrict} || '0';
    my $query = 'SELECT DISTINCT userid, login_name, realname, is_enabled, ' .
        $dbh->sql_date_format('last_seen_date', '%Y-%m-%d') . ' AS last_seen_date ' .
        'FROM profiles';
    my @bindValues;
    my $nextCondition;
    my $visibleGroups;

    # If a group ID is given, make sure it is a valid one.
    my $group;
    if ($grouprestrict)
    {
        $group = new Bugzilla::Group($ARGS->{groupid});
        $group || ThrowUserError('invalid_group_ID');
    }

    if (!$editusers && Bugzilla->params->{usevisibilitygroups})
    {
        # Show only users in visible groups.
        $visibleGroups = $user->visible_groups_as_string();

        if ($visibleGroups)
        {
            $query .= ", user_group_map AS ugm WHERE ugm.user_id=profiles.userid".
                " AND ugm.isbless = 0 AND ugm.group_id IN ($visibleGroups)";
            $nextCondition = 'AND';
        }
    }
    else
    {
        $visibleGroups = 1;
        if ($grouprestrict eq '1')
        {
            $query .= ", user_group_map AS ugm WHERE ugm.user_id = profiles.userid AND ugm.isbless = 0";
            $nextCondition = 'AND';
        }
        else
        {
            $nextCondition = 'WHERE';
        }
    }

    if (!$visibleGroups)
    {
        $vars->{users} = {};
    }
    else
    {
        # Handle selection by login name, real name, or userid.
        if (defined($matchtype))
        {
            $query .= " $nextCondition ";
            my $expr = "";
            if ($matchvalue eq 'userid')
            {
                if ($matchstr)
                {
                    my $stored_matchstr = $matchstr;
                    detaint_natural($matchstr) || ThrowUserError('illegal_user_id', { userid => $stored_matchstr });
                }
                $expr = "profiles.userid";
            }
            elsif ($matchvalue eq 'realname')
            {
                $expr = "profiles.realname";
            }
            else
            {
                $expr = "profiles.login_name";
            }

            if ($matchstr =~ /^(regexp|notregexp|exact)$/)
            {
                $matchstr ||= '.';
            }
            else
            {
                $matchstr = '' unless defined $matchstr;
            }
            # We can trick_taint because we use the value in a SELECT only,
            # using a placeholder.
            trick_taint($matchstr);

            if ($matchtype eq 'regexp')
            {
                $query .= $dbh->sql_regexp($expr, '?', 0, $dbh->quote($matchstr));
            }
            elsif ($matchtype eq 'notregexp')
            {
                $query .= $dbh->sql_not_regexp($expr, '?', 0, $dbh->quote($matchstr));
            }
            elsif ($matchtype eq 'exact')
            {
                $query .= $expr . ' = ?';
            }
            else
            {
                # substr or unknown
                $query .= $dbh->sql_istrcmp($expr, '?', 'LIKE');
                $matchstr = "%$matchstr%";
            }
            $nextCondition = 'AND';
            push @bindValues, $matchstr;
        }

        # Handle selection by group.
        if ($grouprestrict eq '1')
        {
            my $grouplist = join ',', @{Bugzilla::Group->flatten_group_membership($group->id)};
            $query .= " $nextCondition ugm.group_id IN($grouplist) ";
        }
        $query .= ' ORDER BY profiles.login_name';

        $vars->{users} = $dbh->selectall_arrayref($query, {Slice=>{}}, @bindValues);
    }

    if ($matchtype && $matchtype eq 'exact' && scalar(@{$vars->{users}}) == 1)
    {
        edit_processing(Bugzilla::User->new({ id => $vars->{users}->[0]->{userid} }));
    }
    else
    {
        $template->process('admin/users/list.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
    }
}
elsif ($action eq 'add')
{
    $editusers || ThrowUserError("auth_failure", {
        group  => "editusers",
        action => "add",
        object => "users",
    });
    $vars->{token} = issue_session_token('add_user');
    $template->process('admin/users/create.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'new')
{
    $editusers || ThrowUserError("auth_failure", {
        group  => "editusers",
        action => "add",
        object => "users",
    });

    check_token_data($token, 'add_user');

    # When e.g. the 'Env' auth method is used, the password field
    # is not displayed. In that case, set the password to *.
    my $password = $ARGS->{password};
    $password = '*' if !defined $password;

    my $new_user = Bugzilla::User->create({
        login_name    => $ARGS->{login},
        cryptpassword => $password,
        realname      => $ARGS->{realname},
        disabledtext  => $ARGS->{disabledtext},
        disable_mail  => $ARGS->{disable_mail},
    });

    userDataToVars($new_user->id);

    delete_token($token);

    # We already display the updated page. We have to recreate a token now.
    $vars->{token} = issue_session_token('edit_user');
    $vars->{message} = 'account_created';
    $template->process('admin/users/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'edit')
{
    my $otherUser = Bugzilla::User->check({ id => $otherUserID });
    edit_processing($otherUser);
}
elsif ($action eq 'update')
{
    check_token_data($token, 'edit_user');
    my $otherUser = Bugzilla::User->check({ id => $otherUserID });
    $otherUserID = $otherUser->id;

    # Lock tables during the check+update session.
    $dbh->bz_start_transaction();

    $editusers || $user->can_see_user($otherUser)
        || ThrowUserError('auth_failure', {
            reason => "not_visible",
            action => "modify",
            object => "user",
        });

    $vars->{loginold} = $otherUser->login;

    # Update profiles table entry; silently skip doing this if the user
    # is not authorized.
    my $changes = {};
    if ($editusers)
    {
        $otherUser->set_login($ARGS->{login});
        $otherUser->set_realname($ARGS->{realname});
        $otherUser->set_password($ARGS->{password}) if $ARGS->{password};
        $otherUser->set_disabledtext($ARGS->{disabledtext});
        $otherUser->set_disable_mail($ARGS->{disable_mail});
        $changes = $otherUser->update();
    }

    my @groupsAddedTo;
    my @groupsRemovedFrom;
    my @groupsGrantedRightsToBless;
    my @groupsDeniedRightsToBless;

    # Regard only groups the user is allowed to bless and skip all others silently.
    userDataToVars($otherUserID);
    my $permissions = $vars->{permissions};
    foreach my $blessable (@{$user->bless_groups()})
    {
        my $id = $blessable->id;
        my $name = $blessable->name;

        # Change memberships.
        my $groupid = $ARGS->{"group_$id"} || 0;
        if ($groupid != $permissions->{$id}->{directmember})
        {
            if (!$groupid)
            {
                push @groupsRemovedFrom, $blessable;
            }
            else
            {
                push @groupsAddedTo, $blessable;
            }
        }

        # Only members of the editusers group may change bless grants.
        # Skip silently if this is not the case.
        if ($editusers)
        {
            my $groupid = $ARGS->{"bless_$id"} || 0;
            if ($groupid != $permissions->{$id}->{directbless})
            {
                if (!$groupid)
                {
                    push @groupsDeniedRightsToBless, $blessable;
                }
                else
                {
                    push @groupsGrantedRightsToBless, $blessable;
                }
            }
        }
    }

    Bugzilla::Group::add_user_groups([ map { { group => $_, user => $otherUser } } @groupsAddedTo ]);
    Bugzilla::Group::remove_user_groups([ map { { group => $_, user => $otherUser } } @groupsRemovedFrom ]);
    Bugzilla::Group::add_user_groups([ map { { group => $_, user => $otherUser } } @groupsGrantedRightsToBless ], 1);
    Bugzilla::Group::remove_user_groups([ map { { group => $_, user => $otherUser } } @groupsDeniedRightsToBless ], 1);

    $dbh->bz_commit_transaction();

    # FIXME: userDataToVars may be off when editing ourselves.
    userDataToVars($otherUserID);
    delete_token($token);

    Bugzilla::Hook::process('editusers-post_update', { userid => $otherUserID });
    Bugzilla::Views::refresh_some_views([ $otherUser->login ]);
    # Refresh fieldvaluecontrol cache
    Bugzilla->get_field('delta_ts')->touch;

    $vars->{message} = 'account_updated';
    $vars->{changed_fields} = [ keys %$changes ];
    $vars->{groups_added_to} = [ map { $_->name } @groupsAddedTo ];
    $vars->{groups_removed_from} = [ map { $_->name } @groupsRemovedFrom ];
    $vars->{groups_granted_rights_to_bless} = [ map { $_->name } @groupsGrantedRightsToBless ];
    $vars->{groups_denied_rights_to_bless} = [ map { $_->name } @groupsDeniedRightsToBless ];
    # We already display the updated page. We have to recreate a token now.
    $vars->{token} = issue_session_token('edit_user');

    $template->process('admin/users/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'del')
{
    my $otherUser = Bugzilla::User->check({ id => $otherUserID });
    $otherUserID = $otherUser->id;

    Bugzilla->params->{allowuserdeletion} || ThrowUserError('users_deletion_disabled');
    $editusers || ThrowUserError('auth_failure', {
        group  => "editusers",
        action => "delete",
        object => "users",
    });
    $vars->{otheruser} = $otherUser;

    # Find other cross references.
    $vars->{attachments} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM attachments WHERE submitter_id = ?',
        undef, $otherUserID
    );
    $vars->{assignee_or_qa} = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM bugs WHERE assigned_to = ? OR qa_contact = ?",
        undef, $otherUserID, $otherUserID
    );
    $vars->{reporter} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM bugs WHERE reporter = ?', undef, $otherUserID
    );
    $vars->{cc} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM cc WHERE who = ?', undef, $otherUserID
    );
    $vars->{bugs_activity} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM bugs_activity WHERE who = ?', undef, $otherUserID
    );
    $vars->{component_cc} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM component_cc WHERE user_id = ?', undef, $otherUserID
    );
    $vars->{email_setting} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM email_setting WHERE user_id = ?', undef, $otherUserID
    );
    $vars->{flags}{requestee} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM flags WHERE requestee_id = ?', undef, $otherUserID
    );
    $vars->{flags}{setter} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM flags WHERE setter_id = ?', undef, $otherUserID
    );
    $vars->{longdescs} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM longdescs WHERE who = ?', undef, $otherUserID
    );
    my $namedquery_ids = $dbh->selectcol_arrayref(
        'SELECT id FROM namedqueries WHERE userid = ?', undef, $otherUserID
    );
    $vars->{namedqueries} = scalar @$namedquery_ids;
    if (scalar(@$namedquery_ids))
    {
        $vars->{namedquery_group_map} = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM namedquery_group_map WHERE namedquery_id IN' .
            ' (' . join(', ', @$namedquery_ids) . ')');
    }
    else
    {
        $vars->{namedquery_group_map} = 0;
    }
    $vars->{profile_setting} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM profile_setting WHERE user_id = ?', undef, $otherUserID
    );
    $vars->{profiles_activity} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM profiles_activity WHERE who = ? AND userid != ?', undef, $otherUserID, $otherUserID
    );
    $vars->{quips} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM quips WHERE userid = ?', undef, $otherUserID
    );
    $vars->{series} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM series WHERE creator = ?', undef, $otherUserID
    );
    $vars->{votes} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM votes WHERE who = ?', undef, $otherUserID
    );
    $vars->{watch}{watched} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM watch WHERE watched = ?', undef, $otherUserID
    );
    $vars->{watch}{watcher} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM watch WHERE watcher = ?', undef, $otherUserID
    );
    $vars->{whine_events} = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM whine_events WHERE owner_userid = ?', undef, $otherUserID
    );
    $vars->{whine_schedules} = $dbh->selectrow_array(
        "SELECT COUNT(distinct eventid) FROM whine_schedules WHERE mailto = ? AND mailto_type = ?",
        undef, $otherUserID, MAILTO_USER
    );
    $vars->{token} = issue_session_token('delete_user');

    $template->process('admin/users/confirm-delete.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'delete')
{
    check_token_data($token, 'delete_user');
    my $otherUser = Bugzilla::User->check({ id => $otherUserID });
    $otherUserID = $otherUser->id;

    # Cache for user accounts.
    my %usercache = (0 => new Bugzilla::User());
    my %updatedbugs;

    # Lock tables during the check+removal session.
    # FIXME: if there was some change on these tables after the deletion
    # confirmation checks, we may do something here we haven't warned about.
    $dbh->bz_start_transaction();

    Bugzilla->params->{allowuserdeletion}
        || ThrowUserError('users_deletion_disabled');
    $editusers || ThrowUserError('auth_failure', {
        group  => "editusers",
        action => "delete",
        object => "users",
    });
    @{$otherUser->product_responsibilities()}
        && ThrowUserError('user_has_responsibility');

    Bugzilla->logout_user($otherUser);

    # Get the named query list so we can delete namedquery_group_map entries.
    my $namedqueries_as_string = join(', ', @{$dbh->selectcol_arrayref(
        'SELECT id FROM namedqueries WHERE userid = ?', undef, $otherUserID)});

    # Get the timestamp for LogActivityEntry.
    my $timestamp = $dbh->selectrow_array('SELECT NOW()');

    # When we update a bug_activity entry, we update the bug timestamp, too.
    my $sth_set_bug_timestamp = $dbh->prepare('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?');

    my $sth_updateFlag = $dbh->prepare(
        'INSERT INTO bugs_activity (bug_id, attach_id, who, bug_when, fieldid, removed, added)'.
        ' VALUES (?, ?, ?, ?, ?, ?, ?)'
    );

    # Flags
    my $flag_ids = $dbh->selectcol_arrayref(
        'SELECT id FROM flags WHERE requestee_id = ?', undef, $otherUserID
    );

    my $flags = Bugzilla::Flag->new_from_list($flag_ids);

    $dbh->do(
        'UPDATE flags SET requestee_id = NULL, modification_date = ?'.
        ' WHERE requestee_id = ?', undef, $timestamp, $otherUserID
    );

    # We want to remove the requestee but leave the requester alone,
    # so we have to log these changes manually.
    my %bugs;
    push @{$bugs{$_->bug_id}->{$_->attach_id || 0}}, $_ foreach @$flags;
    my $fieldid = Bugzilla->get_field('flagtypes.name')->id;
    foreach my $bug_id (keys %bugs)
    {
        foreach my $attach_id (keys %{$bugs{$bug_id}})
        {
            my @old_summaries = Bugzilla::Flag->snapshot($bugs{$bug_id}->{$attach_id});
            $_->_set_requestee() foreach @{$bugs{$bug_id}->{$attach_id}};
            my @new_summaries = Bugzilla::Flag->snapshot($bugs{$bug_id}->{$attach_id});
            my ($removed, $added) = Bugzilla::Flag->update_activity(\@old_summaries, \@new_summaries);
            $sth_updateFlag->execute(
                $bug_id, $attach_id || undef, $userid,
                $timestamp, $fieldid, $removed, $added
            );
        }
        $sth_set_bug_timestamp->execute($timestamp, $bug_id);
        $updatedbugs{$bug_id} = 1;
    }

    # Deletions in referred tables which need LogActivityEntry.
    my $buglist = $dbh->selectcol_arrayref('SELECT bug_id FROM cc WHERE who = ?', undef, $otherUserID);
    $dbh->do('DELETE FROM cc WHERE who = ?', undef, $otherUserID);
    foreach my $bug_id (@$buglist)
    {
        LogActivityEntry($bug_id, 'cc', $otherUser->login, '', $userid, $timestamp);
        $sth_set_bug_timestamp->execute($timestamp, $bug_id);
        $updatedbugs{$bug_id} = 1;
    }

    # Even more complex deletions in referred tables.
    my $id;

    # 3) Bugs
    # 3.1) fall back to the default assignee
    $buglist = $dbh->selectall_arrayref(
        'SELECT bug_id, initialowner FROM bugs'.
        ' INNER JOIN components ON components.id = bugs.component_id'.
        ' WHERE assigned_to = ?', undef, $otherUserID
    );

    my $sth_updateAssignee = $dbh->prepare('UPDATE bugs SET assigned_to = ?, delta_ts = ? WHERE bug_id = ?');

    foreach my $bug (@$buglist)
    {
        my ($bug_id, $default_assignee_id) = @$bug;
        $sth_updateAssignee->execute($default_assignee_id, $timestamp, $bug_id);
        $updatedbugs{$bug_id} = 1;
        $default_assignee_id ||= 0;
        $usercache{$default_assignee_id} ||= new Bugzilla::User($default_assignee_id);
        LogActivityEntry(
            $bug_id, 'assigned_to', $otherUser->login,
            $usercache{$default_assignee_id}->login,
            $userid, $timestamp
        );
    }

    # 3.2) fall back to the default QA contact
    $buglist = $dbh->selectall_arrayref(
        'SELECT bug_id, initialqacontact FROM bugs'.
        ' INNER JOIN components ON components.id = bugs.component_id'.
        ' WHERE qa_contact = ?', undef, $otherUserID
    );

    my $sth_updateQAcontact = $dbh->prepare('UPDATE bugs SET qa_contact = ?, delta_ts = ? WHERE bug_id = ?');
    foreach my $bug (@$buglist)
    {
        my ($bug_id, $default_qa_contact_id) = @$bug;
        $sth_updateQAcontact->execute($default_qa_contact_id, $timestamp, $bug_id);
        $updatedbugs{$bug_id} = 1;
        $default_qa_contact_id ||= 0;
        $usercache{$default_qa_contact_id} ||= new Bugzilla::User($default_qa_contact_id);
        LogActivityEntry(
            $bug_id, 'qa_contact', $otherUser->login,
            $usercache{$default_qa_contact_id}->login, $userid, $timestamp
        );
    }

    # Finally, remove the user account itself.
    $dbh->do('DELETE FROM profiles WHERE userid = ?', undef, $otherUserID);

    $dbh->bz_commit_transaction();
    delete_token($token);

    Bugzilla::Hook::process('editusers-post_delete', { userid => $otherUserID });
    Bugzilla::Views::refresh_some_views([ $otherUser->login ]);

    $vars->{message} = 'account_deleted';
    $vars->{otheruser}{login} = $otherUser->login;
    $vars->{restrictablegroups} = $user->bless_groups();
    $template->process('admin/users/search.html.tmpl', $vars)
        || ThrowTemplateError($template->error());

    # Send mail about what we've done to bugs.
    # The deleted user is not notified of the changes.
    foreach (keys(%updatedbugs))
    {
        # FIXME save this into session and redirect
        Bugzilla->add_result_message({
            type => 'bugmail',
            bug_id => $_,
            mailrecipients => { 'changer' => $user->login },
        });
    }
    Bugzilla->send_mail;
}
elsif ($action eq 'activity')
{
    my $otherUser = Bugzilla::User->check({ id => $otherUserID });
    $vars->{profile_changes} = $dbh->selectall_arrayref(
        "SELECT profiles.login_name AS who, " .
        $dbh->sql_date_format('profiles_activity.profiles_when') . " AS activity_when,".
        " fielddefs.name AS what, profiles_activity.oldvalue AS removed, profiles_activity.newvalue AS added".
        " FROM profiles_activity".
        " INNER JOIN profiles ON profiles_activity.who = profiles.userid".
        " INNER JOIN fielddefs ON fielddefs.id = profiles_activity.fieldid".
        " WHERE profiles_activity.userid = ?".
        " ORDER BY profiles_activity.profiles_when",
        {Slice=>{}}, $otherUser->id
    );
    $vars->{otheruser} = $otherUser;
    $template->process("account/profile-activity.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}
else
{
    $vars->{action} = $action;
    ThrowCodeError('action_unrecognized', $vars);
}

exit;

###########################################################################
# Helpers
###########################################################################

# Copy incoming list selection values from request params to template variables.
sub mirrorListSelectionValues
{
    my $ARGS = Bugzilla->input_params;
    if (defined $ARGS->{matchtype})
    {
        foreach('matchvalue', 'matchstr', 'matchtype', 'grouprestrict', 'groupid')
        {
            $vars->{listselectionvalues}{$_} = $ARGS->{$_};
        }
    }
}

# Retrieve user data for the user editing form. User creation and user
# editing code rely on this to call derive_groups().
sub userDataToVars
{
    my $otheruserid = shift;
    my $otheruser = new Bugzilla::User($otheruserid);
    my $query;
    my $user = Bugzilla->user;
    my $dbh = Bugzilla->dbh;

    my $grouplist = $otheruser->groups_as_string;

    $vars->{otheruser} = $otheruser;
    $vars->{groups} = $user->bless_groups();

    $vars->{permissions} = $dbh->selectall_hashref(
        "SELECT id, COUNT(directmember.group_id) AS directmember,".
        " COUNT(regexpmember.group_id) AS regexpmember,".
        " (CASE WHEN (groups.id IN ($grouplist)".
        " AND COUNT(directmember.group_id) = 0 AND COUNT(regexpmember.group_id) = 0".
        " ) THEN 1 ELSE 0 END) AS derivedmember,".
        " COUNT(directbless.group_id) AS directbless".
        " FROM groups".
        " LEFT JOIN user_group_map AS directmember".
        " ON directmember.group_id = id AND directmember.user_id = ?".
        " AND directmember.isbless = 0 AND directmember.grant_type = ?".
        " LEFT JOIN user_group_map AS regexpmember".
        " ON regexpmember.group_id = id AND regexpmember.user_id = ?".
        " AND regexpmember.isbless = 0 AND regexpmember.grant_type = ?".
        " LEFT JOIN user_group_map AS directbless".
        " ON directbless.group_id = id AND directbless.user_id = ?".
        " AND directbless.isbless = 1 AND directbless.grant_type = ?".
        " GROUP BY id",
        'id', undef, $otheruserid, GRANT_DIRECT,
        $otheruserid, GRANT_REGEXP, $otheruserid, GRANT_DIRECT
    );

    # Find indirect bless permission.
    $query = "SELECT groups.id FROM groups, group_group_map AS ggm".
        " WHERE groups.id = ggm.grantor_id AND ggm.member_id IN ($grouplist)".
        " AND ggm.grant_type = ? GROUP BY id";
    foreach (@{$dbh->selectall_arrayref($query, undef, GROUP_BLESS)})
    {
        # Merge indirect bless permissions into permission variable.
        $vars->{permissions}{${$_}[0]}{indirectbless} = 1;
    }
}

sub edit_processing
{
    my $otherUser = shift;
    my $user = Bugzilla->user;
    my $template = Bugzilla->template;

    $user->in_group('editusers') || $user->can_see_user($otherUser)
        || ThrowUserError('auth_failure', {
            reason => "not_visible",
            action => "modify",
            object => "user",
        });

    userDataToVars($otherUser->id);
    $vars->{token} = issue_session_token('edit_user');

    $template->process('admin/users/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
