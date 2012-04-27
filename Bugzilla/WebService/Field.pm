#!/usr/bin/perl
# Bugzilla::WebService::Field - API for managing custom fields and values
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::Field;

use strict;
use base qw(Bugzilla::WebService);
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::Hook;
use Bugzilla::WebService::Util qw(validate);

# { field => 'field_name' }
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

# { field => 'field_name', value => 'value_name',
#   sortkey => number_for_sorting,
#   [optional] id => id,
#   other columns from $type->DB_COLUMNS }
sub add_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    if ($type->new({ name => $params->{value} }) ||
        $params->{id} && $type->new({ id => $params->{id} }))
    {
        return {status => 'value_already_exists'};
    }
    my $row = {};
    for ($type->DB_COLUMNS)
    {
        if ($_ eq $type->NAME_FIELD)
        {
            $row->{$_} = $params->{value};
        }
        elsif (exists $params->{$_})
        {
            $row->{$_} = $params->{$_};
        }
    }
    my $value = $type->create($row);
    return {status => 'ok', id => $value->id};
}

# Get value by id=$params->{id} or name=$params->{value}
sub _get_value
{
    my ($type, $params) = @_;
    my $value;
    if ($params->{id})
    {
        $value = $type->new({ id => $params->{id} });
    }
    elsif ($params->{value})
    {
        $value = $type->new({ name => $params->{value} });
    }
    return $value;
}

# { field => 'field_name'
#   ( id => 'old_id' | value => 'old_value' )
#   ( new_value => 'new_value' )?
#   sortkey => new_sortkey
#   isactive => new_isactive
#   other columns from $type->DB_COLUMNS }
sub update_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = _get_value($type, $params) || return {status => 'value_not_found'};
    # Name
    if (defined $params->{new_value} && $params->{new_value} ne $value->name)
    {
        my $newvalue = $type->new({ name => $params->{new_value} });
        if ($newvalue)
        {
            return {status => 'value_already_exists'};
        }
        $value->set_name($params->{new_value});
    }
    # Other fields
    for ($type->DB_COLUMNS)
    {
        if ($_ ne $type->NAME_FIELD &&
            $_ ne $type->ID_FIELD &&
            exists $params->{$_})
        {
            my $m = "set_$_";
            $value->$m($params->{$_});
        }
    }
    $value->update;
    return {status => 'ok', id => $value->id};
}

# { field => 'field_name', ( id => value_id | value => 'value_name' ) }
sub delete_value
{
    my ($self, $params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    if (!$field)
    {
        return {status => 'field_not_found'};
    }
    my $type = Bugzilla::Field::Choice->type($field);
    my $value = _get_value($type, $params) || return {status => 'value_not_found'};
    $value->remove_from_db;
    return {status => 'ok'};
}

# { field => 'field_name', ( id => value_id | value => 'value_name' ),
#   ids => [ visibility_ID, visibility_ID, ... ] }
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
    my $value = _get_value($type, $params) || return {status => 'value_not_found'};
    my $ids = $params->{ids} || [];
    $ids = [ $ids ] unless ref $ids;
    $ids = [ map { $_->id } @{ Bugzilla::Field::Choice->type($field->value_field)->new_from_list($ids) } ];
    $value->set_visibility_values($ids);
    return {status => 'ok', ids => $ids};
}

1;
__END__
