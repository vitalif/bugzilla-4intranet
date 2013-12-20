#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# Page of editinig visibility of custom fields.
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vladimir Koptev <vladimir.koptev@gmail.com>

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

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};
# There is only one section about components in the documentation,
# so all actions point to the same page.
$vars->{'doc_section'} = 'visibility-list.html';

#
# Preliminary checks:
#
my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editfields')
  || scalar(@{$user->get_editable_products})
  || ThrowUserError("auth_failure", {group  => "admin",
                                     action => "edit",
                                     object => "custom_fields"});

#
# often used variables
#
my $field_name    = trim($cgi->param('field')   || '');
my $value_name    = trim($cgi->param('value')   || '');
my $action        = trim($cgi->param('action')  || '');
my $token         = $cgi->param('token');

unless ($field_name) {
    ThrowUserError('no_valid_field', {'field' => "field"});
}

my $field = Bugzilla->get_field($field_name);
ThrowUserError('no_valid_field', {'field' => "field"}) unless $field;

my $value = Bugzilla::Field::Choice->type($field)->check($value_name);
ThrowUserError('no_valid_value', {'field' => "value"}) unless $value;

#
# action='' -> Show list of custom fields
#
unless ($action) {
    $vars->{'field'}  = $field;
    $vars->{'value'}  = $value;
    # controlled fields
    my $controlled_fields = { map { $_->id => $_ } values $field->controls_visibility_of() };
    # all custom fields
    my @fields = Bugzilla->get_fields({custom => 1, sort => 1});
    # except fields that controls this
    my $except_fields = { map { $_->id => { map { $_->id => 1 } values $_->controls_visibility_of } } @fields };
    # fields list
    my $fields_visibility = {
        map {
            $_->id => {
                id => $_->id,
                name => $_->name,
                description => $_->description,
                visible => $controlled_fields->{$_->id} ? $controlled_fields->{$_->id}->has_visibility_value($value) : 0
            }
        }
        grep { $_->id ne $field->id && !($except_fields->{$_->id}->{$field->id}) } @fields
    };
    #check visible for all fields
    for my $cfield (@fields)
    {
        # first check is not current field and not controlled
        my $visible_for_all = $cfield->id ne $field->id && !($except_fields->{$field->id}->{$cfield->id});
        if ($visible_for_all)
        {
            # check visible for all values
            for my $cvalue (@{$cfield->legal_values})
            {
                next if $cvalue->is_static;
                if (!$cvalue->visible_for_all(1))
                {
                    $visible_for_all = 0;
                    last;
                }
            }
        }
        if ($visible_for_all)
        {
            # realy visible for all
            # if exists set visibility else push
            if ($fields_visibility->{$cfield->id})
            {
                $fields_visibility->{$cfield->id}->{visible_for_all} = 1;
                $fields_visibility->{$cfield->id}->{visible} = 1;
            }
            else
            {
                push $vars->{'fields'}, {
                    id => $cfield->id,
                    name => $cfield->name,
                    description => $cfield->description,
                    visible_for_all => 1
                };
            }
        }
    }
    $vars->{'fields'} = [values $fields_visibility];
    $vars->{'token'} = issue_session_token('change_visibility');
    $template->process("admin/fieldvalues/visibility-list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

# update result page
if ($action eq 'update' && $token) {
    check_token_data($token, 'change_visibility');

    my @fields = $cgi->param('fields[]');
    my $controlled_fields = { map { $_->id => $_ } values $field->controls_visibility_of() };
    my $length = @fields;
    my $to_update;
    # if somthing checked
    if ($length) {
        # for each checked
        for my $field_id (@fields) {
            my $cfield = Bugzilla->get_field($field_id);
            my $changed = 0;
            # set VISIBILITY field
            if ($cfield->visibility_field_id ne $field->id) {
                $cfield->set_visibility_field($field->id);
                $changed = 1;
            }
            # set VALUE field
            if ($cfield->value_field_id ne $field->id) {
                $cfield->set_value_field($field->id);
                $changed = 1;
            }
            # set visibility values
            my $visibility_values = {map { $_->id=>1 } values ($cfield->visibility_values || [])};
            if (!$visibility_values->{$value->id}) {
                $visibility_values->{$value->id} = 1;
                $cfield->set_visibility_values([keys $visibility_values]);
                $changed = 1;
            }
            # update if something was changed
            if ($changed) {
                if (!$to_update->{$cfield->id}) {
                    $to_update->{$cfield->id} = {field => $cfield, actions => {updated => 1}};
                }
            }
            # delete from controlled fields for next checking "visible for all"
            if ($controlled_fields->{$cfield->id}) {
                delete $controlled_fields->{$cfield->id};
            }
        }
    }

    # make visible for all if it needs
    for my $cfield (values $controlled_fields) {
        my $visibility_values = { map { $_->id => 1 } values $cfield->visibility_values};
        if (!%$visibility_values) {
            # cfield is visible for all values
            # get them all!!!
            $visibility_values = { map { $_->id => 1 } values $cfield->visibility_field->legal_values};
        }
        if ($visibility_values->{$value->id}) {
            delete $visibility_values->{$value->id};
            $cfield->set_visibility_values([keys $visibility_values]);
            if (!$to_update->{$cfield->id}) {
                 $to_update->{$cfield->id} = {field => $cfield, actions => {}};
            }
            $to_update->{$cfield->id}->{actions}->{cleared} = 1;
        }
        if (!%$visibility_values) {
            $cfield->set_visibility_field(undef);
            $cfield->set_value_field(undef);
            if (!$to_update->{$cfield->id}) {
                 $to_update->{$cfield->id} = {field => $cfield, actions => {}};
            }
            $to_update->{$cfield->id}->{actions}->{cleared} = 1;
        }
    }

    # make lists of updated and cleared fields for view
    my @updated;
    my @cleared;
    for my $cfield (values $to_update) {
        $cfield->{field}->update();
        if ($cfield->{actions}->{cleared}) {
            push @cleared, $cfield->{field}->description;
        }
        if ($cfield->{actions}->{updated}) {
            push @updated, $cfield->{field}->description;
        }
    }
    delete_token($token);

    $vars->{'field'} = $field;
    $vars->{'value'} = $value;
    $vars->{'update'} = 1;
    $vars->{'updated'} = join(', ', @updated);
    $vars->{'cleared'} = join(', ', @cleared);
    $template->process("admin/fieldvalues/visibility-list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# No valid action found
#
ThrowUserError('no_valid_action', {'field' => "action"});

__END__
