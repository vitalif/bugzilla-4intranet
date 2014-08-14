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
# Contributor(s): Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Token;

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};

# Make sure the user is logged in and is an administrator.
my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editfields') || ThrowUserError('auth_failure', {
    group  => 'editfields',
    action => 'edit',
    object => 'custom_fields',
});

my $action = trim($cgi->param('action') || '');
my $token  = $cgi->param('token');

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
        name                => scalar $cgi->param('name'),
        url                 => scalar $cgi->param('url'),
        description         => scalar $cgi->param('desc'),
        type                => scalar $cgi->param('type'),
        sortkey             => scalar $cgi->param('sortkey'),
        mailhead            => scalar $cgi->param('new_bugmail'),
        enter_bug           => scalar $cgi->param('enter_bug'),
        clone_bug           => scalar $cgi->param('clone_bug'),
        obsolete            => scalar $cgi->param('obsolete'),
        is_mandatory        => !scalar $cgi->param('nullable'),
        custom              => 1,
        visibility_field_id => scalar $cgi->param('visibility_field_id'),
        value_field_id      => scalar $cgi->param('value_field_id'),
        add_to_deps         => scalar $cgi->param('add_to_deps'),
    });
    $field->set_visibility_values([ $cgi->param('visibility_value_id') ]);
    $field->set_null_visibility_values([ $cgi->param('null_visibility_values') ]);

    delete_token($token);

    $vars->{'message'} = 'custom_field_created';

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'edit')
{
    my $name = $cgi->param('name') || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', {'name' => $name});

    $vars->{'field'} = $field;
    $vars->{'token'} = issue_session_token('edit_field');

    $template->process('admin/custom_fields/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'update')
{
    check_token_data($token, 'edit_field');
    my $name = $cgi->param('name');

    # Validate fields.
    $name || ThrowUserError('field_missing_name');
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', {'name' => $name});

    $field->set_description(scalar $cgi->param('desc'));
    $field->set_sortkey(scalar $cgi->param('sortkey'));
    $field->set_url(scalar $cgi->param('url'));
    $field->set_add_to_deps($cgi->param('add_to_deps'));
    if ($field->can_tweak('mailhead'))
    {
        $field->set_in_new_bugmail(scalar $cgi->param('new_bugmail'));
    }
    if ($field->can_tweak('obsolete'))
    {
        $field->set_obsolete(scalar $cgi->param('obsolete'));
    }
    if ($field->can_tweak('nullable'))
    {
        $field->set_is_mandatory(!scalar $cgi->param('nullable'));
    }
    if ($field->can_tweak('default_value'))
    {
        $field->set_default_value($field->type == FIELD_TYPE_MULTI_SELECT ? [ $cgi->param('default_value') ] : scalar $cgi->param('default_value'));
    }
    if ($field->can_tweak('clone_bug'))
    {
        $field->set_clone_bug(scalar $cgi->param('clone_bug'));
    }
    if ($field->can_tweak('value_field_id'))
    {
        $field->set_value_field(scalar $cgi->param('value_field_id'));
    }
    if ($field->can_tweak('default_field_id'))
    {
        # FIXME Disallow to change default field if it will lead to losing all the default values
        $field->set_default_field($cgi->param('default_field_id'));
    }
    for (
        [ qw(visibility_field_id set_visibility_field set_visibility_values visibility_value_id) ],
        [ qw(null_field_id set_null_field set_null_visibility_values null_visibility_values) ],
        [ qw(clone_field_id set_clone_field set_clone_visibility_values clone_visibility_values) ],
    ) {
        if ($field->can_tweak($_->[0]))
        {
            my $vf = $cgi->param($_->[0]);
            if ($vf ne $field->${\$_->[0]}())
            {
                $field->${\$_->[1]}($vf);
                $field->${\$_->[2]}([]);
            }
            else
            {
                $field->${\$_->[2]}([ $cgi->param($_->[3]) ]);
            }
        }
    }
    $field->update();

    delete_token($token);

    $vars->{'field'}   = $field;
    $vars->{'message'} = 'custom_field_updated';

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'del')
{
    my $name = $cgi->param('name');

    # Validate field.
    $name || ThrowUserError('field_missing_name');
    # Do not allow deleting non-custom fields.
    # Custom field names must start with "cf_".
    if ($name !~ /^cf_/) {
        $name = 'cf_' . $name;
    }
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', {'name' => $name});

    $vars->{'field'} = $field;
    $vars->{'token'} = issue_session_token('delete_field');

    $template->process('admin/custom_fields/confirm-delete.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
}
elsif ($action eq 'delete')
{
    check_token_data($token, 'delete_field');
    my $name = $cgi->param('name');

    # Validate fields.
    $name || ThrowUserError('field_missing_name');
    # Do not allow deleting non-custom fields.
    # Custom field names must start with "cf_".
    if ($name !~ /^cf_/) {
        $name = 'cf_' . $name;
    }
    my $field = Bugzilla->get_field($name);
    $field || ThrowUserError('customfield_nonexistent', {'name' => $name});

    # Calling remove_from_db will check if field can be deleted.
    # If the field cannot be deleted, it will throw an error.
    $field->remove_from_db();

    $vars->{'field'}   = $field;
    $vars->{'message'} = 'custom_field_deleted';

    delete_token($token);

    $template->process('admin/custom_fields/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
else
{
    ThrowUserError('no_valid_action', {'field' => 'custom_field'});
}
