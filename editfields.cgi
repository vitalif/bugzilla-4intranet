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
# Contributor(s): Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Token;

my $template = Bugzilla->template;
my $ARGS = Bugzilla->input_params;
my $vars = {};

# Make sure the user is logged in and is an administrator.
my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editfields') || ThrowUserError('auth_failure', {
    group  => 'editfields',
    action => 'edit',
    object => 'custom_fields',
});

my $action = trim($ARGS->{action} || '');
my $token  = $ARGS->{token};

$vars->{field_types} = Bugzilla->messages->{field_types};
# List all existing custom fields if no action is given.
if (!$action)
{
    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
# Interface to add a new custom field.
elsif ($action eq 'add')
{
    $vars->{token} = issue_session_token('add_field');
    $template->process('admin/custom_fields/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'new')
{
    check_token_data($token, 'add_field');

    my $field = $vars->{field} = Bugzilla::Field->create({
        map { ($_ => $ARGS->{$_}) } Bugzilla::Field->DB_COLUMNS,
        custom => 1,
        is_mandatory => !$ARGS->{nullable},
    });
    $field->set_visibility_values([ list $ARGS->{visibility_value_id} ]);
    $field->set_null_visibility_values([ list $ARGS->{null_visibility_values} ]);
    $field->set_clone_visibility_values([ list $ARGS->{clone_visibility_values} ]);

    delete_token($token);

    $vars->{message} = 'custom_field_created';

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'edit')
{
    my $name = $ARGS->{name} || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', { name => $name });

    $vars->{field} = $field;
    $vars->{token} = issue_session_token('edit_field');

    $template->process('admin/custom_fields/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'update')
{
    check_token_data($token, 'edit_field');

    my $name = $ARGS->{name} || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', { name => $name });
    $vars->{field} = $field;

    if ($field->can_tweak('value_field_id') &&
        ($ARGS->{value_field_id} || 0) != ($field->value_field_id || 0))
    {
        if (!$ARGS->{force_changes} && $field->value_field_id)
        {
            my $h = Bugzilla->fieldvaluecontrol->{$field->value_field_id}->{values}->{$field->id};
            $vars->{value_dep_count} = scalar keys %{ { map { %$_ } values %$h } };
        }
        if (!$vars->{value_dep_count})
        {
            $field->set('value_field_id', $ARGS->{value_field_id});
            $field->clear_value_visibility_values;
        }
    }
    if ($field->can_tweak('default_field_id') &&
        ($ARGS->{default_field_id} || 0) != ($field->default_field_id || 0))
    {
        if (!$ARGS->{force_changes} && $field->default_field_id)
        {
            my $h = Bugzilla->fieldvaluecontrol->{$field->default_field_id}->{defaults}->{$field->id};
            $vars->{default_count} = scalar keys %$h;
        }
        if (!$vars->{default_count})
        {
            $field->set('default_field_id', $ARGS->{default_field_id});
            $field->clear_default_values;
        }
    }
    if ($vars->{default_count} || $vars->{value_dep_count})
    {
        $template->process('admin/custom_fields/confirm-changes.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
        exit;
    }

    for (grep { !/_field_id/ && $_ ne 'is_mandatory' } Bugzilla::Field->UPDATE_COLUMNS)
    {
        $field->set($_, $ARGS->{$_}) if $field->can_tweak($_);
    }
    $field->set_is_mandatory(!$ARGS->{nullable}) if $field->can_tweak('nullable');
    for (
        [ qw(visibility_field_id set_visibility_field set_visibility_values visibility_value_id) ],
        [ qw(null_field_id set_null_field set_null_visibility_values null_visibility_values) ],
        [ qw(clone_field_id set_clone_field set_clone_visibility_values clone_visibility_values) ],
    ) {
        if ($field->can_tweak($_->[0]))
        {
            my $vf = $ARGS->{$_->[0]};
            if ($vf ne $field->${\$_->[0]}())
            {
                $field->${\$_->[1]}($vf);
                $field->${\$_->[2]}([]);
            }
            else
            {
                $field->${\$_->[2]}([ list $ARGS->{$_->[3]} ]);
            }
        }
    }
    $field->update();

    delete_token($token);

    $vars->{message} = 'custom_field_updated';

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'del')
{
    my $name = $ARGS->{name} || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', { name => $name });
    $field->custom || ThrowUserError('field_not_custom', { name => $name });
    $field->obsolete || ThrowUserError('field_not_obsolete', { name => $name });

    $vars->{field} = $field;
    $vars->{token} = issue_session_token('delete_field');

    $template->process('admin/custom_fields/confirm-delete.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
}
elsif ($action eq 'delete')
{
    check_token_data($token, 'delete_field');
    my $name = $ARGS->{name} || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', { name => $name });

    # Calling remove_from_db will check if field can be deleted.
    # If the field cannot be deleted, it will throw an error.
    $field->remove_from_db();

    $vars->{field}   = $field;
    $vars->{message} = 'custom_field_deleted';

    delete_token($token);

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
else
{
    ThrowUserError('no_valid_action', { field => 'custom_field' });
}
exit;
