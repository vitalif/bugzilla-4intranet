#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
#
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
use URI;

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
sub DoAccount {
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    ($vars->{'realname'}) = $dbh->selectrow_array(
        "SELECT realname FROM profiles WHERE userid = ?", undef, $user->id);

    if(Bugzilla->params->{'allowemailchange'} 
       && Bugzilla->user->authorizer->can_change_email) {
       # First delete old tokens.
       Bugzilla::Token::CleanTokenTable();

        my @token = $dbh->selectrow_array(
            "SELECT tokentype, issuedate + " .
                    $dbh->sql_interval(MAX_TOKEN_AGE, 'DAY') . ", eventdata
               FROM tokens
              WHERE userid = ?
                AND tokentype LIKE 'email%'
           ORDER BY tokentype ASC " . $dbh->sql_limit(1), undef, $user->id);
        if (scalar(@token) > 0) {
            my ($tokentype, $change_date, $eventdata) = @token;
            $vars->{'login_change_date'} = $change_date;

            if($tokentype eq 'emailnew') {
                my ($oldemail,$newemail) = split(/:/,$eventdata);
                $vars->{'new_login_name'} = $newemail;
            }
        }
    }
}

sub SaveAccount {
    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    my $pwd1 = $cgi->param('new_password1');
    my $pwd2 = $cgi->param('new_password2');

    if ($user->authorizer->can_change_password
        && ($cgi->param('Bugzilla_password') ne "" || $pwd1 ne "" || $pwd2 ne ""))
    {
        my ($oldcryptedpwd) = $dbh->selectrow_array(
                        q{SELECT cryptpassword FROM profiles WHERE userid = ?},
                        undef, $user->id);
        $oldcryptedpwd || ThrowCodeError("unable_to_retrieve_password");

        my $oldpassword = $cgi->param('Bugzilla_password');

        if (bz_crypt($oldpassword, $oldcryptedpwd) ne $oldcryptedpwd) 
        {
            ThrowUserError("old_password_incorrect");
        }

        if ($pwd1 ne "" || $pwd2 ne "")
        {
            $cgi->param('new_password1')
              || ThrowUserError("new_password_missing");
            validate_password($pwd1, $pwd2);

            if ($cgi->param('Bugzilla_password') ne $pwd1) {
                my $cryptedpassword = bz_crypt($pwd1);
                $dbh->do(q{UPDATE profiles
                              SET cryptpassword = ?
                            WHERE userid = ?},
                         undef, ($cryptedpassword, $user->id));

                # Invalidate all logins except for the current one
                Bugzilla->logout(LOGOUT_KEEP_CURRENT);
            }
        }
    }

    if ($user->authorizer->can_change_email
        && Bugzilla->params->{"allowemailchange"}
        && $cgi->param('new_login_name'))
    {
        my $old_login_name = $cgi->param('Bugzilla_login');
        my $new_login_name = trim($cgi->param('new_login_name'));

        if($old_login_name ne $new_login_name) {
            $cgi->param('Bugzilla_password') 
              || ThrowUserError("old_password_required");

            # Block multiple email changes for the same user.
            if (Bugzilla::Token::HasEmailChangeToken($user->id)) {
                ThrowUserError("email_change_in_progress");
            }

            # Before changing an email address, confirm one does not exist.
            validate_email_syntax($new_login_name)
              || ThrowUserError('illegal_email_address', {addr => $new_login_name});
            is_available_username($new_login_name)
              || ThrowUserError("account_exists", {email => $new_login_name});

            Bugzilla::Token::IssueEmailChangeToken($user, $old_login_name,
                                                   $new_login_name);

            $vars->{'email_changes_saved'} = 1;
        }
    }

    my $realname = trim($cgi->param('realname'));
    trick_taint($realname); # Only used in a placeholder
    $dbh->do("UPDATE profiles SET realname = ? WHERE userid = ?",
             undef, ($realname, $user->id));
}


sub DoSettings {
    my $user = Bugzilla->user;

    my $settings = $user->settings;
    $vars->{'settings'} = $settings;

    my @setting_list = keys %$settings;
    $vars->{'setting_names'} = \@setting_list;

    $vars->{'has_settings_enabled'} = 0;
    # Is there at least one user setting enabled?
    foreach my $setting_name (@setting_list) {
        if ($settings->{"$setting_name"}->{'is_enabled'}) {
            $vars->{'has_settings_enabled'} = 1;
            last;
        }
    }
    $vars->{'dont_show_button'} = !$vars->{'has_settings_enabled'};
}

sub SaveSettings {
    my $cgi = Bugzilla->cgi;
    my $user = Bugzilla->user;

    my $settings = $user->settings;
    my @setting_list = keys %$settings;

    foreach my $name (@setting_list) {
        next if ! ($settings->{$name}->{'is_enabled'});
        my $value = $cgi->param($name);
        next unless defined $value;
        my $setting = new Bugzilla::User::Setting($name);

        if ($value eq "${name}-isdefault" ) {
            if (! $settings->{$name}->{'is_default'}) {
                $settings->{$name}->reset_to_default;
            }
        }
        else {
            $setting->validate_value($value);
            $settings->{$name}->set($value);
        }
    }
    $vars->{'settings'} = $user->settings(1);
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
    while (my ($relationship, $event) = $sth->fetchrow_array()) {
        $mail{$relationship}{$event} = 1;
    }

    $vars->{mail} = \%mail;
}

sub SaveEmail
{
    my $dbh = Bugzilla->dbh;
    my $cgi = Bugzilla->cgi;
    my $user = Bugzilla->user;

    Bugzilla::User::match_field($cgi, { new_watchedusers => { type => 'multi' } });

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
    foreach my $rel (RELATIONSHIPS) {
        # Positive events: a ticked box means "send me mail."
        foreach my $event (POS_EVENTS) {
            if (defined($cgi->param("email-$rel-$event"))
                && $cgi->param("email-$rel-$event") == 1)
            {
                $dbh->do("INSERT INTO email_setting " .
                         "(user_id, relationship, event) " .
                         "VALUES (?, ?, ?)",
                         undef, ($user->id, $rel, $event));
            }
        }

        # Negative events: a ticked box means "don't send me mail."
        foreach my $event (NEG_EVENTS) {
            if (!defined($cgi->param("neg-email-$rel-$event")) ||
                $cgi->param("neg-email-$rel-$event") != 1)
            {
                $dbh->do("INSERT INTO email_setting " .
                         "(user_id, relationship, event) " .
                         "VALUES (?, ?, ?)",
                         undef, ($user->id, $rel, $event));
            }
        }
    }

    # Global positive events: a ticked box means "send me mail."
    foreach my $event (GLOBAL_EVENTS) {
        if (defined($cgi->param("email-" . REL_ANY . "-$event"))
            && $cgi->param("email-" . REL_ANY . "-$event") == 1)
        {
            $dbh->do("INSERT INTO email_setting " .
                     "(user_id, relationship, event) " .
                     "VALUES (?, ?, ?)",
                     undef, ($user->id, REL_ANY, $event));
        }
    }

    $dbh->bz_commit_transaction();

    ###########################################################################
    # User watching
    ###########################################################################
    if ($cgi->param('new_watchedusers') || $cgi->param('remove_watched_users') ||
        $cgi->param('new_watchers') || $cgi->param('remove_watchers'))
    {
        $dbh->bz_start_transaction();

        my $userid = $user->id;
        my $add_wdwr = [];
        my $del_wdwr = [];

        # New watched users
        push @$add_wdwr,
            map { [ login_to_id(trim($_), THROW_ERROR), $userid ] }
            split /[,\s]+/,
            join(',', $cgi->param('new_watchedusers')) || '';

        # New watchers
        push @$add_wdwr,
            map { [ $userid, login_to_id(trim($_), THROW_ERROR) ] }
            split /[,\s]+/,
            join(',', $cgi->param('new_watchers')) || '';

        if ($cgi->param('remove_watched_users'))
        {
            # User wants to remove selected watched users
            push @$del_wdwr,
                map { [ login_to_id(trim($_), THROW_ERROR), $userid ] }
                $cgi->param('watched_by_you');
        }

        if ($cgi->param('remove_watchers'))
        {
            # User wants to remove selected watchers
            push @$del_wdwr,
                map { [ $userid, login_to_id(trim($_), THROW_ERROR) ] }
                $cgi->param('watchers');
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
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    my (@has_bits, @set_bits);

    my $groups = $dbh->selectall_arrayref(
               "SELECT DISTINCT name, description FROM groups WHERE id IN (" . 
               $user->groups_as_string . ") ORDER BY name");
    foreach my $group (@$groups) {
        my ($nam, $desc) = @$group;
        push(@has_bits, {"desc" => $desc, "name" => $nam});
    }
    $groups = $dbh->selectall_arrayref('SELECT DISTINCT id, name, description
                                          FROM groups
                                         ORDER BY name');
    foreach my $group (@$groups) {
        my ($group_id, $nam, $desc) = @$group;
        if ($user->can_bless($group_id)) {
            push(@set_bits, {"desc" => $desc, "name" => $nam});
        }
    }

    if (!$user->in_group('editcomponents'))
    {
        # There exists a distinct function for this
        $vars->{local_editcomponents} = $user->get_editable_products;
    }

    foreach my $privs (PER_PRODUCT_PRIVILEGES)
    {
        next if $privs eq 'editcomponents' || $user->in_group($privs);
        $vars->{"local_$privs"} = $user->get_products_by_permission($privs);
    }

    $vars->{'has_bits'} = \@has_bits;
    $vars->{'set_bits'} = \@set_bits;
}

# No SavePermissions() because this panel has no changeable fields.

sub DoSavedSearches {
    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # CustIS Bug 53697 - Bookmarks
    if ((my $name = trim($cgi->param('addbookmarkname'))) &&
        (my $url = $cgi->param('addbookmarkurl')))
    {
        trick_taint($name);
        trick_taint($url);
        eval { $url = URI->new($url)->canonical->as_string; };
        ThrowCodeError("invalid_url", { url => $url }) if $@;
        $dbh->do('INSERT INTO namedqueries (userid, name, query) VALUES (?, ?, ?)', undef,
            $user->id, $name, $url);
        $dbh->commit;
    }

    if ($user->queryshare_groups_as_string) {
        $vars->{'queryshare_groups'} =
            Bugzilla::Group->new_from_list($user->queryshare_groups);
    }
    $vars->{'bless_group_ids'} = [map { $_->id } @{$user->bless_groups}];
}

sub SaveSavedSearches {
    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # We'll need this in a loop, so do the call once.
    my $user_id = $user->id;

    my $sth_insert_nl = $dbh->prepare('INSERT INTO namedqueries_link_in_footer
                                       (namedquery_id, user_id)
                                       VALUES (?, ?)');
    my $sth_delete_nl = $dbh->prepare('DELETE FROM namedqueries_link_in_footer
                                             WHERE namedquery_id = ?
                                               AND user_id = ?');
    my $sth_insert_ngm = $dbh->prepare('INSERT INTO namedquery_group_map
                                        (namedquery_id, group_id)
                                        VALUES (?, ?)');
    my $sth_update_ngm = $dbh->prepare('UPDATE namedquery_group_map
                                           SET group_id = ?
                                         WHERE namedquery_id = ?');
    my $sth_delete_ngm = $dbh->prepare('DELETE FROM namedquery_group_map
                                              WHERE namedquery_id = ?');

    # Update namedqueries_link_in_footer for this user.
    foreach my $q (@{$user->queries}, @{$user->queries_available}) {
        if (defined $cgi->param("link_in_footer_" . $q->id)) {
            $sth_insert_nl->execute($q->id, $user_id) if !$q->link_in_footer;
        }
        else {
            $sth_delete_nl->execute($q->id, $user_id) if $q->link_in_footer;
        }
    }

    # For user's own queries, update namedquery_group_map.
    foreach my $q (@{$user->queries}) {
        my $group_id;

        if ($user->in_group(Bugzilla->params->{'querysharegroup'})) {
            $group_id = $cgi->param("share_" . $q->id) || '';
        }

        if ($group_id) {
            # Don't allow the user to share queries with groups he's not
            # allowed to.
            next unless grep($_ eq $group_id, @{$user->queryshare_groups});

            # $group_id is now definitely a valid ID of a group the
            # user can share queries with, so we can trick_taint.
            detaint_natural($group_id);
            if ($q->shared_with_group) {
                $sth_update_ngm->execute($group_id, $q->id);
            }
            else {
                $sth_insert_ngm->execute($q->id, $group_id);
            }

            # If we're sharing our query with a group we can bless, we 
            # have the ability to add link to our search to the footer of
            # direct group members automatically.
            if ($user->can_bless($group_id) && $cgi->param('force_' . $q->id)) {
                my $group = new Bugzilla::Group($group_id);
                my $members = $group->members_non_inherited;
                foreach my $member (@$members) {
                    next if $member->id == $user->id;
                    $sth_insert_nl->execute($q->id, $member->id)
                        if !$q->link_in_footer($member);
                }
            }
        }
        else {
            # They have unshared that query.
            if ($q->shared_with_group) {
                $sth_delete_ngm->execute($q->id);
            }

            # Don't remove namedqueries_link_in_footer entries for users
            # subscribing to the shared query. The idea is that they will
            # probably want to be subscribers again should the sharing
            # user choose to share the query again.
        }
    }

    $user->flush_queries_cache;
    
    # Update profiles.mybugslink.
    my $showmybugslink = defined($cgi->param("showmybugslink")) ? 1 : 0;
    $dbh->do("UPDATE profiles SET mybugslink = ? WHERE userid = ?",
             undef, ($showmybugslink, $user->id));    
    $user->{'showmybugslink'} = $showmybugslink;
}


###############################################################################
# Live code (not subroutine definitions) starts here
###############################################################################

my $cgi = Bugzilla->cgi;

# This script needs direct access to the username and password CGI variables,
# so we save them before their removal in Bugzilla->login, and delete them 
# before login in case we might be in a sudo session.
my $bugzilla_login    = $cgi->param('Bugzilla_login');
my $bugzilla_password = $cgi->param('Bugzilla_password');
$cgi->delete('Bugzilla_login', 'Bugzilla_password') if ($cgi->cookie('sudo'));

Bugzilla->login(LOGIN_REQUIRED);
$cgi->param('Bugzilla_login', $bugzilla_login);
$cgi->param('Bugzilla_password', $bugzilla_password);

$vars->{'changes_saved'} = $cgi->param('dosave');

my $current_tab_name = $cgi->param('tab') || "settings";

# The SWITCH below makes sure that this is valid
trick_taint($current_tab_name);

$vars->{'current_tab_name'} = $current_tab_name;

my $token = $cgi->param('token');
check_token_data($token, 'edit_user_prefs') if $cgi->param('dosave');

# Do any saving, and then display the current tab.
SWITCH: for ($current_tab_name) {
    /^account$/ && do {
        SaveAccount() if $cgi->param('dosave');
        DoAccount();
        last SWITCH;
    };
    /^settings$/ && do {
        SaveSettings() if $cgi->param('dosave');
        DoSettings();
        last SWITCH;
    };
    /^email$/ && do {
        SaveEmail() if $cgi->param('dosave');
        DoEmail();
        last SWITCH;
    };
    /^permissions$/ && do {
        DoPermissions();
        last SWITCH;
    };
    /^saved-searches$/ && do {
        SaveSavedSearches() if $cgi->param('dosave');
        DoSavedSearches();
        last SWITCH;
    };
    ThrowUserError("unknown_tab",
                   { current_tab_name => $current_tab_name });
}

delete_token($token) if $cgi->param('dosave');
if ($current_tab_name ne 'permissions') {
    $vars->{'token'} = issue_session_token('edit_user_prefs');
}

# Generate and return the UI (HTML page) from the appropriate template.
print $cgi->header();
$template->process("account/prefs/prefs.html.tmpl", $vars)
  || ThrowTemplateError($template->error());
