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
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Alan Raetz <al_raetz@yahoo.com>
#                 David Miller <justdave@syndicomm.com>
#                 Christopher Aillon <christopher@aillon.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Vlad Dascalu <jocuri@softhome.net>
#                 Shane H. W. Travis <travis@sedsystems.ca>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Search;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Token;

my $template = Bugzilla->template;
local our $vars = {};

###############################################################################
# Each panel has two functions - panel Foo has a DoFoo, to get the data
# necessary for displaying the panel, and a SaveFoo, to save the panel's
# contents from the form data (if appropriate).
# SaveFoo may be called before DoFoo.
###############################################################################
sub DoAccount
{
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    ($vars->{realname}) = $dbh->selectrow_array(
        "SELECT realname FROM profiles WHERE userid = ?", undef, $user->id
    );

    if (Bugzilla->params->{allowemailchange} &&
        Bugzilla->user->authorizer->can_change_email)
    {
        # First delete old tokens.
        Bugzilla::Token::CleanTokenTable();
        my @token = $dbh->selectrow_array(
            "SELECT tokentype, " . $dbh->sql_date_math('issuedate', '+', MAX_TOKEN_AGE, 'DAY') . ", eventdata".
            " FROM tokens WHERE userid = ? AND tokentype LIKE 'email%'".
            " ORDER BY tokentype ASC " . $dbh->sql_limit(1), undef, $user->id
        );
        if (@token)
        {
            my ($tokentype, $change_date, $eventdata) = @token;
            $vars->{login_change_date} = $change_date;
            if ($tokentype eq 'emailnew')
            {
                my ($oldemail,$newemail) = split /:/, $eventdata;
                $vars->{new_login_name} = $newemail;
            }
        }
    }
}

sub SaveAccount
{
    my $ARGS = Bugzilla->input_params;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    my $oldpassword = $ARGS->{old_password};
    my $pwd1 = $ARGS->{new_password1};
    my $pwd2 = $ARGS->{new_password2};

    my $old_login_name = $user->login;
    my $new_login_name = trim($ARGS->{new_login_name});

    if ($user->authorizer->can_change_password && ($oldpassword ne "" || $pwd1 ne "" || $pwd2 ne ""))
    {
        my $oldcryptedpwd = $user->cryptpassword;
        $oldcryptedpwd || ThrowCodeError("unable_to_retrieve_password");

        if (bz_crypt($oldpassword, $oldcryptedpwd) ne $oldcryptedpwd)
        {
            ThrowUserError("old_password_incorrect");
        }

        if ($pwd1 ne "" || $pwd2 ne "")
        {
            $pwd1 || ThrowUserError("new_password_missing");
            Bugzilla::User::validate_password($pwd1, $pwd2);

            if ($oldpassword ne $pwd1)
            {
                my $cryptedpassword = bz_crypt($pwd1);
                $dbh->do(
                    "UPDATE profiles SET cryptpassword = ? WHERE userid = ?",
                    undef, $cryptedpassword, $user->id
                );
                # Invalidate all logins except for the current one
                Bugzilla->logout(LOGOUT_KEEP_CURRENT);
            }
        }
    }

    if ($user->authorizer->can_change_email && Bugzilla->params->{allowemailchange} && $new_login_name)
    {
        if ($old_login_name ne $new_login_name)
        {
            $oldpassword || ThrowUserError("old_password_required");

            # Block multiple email changes for the same user.
            if (Bugzilla::Token::HasEmailChangeToken($user->id))
            {
                ThrowUserError("email_change_in_progress");
            }

            # Before changing an email address, confirm one does not exist.
            validate_email_syntax($new_login_name)
                || ThrowUserError('illegal_email_address', { addr => $new_login_name });
            Bugzilla::User::is_available_username($new_login_name)
                || ThrowUserError("account_exists", { email => $new_login_name });

            Bugzilla::Token::IssueEmailChangeToken($user, $old_login_name, $new_login_name);

            $vars->{email_changes_saved} = 1;
        }
    }

    my $realname = trim($ARGS->{realname});
    trick_taint($realname); # Only used in a placeholder
    $dbh->do("UPDATE profiles SET realname = ? WHERE userid = ?", undef, $realname, $user->id);
}

sub DoSettings
{
    my $user = Bugzilla->user;

    my $settings = $user->settings;
    $vars->{settings} = $settings;

    my $descs = Bugzilla->messages->{setting_descs};
    my @setting_list = sort { lc $descs->{$a} cmp lc $descs->{$b} } keys %$settings;
    $vars->{setting_names} = \@setting_list;
    $vars->{has_settings_enabled} = 0;

    # Is there at least one user setting enabled?
    foreach my $setting_name (@setting_list)
    {
        if ($settings->{"$setting_name"}->{is_enabled})
        {
            $vars->{has_settings_enabled} = 1;
            last;
        }
    }

    $vars->{dont_show_button} = !$vars->{has_settings_enabled};
}

sub SaveSettings
{
    my $ARGS = Bugzilla->input_params;
    my $user = Bugzilla->user;

    my $settings = $user->settings;
    my @setting_list = keys %$settings;

    foreach my $name (@setting_list)
    {
        next if !$settings->{$name}->{is_enabled};
        my $value = $ARGS->{$name};
        next unless defined $value;
        my $setting = new Bugzilla::User::Setting($name);

        if ($value eq "${name}-isdefault")
        {
            if (!$settings->{$name}->{is_default})
            {
                $settings->{$name}->reset_to_default;
            }
        }
        else
        {
            $setting->validate_value($value);
            $settings->{$name}->set($value);
        }
    }
    $vars->{settings} = $user->settings(1);
}

sub DoEmail
{
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    ###########################################################################
    # User watching
    ###########################################################################
    my $userid = $user->id;
    # WatcheD and WatcherR ID's together
    my $wdwr_ids = $dbh->selectall_arrayref(
        "SELECT watched, watcher FROM watch WHERE watcher=? OR watched=?",
        undef, $userid, $userid
    ) || [];
    $vars->{watchedusers} = [];
    $vars->{watchers} = [];
    foreach (@$wdwr_ids)
    {
        if ($_->[1] eq $userid)
        {
            push @{$vars->{watchedusers}}, Bugzilla::User->new($_->[0]);
        }
        else
        {
            push @{$vars->{watchers}}, Bugzilla::User->new($_->[1]);
        }
    }
    $vars->{watchedusers} = [ sort { $a->identity cmp $b->identity } @{$vars->{watchedusers}} ];
    $vars->{watchers} = [ sort { $a->identity cmp $b->identity } @{$vars->{watchers}} ];

    ###########################################################################
    # Role-based preferences
    ###########################################################################
    my $sth = $dbh->prepare(
        "SELECT relationship, event FROM email_setting WHERE user_id = ?"
    );
    $sth->execute($user->id);

    my %mail;
    while (my ($relationship, $event) = $sth->fetchrow_array())
    {
        $mail{$relationship}{$event} = 1;
    }

    $vars->{mail} = \%mail;
}

sub SaveEmail
{
    my $dbh = Bugzilla->dbh;
    my $ARGS = Bugzilla->input_params;
    my $user = Bugzilla->user;

    Bugzilla::User::match_field({ 'new_watchedusers' => {'type' => 'multi'} });

    ###########################################################################
    # Role-based preferences
    ###########################################################################
    $dbh->bz_start_transaction();

    # Delete all the user's current preferences
    $dbh->do("DELETE FROM email_setting WHERE user_id = ?", undef, $user->id);

    # Repopulate the table - first, with normal events in the
    # relationship/event matrix.
    # Note: the database holds only "off" email preferences, as can be implied
    # from the name of the table - profiles_nomail.
    foreach my $rel (RELATIONSHIPS)
    {
        # Positive events: a ticked box means "send me mail."
        foreach my $event (POS_EVENTS)
        {
            if ($ARGS->{"email-$rel-$event"})
            {
                $dbh->do(
                    "INSERT INTO email_setting (user_id, relationship, event) VALUES (?, ?, ?)",
                    undef, $user->id, $rel, $event
                );
            }
        }
        # Negative events: a ticked box means "don't send me mail."
        foreach my $event (NEG_EVENTS)
        {
            if (!$ARGS->{"neg-email-$rel-$event"})
            {
                $dbh->do(
                    "INSERT INTO email_setting (user_id, relationship, event) VALUES (?, ?, ?)",
                    undef, $user->id, $rel, $event
                );
            }
        }
    }

    # Global positive events: a ticked box means "send me mail."
    foreach my $event (GLOBAL_EVENTS)
    {
        if ($ARGS->{"email-".REL_ANY."-$event"})
        {
            $dbh->do(
                "INSERT INTO email_setting (user_id, relationship, event) VALUES (?, ?, ?)",
                undef, $user->id, REL_ANY, $event
            );
        }
    }

    $dbh->bz_commit_transaction();

    ###########################################################################
    # User watching
    ###########################################################################
    if ($ARGS->{new_watchedusers} || $ARGS->{remove_watched_users} ||
        $ARGS->{new_watchers} || $ARGS->{remove_watchers})
    {
        $dbh->bz_start_transaction();

        my $userid = $user->id;
        my $add_wdwr = [];
        my $del_wdwr = [];

        # New watched users
        push @$add_wdwr,
            map { [ Bugzilla::User::login_to_id(trim($_), THROW_ERROR), $userid ] }
            split /[,\s]+/,
            join(',', $ARGS->{new_watchedusers}) || '';

        # New watchers
        push @$add_wdwr,
            map { [ $userid, Bugzilla::User::login_to_id(trim($_), THROW_ERROR) ] }
            split /[,\s]+/,
            join(',', $ARGS->{new_watchers}) || '';

        if ($ARGS->{remove_watched_users})
        {
            # User wants to remove selected watched users
            push @$del_wdwr,
                map { [ Bugzilla::User::login_to_id(trim($_), THROW_ERROR), $userid ] }
                $ARGS->{watched_by_you};
        }

        if ($ARGS->{remove_watchers})
        {
            # User wants to remove selected watchers
            push @$del_wdwr,
                map { [ $userid, Bugzilla::User::login_to_id(trim($_), THROW_ERROR) ] }
                $ARGS->{watchers};
        }

        if (@$add_wdwr)
        {
            # Add new watchers / watched users
            $dbh->do(
                "REPLACE INTO watch (watched, watcher) VALUES " .
                (join ",", ("(?,?)") x scalar @$add_wdwr),
                undef, map { @$_ } @$add_wdwr
            );
        }

        if (@$del_wdwr)
        {
            # Delete watchers / watched users
            $dbh->do(
                "DELETE FROM watch WHERE (watched, watcher) IN (" .
                (join ",", ("(?,?)") x scalar @$del_wdwr) . ")",
                undef, map { @$_ } @$del_wdwr
            );
        }

        $dbh->bz_commit_transaction();
    }
}

sub DoPermissions
{
    $vars->{all_groups} = [ Bugzilla::Group->get_all ];
    $vars->{pergroup} = Bugzilla::Group->get_per_group_permissions;
}

# No SavePermissions() because this panel has no changeable fields.

sub DoSavedSearches
{
    my $ARGS = Bugzilla->input_params;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    # CustIS Bug 53697 - Bookmarks
    if ((my $name = trim($ARGS->{addbookmarkname})) &&
        (my $url = $ARGS->{addbookmarkurl}))
    {
        trick_taint($name);
        trick_taint($url);
        $dbh->do(
            'INSERT INTO namedqueries (userid, name, query) VALUES (?, ?, ?)',
            undef, $user->id, $name, $url
        );
        $dbh->commit;
    }
    if ($user->queryshare_groups_as_string)
    {
        $vars->{queryshare_groups} = Bugzilla::Group->new_from_list($user->queryshare_groups);
    }
    $vars->{bless_group_ids} = [ map { $_->id } @{$user->bless_groups} ];
}

sub SaveSavedSearches
{
    my $ARGS = Bugzilla->input_params;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # We'll need this in a loop, so do the call once.
    my $user_id = $user->id;

    my $sth_insert_ngm = $dbh->prepare(
        'INSERT INTO namedquery_group_map (namedquery_id, group_id) VALUES (?, ?)'
    );
    my $sth_update_ngm = $dbh->prepare(
        'UPDATE namedquery_group_map SET group_id = ? WHERE namedquery_id = ?'
    );
    my $sth_delete_ngm = $dbh->prepare(
        'DELETE FROM namedquery_group_map WHERE namedquery_id = ?'
    );

    # FIXME do batch updates

    # For user's own queries, update namedquery_group_map.
    my $group;
    foreach my $q (@{$user->queries})
    {
        if ($user->in_group(Bugzilla->params->{querysharegroup}))
        {
            $group = $ARGS->{"share_".$q->id};
            $group = $group ? Bugzilla::Group->check({ id => $group }) : undef;
        }
        $q->set_shared_with_group($group, $ARGS->{'force_'.$q->id});
    }

    # Update namedqueries_link_in_footer for this user.
    foreach my $q (@{$user->queries}, @{$user->queries_available})
    {
        $q->set_link_in_footer($ARGS->{"link_in_footer_".$q->id});
    }

    $user->flush_queries_cache;

    # Update profiles.mybugslink.
    my $showmybugslink = defined($ARGS->{showmybugslink}) ? 1 : 0;
    $dbh->do("UPDATE profiles SET mybugslink = ? WHERE userid = ?", undef, $showmybugslink, $user->id);
    $user->{showmybugslink} = $showmybugslink;
}

###############################################################################
# Live code (not subroutine definitions) starts here
###############################################################################

my $ARGS = Bugzilla->input_params;

# Delete credentials before logging in in case we are in a sudo session.
if (Bugzilla->cookies->{sudo})
{
    delete $ARGS->{Bugzilla_login};
    delete $ARGS->{Bugzilla_password};
}
delete $ARGS->{GoAheadAndLogIn};

# First try to get credentials from cookies.
Bugzilla->login(LOGIN_OPTIONAL);

if (!Bugzilla->user->id)
{
    # Use credentials given in the form if login cookies are not available.
    $ARGS->{Bugzilla_login} = $ARGS->{old_login};
    $ARGS->{Bugzilla_password} = $ARGS->{old_password};
}
Bugzilla->login(LOGIN_REQUIRED);

$vars->{changes_saved} = $ARGS->{dosave};

my $current_tab_name = $ARGS->{tab} || "settings";

# The SWITCH below makes sure that this is valid
trick_taint($current_tab_name);

$vars->{current_tab_name} = $current_tab_name;

my $token = $ARGS->{token};
check_token_data($token, 'edit_user_prefs') if $ARGS->{dosave};

if ($current_tab_name eq 'account')
{
    SaveAccount() if $ARGS->{dosave};
    DoAccount();
}
elsif ($current_tab_name eq 'settings')
{
    SaveSettings() if $ARGS->{dosave};
    DoSettings();
}
elsif ($current_tab_name eq 'email')
{
    SaveEmail() if $ARGS->{dosave};
    DoEmail();
}
elsif ($current_tab_name eq 'permissions')
{
    DoPermissions();
}
elsif ($current_tab_name eq 'saved-searches')
{
    SaveSavedSearches() if $ARGS->{dosave};
    DoSavedSearches();
}
else
{
    ThrowUserError("unknown_tab", { current_tab_name => $current_tab_name });
}

delete_token($token) if $ARGS->{dosave};
if ($current_tab_name ne 'permissions')
{
    $vars->{token} = issue_session_token('edit_user_prefs');
}

# Generate and return the UI (HTML page) from the appropriate template.
$template->process("account/prefs/prefs.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
