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
# Contributor(s): Myk Melez <myk@mozilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Token;
use Bugzilla::User;

use Date::Format;
use Date::Parse;

local our $ARGS = Bugzilla->input_params;
local our $vars = {};
local our $template = Bugzilla->template;

my $action = $ARGS->{a};
my $token = $ARGS->{t};

Bugzilla->login(LOGIN_OPTIONAL);

# Throw an error if the form does not contain an "action" field specifying
# what the user wants to do.
$action || ThrowUserError('unknown_action');

# If a token was submitted, make sure it is a valid token that exists in the
# database and is the correct type for the action being taken.
if ($token)
{
    Bugzilla::Token::CleanTokenTable();

    # It's safe to detaint the token as it's used in a placeholder.
    trick_taint($token);

    # Make sure the token exists in the database.
    my ($tokentype) = Bugzilla->dbh->selectrow_array(
        'SELECT tokentype FROM tokens WHERE token = ?', undef, $token
    );
    $tokentype || ThrowUserError("token_does_not_exist");

    # Make sure the token is the correct type for the action being taken.
    if (grep ($action eq $_, qw(cfmpw cxlpw chgpw)) && $tokentype ne 'password')
    {
        Bugzilla::Token::Cancel($token, "wrong_token_for_changing_passwd");
        ThrowUserError("wrong_token_for_changing_passwd");
    }
    if ($action eq 'cxlem' && $tokentype ne 'emailold' && $tokentype ne 'emailnew')
    {
        Bugzilla::Token::Cancel($token, "wrong_token_for_cancelling_email_change");
        ThrowUserError("wrong_token_for_cancelling_email_change");
    }
    if (grep($action eq $_, qw(cfmem chgem)) && $tokentype ne 'emailnew')
    {
        Bugzilla::Token::Cancel($token, "wrong_token_for_confirming_email_change");
        ThrowUserError("wrong_token_for_confirming_email_change");
    }
    if ($action =~ /^(request|confirm|cancel)_new_account$/ && $tokentype ne 'account')
    {
        Bugzilla::Token::Cancel($token, 'wrong_token_for_creating_account');
        ThrowUserError('wrong_token_for_creating_account');
    }
}

################################################################################
# Main Body Execution
################################################################################

# All calls to this script should contain an "action" variable whose value
# determines what the user wants to do.  The code below checks the value of
# that variable and runs the appropriate code.

if ($action eq 'reqpw')
{
    requestChangePassword();
}
elsif ($action eq 'cfmpw')
{
    confirmChangePassword($token);
}
elsif ($action eq 'cxlpw')
{
    cancelChangePassword($token);
}
elsif ($action eq 'chgpw')
{
    changePassword($token);
}
elsif ($action eq 'cfmem')
{
    confirmChangeEmail($token);
}
elsif ($action eq 'cxlem')
{
    cancelChangeEmail($token);
}
elsif ($action eq 'chgem')
{
    changeEmail($token);
}
elsif ($action eq 'request_new_account')
{
    request_create_account($token);
}
elsif ($action eq 'confirm_new_account')
{
    confirm_create_account($token);
}
elsif ($action eq 'cancel_new_account')
{
    cancel_create_account($token);
}
else
{
    # If the action that the user wants to take (specified in the "a" form field)
    # is none of the above listed actions, display an error telling the user 
    # that we do not understand what they would like to do.
    ThrowCodeError("unknown_action", { action => $action });
}

exit;

################################################################################
# Functions
################################################################################

sub requestChangePassword
{
    # If the user is requesting a password change, make sure they submitted
    # their login name and it exists in the database, and that the DB module is in
    # the list of allowed verification methods.
    my $login_name = $ARGS->{loginname} || ThrowUserError("login_needed_for_password_change");

    # check verification methods
    unless (Bugzilla->user->authorizer->can_change_password)
    {
        ThrowUserError('password_change_requests_not_allowed');
    }
    validate_email_syntax($login_name) || ThrowUserError('illegal_email_address', { addr => $login_name });

    my $user = Bugzilla::User->check($login_name);
    # Make sure the user account is active.
    if (!$user->is_enabled)
    {
        ThrowUserError('account_disabled', {
            disabled_reason => get_text('account_disabled', { account => $login_name }),
        });
    }

    Bugzilla::Token::IssuePasswordToken($user);
    $vars->{message} = "password_change_request";
    $template->process("global/message.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub confirmChangePassword
{
    my $token = shift;
    $vars->{token} = $token;
    $template->process("account/password/set-forgotten-password.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub cancelChangePassword
{
    my $token = shift;
    $vars->{message} = "password_change_canceled";
    Bugzilla::Token::Cancel($token, $vars->{message});
    $template->process("global/message.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub changePassword
{
    my ($token) = @_;

    # If the user is changing their password, make sure they submitted a new
    # password and that the new password is valid.
    # Make sure that these never show up in the UI under any circumstances.
    my $password = delete $ARGS->{password};
    my $matchpassword = delete $ARGS->{matchpassword};
    defined $password && defined $matchpassword || ThrowUserError('require_new_password');
    Bugzilla::User::validate_password($password, $matchpassword);

    my $dbh = Bugzilla->dbh;

    # Create a crypted version of the new password
    my $cryptedpassword = bz_crypt($password);

    # Get the user's ID from the tokens table.
    my ($userid) = $dbh->selectrow_array('SELECT userid FROM tokens WHERE token = ?', undef, $token);

    # Update the user's password in the profiles table and delete the token
    # from the tokens table.
    $dbh->bz_start_transaction();
    $dbh->do(
        'UPDATE profiles SET cryptpassword = ? WHERE userid = ?',
        undef, $cryptedpassword, $userid
    );
    $dbh->do('DELETE FROM tokens WHERE token = ?', undef, $token);
    $dbh->bz_commit_transaction();

    Bugzilla->logout_user_by_id($userid);

    $template->process("global/message.html.tmpl", { message => 'password_changed' })
        || ThrowTemplateError($template->error());
}

sub confirmChangeEmail
{
    my $token = shift;
    $template->process("account/email/confirm.html.tmpl", { token => $token })
        || ThrowTemplateError($template->error());
}

sub changeEmail
{
    my $token = shift;
    my $dbh = Bugzilla->dbh;
    # Get the user's ID from the tokens table.
    my ($userid, $eventdata) = $dbh->selectrow_array(
        'SELECT userid, eventdata FROM tokens WHERE token = ?', undef, $token
    );
    my ($old_email, $new_email) = split /:/, $eventdata;
    # Check the user entered the correct old email address
    if (lc Bugzilla->input_params->param('email') ne lc $old_email)
    {
        ThrowUserError("email_confirmation_failed");
    }
    # The new email address should be available as this was
    # confirmed initially so cancel token if it is not still available
    if (!Bugzilla::User::is_available_username($new_email, $old_email))
    {
        $vars->{email} = $new_email; # Needed for Bugzilla::Token::Cancel's mail
        Bugzilla::Token::Cancel($token, "account_exists", $vars);
        ThrowUserError("account_exists", { email => $new_email });
    }
    # Update the user's login name in the profiles table and delete the token
    # from the tokens table.
    $dbh->bz_start_transaction();
    $dbh->do('UPDATE profiles SET login_name = ? WHERE userid = ?', undef, $new_email, $userid);
    $dbh->do('DELETE FROM tokens WHERE token = ?', undef, $token);
    $dbh->do("DELETE FROM tokens WHERE userid = ? AND tokentype = 'emailnew'", undef, $userid);

    # The email address has been changed, so we need to rederive the groups
    my $user = new Bugzilla::User($userid);
    $user->derive_regexp_groups;

    $dbh->bz_commit_transaction();

    # Let the user know their email address has been changed.
    $vars->{message} = "login_changed";

    $template->process("global/message.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub cancelChangeEmail
{
    my $token = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    # Get the user's ID from the tokens table.
    my ($userid, $tokentype, $eventdata) = $dbh->selectrow_array(
        'SELECT userid, tokentype, eventdata FROM tokens WHERE token = ?', undef, $token
    );
    my ($old_email, $new_email) = split /:/, $eventdata;

    if ($tokentype eq 'emailold')
    {
        $vars->{message} = "emailold_change_canceled";
        my $actualemail = $dbh->selectrow_array(
            'SELECT login_name FROM profiles WHERE userid = ?', undef, $userid
        );
        # check to see if it has been altered
        if ($actualemail ne $old_email)
        {
            # This is NOT safe - if A has change to B, another profile
            # could have grabbed A's username in the meantime.
            # The DB constraint will catch this, though
            $dbh->do('UPDATE profiles SET login_name=? WHERE userid=?', undef, $old_email, $userid);

            # email has changed, so rederive groups
            my $user = new Bugzilla::User($userid);
            $user->derive_regexp_groups;
            $vars->{message} = "email_change_canceled_reinstated";
        }
    }
    else
    {
        $vars->{message} = 'email_change_canceled';
    }

    $vars->{old_email} = $old_email;
    $vars->{new_email} = $new_email;
    Bugzilla::Token::Cancel($token, $vars->{message}, $vars);

    $dbh->do(
        "DELETE FROM tokens WHERE userid = ? AND tokentype = 'emailold' OR tokentype = 'emailnew'",
        undef, $userid
    );
    $dbh->bz_commit_transaction();

    $template->process("global/message.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub request_create_account
{
    my $token = shift;
    Bugzilla->user->check_account_creation_enabled;
    my (undef, $date, $login_name) = Bugzilla::Token::GetTokenData($token);
    $vars->{token} = $token;
    $vars->{email} = $login_name . Bugzilla->params->{emailsuffix};
    $vars->{expiration_ts} = ctime(str2time($date) + MAX_TOKEN_AGE * 86400);
    $template->process('account/email/confirm-new.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}

sub confirm_create_account
{
    my $token = shift;
    my $ARGS = Bugzilla->input_params;

    Bugzilla->user->check_account_creation_enabled;
    my (undef, undef, $login_name) = Bugzilla::Token::GetTokenData($token);

    my $password = delete $ARGS->{passwd1} || '';
    Bugzilla::User::validate_password($password, delete $ARGS->{passwd2} || '');

    my $otheruser = Bugzilla::User->create({
        login_name => $login_name,
        realname   => $ARGS->{realname},
        cryptpassword => $password,
    });

    # Now delete this token.
    delete_token($token);

    # Let the user know that his user account has been successfully created.
    $vars->{message} = 'account_created';
    $vars->{otheruser} = $otheruser;

    # Log in the new user using credentials he just gave.
    $ARGS->{Bugzilla_login} = $otheruser->login;
    $ARGS->{Bugzilla_password} = $password;
    delete Bugzilla->request_cache->{sub_login_to_id}->{$otheruser->login};
    Bugzilla->login(LOGIN_OPTIONAL);

    $template->process('index.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}

sub cancel_create_account
{
    my $token = shift;
    my (undef, undef, $login_name) = Bugzilla::Token::GetTokenData($token);
    $vars->{message} = 'account_creation_canceled';
    $vars->{account} = $login_name;
    Bugzilla::Token::Cancel($token, $vars->{message});
    $template->process('global/message.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
