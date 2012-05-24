#!/usr/bin/perl
# Bugzilla::WebService::Field - API for managing custom fields and values
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::Field;

use strict;
use base qw(Bugzilla::WebService);
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::WebService::Util qw(validate);
use Bugzilla::Error;

use constant READ_ONLY => qw(
    get_values
);

# Get field and choice type by $params->{field}
# Throws 'field_not_found' for incorrect fields
sub _get_field
{
    my ($params) = @_;
    my $field = Bugzilla->get_field($params->{field});
    ThrowUserError('account_disabled') if !$field;
    my $type = Bugzilla::Field::Choice->type($field);
    return ($field, $type);
}

# Get value by id=$params->{id} or name=$params->{value}
# Throws 'value_not_found' for incorrect values
sub _get_value
{
    my ($type, $params, $value_param) = @_;
    my $value;
    if ($params->{id})
    {
        $value = $type->new({ id => $params->{id} });
    }
    elsif ($params->{value})
    {
        $value = $type->new({ name => $params->{$value_param || 'value'} });
    }
    ThrowUserError('value_not_found') if !$value;
    return $value;
}

# Get all values for a field. Arguments:
# field => <field_name>
sub get_values
{
    my ($self, $params) = @_;
    my ($field) = _get_field($params);
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

# Add value for a field. Arguments:
# field => <field_name>
# value => <value_name>
# sortkey => <number_for_sorting>
# ...other columns from $type->DB_COLUMNS...
sub add_value
{
    my ($self, $params) = @_;
    my ($field, $type) = _get_field($params);
    my $value = $type->new({ name => $params->{value} });
    if ($value)
    {
        return {status => 'value_already_exists'};
    }
    my $row = {};
    delete $params->{$type->ID_FIELD};
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
    $value = $type->create($row);
    return {status => 'ok', id => $value->id};
}

# Update a value. Arguments:
# field => <field_name>
# old_value => <old_value_name> or id => <value_id>
# value => <new_value>
# sortkey => <new_sortkey>
# isactive => <new_isactive>
# ...other columns from $type->DB_COLUMNS...
sub update_value
{
    my ($self, $params) = @_;
    my ($field, $type) = _get_field($params);
    my $value = _get_value($type, $params, 'old_value') || return {status => 'value_not_found'};
    if (defined $params->{value} && $params->{value} ne $value->name)
    {
        my $newvalue = $type->new({ name => $params->{value} });
        if ($newvalue)
        {
            return {status => 'value_already_exists', other_id => $newvalue->id, my_id => $value->id};
        }
        $value->set_name($params->{value});
    }
    # Other columns
    delete $params->{$type->ID_FIELD};
    for ($type->DB_COLUMNS)
    {
        if ($_ ne $type->NAME_FIELD &&
            exists $params->{$_})
        {
            my $m = "set_$_";
            $value->$m($params->{$_});
        }
    }
    $value->update;
    return {status => 'ok', id => $value->id};
}

# Delete a value (by name or by id). Arguments:
# field => <field_name>
# value => <value_name> or id => <value_id>
sub delete_value
{
    my ($self, $params) = @_;
    my ($field, $type) = _get_field($params);
    my $value = _get_value($type, $params) || return {status => 'value_not_found'};
    $value->remove_from_db;
    return {status => 'ok'};
}

# Set visibility values for a value. Arguments:
# field => <field_name>
# value => <value_name> or id => <value_id>
# ids => [ visibility_ID, visibility_ID, ... ]
sub set_visibility_values
{
    my ($self, $params) = @_;
    my ($field, $type) = _get_field($params);
    if (!$field->value_field)
    {
        return {status => 'fieldvalues_not_controlled'};
    }
    my $value = _get_value($type, $params) || return {status => 'value_not_found'};
    my $ids = $params->{ids} || [];
    $ids = [ $ids ] unless ref $ids;
    $ids = [ map { $_->id } @{ Bugzilla::Field::Choice->type($field->value_field)->new_from_list($ids) } ];
    $value->set_visibility_values($ids);
    return {status => 'ok', ids => $ids};
}

1;
__END__
