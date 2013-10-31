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
# The Initial Developer of the Original Code is NASA.
# Portions created by NASA are Copyright (C) 2006 San Jose State
# University Foundation. All Rights Reserved.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Greg Hendricks <ghendricks@novell.com>
#                 Vitaliy Filippov    <vitalif@mail.ru>

use strict;

##############################################
# Class representing single value of a field #
##############################################

package Bugzilla::Field::Choice;

use base qw(Bugzilla::Object);

use Bugzilla::Config qw(SetParam write_params);
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Field;
use Bugzilla::Util qw(trim detaint_natural trick_taint diff_arrays);

use Scalar::Util qw(blessed);

##################
# Initialization #
##################

use constant DB_COLUMNS => qw(
    id
    value
    sortkey
    isactive
);

use constant UPDATE_COLUMNS => qw(
    value
    sortkey
    isactive
);

use constant NAME_FIELD => 'value';
use constant LIST_ORDER => 'sortkey, value';

use constant REQUIRED_CREATE_FIELDS => qw(value);

use constant VALIDATORS => {
    value    => \&_check_value,
    sortkey  => \&_check_sortkey,
    isactive => \&Bugzilla::Object::check_boolean,
};

use constant CLASS_MAP => {
    bug_status       => 'Bugzilla::Status',
    product          => 'Bugzilla::Product',
    component        => 'Bugzilla::Component',
    version          => 'Bugzilla::Version',
    target_milestone => 'Bugzilla::Milestone',
    classification   => 'Bugzilla::Classification',
};

use constant DEFAULT_MAP => {
    op_sys       => 'defaultopsys',
    rep_platform => 'defaultplatform',
    priority     => 'defaultpriority',
    bug_severity => 'defaultseverity',
};

use constant EXCLUDE_CONTROLLED_FIELDS => ();

#################
# Class Factory #
#################

# Bugzilla::Field::Choice is actually an abstract base class. Every field
# type has its own dynamically-generated class for its values. This allows
# certain fields to have special types, like how bug_status's values
# are Bugzilla::Status objects.

sub type
{
    my ($class, $field) = @_;
    my $field_obj = blessed $field ? $field : Bugzilla->get_field($field, THROW_ERROR);
    my $field_name = $field_obj->name;

    my $package;
    if ($class->CLASS_MAP->{$field_name})
    {
        $package = $class->CLASS_MAP->{$field_name};
        if (!defined *{"${package}::DB_TABLE"})
        {
            eval "require $package";
        }
    }
    else
    {
        # For generic classes, we use a lowercase class name, so as
        # not to interfere with any real subclasses we might make some day.
        $package = "Bugzilla::Field::Choice::$field_name";

        # The package only needs to be created once. We check if the DB_TABLE
        # glob for this package already exists, which tells us whether or not
        # we need to create the package (this works even under mod_perl, where
        # this package definition will persist across requests)).
        if (!defined *{"${package}::DB_TABLE"})
        {
            eval <<EOC;
                package $package;
                use base qw(Bugzilla::Field::Choice);
                use constant DB_TABLE => '$field_name';
                use constant FIELD_NAME => '$field_name';
EOC
        }
    }

    return $package;
}

################
# Constructors #
################

# We just make new() enforce this, which should give developers 
# the understanding that you can't use Bugzilla::Field::Choice
# without calling type().
sub new {
    my $class = shift;
    if ($class eq 'Bugzilla::Field::Choice') {
        ThrowCodeError('field_choice_must_use_type');
    }
    $class->SUPER::new(@_);
}

#########################
# Database Manipulation #
#########################

# Our subclasses can take more arguments than we normally accept.
# So, we override create() to remove arguments that aren't valid
# columns. (Normally Bugzilla::Object dies if you pass arguments
# that aren't valid columns.)
sub create {
    my $class = shift;
    my ($params) = @_;
    foreach my $key (keys %$params) {
        if (!grep {$_ eq $key} $class->_get_db_columns) {
            delete $params->{$key};
        }
    }
    return $class->SUPER::create(@_);
}

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $fname = $self->field->name;

    $dbh->bz_start_transaction();

    my ($changes, $old_self) = $self->SUPER::update(@_);
    if (exists $changes->{$self->NAME_FIELD}) {
        my ($old, $new) = @{ $changes->{$self->NAME_FIELD} };
        if ($self->field->type != FIELD_TYPE_MULTI_SELECT)
        {
            $self->field->{has_activity} = 1;
            $dbh->do(
                "INSERT INTO bugs_activity (bug_id, who, bug_when, fieldid, added, removed)".
                " SELECT bug_id, ?, NOW(), ?, ?, ? FROM bugs WHERE $fname = ?", undef,
                Bugzilla->user->id, $self->field->id, $new, $old, $old
            );
            $dbh->do("UPDATE bugs SET $fname = ?, lastdiffed = NOW() WHERE $fname = ?",
                     undef, $new, $old);
        }

        if ($old_self->is_default) {
            my $param = $self->DEFAULT_MAP->{$self->field->name};
            SetParam($param, $self->name);
            write_params();
        }
    }

    $self->field->touch;
    $dbh->bz_commit_transaction();
    return wantarray ? ($changes, $old_self) : $changes;
}

sub remove_from_db {
    my $self = shift;
    if ($self->is_default) {
        ThrowUserError('fieldvalue_is_default',
                       { field => $self->field, value => $self,
                         param_name => $self->DEFAULT_MAP->{$self->field->name},
                       });
    }
    if ($self->is_static) {
        ThrowUserError('fieldvalue_not_deletable', 
                       { field => $self->field, value => $self });
    }
    if ($self->bug_count) {
        ThrowUserError('fieldvalue_still_has_bugs',
                       { field => $self->field, value => $self });
    }
    $self->_check_if_controller();
    $self->set_visibility_values(undef);
    $self->field->touch;
    $self->SUPER::remove_from_db();
}

# Default implementation of get_all for choice fields
# Returns all values (active+inactive), enabled for products that current user can see
sub get_all
{
    my $class = shift;
    my ($include_disabled) = @_;
    my $rc_cache = Bugzilla->rc_cache_fields;
    if ($rc_cache->{get_all}->{$class}->{$include_disabled ? 1 : 0})
    {
        # Filtered lists are cached for a single request
        return @{$rc_cache->{get_all}->{$class}->{$include_disabled ? 1 : 0}};
    }
    my $f = $class->field;
    my $all;
    my $cache = Bugzilla->cache_fields;
    if (!$include_disabled && grep { $_ eq 'isactive' } $class->DB_COLUMNS)
    {
        $all = $class->match({ isactive => 1 });
    }
    elsif (!defined $f->{legal_values})
    {
        # Only full unfiltered list of active values is cached between requests
        $all = [ $class->SUPER::get_all() ];
        $f->{legal_values} = $all;
    }
    else
    {
        $all = $f->{legal_values};
    }
    if (!$f->value_field_id || $f->value_field->name ne 'product')
    {
        # Just return unfiltered list
        return @$all;
    }
    # Product field is a special case: it has access controls applied.
    # So if our values are controlled by product field value,
    # return only ones visible inside products visible to current user.
    my $h = Bugzilla->fieldvaluecontrol_hash
        ->{Bugzilla->get_field('product')->id}
        ->{values}
        ->{$f->id};
    my $visible_ids = { map { $_->id => 1 } Bugzilla::Product->get_all };
    my $vis;
    my $filtered;
    for my $value (@$all)
    {
        $vis = !$h->{$value->id} || !%{$h->{$value->id}} ? 1 : 0;
        for (keys %{$h->{$value->id}})
        {
            if ($visible_ids->{$_})
            {
                $vis = 1;
                last;
            }
        }
        push @$filtered, $value if $vis;
    }
    my $order = $class->LIST_ORDER;
    $order =~ s/(\s+(A|DE)SC)(?!\w)//giso;
    $order = [ split /[\s,]*,[\s,]*/, $order ];
    $filtered = [ sort
    {
        my $t;
        for (@$order)
        {
            if ($a->{$_} =~ /^[\d\.]+$/s && $b->{$_} =~ /^[\d\.]+$/s)
            {
                $t = $a->{$_} <=> $b->{$_};
            }
            else
            {
                $t = $a->{$_} cmp $b->{$_};
            }
            return $t if $t;
        }
        return 0;
    } @$filtered ];
    $rc_cache->{get_all}->{$class}->{$include_disabled ? 1 : 0} = $filtered;
    return @$filtered;
}

# Returns names of all _active_ values, enabled for products that current user can see
sub get_all_names
{
    my $class = shift;
    my $dup = {};
    my $names = [];
    my $idf = $class->ID_FIELD;
    my $namef = $class->NAME_FIELD;
    # Remember IDs of each name
    for ($class->get_all())
    {
        if (!$dup->{$_->{$namef}})
        {
            push @$names, ($dup->{$_->{$namef}} = { name => $_->{$namef}, ids => [ $_->{$idf} ] });
        }
        else
        {
            push @{$dup->{$_->{$namef}}->{ids}}, $_->{$idf};
        }
    }
    return $names;
}

sub _check_if_controller
{
    my $self = shift;
    my %exclude = map { $_ => 1 } $self->EXCLUDE_CONTROLLED_FIELDS;
    my $c_fields = $self->controls_visibility_of_fields;
    my $c_values = $self->controls_visibility_of_field_values;
    $c_fields = [ grep { !$exclude{$_->name} } @$c_fields ];
    $c_values = {
        map { $_ => $c_values->{$_} }
        grep { !$exclude{$_} && $c_values->{$_} }
        keys %$c_values
    };
    if (@$c_fields || %$c_values)
    {
        ThrowUserError('fieldvalue_is_controller', {
            value  => $self,
            fields => [ map { $_->name } @$c_fields ],
            vals   => $c_values,
        });
    }
}

#############
# Accessors #
#############

sub is_active { return $_[0]->{'isactive'}; }
sub sortkey   { return $_[0]->{'sortkey'};  }

sub bug_count {
    my $self = shift;
    return $self->{bug_count} if defined $self->{bug_count};
    my $dbh = Bugzilla->dbh;
    my $fname = $self->field->name;
    my $count;
    if ($self->field->type == FIELD_TYPE_MULTI_SELECT) {
        $count = $dbh->selectrow_array("SELECT COUNT(*) FROM bug_$fname
                                         WHERE value_id = ?", undef, $self->id);
    }
    else {
        $count = $dbh->selectrow_array("SELECT COUNT(*) FROM bugs 
                                         WHERE $fname = ?",
                                       undef, $self->name);
    }
    $self->{bug_count} = $count;
    return $count;
}

sub field
{
    my $invocant = shift;
    return Bugzilla->get_field($invocant->FIELD_NAME);
}

sub is_default {
    my $self = shift;
    my $name = $self->DEFAULT_MAP->{$self->field->name};
    # If it doesn't exist in DEFAULT_MAP, then there is no parameter
    # related to this field.
    return 0 unless $name;
    return ($self->name eq Bugzilla->params->{$name}) ? 1 : 0;
}

sub is_static {
    my $self = shift;
    # If we need to special-case Resolution for *anything* else, it should
    # get its own subclass.
    if ($self->field->name eq 'resolution') {
        return grep($_ eq $self->name, ('', 'FIXED', 'MOVED', 'DUPLICATE'))
               ? 1 : 0;
    }
    elsif ($self->field->custom) {
        return $self->name eq '---' ? 1 : 0;
    }
    return 0;
}

sub controls_visibility_of_fields
{
    my $self = shift;
    my $vid = $self->id;
    my $fid = $self->field->id;
    $self->{controls_visibility_of_fields} ||= [
        map { Bugzilla->get_field($_->{field_id}) }
        grep { !$_->{value_id} &&
            $_->{visibility_value_id} == $vid &&
            $_->{visibility_field_id} == $fid }
        @{Bugzilla->fieldvaluecontrol}
    ];
    return $self->{controls_visibility_of_fields};
}

sub controls_visibility_of_field_values
{
    my $self = shift;
    my $vid = $self->id;
    my $fid = $self->field->id;
    if (!$self->{controls_visibility_of_field_values})
    {
        my $r = {};
        for (@{Bugzilla->fieldvaluecontrol})
        {
            if ($_->{value_id} &&
                $_->{visibility_value_id} == $vid &&
                $_->{visibility_field_id} == $fid)
            {
                push @{$r->{$_->{field_id}}}, $_->{value_id};
            }
        }
        $self->{controls_visibility_of_field_values} = { map {
            Bugzilla->get_field($_)->name =>
                Bugzilla::Field::Choice->type(Bugzilla->get_field($_))->new_from_list($r->{$_})
        } keys %$r };
    }
    return $self->{controls_visibility_of_field_values};
}

sub visibility_values
{
    my $self = shift;
    my $f;
    if ($self->field->value_field_id && !($f = $self->{visibility_values}))
    {
        my $hash = Bugzilla->fieldvaluecontrol_hash
            ->{$self->field->value_field_id}
            ->{values}
            ->{$self->field->id}
            ->{$self->id};
        $f = $hash ? [ keys %$hash ] : [];
        if (@$f)
        {
            my $type = Bugzilla::Field::Choice->type($self->field->value_field);
            $f = $type->new_from_list($f);
        }
        $self->{visibility_values} = $f;
    }
    return $f;
}

sub has_visibility_value
{
    my $self = shift;
    my ($value, $default) = @_;
    $default = 1 if !defined $default;
    return $default if $self->name eq '---' || !$self->field->value_field_id;
    $value = $value->id if ref $value;
    my $hash = Bugzilla->fieldvaluecontrol_hash
        ->{$self->field->value_field_id}
        ->{values}
        ->{$self->field->id}
        ->{$self->id};
    return $default if !$hash || !%$hash;
    return $hash->{$value};
}

sub is_default_controlled_value
{
    my $self = shift;
    my $result = $self->has_visibility_value(@_);
    return $result unless ref $result;
    return $result->{is_default};
}

# Check visibility of field value for a bug
sub check_visibility
{
    my $self = shift;
    return 1 if $self->name eq '---';
    my $bug = shift || return 1;
    my $vf = $self->field->value_field || return 1;
    my $m = $vf->name;
    $m = blessed $bug ? $bug->$m : $bug->{$m};
    $m = ref $m ? $m->name : $m;
    my $value = Bugzilla::Field::Choice->type($vf)->new({ name => $m }) || return 1;
    return $self->has_visibility_value($value);
}

############
# Mutators #
############

sub set_is_active { $_[0]->set('isactive', $_[1]); }
*set_isactive = *set_is_active;

sub set_name      { $_[0]->set('value', $_[1]);    }
sub set_sortkey   { $_[0]->set('sortkey', $_[1]);  }

sub set_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    update_visibility_values($self->field, $self->id, $value_ids);
    delete $self->{visibility_values};
    return 1;
}

##############
# Validators #
##############

sub _check_value {
    my ($invocant, $value) = @_;

    my $field = $invocant->field;

    $value = trim($value);

    # Make sure people don't rename static values
    if (blessed($invocant) && $value ne $invocant->name 
        && $invocant->is_static) 
    {
        ThrowUserError('fieldvalue_not_editable',
                       { field => $field, old_value => $invocant });
    }

    ThrowUserError('fieldvalue_undefined') if !defined $value || $value eq "";
    ThrowUserError('fieldvalue_name_too_long', { value => $value })
        if length($value) > MAX_FIELD_VALUE_SIZE;

    my $exists = $invocant->type($field)->new({ name => $value });
    if ($exists && (!blessed($invocant) || $invocant->id != $exists->id)) {
        ThrowUserError('fieldvalue_already_exists', 
                       { field => $field, value => $exists });
    }

    return $value;
}

sub _check_sortkey {
    my ($invocant, $value) = @_;
    $value = trim($value);
    return 0 if !$value;
    # Store for the error message in case detaint_natural clears it.
    my $orig_value = $value;
    detaint_natural($value)
        || ThrowUserError('fieldvalue_sortkey_invalid',
                          { sortkey => $orig_value,
                            field   => $invocant->field });
    return $value;
}

1;

__END__

=head1 NAME

Bugzilla::Field::Choice - A legal value for a <select>-type field.

=head1 SYNOPSIS

 my $field = new Bugzilla::Field({name => 'bug_status'});

 my $choice = new Bugzilla::Field::Choice->type($field)->new(1);

 my $choices = Bugzilla::Field::Choice->type($field)->new_from_list([1,2,3]);
 my $choices = Bugzilla::Field::Choice->type($field)->get_all();
 my $choices = Bugzilla::Field::Choice->type($field->match({ sortkey => 10 }); 

=head1 DESCRIPTION

This is an implementation of L<Bugzilla::Object>, but with a twist.
You can't call any class methods (such as C<new>, C<create>, etc.) 
directly on C<Bugzilla::Field::Choice> itself. Instead, you have to
call C<Bugzilla::Field::Choice-E<gt>type($field)> to get the class
you're going to instantiate, and then you call the methods on that.

We do that because each field has its own database table for its values, so
each value type needs its own class.

See the L</SYNOPSIS> for examples of how this works.

=head1 METHODS

=head2 Class Factory

In object-oriented design, a "class factory" is a method that picks
and returns the right class for you, based on an argument that you pass.

=over

=item C<type>

Takes a single argument, which is either the name of a field from the
C<fielddefs> table, or a L<Bugzilla::Field> object representing a field.

Returns an appropriate subclass of C<Bugzilla::Field::Choice> that you
can now call class methods on (like C<new>, C<create>, C<match>, etc.)

B<NOTE>: YOU CANNOT CALL CLASS METHODS ON C<Bugzilla::Field::Choice>. You
must call C<type> to get a class you can call methods on.

=back

=head2 Accessors

These are in addition to the standard L<Bugzilla::Object> accessors.

=over

=item C<sortkey>

The key that determines the sort order of this item.

=item C<field>

The L<Bugzilla::Field> object that this field value belongs to.

=item C<controlled_values>

Tells you which values in B<other> fields appear (become visible) when this
value is set in its field.

Returns a hashref of arrayrefs. The hash keys are the names of fields,
and the values are arrays of C<Bugzilla::Field::Choice> objects,
representing values that this value controls the visibility of, for
that field.

=back
