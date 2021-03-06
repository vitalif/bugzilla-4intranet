# Class representing single value of a field
# Nearly 100% refactored
# Author(s): Vitaliy Filippov <vitalif@mail.ru>, Max Kanat-Alexander <mkanat@bugzilla.org>, Greg Hendricks <ghendricks@novell.com>
# License: Dual-license GPL 3.0+ or MPL 1.1+

use strict;

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
use constant CUSTOM_SORT => undef;

# Table storing many-to-many relationship for this field
sub REL_TABLE { 'bug_'.$_[0]->FIELD_NAME }

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
    op_sys           => 'Bugzilla::OS',
    rep_platform     => 'Bugzilla::Platform',
    keywords         => 'Bugzilla::Keyword',
};

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
            my $code = "package $package;
                use base qw(Bugzilla::Field::Choice);
                use constant DB_TABLE => '$field_name';
                use constant FIELD_NAME => '$field_name';";
            eval $code;
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
sub new
{
    my $class = shift;
    if ($class eq 'Bugzilla::Field::Choice')
    {
        ThrowCodeError('field_choice_must_use_type');
    }
    $class->SUPER::new(@_);
}

#########################
# Database Manipulation #
#########################

# vitalif@mail.ru 2010-11-11 //
# This is incorrect in create() to remove arguments that are not valid DB columns
# BEFORE calling run_create_validators etc, as these methods can change
# params hash (for example turn Bugzilla::Product to product_id field)

sub create
{
    my $self = shift;
    $self = $self->SUPER::create(@_);
    $self->field->touch;
    return $self;
}

sub update
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $fname = $self->field->name;

    $dbh->bz_start_transaction();

    my ($changes, $old_self) = $self->SUPER::update(@_);

    $self->field->touch;
    $dbh->bz_commit_transaction();
    return wantarray ? ($changes, $old_self) : $changes;
}

sub remove_from_db
{
    my $self = shift;
    if ($self->is_default)
    {
        ThrowUserError('fieldvalue_is_default', {
            field => $self->field,
            value => $self,
        });
    }
    if ($self->bug_count)
    {
        ThrowUserError('fieldvalue_still_has_bugs', {
            field => $self->field,
            value => $self,
        });
    }
    # Delete visibility values
    $self->set_visibility_values(undef);
    # Delete controlled value records
    $self->field->update_control_lists($self->id, {});
    # Delete records about this value used as default
    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM field_defaults WHERE field_id=? AND default_value=?", undef, $self->field->id, $self->id);
    if ($self->field->type == FIELD_TYPE_MULTI_SELECT)
    {
        $dbh->do(
            "UPDATE field_defaults SET default_value=REPLACE(default_value, ?, ?) WHERE field_id=?".
            " AND default_value LIKE ?", undef, ','.$self->id.',', ',', $self->field->id, '%,'.$self->id.',%'
        );
        $dbh->do(
            "UPDATE field_defaults SET default_value=SUBSTR(default_value, ?) WHERE field_id=?".
            " AND default_value LIKE ?", undef, length($self->id)+2, $self->field->id, $self->id.',%'
        );
        $dbh->do(
            "UPDATE field_defaults SET default_value=SUBSTR(default_value, 1, LENGTH(default_value)-?) WHERE field_id=?".
            " AND default_value LIKE ?", undef, length($self->id)+1, $self->field->id, '%,'.$self->id
        );
    }
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
    if (!defined $f->{legal_values})
    {
        # Only full unfiltered list of active values is cached between requests
        $all = [ $class->SUPER::get_all() ];
        $f->{legal_values} = $all;
    }
    else
    {
        $all = $f->{legal_values};
    }
    if (!$include_disabled)
    {
        $all = [ grep { $_->is_active } @$all ];
    }
    if (!$f->value_field_id || $f->value_field->name ne 'product' || Bugzilla->user->in_group('editvalues'))
    {
        # Just return unfiltered list
        return @$all;
    }
    # Product field is a special case: it has access controls applied.
    # So if our values are controlled by product field value,
    # return only ones visible inside products visible to current user.
    my $h = Bugzilla->fieldvaluecontrol
        ->{Bugzilla->get_field('product')->id}
        ->{values}
        ->{$f->id};
    my $visible_ids = { map { $_->id => 1 } Bugzilla::Product->get_all };
    my $vis;
    my $filtered = [];
    for my $value (@$all)
    {
        $vis = !$h->{$value->id} || !%{$h->{$value->id}};
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
    # CUSTOM_SORT means the class has manual sorting in new_from_list, like Bugzilla::Version
    if (!$class->CUSTOM_SORT)
    {
        my $order = $class->LIST_ORDER;
        $order =~ s/(\s+(A|DE)SC)(?!\w)//giso;
        $order = [ split /[\s,]*,[\s,]*/, $order ];
        $filtered = [ sort
        {
            # FIXME Think about "natural sort"?
            my $t;
            for (@$order)
            {
                if ($a->{$_} =~ /^-?\d+(\.\d+)?$/so && $b->{$_} =~ /^-?\d+(\.\d+)?$/so)
                {
                    $t = $a->{$_} <=> $b->{$_};
                }
                else
                {
                    $t = lc $a->{$_} cmp lc $b->{$_};
                }
                return $t if $t;
            }
            return 0;
        } @$filtered ];
    }
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

#############
# Accessors #
#############

sub is_active { return $_[0]->{isactive}; }
sub sortkey   { return $_[0]->{sortkey};  }
sub full_name { return $_[0]->name; }

# FIXME Never use bug_count() on a copy from legal_values, as the result will be cached...
sub bug_count
{
    my $self = shift;
    return $self->{bug_count} if defined $self->{bug_count};
    my $dbh = Bugzilla->dbh;
    my $fname = $self->field->name;
    my $count;
    if ($self->field->type == FIELD_TYPE_MULTI_SELECT)
    {
        $count = $dbh->selectrow_array("SELECT COUNT(*) FROM ".$self->REL_TABLE." WHERE value_id = ?", undef, $self->id);
    }
    else
    {
        $count = $dbh->selectrow_array("SELECT COUNT(*) FROM bugs WHERE $fname = ?", undef, $self->id);
    }
    $self->{bug_count} = $count;
    return $count;
}

sub field
{
    my $invocant = shift;
    return Bugzilla->get_field($invocant->FIELD_NAME);
}

sub is_default
{
    my $self = shift;
    return $self->field->default_value_hash->{$self->id};
}

sub controls_visibility_of_fields
{
    my $self = shift;
    my $vid = $self->id;
    my $fid = $self->field->id;
    return [
        map { Bugzilla->get_field($_) }
        grep { Bugzilla->fieldvaluecontrol->{$fid}->{fields}->{$_}->{$vid} }
        keys %{Bugzilla->fieldvaluecontrol->{$fid}->{fields}}
    ];
}

sub controls_visibility_of_field_values
{
    my $self = shift;
    my $vid = $self->id;
    my $fid = $self->field->id;
    if (!$self->{controls_visibility_of_field_values})
    {
        my $h = Bugzilla->fieldvaluecontrol->{$fid}->{values};
        my $r = {};
        for my $f (keys %$h)
        {
            my $t = [ grep { $h->{$f}->{$_}->{$vid} } keys %{$h->{$f}} ];
            $f = Bugzilla->get_field($f);
            $r->{$f->name} = $f->value_type->new_from_list($t) if @$t;
        }
        $self->{controls_visibility_of_field_values} = $r;
    }
    return $self->{controls_visibility_of_field_values};
}

sub visibility_values
{
    my $self = shift;
    my $f;
    if ($self->field->value_field_id && !($f = $self->{visibility_values}))
    {
        my $hash = Bugzilla->fieldvaluecontrol
            ->{$self->field->value_field_id}
            ->{values}
            ->{$self->field->id}
            ->{$self->id};
        $f = $hash ? [ keys %$hash ] : [];
        if (@$f)
        {
            $f = $self->field->value_field->value_type->new_from_list($f);
        }
        $self->{visibility_values} = $f;
    }
    return $f;
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
    my ($value_ids, $skip_invisible) = @_;
    $self->field->update_visibility_values($self->id, $value_ids, $skip_invisible);
    delete $self->{visibility_values};
    return $value_ids;
}

##############
# Validators #
##############

sub _check_value
{
    my ($invocant, $value) = @_;

    my $field = $invocant->field;

    $value = trim($value);

    ThrowUserError('fieldvalue_undefined') if !defined $value || $value eq "";
    ThrowUserError('fieldvalue_name_too_long', { value => $value })
        if length($value) > MAX_FIELD_VALUE_SIZE;

    my $exists = $invocant->type($field)->new({ name => $value });
    if ($exists && (!blessed($invocant) || $invocant->id != $exists->id))
    {
        ThrowUserError('fieldvalue_already_exists', { field => $field, value => $exists });
    }

    return $value;
}

sub _check_sortkey
{
    my ($invocant, $value) = @_;
    $value = trim($value);
    return 0 if !$value;
    # Store for the error message in case detaint_natural clears it.
    my $orig_value = $value;
    detaint_natural($value) || ThrowUserError('fieldvalue_sortkey_invalid', {
        sortkey => $orig_value,
        field   => $invocant->field,
    });
    return $value;
}

1;

__END__

=head1 NAME

Bugzilla::Field::Choice - A legal value for a <select>-type field.

=head1 SYNOPSIS

 my $field = new Bugzilla::Field({name => 'bug_status'});

 my $choice = $field->value_type->new(1);

 my $choices = $field->value_type->new_from_list([1,2,3]);
 my $choices = $field->value_type->get_all();
 my $choices = $field->value_type->match({ sortkey => 10 });

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
