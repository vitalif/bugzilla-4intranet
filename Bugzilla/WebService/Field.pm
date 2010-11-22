#!/usr/bin/perl
# Bugzilla::WebService::Field - API for managing custom fields and values

package Bugzilla::WebService::Field;

use strict;
use base qw(Bugzilla::WebService);
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::WebService::Util qw(validate);

# { field => 'имя_поля' }
sub get_values
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    if (!$field->is_select)
    {
        return {status => 'field_not_select'};
    }
    my $values;
    if ($field->value_field_id)
    {
        $values = [ map { {
            id => $_->id,
            name => $_->name,
            visibility_value_ids => [ map { $_->id } @{$_->visibility_values} ],
        } } @{$field->legal_values} ];
    }
    else
    {
        $values = [ map { { id => $_->id, name => $_->name } } @{$field->legal_values} ];
    }
    return {
        status => 'ok',
        values => $values,
    };
}

# { field => 'имя_поля', value => 'имя_значения', sortkey => число_для_сортировки }
sub add_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = $type->new({ name => $params->{value} });
    if ($value)
    {
        return {status => 'value_already_exists'};
    }
    $value = $type->create({
        value   => $params->{value},
        sortkey => $params->{sortkey},
    });
    return {status => 'ok', id => $value->id};
}

# { field => 'имя_поля', old_value => 'имя_значения', new_value => 'новое_имя_значения', sortkey => новый_sortkey }
sub update_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = $type->new({ name => $params->{old_value} });
    if (!$value)
    {
        return {status => 'value_not_found'};
    }
    $params->{new_value} = $params->{old_value} unless defined $params->{new_value};
    if ($params->{new_value} ne $params->{old_value})
    {
        my $newvalue = $type->new({ name => $params->{new_value} });
        if ($newvalue)
        {
            return {status => 'value_already_exists'};
        }
        $value->set_name($params->{new_value});
    }
    if (exists $params->{sortkey})
    {
        $value->set_sortkey($params->{sortkey});
    }
    $value->update;
    return {status => 'ok', id => $value->id};
}

# { field => 'имя_поля', value => 'имя_значения' }
sub delete_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = $type->new({ name => $params->{value} });
    if (!$value)
    {
        return {status => 'value_not_found'};
    }
    $value->remove_from_db;
    return {status => 'ok'};
}

# { field => 'имя_поля', value => 'имя_значения', ids => [ ID продукта, ID продукта, ... ] }
sub set_visibility_values
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    if (!$field->value_field)
    {
        return {status => 'fieldvalues_not_controlled'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = $type->new({ name => $params->{value} });
    if (!$value)
    {
        return {status => 'value_not_found'};
    }
    my $ids = $params->{ids} || [];
    $ids = [ $ids ] unless ref $ids;
    $ids = [ map { $_->id } @{ Bugzilla::Field::Choice->type($field->value_field)->new_from_list($ids) } ];
    $value->set_visibility_values($ids);
    return {status => 'ok', ids => $ids};
}

1;
__END__

The contents of this file are subject to the Mozilla Public
License Version 1.1 (the "License"); you may not use this file
except in compliance with the License. You may obtain a copy of
the License at http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS
IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
implied. See the License for the specific language governing
rights and limitations under the License.

The Original Code is the Bugzilla Bug Tracking System.

Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
