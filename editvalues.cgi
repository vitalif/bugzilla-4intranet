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
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Token;
use Bugzilla::Field;
use Bugzilla::Field::Choice;

# require the user to have logged in
Bugzilla->login(LOGIN_REQUIRED);

my $dbh      = Bugzilla->dbh;
my $cgi      = Bugzilla->cgi;
my $template = Bugzilla->template;
my $ARGS     = $cgi->VarHash;
my $vars     = {};

Bugzilla->user->in_group('editvalues')
|| $ARGS->{field} eq 'keywords' && Bugzilla->user->in_group('editkeywords')
|| ThrowUserError('auth_failure', {
    group  => 'editvalues',
    action => 'edit',
    object => 'field_values',
});

#
# often-used variables
#
my $action = trim($ARGS->{action} || '');
my $token  = $ARGS->{token};

# Fields listed here must not be edited from this interface.
my %block_list = map { $_ => 1 } qw(product);

#
# field = '' -> Show nice list of fields
#
if (!$ARGS->{field})
{
    my @field_list = grep { !$block_list{$_->name} } Bugzilla->get_fields({ is_select => 1 });
    $vars->{fields} = \@field_list;
    $template->process("admin/fieldvalues/select-field.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

# At this point, the field must be defined.
my $field = Bugzilla::Field->check($ARGS->{field});
if (!$field->is_select || $block_list{$field->name})
{
    ThrowUserError('fieldname_invalid', { field => $field });
}
$vars->{field} = $field;

#
# action='' -> Show nice list of values.
#
display_field_values($vars) unless $action;

#
# action='add' -> show form for adding new field value.
# (next action will be 'new')
#
if ($action eq 'add')
{
    $vars->{token} = issue_session_token('add_field_value');
    $template->process("admin/fieldvalues/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='new' -> add field value entered in the 'action=add' screen
#
if ($action eq 'new')
{
    check_token_data($token, 'add_field_value');

    my $type = $field->value_type;
    # Some types have additional parameters inside REQUIRED_CREATE_FIELDS
    my $created_value = $type->create({
        map { $_ => $ARGS->{$_} }
        grep { defined $ARGS->{$_} } ($type->DB_COLUMNS, $type->REQUIRED_CREATE_FIELDS)
    });
    $created_value->set_visibility_values($ARGS->{visibility_value_id});

    delete_token($token);

    $vars->{message} = 'field_value_created';
    $vars->{value} = $created_value;
    display_field_values($vars);
}

# After this, we always have a value
my $value = $field->value_type->check(exists $ARGS->{value_old} ? $ARGS->{value_old} : $ARGS->{value});
$vars->{value} = $value;

#
# action='del' -> ask if user really wants to delete
# (next action would be 'delete')
#
if ($action eq 'del')
{
    $vars->{token} = issue_session_token('delete_field_value');

    $template->process("admin/fieldvalues/confirm-delete.html.tmpl", $vars)
        || ThrowTemplateError($template->error());

    exit;
}

#
# action='delete' -> really delete the field value
#
if ($action eq 'delete')
{
    check_token_data($token, 'delete_field_value');
    $value->remove_from_db();
    delete_token($token);
    $vars->{message} = 'field_value_deleted';
    $vars->{no_edit_link} = 1;
    display_field_values($vars);
}

#
# action='edit' -> present the edit-value form
# (next action would be 'update')
#
if ($action eq 'edit')
{
    $vars->{token} = issue_session_token('edit_field_value');
    $template->process("admin/fieldvalues/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='update' -> update the field value
#
if ($action eq 'update')
{
    check_token_data($token, 'edit_field_value');
    $vars->{value_old} = $value->name;
    for ($value->UPDATE_COLUMNS)
    {
        $value->set($_, $ARGS->{$_});
    }
    if ($value->field->value_field)
    {
        $vars->{changes}->{visibility_values} = $value->set_visibility_values($ARGS->{visibility_value_id});
    }
    delete_token($token);
    $vars->{changes} = $value->update;
    $vars->{message} = 'field_value_updated';
    display_field_values($vars);
}

#
# No valid action found
#
# We can't get here without $field being defined --
# See the unless($field) block at the top.
ThrowUserError('no_valid_action', { field => $field } );

sub display_field_values
{
    my $vars = shift;
    my $template = Bugzilla->template;
    $vars->{values} = $vars->{field}->legal_values('include_disabled');
    $template->process("admin/fieldvalues/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}
