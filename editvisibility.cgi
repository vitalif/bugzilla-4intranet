#!/usr/bin/perl -wT
# Enable/disable field values for a selected value of the controlling field
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>, Vladimir Koptev <vladimir.koptev@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Field;
use Bugzilla::Field::Choice;
use Bugzilla::Token;

my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};

my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editvalues') || ThrowUserError('auth_failure', {
    group  => 'admin',
    action => 'edit',
    object => 'fieldvalues'
});

my $deny_edit = { version => 1, target_milestone => 1, component => 1, product => 1 };
my $field = Bugzilla->get_field($ARGS->{field});
ThrowUserError('fieldname_invalid', { field => { name => $ARGS->{field} } }) if !$field || $deny_edit->{$field->name};
ThrowUserError('no_value_field', { field => $field }) unless $field->value_field;

my $value = $field->value_field->value_type->check({ id => $ARGS->{visibility_value_id} });

if ($ARGS->{action} eq 'save')
{
    check_token_data($ARGS->{token}, 'edit_visibility');
    $field->update_controlled_values($ARGS->{values}, $value->id);
    delete_token($ARGS->{token});
    Bugzilla->add_result_message({ message => 'visibility_updated' });
    Bugzilla->save_session_data;
    print Bugzilla->cgi->redirect('editvisibility.cgi?field='.$field->name.'&visibility_value_id='.$value->id);
    exit;
}

$vars->{field} = $field;
$vars->{visibility_value} = $value;
$vars->{token} = issue_session_token('edit_visibility');

$template->process('admin/fieldvalues/control-list.html.tmpl', $vars)
    || ThrowTemplateError($template->error());
exit;

__END__
