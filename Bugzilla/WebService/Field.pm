#!/usr/bin/perl
# Bugzilla::WebService::Field - API for managing custom fields and values
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::Field;

use strict;
use base qw(Bugzilla::WebService);
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::Util;
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
    my $type = $field->value_type;
    return ($field, $type);
}

# Get value by id=$params->{id} or name=$params->{value}
# Throws 'value_not_found' for incorrect values
sub _get_value
{
    my ($type, $params, $value_param) = @_;
    my $value;
    $value_param ||= 'value';
    if ($params->{id})
    {
        $value = $type->new({ id => $params->{id} });
    }
    elsif ($params->{$value_param})
    {
        $value = $type->new({ name => $params->{$value_param} });
    }
    ThrowUserError('value_not_found') if !$value;
    return $value;
}

# Get all or some values for a field. Arguments:
# field => <field name>
# optional:
# name => <name(s) to search for exact match>
# match => <string(s) to search in the beginning of value name>
# visibility_value_ids => <ID(s) of controlling value in which returned ones should be visible>
# limit => maximum number of matches
sub get_values
{
    my ($self, $params) = @_;
    my ($field) = _get_field($params);
    if (!$field->is_select)
    {
        return {status => 'field_not_select'};
    }
    my $join = '';
    my $where = [];
    my $bind = [];
    my $type = $field->value_type;
    my @vv = $field->value_field_id ? list $params->{visibility_value_ids} : ();
    my @match = list $params->{match};
    my @name = list $params->{name};
    if (@match || @name)
    {
        my @m;
        push @m, ('v.'.$type->NAME_FIELD.' LIKE ?') x @match;
        push @m, 'v.'.$type->NAME_FIELD.' IN ('.join(', ', ('?') x @name).')' if @name;
        push @$where, '('.join(' OR ', @m).')';
        push @$bind, (map { $_.'%' } @match), @name;
    }
    if (@vv)
    {
        $join = " INNER JOIN fieldvaluecontrol fc ON fc.field_id=?".
            " AND fc.value_id=v.id AND fc.visibility_value_id IN (".join(", ", ("?") x @vv).")";
        unshift @$bind, $field->id, @vv;
    }
    $where = @$where ? join(' AND ', @$where) : '1=1';
    my $order = $type->LIST_ORDER;
    $order =~ s/(^|,)\s*(\S)/$1v.$2/gso;
    trick_taint($_) for @$bind;
    my $values = Bugzilla->dbh->selectall_arrayref(
        "SELECT v.* FROM ".$type->DB_TABLE." v $join WHERE $where GROUP BY v.id".
        " ORDER BY $order ".($params->{limit} ? Bugzilla->dbh->sql_limit(int($params->{limit})) : ''),
        {Slice=>{}}, @$bind
    );
    bless $_, $type for @$values;
    if ($field->value_field_id)
    {
        $values = [ map { {
            id => $_->id,
            name => $_->name,
            visibility_value_ids => [ map { $_->id } @{$_->visibility_values} ],
        } } @$values ];
    }
    else
    {
        $values = [ map { { id => $_->id, name => $_->name } } @$values ];
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
    # Backwards compatibility (old version had value/new_value instead of old_value/value)
    $params->{old_value} ||= $params->{value};
    $params->{value} = delete $params->{new_value} if defined $params->{new_value};
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
    $ids = [ map { $_->id } @{ $field->value_field->value_type->new_from_list($ids) } ];
    $value->set_visibility_values($ids);
    return {status => 'ok', ids => $ids};
}

1;
__END__
