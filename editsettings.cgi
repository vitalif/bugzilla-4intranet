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
# Contributor(s): Shane H. W. Travis <travis@sedsystems.ca>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User::Setting;
use Bugzilla::Token;

my $template = Bugzilla->template;
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $ARGS = Bugzilla->input_params;
my $vars = {};

$user->in_group('tweakparams') || ThrowUserError("auth_failure", {
    group  => "tweakparams",
    action => "modify",
    object => "settings",
});

my $action = trim($ARGS->{action} || '');
my $token = $ARGS->{token};

if ($action eq 'update')
{
    check_token_data($token, 'edit_settings');
    my $settings = Bugzilla::User::Setting::get_defaults();
    my $changed = 0;
    foreach my $name (keys %$settings)
    {
        my $old_enabled = $settings->{$name}->{is_enabled};
        my $old_value = $settings->{$name}->{default_value};
        my $enabled = $ARGS->{$name.'-enabled'} ? 1 : 0;
        my $value = $ARGS->{$name};
        my $setting = new Bugzilla::User::Setting($name);
        $setting->validate_value($value);
        if ($old_enabled != $enabled || $old_value ne $value)
        {
            Bugzilla::User::Setting::set_default($name, $value, $enabled);
            $changed = 1;
        }
    }
    delete_token($token);
    Bugzilla->add_result_message({
        message => 'default_settings_updated',
        changes_saved => $changed,
    });
    Bugzilla->save_session_data;
    print Bugzilla->cgi->redirect('editsettings.cgi');
    exit;
}

$vars->{settings} = Bugzilla::User::Setting::get_defaults();
$vars->{token} = issue_session_token('edit_settings');

$template->process("admin/settings/edit.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
