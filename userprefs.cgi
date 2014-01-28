#!/usr/bin/perl -wT
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use 5.10.1;
use strict;
use lib qw(. lib);
use URI;

use Bugzilla;
use Bugzilla::BugMail;
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

    $vars->{'realname'} = $user->name;

    if (Bugzilla->params->{'allowemailchange'}
        && $user->authorizer->can_change_email)
    {
       # First delete old tokens.
       Bugzilla::Token::CleanTokenTable();

        my @token = $dbh->selectrow_array(
            "SELECT tokentype, " .
                    $dbh->sql_date_math('issuedate', '+', MAX_TOKEN_AGE, 'DAY')
                    . ", eventdata
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
    
    $dbh->bz_start_transaction;

    my $user = Bugzilla->user;

    my $oldpassword = $cgi->param('old_password');
    my $pwd1 = $cgi->param('new_password1');
    my $pwd2 = $cgi->param('new_password2');
    my $new_login_name = trim($cgi->param('new_login_name'));

    if ($user->authorizer->can_change_password
        && ($oldpassword ne "" || $pwd1 ne "" || $pwd2 ne ""))
    {
        my $oldcryptedpwd = $user->cryptpassword;
        $oldcryptedpwd || ThrowCodeError("unable_to_retrieve_password");

        if (bz_crypt($oldpassword, $oldcryptedpwd) ne $oldcryptedpwd) {
            ThrowUserError("old_password_incorrect");
        }

        if ($pwd1 ne "" || $pwd2 ne "") {
            $pwd1 || ThrowUserError("new_password_missing");
            validate_password($pwd1, $pwd2);

            if ($oldpassword ne $pwd1) {
                $user->set_password($pwd1);
                # Invalidate all logins except for the current one
                Bugzilla->logout(LOGOUT_KEEP_CURRENT);
            }
        }
    }

    if ($user->authorizer->can_change_email
        && Bugzilla->params->{"allowemailchange"}
        && $new_login_name)
    {
        if ($user->login ne $new_login_name) {
            $oldpassword || ThrowUserError("old_password_required");

            # Block multiple email changes for the same user.
            if (Bugzilla::Token::HasEmailChangeToken($user->id)) {
                ThrowUserError("email_change_in_progress");
            }

            # Before changing an email address, confirm one does not exist.
            check_email_syntax($new_login_name);
            is_available_username($new_login_name)
              || ThrowUserError("account_exists", {email => $new_login_name});

            Bugzilla::Token::IssueEmailChangeToken($user, $new_login_name);

            $vars->{'email_changes_saved'} = 1;
        }
    }

    $user->set_name($cgi->param('realname'));
    $user->update({ keep_session => 1, keep_tokens => 1 });
    $dbh->bz_commit_transaction;
}

sub DoSettings {
    my $user = Bugzilla->user;

    my $settings = $user->settings;
    $vars->{'settings'} = $settings;

    my @setting_list = sort keys %$settings;
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

    $vars->{'mail'} = \%mail;
}

sub SaveEmail {
    my $dbh = Bugzilla->dbh;
    my $cgi = Bugzilla->cgi;
    my $user = Bugzilla->user;

    Bugzilla::User::match_field({ 'new_watchedusers' => {'type' => 'multi'} });

    ###########################################################################
    # Role-based preferences
    ###########################################################################
    $dbh->bz_start_transaction();

    my $sth_insert = $dbh->prepare('INSERT INTO email_setting
                                    (user_id, relationship, event) VALUES (?, ?, ?)');

    my $sth_delete = $dbh->prepare('DELETE FROM email_setting
                                    WHERE user_id = ? AND relationship = ? AND event = ?');
    # Load current email preferences into memory before updating them.
    my $settings = $user->mail_settings;

    # Update the table - first, with normal events in the
    # relationship/event matrix.
    my %relationships = Bugzilla::BugMail::relationships();
    foreach my $rel (keys %relationships) {
        next if ($rel == REL_QA && !Bugzilla->params->{'useqacontact'});
        # Positive events: a ticked box means "send me mail."
        foreach my $event (POS_EVENTS) {
            my $is_set = $cgi->param("email-$rel-$event");
            if ($is_set xor $settings->{$rel}{$event}) {
                if ($is_set) {
                    $sth_insert->execute($user->id, $rel, $event);
                }
                else {
                    $sth_delete->execute($user->id, $rel, $event);
                }
            }
        }
        
        # Negative events: a ticked box means "don't send me mail."
        foreach my $event (NEG_EVENTS) {
            my $is_set = $cgi->param("neg-email-$rel-$event");
            if (!$is_set xor $settings->{$rel}{$event}) {
                if (!$is_set) {
                    $sth_insert->execute($user->id, $rel, $event);
                }
                else {
                    $sth_delete->execute($user->id, $rel, $event);
                }
            }
        }
    }

    # Global positive events: a ticked box means "send me mail."
    foreach my $event (GLOBAL_EVENTS) {
        my $is_set = $cgi->param("email-" . REL_ANY . "-$event");
        if ($is_set xor $settings->{+REL_ANY}{$event}) {
            if ($is_set) {
                $sth_insert->execute($user->id, REL_ANY, $event);
            }
            else {
                $sth_delete->execute($user->id, REL_ANY, $event);
            }
        }
    }

    $dbh->bz_commit_transaction();

    # We have to clear the cache about email preferences.
    delete $user->{'mail_settings'};

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

    ###########################################################################
    # Ignore Bugs
    ###########################################################################
    my %ignored_bugs = map { $_->{'id'} => 1 } @{$user->bugs_ignored};

    # Validate the new bugs to ignore by checking that they exist and also
    # if the user gave an alias
    my @add_ignored = split(/[\s,]+/, $cgi->param('add_ignored_bugs'));
    @add_ignored = map { Bugzilla::Bug->check($_)->id } @add_ignored;
    map { $ignored_bugs{$_} = 1 } @add_ignored;

    # Remove any bug ids the user no longer wants to ignore
    foreach my $key (grep(/^remove_ignored_bug_/, $cgi->param)) {
        my ($bug_id) = $key =~ /(\d+)$/;
        delete $ignored_bugs{$bug_id};
    }

    # Update the database with any changes made
    my ($removed, $added) = diff_arrays([ map { $_->{'id'} } @{$user->bugs_ignored} ],
                                        [ keys %ignored_bugs ]);

    if (scalar @$removed || scalar @$added) {
        $dbh->bz_start_transaction();

        if (scalar @$removed) {
            $dbh->do('DELETE FROM email_bug_ignore WHERE user_id = ? AND ' . 
                     $dbh->sql_in('bug_id', $removed),
                     undef, $user->id);
        }
        if (scalar @$added) {
            my $sth = $dbh->prepare('INSERT INTO email_bug_ignore
                                     (user_id, bug_id) VALUES (?, ?)');
            $sth->execute($user->id, $_) foreach @$added;
        }

        # Reset the cache of ignored bugs if the list changed.
        delete $user->{bugs_ignored};

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

sub SaveSavedSearches
{
    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # We'll need this in a loop, so do the call once.
    my $user_id = $user->id;

    my $sth_insert_ngm = $dbh->prepare('INSERT INTO namedquery_group_map
                                        (namedquery_id, group_id)
                                        VALUES (?, ?)');
    my $sth_update_ngm = $dbh->prepare('UPDATE namedquery_group_map
                                           SET group_id = ?
                                         WHERE namedquery_id = ?');
    my $sth_delete_ngm = $dbh->prepare('DELETE FROM namedquery_group_map
                                              WHERE namedquery_id = ?');

    # TODO batch update

    # For user's own queries, update namedquery_group_map.
    my $group;
    foreach my $q (@{$user->queries})
    {
        if ($user->in_group(Bugzilla->params->{querysharegroup}))
        {
            $group = $cgi->param("share_" . $q->id);
            $group = $group ? Bugzilla::Group->check({ id => $group }) : undef;
        }
        $q->set_shared_with_group(
            $group,
            $cgi->param('force_' . $q->id)
        );
    }

    # Update namedqueries_link_in_footer for this user.
    foreach my $q (@{$user->queries}, @{$user->queries_available})
    {
        $q->set_link_in_footer(defined $cgi->param("link_in_footer_" . $q->id));
    }

    $user->flush_queries_cache;

    # Update profiles.mybugslink.
    my $showmybugslink = defined($cgi->param("showmybugslink")) ? 1 : 0;
    $dbh->do("UPDATE profiles SET mybugslink = ? WHERE userid = ?", undef, $showmybugslink, $user->id);
    $user->{showmybugslink} = $showmybugslink;
}

###############################################################################
# Live code (not subroutine definitions) starts here
###############################################################################

my $cgi = Bugzilla->cgi;

# Delete credentials before logging in in case we are in a sudo session.
$cgi->delete('Bugzilla_login', 'Bugzilla_password') if ($cgi->cookie('sudo'));
$cgi->delete('GoAheadAndLogIn');

# First try to get credentials from cookies.
my $user = Bugzilla->login(LOGIN_OPTIONAL);

if (!$user->id) {
    # Use credentials given in the form if login cookies are not available.
    $cgi->param('Bugzilla_login', $cgi->param('old_login'));
    $cgi->param('Bugzilla_password', $cgi->param('old_password'));
}
Bugzilla->login(LOGIN_REQUIRED);

my $save_changes = $cgi->param('dosave');
$vars->{'changes_saved'} = $save_changes;

my $current_tab_name = $cgi->param('tab') || "settings";

# The SWITCH below makes sure that this is valid
trick_taint($current_tab_name);

$vars->{'current_tab_name'} = $current_tab_name;

my $token = $cgi->param('token');
check_token_data($token, 'edit_user_prefs') if $save_changes;

# Do any saving, and then display the current tab.
SWITCH: for ($current_tab_name) {

    # Extensions must set it to 1 to confirm the tab is valid.
    my $handled = 0;
    Bugzilla::Hook::process('user_preferences',
                            { 'vars'       => $vars,
                              save_changes => $save_changes,
                              current_tab  => $current_tab_name,
                              handled      => \$handled });
    last SWITCH if $handled;

    /^account$/ && do {
        SaveAccount() if $save_changes;
        DoAccount();
        last SWITCH;
    };
    /^settings$/ && do {
        SaveSettings() if $save_changes;
        DoSettings();
        last SWITCH;
    };
    /^email$/ && do {
        SaveEmail() if $save_changes;
        DoEmail();
        last SWITCH;
    };
    /^permissions$/ && do {
        DoPermissions();
        last SWITCH;
    };
    /^saved-searches$/ && do {
        SaveSavedSearches() if $save_changes;
        DoSavedSearches();
        last SWITCH;
    };

    ThrowUserError("unknown_tab",
                   { current_tab_name => $current_tab_name });
}

delete_token($token) if $save_changes;
if ($current_tab_name ne 'permissions') {
    $vars->{'token'} = issue_session_token('edit_user_prefs');
}

# Generate and return the UI (HTML page) from the appropriate template.
$template->process("account/prefs/prefs.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
