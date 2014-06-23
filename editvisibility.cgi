#!/usr/bin/perl -wT
# Enable/disable custom fields for a value of the controlling field
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

my $ARGS = { %{ Bugzilla->cgi->Vars } };
my $template = Bugzilla->template;
my $vars = {};

my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editfields') || ThrowUserError('auth_failure', {
    group  => "admin",
    action => "edit",
    object => "custom_fields"});

my $field_name = trim($ARGS->{field} || '');
my $value_name = trim($ARGS->{value} || '');
my $action     = trim($ARGS->{action} || '');
my $token      = $ARGS->{token};

unless ($field_name)
{
    ThrowUserError('no_valid_field', { field => 'field' });
}

my $field = Bugzilla->get_field($field_name);
ThrowUserError('no_valid_field', { field => 'field' }) unless $field;

my $value = Bugzilla::Field::Choice->type($field)->check($value_name);
ThrowUserError('no_valid_value', { field => 'value' }) unless $value;

if ($field->name eq 'product')
{
    $user->check_can_admin_product($value->name);
}

#
# action='' -> Show list of custom fields
#
unless ($action)
{
    $vars->{field} = $field;
    $vars->{value} = $value;
    $vars->{token} = issue_session_token('change_visibility');
    $template->process('admin/custom_fields/visibility-list.html.tmpl', $vars)
        || ThrowTemplateError($template->error);
    exit;
}

# update result page
if ($action eq 'update' && $token)
{
    check_token_data($token, 'change_visibility');

    my (@updated, @cleared);
    for my $cfield (@{$field->controls_visibility_of})
    {
        # check if it is 'visible for all'
        my $visibility_values = $cfield->visibility_values || next;
        # check if changed
        next unless ($ARGS->{'visible_'.$cfield->id} xor $visibility_values->{$value->id});
        if ($ARGS->{'visible_'.$cfield->id})
        {
            $visibility_values->{$value->id} = 1;
            push @updated, $cfield->description;
        }
        elsif ($visibility_values->{$value->id})
        {
            delete $visibility_values->{$value->id};
            push @cleared, $cfield->description;
        }
        $cfield->set_visibility_values([ keys %$visibility_values ]);
    }

    delete_token($token);

    $vars->{field} = $field;
    $vars->{value} = $value;
    $vars->{update} = 1;
    $vars->{updated} = join(', ', @updated);
    $vars->{cleared} = join(', ', @cleared);
    $template->process('admin/custom_fields/visibility-list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

ThrowUserError('no_valid_action', { field => 'action'});

__END__
