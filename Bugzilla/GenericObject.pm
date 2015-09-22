#!/usr/bin/perl
# Generic object type based on the metamodel stored in the database
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: (c) 2014+ Vitaliy Filippov <vitalif@mail.ru>, see http://wiki.4intra.net/Bugzilla4Intranet

package Bugzilla::GenericObject;

use utf8;
use strict;

use Bugzilla::Field;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Util;

use List::Util qw(min);
use URI;
use URI::QueryParam;
use Date::Format qw(time2str);
use POSIX qw(floor);
use Scalar::Util qw(blessed);

use base qw(Bugzilla::NewObject Exporter);

use constant ID_FIELD => 'id';
use constant LIST_ORDER => 'id';
sub CLASS_ID { Bugzilla->get_class($_[0]->CLASS_NAME)->id }
sub CLASS_NAME { die 'CLASS_NAME is abstract method' }

sub class
{
    my $class = shift;
    return Bugzilla->get_class($class->CLASS_ID);
}

sub DB_COLUMNS
{
    my $class = shift;
    my $cache = Bugzilla->cache_fields;
    return @{$cache->{columns}->{$class}} if defined $cache->{columns}->{$class};

    my @columns = ($class->ID_FIELD);
    my $dbh = Bugzilla->dbh;

    push @columns, map { $_->db_column }
        grep { $_->type != FIELD_TYPE_MULTI && $_->type != FIELD_TYPE_REVERSE }
        Bugzilla->get_fields({ class_id => $class->CLASS_ID, obsolete => 0 });

    $cache->{columns}->{$class} = \@columns;
    return @columns;
}

# Allow to update every valid DB column :-/
*UPDATE_COLUMNS = *DB_COLUMNS;

sub NUMERIC_COLUMNS
{
    my $class = shift;
    my %columns = (
        (map { $_->name => 1 } Bugzilla->get_fields({ class_id => $class->CLASS_ID, type => FIELD_TYPE_NUMERIC })),
    );
    return \%columns;
}

sub DATE_COLUMNS
{
    my $class = shift;
    return { map { $_->name => 1 } Bugzilla->get_fields({ class_id => $class->CLASS_ID, type => FIELD_TYPE_DATETIME }) };
}

use constant OVERRIDE_ID_FIELD => {};

use constant CUSTOM_FIELD_VALIDATORS => {
    FIELD_TYPE_SINGLE()   => \&_set_select_field,
    FIELD_TYPE_MULTI()    => \&_set_multi_field,
    FIELD_TYPE_REVERSE()  => \&_set_reverse_field,
    FIELD_TYPE_FREETEXT() => \&_set_freetext_field,
    FIELD_TYPE_TEXTAREA() => \&_set_default_field,
    FIELD_TYPE_DATETIME() => \&_set_datetime_field,
    FIELD_TYPE_NUMERIC()  => \&_set_numeric_field,
    FIELD_TYPE_INTEGER()  => \&_set_integer_field,
    FIELD_TYPE_EXTURL()   => \&_set_freetext_field,
    FIELD_TYPE_BOOLEAN()  => \&_set_boolean_field,
};

sub SETTERS
{
    my $class = shift;
    $class = ref($class) || $class;
    my $cache = Bugzilla->cache_fields;
    return $cache->{setters}->{$class} if defined $cache->{setters}->{$class};

    my $s = {};
    for my $field (Bugzilla->get_fields({ class_id => $class->CLASS_ID }))
    {
        $s->{$field->name} = CUSTOM_FIELD_VALIDATORS->{$field->type};
    }
    my $ns = $class->OVERRIDE_SETTERS($s);
    if ($ns ne $s && ref $ns)
    {
        $s = { %$s, %$ns };
    }

    $cache->{setters}->{$class} = $s;
    return $cache->{setters}->{$class};
}

# These dependencies specify in which order should setters be called for correct validation
sub DEPENDENCIES
{
    my $class = shift;
    $class = ref($class) || $class;
    my $cache = Bugzilla->cache_fields;
    return $cache->{field_deps}->{$class} if defined $cache->{field_deps}->{$class};

    my $deps = {};
    foreach my $field (Bugzilla->get_fields({ class_id => $class->CLASS_ID, obsolete => 0 }))
    {
        for (qw(visibility_field value_field null_field))
        {
            $deps->{$field->name}->{$field->$_->name} = 1 if $field->$_;
        }
    }
    $class->OVERRIDE_DEPS($deps);

    return ($cache->{field_deps}->{$class} = $deps);
}

sub OVERRIDE_SETTERS
{
}

sub OVERRIDE_DEPS
{
}

# Check if an object exists or throw an error
sub check_exists
{
    my ($class, $id) = @_;

    my $self = $class->new(trim($id));
    if (!$self)
    {
        ThrowUserError('object_not_found', { class => $class->CLASS_NAME, id => $id });
    }

    return $self;
}

sub _before_update
{
    my $self = shift;

    # First check dependent field values
    $self->check_dependent_fields;

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    # FIXME 'shift ||' is just a temporary hack until all updating happens inside this function
    my $delta_ts = shift || $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    # You can't set these fields by hand
    $self->{delta_ts} = $delta_ts;
    delete $self->{lastdiffed};

    # Check/set default values
    $self->check_default_values if !$self->id;

    # FIXME: Run pre-create/pre-update hooks
}

sub _after_update
{
    my ($self, $changes) = @_;

    # Transform IDs to names for the activity log
    $self->transform_id_changes($changes);
    delete $changes->{delta_ts};
    delete $changes->{lastdiffed};

    # Insert the values into the multiselect value tables
    $self->save_multiselects($changes);

    # Save reverse relationships
    $self->save_reverse_fields($changes);

    if ($self->{_old_self})
    {
        $self->log_history($changes, $self->{delta_ts});
    }

    # FIXME: Run post-create/post-update hooks

    for (Bugzilla->get_fields({ class_id => undef, value_class_id => $self->class->id }))
    {
        $_->touch;
    }
}

# Default implementation of get_all for object classes
# Filters by 'isactive' column if it's there
# FIXME Forbid get_all for some classes
sub get_all
{
    my $class = shift;
    my ($include_disabled) = @_;
    $include_disabled = 1 if !grep { $_ eq 'isactive' } $class->DB_COLUMNS;
    my $rc_cache = Bugzilla->rc_cache_fields;
    if ($rc_cache->{get_all}->{$class}->{$include_disabled ? 1 : 0})
    {
        # Filtered lists are cached inside a single request
        return @{$rc_cache->{get_all}->{$class}->{$include_disabled ? 1 : 0}};
    }
    my $class_obj = $class->class;
    my $all = $class_obj->{_all_objects};
    if (!$all)
    {
        # Only full unfiltered list of objects is cached between requests
        $all = $class_obj->{_all_objects} = [ $class->SUPER::get_all() ];
    }
    if (!$include_disabled)
    {
        $all = [ grep { $_->{isactive} } @$all ];
    }
    return @$all;
}

# Returns names of all _active_ objects
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

sub user_can_edit
{
    my ($class, $ids) = @_;
    return 1;
}

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    for my $f (Bugzilla->get_fields({ class_id => undef, value_class_id => $self->class->id }))
    {
        if ($f->default_value_hash->{$self->id})
        {
            ThrowUserError('fieldvalue_is_default', {
                field => $f,
                value => $self,
            });
        }
        if ($f->count_value_objects($self->id))
        {
            ThrowUserError('fieldvalue_still_has_objects', {
                field => $f,
                value => $self,
            });
        }
    }
    # Log final values of all fields
    my ($delta_ts) = $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');
    my $changes = {};
    for my $f (grep { $_ ne $self->ID_FIELD && $_ ne 'delta_ts' && $_ ne 'lastdiffed' } $self->DB_COLUMNS)
    {
        $changes->{$f} = [ $self->{$f}, '' ];
    }
    for my $f (map { $_->name } Bugzilla->get_fields({
        class_id => $self->CLASS_ID,
        type => [ FIELD_TYPE_REVERSE, FIELD_TYPE_MULTI ],
    }))
    {
        $changes->{$f} = [ join_escaped(', ', ',', map { $_->name } @{$self->get_object($f)}), '' ];
    }
    $self->log_history($changes, $delta_ts);
    # Remove field dependencies
    for my $f (Bugzilla->get_fields({ class_id => undef, value_class_id => $self->class->id }))
    {
        $dbh->do(
            "DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id=?",
            undef, $f->id, $self->id
        );
        $f->update_control_lists($self->id, {});
        # Remove records about this object being used as default
        $dbh->do("DELETE FROM field_defaults WHERE field_id=? AND default_value=?", undef, $f->id, $self->id);
        if ($f->type == FIELD_TYPE_MULTI_SELECT)
        {
            $dbh->do(
                "UPDATE field_defaults SET default_value=REPLACE(default_value, ?, ?) WHERE field_id=?".
                " AND default_value LIKE ?", undef, ','.$self->id.',', ',', $f->id, '%,'.$self->id.',%'
            );
            $dbh->do(
                "UPDATE field_defaults SET default_value=SUBSTR(default_value, ?) WHERE field_id=?".
                " AND default_value LIKE ?", undef, length($self->id)+2, $f->id, $self->id.',%'
            );
            $dbh->do(
                "UPDATE field_defaults SET default_value=SUBSTR(default_value, 1, LENGTH(default_value)-?) WHERE field_id=?".
                " AND default_value LIKE ?", undef, length($self->id)+1, $f->id, '%,'.$self->id
            );
        }
        $f->touch;
    }
    # Remove the object itself
    $self->SUPER::remove_from_db();
}

# There is no guarantee that any setters were called after creating an
# empty object, so we must make sure all fields have allowed values.
sub check_default_values
{
    my $self = shift;
    for my $field (Bugzilla->get_fields({ class_id => $self->CLASS_ID, obsolete => 0 }))
    {
        if (!$self->{$field->db_column} && Bugzilla::Field->SQL_DEFINITIONS->{$field->type} &&
            Bugzilla::Field->SQL_DEFINITIONS->{$field->type}->{NOTNULL})
        {
            $self->set($field->name, undef);
        }
    }
    # creation_ts, delta_ts and lastdiffed are supported by this code,
    # but they may or may not be saved in the DB
    $self->{creation_ts} = $self->{delta_ts} if !defined $self->{creation_ts};
}

# FIXME cache it
sub get_dependent_check_order
{
    my $self = shift;
    my %seen = ();
    my %check = map { $_->id => $_ } Bugzilla->get_fields({
        class_id => $self->CLASS_ID,
        obsolete => 0,
    });
    my @check;
    for my $f (@{ [ values %check ] }) # iterate over array copy
    {
        my @d = ($f->id);
        my @a;
        while (@d)
        {
            $f = $check{shift(@d)||''};
            if ($f)
            {
                unshift @a, $f;
                delete $check{$f->id};
                unshift @d, $f->visibility_field_id, $f->value_field_id, $f->null_field_id, $f->default_field_id;
            }
        }
        push @check, @a;
    }
    return @check;
}

# All validation of field values that depend on other fields' values MUST be done here!
# It is needed because else the result of validation will depend on the calling order.
sub check_dependent_fields
{
    my $self = shift;
    my $incorrect_fields = {};

    for my $field_obj ($self->get_dependent_check_order)
    {
        my $fn = $field_obj->name;
        if ($field_obj->obsolete)
        {
            # Do not validate values of obsolete fields, only set empty values for new objects
            $self->set($fn, undef) if !$self->id;
            next;
        }
        # Check field visibility
        if (!$field_obj->check_visibility($self))
        {
            # Field is invisible, clear value
            $self->set($fn, undef);
            next;
        }
        # FIXME Run hooks here?
        # Check field values of dependent select fields
        if ($field_obj->is_select)
        {
            # $self->{_unknown_dependent_values} may contain names of unidentified values
            my $value_objs = $self->{_unknown_dependent_values}->{$fn} || $self->get_object($fn);
            if (!defined $value_objs)
            {
                my $nullable = $field_obj->check_is_nullable($self);
                if (!$nullable || !$self->id)
                {
                    # Try to select default value
                    my $default = $field_obj->get_default_value($self, 1);
                    if ($default)
                    {
                        $self->set($field_obj->name, $default);
                        $value_objs = $self->{_unknown_dependent_values}->{$fn} || $self->get_object($fn);
                    }
                }
                if (!defined $value_objs && !$nullable)
                {
                    ThrowUserError('object_not_specified_generic', {
                        subject_class => $self->class,
                        subject_id => $self->id,
                        class => $field_obj->value_type,
                        field => $field_obj,
                    });
                }
            }
            elsif ($field_obj->value_field_id)
            {
                my $vv = $self->get_ids($field_obj->value_field->name);
                my @bad = grep { !ref $_ || !$field_obj->is_value_enabled($_, $vv) } list($value_objs);
                if (@bad)
                {
                    my $n = $field_obj->value_field->name;
                    $incorrect_fields->{$fn} = {
                        field => $field_obj,
                        options => [ map { $_->name } @{ $field_obj->restricted_legal_values($self->get_ids($n)) } ],
                        values => [ map { ref $_ ? $_ : undef } @bad ],
                        value_names => [ map { ref $_ ? $_->name : $_ } @bad ],
                        controller => $self->get_object($n),
                    };
                }
            }
            elsif (my @bad = grep { !ref $_ } list($value_objs))
            {
                ThrowUserError('object_unknown_generic', {
                    field => $field_obj,
                    names => [ @bad ],
                });
            }
        }
        # Check other fields for empty values
        elsif (!$self->{$fn} || ($field_obj->type == FIELD_TYPE_FREETEXT ||
            $field_obj->type == FIELD_TYPE_TEXTAREA) && $self->{$fn} =~ /^\s*$/so)
        {
            my $nullable = $field_obj->check_is_nullable($self);
            if (!$nullable || !$self->id)
            {
                # Try to set default value
                my $default = $field_obj->get_default_value($self, 1);
                if ($default)
                {
                    $self->set($field_obj->name, $default);
                }
            }
            if (!$nullable && (!$self->{$fn} || ($field_obj->type == FIELD_TYPE_FREETEXT ||
                $field_obj->type == FIELD_TYPE_TEXTAREA) && $self->{$fn} =~ /^\s*$/so))
            {
                ThrowUserError('field_not_nullable', { field => $field_obj });
            }
        }
    }

    delete $self->{_unknown_dependent_values};

    # If we're not in browser, throw an error
    if (Bugzilla->usage_mode != USAGE_MODE_BROWSER && %$incorrect_fields)
    {
        ThrowUserError('incorrect_field_values', {
            object           => $self,
            incorrect_fields => [ values %$incorrect_fields ],
        });
    }

    # Else display UI for verifying values
    if (Bugzilla->usage_mode == USAGE_MODE_BROWSER && %$incorrect_fields)
    {
        Bugzilla->template->process('object/verify-field-values.html.tmpl', {
            incorrect_fields => [ values %$incorrect_fields ],
            incorrect_field_descs => [ map { $_->{field}->description } values %$incorrect_fields ],
            exclude_params_re => '^(' . join('|', keys %$incorrect_fields) . ')$',
        });
        Bugzilla->dbh->rollback;
        exit;
    }
}

sub transform_id_changes
{
    my ($self, $changes) = @_;
    # Transform single-select DB column changes to names
    for my $f (Bugzilla->get_fields({ class_id => $self->CLASS_ID, type => FIELD_TYPE_SINGLE }))
    {
        if (delete $changes->{$f->db_column})
        {
            $changes->{$f->name} = [
                $self->{_old_self} ? $self->{_old_self}->get_string($f->name) : '',
                $self->get_string($f->name)
            ];
        }
    }
}

sub save_reverse_fields
{
    my ($self, $changes) = @_;
    for my $field (Bugzilla->get_fields({ class_id => $self->CLASS_ID, obsolete => 0, type => FIELD_TYPE_REVERSE }))
    {
        my $name = $field->name;
        next if !defined $self->{$name};
        my $vf = $field->value_field;
        my $vt = $field->value_field->class->type;
        my ($removed, $added) = diff_arrays($self->{_old_self} ? $self->{_old_self}->$name : [], $self->$name);
        # Try to retrieve added/removed objects slightly more optimal
        my $old_rev = {};
        if ($self->{_old_self} && (my $o = $self->{_old_self}->{$name.'_obj'}))
        {
            $old_rev->{$_->id} = $_ for @$o;
        }
        elsif (@$removed)
        {
            $old_rev = { map { $_->id => $_ } $vt->new_from_list($removed) };
        }
        my $cur_rev = @$added ? { map { $_->id => $_ } @{$self->get_object($name)} } : {};
        # FIXME Maybe trigger mid-air collisions before updating?
        if ($vf->type == FIELD_TYPE_SINGLE)
        {
            # Update other objects to change reverse single relationships
            if (@$removed)
            {
                for (@$removed)
                {
                    $old_rev->{$_}->set($vf->name, undef);
                    $old_rev->{$_}->update;
                }
            }
            if (@$added)
            {
                for (@$added)
                {
                    $cur_rev->{$_}->set($vf->name, $self->id);
                    $cur_rev->{$_}->update;
                }
            }
        }
        elsif (@$removed || @$added)
        {
            # Update many-to-many relationship table directly for reverse multiple relationships
            $changes->{$name} = [
                join_escaped(', ', ',', map { $old_rev->{$_}->name; } @$removed),
                join_escaped(', ', ',', map { $cur_rev->{$_}->name; } @$added),
            ];
            Bugzilla->dbh->do("DELETE FROM ".$field->rel_table." WHERE ".$field->rel_value_id."=?", undef, $self->id);
            if (@{$self->$name})
            {
                Bugzilla->dbh->do(
                    "INSERT INTO ".$field->rel_table." (".$field->rel_value_id.", ".$field->rel_object_id.") VALUES ".
                    join(',', ('(?, ?)') x @{$self->$name}),
                    undef, map { ($self->id, $_) } @{$self->$name}
                );
            }
        }
    }
}

sub save_multiselects
{
    my ($self, $changes) = @_;
    my @multi_selects = Bugzilla->get_fields({ class_id => $self->CLASS_ID, obsolete => 0, type => FIELD_TYPE_MULTI });
    foreach my $field (@multi_selects)
    {
        my $name = $field->name;
        next if !defined $self->{$name};
        my %old = $self->{_old_self} ? (map { $_->id => $_ } @{$self->{_old_self}->get_object($name)}) : ();
        my %new = map { $_->id => $_ } @{$self->get_object($name)};
        my $removed = [ grep { !$new{$_} } keys %old ];
        my $added = [ grep { !$old{$_} } keys %new ];
        if (@$removed || @$added)
        {
            $changes->{$name} = [
                join_escaped(', ', ',', map { $old{$_}->name; } @$removed),
                join_escaped(', ', ',', map { $new{$_}->name; } @$added),
            ];
            Bugzilla->dbh->do("DELETE FROM ".$field->rel_table." WHERE ".$field->rel_object_id."=?", undef, $self->id);
            if (@{$self->$name})
            {
                Bugzilla->dbh->do(
                    "INSERT INTO ".$field->rel_table." (".$field->rel_object_id.", ".$field->rel_value_id.") VALUES ".
                    join(',', ('(?, ?)') x @{$self->$name}),
                    undef, map { ($self->id, $_) } @{$self->$name}
                );
            }
        }
    }
}

#####################################################################
# Validators/setters
#####################################################################

sub _set_datetime_field
{
    my ($self, $date_time, $field) = @_;

    # Empty datetimes are empty strings or strings only containing
    # 0's, whitespace, and punctuation.
    if ($date_time =~ /^[\s0[:punct:]]*$/)
    {
        return $self->{$field} = undef;
    }

    $date_time = trim($date_time);
    my ($date, $time) = split(' ', $date_time);
    if ($date && !validate_date($date))
    {
        ThrowUserError('illegal_date', { date => $date, format => 'YYYY-MM-DD' });
    }
    if ($time && !validate_time($time))
    {
        ThrowUserError('illegal_time', { time => $time, format => 'HH:MM:SS' });
    }
    return $date_time;
}

sub _set_default_field
{
    my ($self, $value, $field) = @_;
    if (!defined($value))
    {
        return '';
    }
    return trim($value);
}

sub _set_numeric_field
{
    my ($self, $text, $field) = @_;
    ($text) = $text =~ /^(-?\d+(\.\d+)?)$/so;
    return $text || 0;
}

sub _set_integer_field
{
    my ($self, $text, $field) = @_;
    ($text) = $text =~ /^(-?\d+)$/so;
    return $text || 0;
}

sub _set_boolean_field
{
    my ($self, $value, $field) = @_;
    $value = $value ? 1 : 0;
    return $value;
}

sub _set_freetext_field
{
    my ($self, $text, $field) = @_;
    $text = defined($text) ? trim($text) : '';
    if (length($text) > MAX_FREETEXT_LENGTH)
    {
        ThrowUserError('freetext_too_long', { text => $text });
    }
    return $text;
}

sub _set_multi_field
{
    my ($self, $values, $field) = @_;
    $values = defined $values ? [ $values ] : [] if ref($values) ne 'ARRAY';
    if (!$values || !@$values)
    {
        $self->{$field.'_obj'} = [];
        return [];
    }
    if (!grep { ref $_ } @$values)
    {
        my $field_obj = Bugzilla->get_class_field($field, $self->CLASS_ID);
        my $t = $field_obj->value_type;
        if (!grep { !/^\d+$/ } @$values)
        {
            # Allow to specify IDs
            $values = $t->new_from_list($values);
        }
        else
        {
            my $value_objs = $t->match({ $t->NAME_FIELD => $values });
            my $h = { map { lc($_->{$t->NAME_FIELD}) => $_ } @$value_objs };
            my @bad = grep { !$h->{lc $_} } @$values;
            if (@bad)
            {
                $self->{_unknown_dependent_values}->{$field} = \@bad;
                return undef;
            }
            $values = $value_objs;
        }
    }
    $self->{$field.'_obj'} = $values;
    return [ map { $_->id } @$values ];
}

sub _set_select_field
{
    my ($self, $value, $field) = @_;
    if (!defined $value || !length $value)
    {
        $self->{_unknown_dependent_values}->{$field} = undef;
        $self->{$field.'_obj'} = undef;
        return $self->{$field} = undef;
    }
    my $field_obj = Bugzilla->get_class_field($field, $self->CLASS_ID);
    my $t = $field_obj->value_type;
    my $value_obj = ref $value ? $value : $t->new({ name => $value });
    if (!$value_obj)
    {
        $self->{_unknown_dependent_values}->{$field} = [ $value ];
        return undef;
    }
    $self->{$field.'_obj'} = $value_obj;
    return $value_obj->id;
}

sub _set_reverse_field
{
    my ($self, $ids, $field) = @_;
    return [] if !$ids;
    my $field_obj = Bugzilla->get_class_field($field, $self->CLASS_ID);
    my $old = $self->{_old_self} || $self;
    $old = $old->get_ids($field);
    $ids = [ $ids ] if !ref $ids;
    $self->{$field.'_obj'} = $field_obj->value_field->value_type->new_from_list($ids);
    $self->{$field} = [ map { $_->id } @{ $self->{$field.'_obj'} } ];
    my $chg = [ diff_arrays($old, $self->{$field}) ];
    $chg = [ @{$chg->[0]}, @{$chg->[1]} ];
    # Check permission for multiple objects at once
    $field_obj->value_field->value_type->user_can_edit($chg);
    return undef;
}

#####################################################################
# Instance Accessors
#####################################################################

# These subs are in alphabetical order, as much as possible.
# If you add a new sub, please try to keep it in alphabetical order
# with the other ones.

#####################################################################
# Subroutines
#####################################################################

sub ValidateTime
{
    my ($time, $field) = @_;

    $time =~ tr/,/./;
    $time = trim($time) || 0;

    if ($time =~ /^(-?)(\d+):(\d+)$/so)
    {
        # HH:MM
        $time = $1 . ($2 + $3/60 + ($4||0)/3600);
        $time = floor($time*100+0.5)/100;
    }
    elsif ($time =~ /^(-?\d+(?:\.\d+)?)d$/so)
    {
        # days
        $time = $1 * 8;
    }

    # regexp verifies one or more digits, optionally followed by a period and
    # zero or more digits, OR we have a period followed by one or more digits
    # (allow negatives, though, so people can back out errors in time reporting)
    if ($time !~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/so)
    {
        ThrowUserError("number_not_numeric", {field => "$field", num => "$time"});
    }

    # Only the "work_time" field is allowed to contain a negative value.
    if ($time < 0 && $field ne "work_time")
    {
        ThrowUserError("number_too_small", {field => "$field", num => "$time", min_num => "0"});
    }

    if ($time > 99999.99)
    {
        ThrowUserError("number_too_large", {field => "$field", num => "$time", max_num => "99999.99"});
    }

    return $time;
}

# Update the activity table to reflect changes made in this object.
sub log_history
{
    my $self = shift;
    my ($changes, $delta_ts) = @_;
    my @delta_ts = $delta_ts ? ($delta_ts) : ();
    $delta_ts = $delta_ts ? "?" : "NOW()";
    my @rows;
    my $userid = Bugzilla->user->id;
    foreach my $field (keys %$changes)
    {
        my $change = $changes->{$field};
        my $from = defined $change->[0] ? $change->[0] : '';
        my $to = defined $change->[1] ? $change->[1] : '';
        my $f = Bugzilla->get_class_field($field, $self->CLASS_ID);
        die "BUG: log_history: '$field' is unknown field for class ".$self->CLASS_NAME if !$f;
        if (!$f->{has_activity})
        {
            $f->{has_activity} = 1;
            $f->update;
        }
        push @rows, $self->CLASS_ID, $self->id, $userid, @delta_ts, $f->id, $from, $to;
    }
    if (@rows)
    {
        Bugzilla->dbh->do(
            "INSERT INTO objects_activity".
            " (class_id, object_id, who, change_ts, field_id, removed, added) VALUES ".
            join(", ", ("(?, ?, ?, $delta_ts, ?, ?, ?)") x (@rows/(6+@delta_ts))),
            undef, @rows
        );
    }
}

# Get the activity of an object, starting from $starttime (if given).
sub get_history
{
    my $class = shift;
    my ($object_id, $starttime) = @_;

    my $rows = Bugzilla->dbh->selectall_arrayref(
        "SELECT a.*, " . Bugzilla->dbh->sql_date_format('a.change_ts') .
        " change_time, p.login_name changer FROM objects_activity a, profiles p, fielddefs f".
        " WHERE a.class_id=? AND a.object_id=? AND a.field_id=f.id AND a.who=p.userid".
        (defined $starttime ? " AND a.change_ts > ?" : "")." ORDER BY a.change_ts, a.who, f.sortkey, f.description",
        {Slice=>{}}, $class->CLASS_ID, $object_id, (defined $starttime ? $starttime : ())
    );

    my (@operations, $operation);
    foreach my $change (@$rows)
    {
        # An operation, done by 'who' at time 'when', has a number of 'changes' associated with it.
        # If this is the start of a new operation, store the data from the previous one, and set up the new one.
        if (!$operation || $operation->{who} ne $change->{who} || $operation->{when} ne $change->{change_ts})
        {
            $operation = {
                changer => $change->{changer},
                who => $change->{who},
                when => $change->{change_ts},
                changes => [],
            };
            push @operations, $operation;
        }
        push @{$operation->{changes}}, $change;
    }

    for (my $i = 0; $i < scalar @operations; $i++)
    {
        my $lines = 0;
        for (my $j = 0; $j < scalar @{$operations[$i]{changes}}; $j++)
        {
            my $change = $operations[$i]{changes}[$j];
            $change->{field} = Bugzilla->get_field($change->{field_id});
            if ($change->{field}->type == FIELD_TYPE_TEXTAREA)
            {
                my $diff = Bugzilla::Diff->new($change->{removed}, $change->{added})->get_table;
                if (!@$diff)
                {
                    splice @{$operations[$i]{changes}}, $j, 1;
                    $j--;
                }
                else
                {
                    $operations[$i]{changes}[$j]{lines} = $diff;
                    $lines += scalar @$diff;
                }
            }
            else
            {
                $lines++;
            }
        }
        $operations[$i]{total_lines} = $lines;
    }

    return \@operations;
}

# Bug field permissions:
# + group(access_group): read and comment
# + group(product.editbugs): anything
# + group(TimeTrackingGroup): timetracking fields
# + group(product.canconfirm): bug_status from !is_confirmed -> is_confirmed
# + assigned_to, qa_contact, cc: anything
# + reporter: anything except assigned_to, qa_contact, target_milestone,
#   priority (if !letsubmitterchoosepriority), unconfirm, change open state

#####################################################################
# Autoloaded Accessors
#####################################################################

# Get id(s) of value(s) of a select field
sub get_ids
{
    my $self = shift;
    my ($fn) = @_;
    my $field = ref $fn ? $fn : Bugzilla->get_class_field($fn, $self->CLASS_ID);
    $fn = ref $fn ? $fn->name : $fn;
    $fn = $self->OVERRIDE_ID_FIELD->{$fn} || $fn;
    if ($field && $field->type == FIELD_TYPE_SINGLE)
    {
        return $self->{$fn};
    }
    elsif ($field && ($field->type == FIELD_TYPE_MULTI || $field->type == FIELD_TYPE_REVERSE))
    {
        return $self->$fn;
    }
    else
    {
        die "Invalid join requested - " . $self->CLASS_NAME . "::" . $fn;
    }
}

# Get value(s) of a select field as object(s)
sub get_object
{
    my $self = shift;
    my ($fn) = @_;
    my $attr = $fn.'_obj';
    return $self->{$attr} if exists $self->{$attr};
    my $field = ref $fn ? $fn : Bugzilla->get_class_field($fn, $self->CLASS_ID);
    $fn = ref $fn ? $fn->name : $fn;
    $fn = $self->OVERRIDE_ID_FIELD->{$fn} || $fn;
    if ($field && $field->type == FIELD_TYPE_SINGLE)
    {
        $self->{$attr} = $self->{$fn} ? $field->value_type->new($self->{$fn}) : undef;
    }
    elsif ($field && $field->type == FIELD_TYPE_MULTI)
    {
        $self->{$attr} = $field->value_type->new_from_list($self->$fn);
    }
    elsif ($field && $field->type == FIELD_TYPE_REVERSE)
    {
        $self->{$attr} = $field->value_field->value_type->new_from_list($self->$fn);
    }
    else
    {
        die "Invalid join requested - " . $self->CLASS_NAME . "::" . $attr;
    }
    return $self->{$attr};
}

# Format value(s) of a field in human-readable plain text format.
# Intended for displaying it to user, but NOT for the activity log.
sub get_string
{
    my $self = shift;
    my ($fn) = @_;
    my $field = ref $fn ? $fn : Bugzilla->get_class_field($fn, $self->CLASS_ID);
    $fn = ref $fn ? $fn->name : $fn;
    my $value;
    if (!$field)
    {
        warn "get_string(): Field '$fn' is unknown for class '".$self->CLASS_NAME."'";
        return undef;
    }
    elsif ($field->type == FIELD_TYPE_SINGLE)
    {
        $value = $self->get_object($fn);
        $value = $value && $value->name;
    }
    elsif ($field->type == FIELD_TYPE_MULTI || $field->type == FIELD_TYPE_REVERSE)
    {
        $value = join ', ', map { $_->name } @{$self->get_object($fn)};
    }
    elsif ($field->type == FIELD_TYPE_BOOLEAN)
    {
        $value = $self->$fn ? 'yes' : 'no';
    }
    elsif ($field->type != FIELD_TYPE_UNKNOWN)
    {
        $value = $self->$fn;
    }
    else
    {
        warn "get_string(): Don't know how to format field '$fn' of class '".$self->CLASS_NAME."' in text";
        return undef;
    }
    return $value;
}

# Determines whether an attribute access may be trapped by the AUTOLOAD function
# is for a valid object attribute. Object attributes are properties and methods
# predefined by this module as well as object fields for which an accessor
# can be defined by AUTOLOAD at runtime when the accessor is first accessed.
my $valid_attributes;
sub _validate_attribute
{
    my $class = shift;
    my ($attr) = @_;
    $class = ref($class) || $class;

    if (!$valid_attributes->{$class})
    {
        # Field data may change, but we generate methods on the fly anyway,
        # so don't care about refreshing this value on a per-request basis
        $valid_attributes->{$class} = {
            # every DB column may be returned via an autoloaded accessor
            (map { $_ => 1 } $class->DB_COLUMNS),
            # multiselect, reverse fields
            (map { $_->name => 1 } Bugzilla->get_fields({ class_id => $class->CLASS_ID, type => [ FIELD_TYPE_MULTI, FIELD_TYPE_REVERSE ] })),
            # get_object accessors
            (map { $_->name.'_obj' => 1 } Bugzilla->get_fields({ class_id => $class->CLASS_ID, type => [ FIELD_TYPE_SINGLE, FIELD_TYPE_MULTI ] })),
        };
    }

    return $valid_attributes->{$class}->{$attr} ? 1 : 0;
}

our $AUTOLOAD;
sub AUTOLOAD
{
    my $class = $_[0];
    my $attr = $AUTOLOAD;

    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;

    if (!$_[0]->_validate_attribute($attr))
    {
        die "invalid attribute $attr for class ".$class->CLASS_NAME;
    }

    no strict 'refs';
    *$AUTOLOAD = sub
    {
        my $self = shift;
        return $self->{$attr} if defined $self->{$attr};

        if ($attr =~ /^(.*)_obj$/s)
        {
            return $self->get_object($1);
        }

        my $field = Bugzilla->get_class_field($attr, $self->CLASS_ID);
        if ($field)
        {
            if ($field->type == FIELD_TYPE_MULTI)
            {
                return $self->{$attr} if $self->{$attr};
                my $t = $field->value_type;
                my $order = $t->LIST_ORDER;
                $order =~ s/((?:^|,\s*)\S)/o.$1/;
                $self->{$attr} = Bugzilla->dbh->selectcol_arrayref(
                    "SELECT o.".$t->ID_FIELD." FROM ".$field->rel_table." r, ".$t->DB_TABLE.
                    " o WHERE r.".$field->rel_value_id."=o.".$t->ID_FIELD." AND r.".$field->rel_object_id."=? ORDER BY $order",
                    undef, $self->id
                );
                return $self->{$attr};
            }
            elsif ($field->type == FIELD_TYPE_REVERSE)
            {
                return $self->{$attr} if $self->{$attr};
                my $vf = $field->value_field;
                my $t = $vf->value_type;
                my $order = $t->LIST_ORDER;
                $order =~ s/((?:^|,\s*)\S)/o.$1/;
                if ($vf->type == FIELD_TYPE_SINGLE || $vf->type == FIELD_TYPE_BUG_ID)
                {
                    $self->{$attr} = Bugzilla->dbh->selectcol_arrayref(
                        "SELECT o.".$t->ID_FIELD." FROM ".$t->DB_TABLE." o WHERE ".$vf->db_column." = ?",
                        undef, $self->id
                    );
                }
                elsif ($vf->type == FIELD_TYPE_MULTI)
                {
                    $self->{$attr} = Bugzilla->dbh->selectcol_arrayref(
                        "SELECT o.".$t->ID_FIELD." FROM ".$vf->rel_table." r, ".$t->DB_TABLE.
                        " o WHERE r.".$vf->rel_object_id."=o.".$t->ID_FIELD." AND r.".$vf->rel_value_id." = ? ORDER BY $order",
                        undef, $self->id
                    );
                }
                return $self->{$attr};
            }
        }

        return '';
    };

    goto &$AUTOLOAD;
}

1;
__END__
