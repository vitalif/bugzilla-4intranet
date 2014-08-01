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
# Contributor(s): Dan Mosedale <dmose@mozilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Myk Melez <myk@mozilla.org>
#                 Greg Hendricks <ghendricks@novell.com>
#
# Deep refactoring by Vitaliy Filippov <vitalif@mail.ru>
# http://wiki.4intra.net/Bugzilla4Intranet

=head1 NAME

Bugzilla::Field - a particular piece of information about bugs
                  and useful routines for form field manipulation

=head1 SYNOPSIS

  use Bugzilla;
  use Data::Dumper;

  # Display information about all fields.
  print Dumper(Bugzilla->get_fields());

  # Display information about non-obsolete custom fields.
  print Dumper(Bugzilla->active_custom_fields);

  use Bugzilla::Field;

  # Display information about non-obsolete custom fields.
  # Bugzilla->get_fields() is a wrapper around Bugzilla::Field->match(),
  # so both methods take the same arguments.
  print Dumper(Bugzilla::Field->match({ obsolete => 0, custom => 1 }));

  # Create or update a custom field or field definition.
  my $field = Bugzilla::Field->create(
    {name => 'cf_silly', description => 'Silly', custom => 1});

  # Instantiate a Field object for an existing field.
  my $field = new Bugzilla::Field({name => 'target_milestone'});
  if ($field->obsolete) {
      print $field->description . " is obsolete\n";
  }

=head1 DESCRIPTION

Field.pm defines field objects, which represent the particular pieces
of information that Bugzilla stores about bugs.

This package also provides functions for dealing with CGI form fields.

C<Bugzilla::Field> is an implementation of L<Bugzilla::Object>, and
so provides all of the methods available in L<Bugzilla::Object>,
in addition to what is documented here.

=cut

package Bugzilla::Field;

use strict;

use base qw(Exporter Bugzilla::Object);
@Bugzilla::Field::EXPORT = qw(update_visibility_values);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
require 'Bugzilla/Field/Choice.pm';

use Scalar::Util qw(blessed);
use Encode;
use JSON;
use POSIX;

###############################
####    Initialization     ####
###############################

use constant DB_TABLE   => 'fielddefs';
use constant LIST_ORDER => 'sortkey, name';

use constant DB_COLUMNS => qw(
    id
    name
    description
    type
    custom
    mailhead
    sortkey
    obsolete
    is_mandatory
    clone_bug
    delta_ts
    has_activity
    add_to_deps
    url
    default_value
    visibility_field_id
    value_field_id
    null_field_id
    default_field_id
    clone_field_id
);

use constant REQUIRED_CREATE_FIELDS => qw(name description);

use constant VALIDATORS => {
    custom              => \&Bugzilla::Object::check_boolean,
    description         => \&_check_description,
    clone_bug           => \&Bugzilla::Object::check_boolean,
    mailhead            => \&Bugzilla::Object::check_boolean,
    obsolete            => \&Bugzilla::Object::check_boolean,
    is_mandatory        => \&Bugzilla::Object::check_boolean,
    sortkey             => \&_check_sortkey,
    type                => \&_check_type,
    visibility_field_id => \&_check_visibility_field_id,
    add_to_deps         => \&_check_add_to_deps,
    null_field_id       => \&_check_visibility_field_id,
    default_field_id    => \&_check_visibility_field_id,
    clone_field_id      => \&_check_visibility_field_id,
};

use constant UPDATE_VALIDATORS => {
    value_field_id      => \&_check_value_field_id,
    default_value       => \&_check_default_value,
};

use constant UPDATE_COLUMNS => grep { $_ ne 'id' } DB_COLUMNS();

# How various field types translate into SQL data definitions.
use constant SQL_DEFINITIONS => {
    # Using commas because these are constants and they shouldn't
    # be auto-quoted by the "=>" operator.
    FIELD_TYPE_FREETEXT,      { TYPE => 'varchar(255)' },
    FIELD_TYPE_EXTURL,        { TYPE => 'varchar(255)' },
    FIELD_TYPE_SINGLE_SELECT, { TYPE => 'INT4'       },
    FIELD_TYPE_TEXTAREA,      { TYPE => 'MEDIUMTEXT' },
    FIELD_TYPE_DATETIME,      { TYPE => 'DATETIME'   },
    FIELD_TYPE_BUG_ID,        { TYPE => 'INT4'       },
    FIELD_TYPE_NUMERIC,       { TYPE => 'NUMERIC', NOTNULL => 1, DEFAULT => '0' },
};

# Field definitions for the fields that ship with Bugzilla.
# These are used by populate_field_definitions to populate
# the fielddefs table.
use constant DEFAULT_FIELD_COLUMNS => [ qw(name description is_mandatory mailhead clone_bug type value_field null_field default_field) ];
use constant DEFAULT_FIELDS => (map { my $i = 0; $_ = { (map { (DEFAULT_FIELD_COLUMNS->[$i++] => $_) } @$_) } } (
    [ 'bug_id',            'Bug ID',            1, 1, 0 ],
    [ 'short_desc',        'Summary',           1, 1, 1, FIELD_TYPE_FREETEXT ],
    [ 'classification',    'Classification',    1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'product',           'Product',           1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'version',           'Version',           0, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product', 'product', 'component' ],
    [ 'rep_platform',      'Platform',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'bug_file_loc',      'URL',               0, 1, 1 ],
    [ 'op_sys',            'OS/Version',        0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'bug_status',        'Status',            1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'status_whiteboard', 'Status Whiteboard', 0, 1, 1, 1, FIELD_TYPE_FREETEXT ],
    [ 'keywords',          'Keywords',          0, 1, 1, FIELD_TYPE_MULTI_SELECT ],
    [ 'resolution',        'Resolution',        0, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'bug_severity',      'Severity',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'priority',          'Priority',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'component',         'Component',         1, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product' ],
    [ 'assigned_to',       'Assignee',          1, 1, 0 ],
    [ 'reporter',          'Reporter',          1, 1, 0 ],
    [ 'votes',             'Votes',             0, 1, 0 ],
    [ 'qa_contact',        'QA Contact',        0, 1, 0 ],
    [ 'cc',                'CC',                0, 1, 1 ], # Also reporter/assigned_to/qa are added to cloned bug...
    [ 'dependson',         'Depends on',        0, 1, 0 ],
    [ 'blocked',           'Blocks',            0, 1, 0 ],
    [ 'dup_id',            'Duplicate of',      0, 1, 0, FIELD_TYPE_BUG_ID ],

    [ 'attachments.description', 'Attachment description', 0, 0, 0 ],
    [ 'attachments.filename',    'Attachment filename',    0, 0, 0 ],
    [ 'attachments.mimetype',    'Attachment mime type',   0, 0, 0 ],
    [ 'attachments.ispatch',     'Attachment is patch',    0, 0, 0 ],
    [ 'attachments.isobsolete',  'Attachment is obsolete', 0, 0, 0 ],
    [ 'attachments.isprivate',   'Attachment is private',  0, 0, 0 ],

    [ 'target_milestone',      'Target Milestone',      0, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product', 'product', 'product' ],
    [ 'creation_ts',           'Creation time',         1, 0, 0, FIELD_TYPE_DATETIME ],
    [ 'delta_ts',              'Last changed time',     1, 0, 0, FIELD_TYPE_DATETIME ],
    [ 'longdesc',              'Comment',               0, 0, 0 ],
    [ 'alias',                 'Alias',                 0, 1, 0, FIELD_TYPE_FREETEXT ],
    [ 'everconfirmed',         'Ever Confirmed',        0, 0, 0 ],
    [ 'reporter_accessible',   'Reporter Accessible',   0, 1, 0 ],
    [ 'cclist_accessible',     'CC Accessible',         0, 1, 0 ],
    [ 'bug_group',             'Group',                 0, 0, 0 ], # FIXME maybe clone_bug=1?
    [ 'estimated_time',        'Estimated Hours',       0, 1, 0, FIELD_TYPE_NUMERIC ],
    [ 'remaining_time',        'Remaining Hours',       0, 0, 0, FIELD_TYPE_NUMERIC ],
    [ 'deadline',              'Deadline',              0, 1, 1, FIELD_TYPE_DATETIME ],
    [ 'flagtypes.name',        'Flags and Requests',    0, 0, 0 ],
    [ 'work_time',             'Hours Worked',          0, 0, 0 ],
    [ 'percentage_complete',   'Percentage Complete',   0, 0, 0 ],
    [ 'content',               'Content',               0, 0, 0 ],
    [ 'see_also',              'See Also',              0, 1, 0, FIELD_TYPE_BUG_URLS ],
));

################
# Constructors #
################

# Override match to add is_select.
sub match
{
    my $self = shift;
    my ($params) = @_;
    if (delete $params->{is_select})
    {
        $params->{type} = [ FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT ];
    }
    return $self->SUPER::match(@_);
}

##############
# Validators #
##############

sub _check_description
{
    my ($invocant, $desc) = @_;
    $desc = clean_text($desc);
    $desc || ThrowUserError('field_missing_description');
    return $desc;
}

sub _check_name
{
    my ($invocant, $name, $is_custom) = @_;
    $name = lc(clean_text($name));
    $name || ThrowUserError('field_missing_name');

    # Don't want to allow a name that might mess up SQL.
    my $name_regex = qr/^[\w\.]+$/;
    # Custom fields have more restrictive name requirements than
    # standard fields.
    $name_regex = qr/^[a-zA-Z0-9_]+$/ if $is_custom;
    # Custom fields can't be named just "cf_", and there is no normal
    # field named just "cf_".
    if ($name !~ $name_regex || $name eq "cf_")
    {
        ThrowUserError('field_invalid_name', { name => $name });
    }

    # If it's custom, prepend cf_ to the custom field name to distinguish
    # it from standard fields.
    if ($name !~ /^cf_/ && $is_custom)
    {
        $name = 'cf_' . $name;
    }

    # Assure the name is unique. Names can't be changed, so we don't have
    # to worry about what to do on updates.
    my $field = Bugzilla->get_field($name);
    ThrowUserError('field_already_exists', {'field' => $field }) if $field;

    return $name;
}

sub _check_sortkey
{
    my ($invocant, $sortkey) = @_;
    my $skey = $sortkey;
    if (!defined $skey || $skey eq '')
    {
        ($sortkey) = Bugzilla->dbh->selectrow_array('SELECT MAX(sortkey) + 100 FROM fielddefs') || 100;
    }
    detaint_natural($sortkey) || ThrowUserError('field_invalid_sortkey', { sortkey => $skey });
    return $sortkey;
}

sub _check_type
{
    my ($invocant, $type) = @_;
    if (ref $invocant)
    {
        # Do not allow to change type of an existing custom field
        return $invocant->type;
    }
    my $saved_type = $type;
    # The constant here should be updated every time a new,
    # higher field type is added.
    if (!detaint_natural($type) || $type <= FIELD_TYPE_UNKNOWN ||
        $type > FIELD_TYPE_KEYWORDS && $type < FIELD_TYPE_NUMERIC ||
        $type > FIELD_TYPE_BUG_ID_REV)
    {
        ThrowCodeError('invalid_customfield_type', { type => $saved_type });
    }
    elsif ($type == FIELD_TYPE_BUG_URLS || $type == FIELD_TYPE_KEYWORDS)
    {
        ThrowUserError('useless_customfield_type', { type => $type });
    }
    return $type;
}

sub _check_value_field_id
{
    my ($invocant, $field_id, undef, $type) = @_;
    $type = $invocant->type if !defined $type;
    if ($type == FIELD_TYPE_BUG_ID_REV)
    {
        # For fields of type "reverse relation of BUG_ID field"
        # value_field indicates the needed direct relation
        my $field = Bugzilla->get_field(trim($field_id));
        if (!$field || $field->type != FIELD_TYPE_BUG_ID)
        {
            ThrowUserError('direct_field_needed_for_reverse');
        }
        for (Bugzilla->get_fields({ type => FIELD_TYPE_BUG_ID_REV, value_field_id => $field->id }))
        {
            if (!ref $invocant || $_->id != $invocant->id)
            {
                ThrowUserError('duplicate_reverse_field');
            }
        }
        return $field->id;
    }
    if ($field_id && $type != FIELD_TYPE_SINGLE_SELECT && $type != FIELD_TYPE_MULTI_SELECT)
    {
        ThrowUserError('field_value_control_select_only');
    }
    return $invocant->_check_visibility_field_id($field_id);
}

sub _check_visibility_field_id
{
    my ($invocant, $field_id) = @_;
    $field_id = trim($field_id);
    return undef if !$field_id;
    my $field = Bugzilla->get_field($field_id);
    if (blessed($invocant) && $field->id == $invocant->id)
    {
        ThrowUserError('field_cant_control_self', { field => $field });
    }
    if (!$field->is_select)
    {
        ThrowUserError('field_control_must_be_select', { field => $field });
    }
    return $field->id;
}

# This has effect only for fields of FIELD_TYPE_BUG_ID type
# When 1, add field value (bug id) to list of bugs blocked by current
# When 2, add field value (bug id) to list of bugs depending on current
sub _check_add_to_deps
{
    my ($invocant, $value) = @_;
    my %addto = ('' => 0, 1 => 1, 2 => 2, no => 0, blocked => 1, dependson => 2);
    return $addto{$value || ''};
}

sub _check_default_value
{
    my ($self, $value) = @_;
    if ($self->type == FIELD_TYPE_SINGLE_SELECT)
    {
        # ID
        detaint_natural($value) || undef;
    }
    elsif ($self->type == FIELD_TYPE_MULTI_SELECT)
    {
        # Array of IDs
        $value = [ $value ] if !ref $value;
        detaint_natural($_) for @$value;
        $value = @$value ? join(',', @$value) : undef;
    }
    elsif ($self->type == FIELD_TYPE_BUG_ID_REV)
    {
        return undef;
    }
    return $value;
}

=pod

=head2 Instance Properties

=over

=item C<name>

the name of the field in the database; begins with "cf_" if field
is a custom field, but test the value of the boolean "custom" property
to determine if a given field is a custom field

=item C<description>

a short string describing the field; displayed to Bugzilla users
in several places within Bugzilla's UI, f.e. as the form field label
on the "show bug" page

=back

=cut

sub description { return $_[0]->{description} }

=over

=item C<type>

an integer specifying the kind of field this is; values correspond to
the FIELD_TYPE_* constants in Constants.pm

=back

=cut

sub type { return $_[0]->{type} }

=over

=item C<custom>

a boolean specifying whether or not the field is a custom field;
if true, field name should start "cf_", but use this property to determine
which fields are custom fields

=back

=cut

sub custom { return $_[0]->{custom} }

=over

=item C<in_new_bugmail>

a boolean specifying whether or not the field is displayed in bugmail
for newly-created bugs;

=back

=cut

sub in_new_bugmail { return $_[0]->{mailhead} }

=over

=item C<sortkey>

an integer specifying the sortkey of the field

=back

=cut

sub sortkey { return $_[0]->{sortkey} }

=over

=item C<obsolete>

a boolean specifying whether or not the field is obsolete

=back

=cut

sub obsolete { return $_[0]->{obsolete} }

=over

=item C<nullable>

a boolean specifying whether empty value is allowed for this field

=back

=item C<is_mandatory>

the reverse of nullable

=back

=cut

sub nullable { return !$_[0]->type || $_[0]->type == FIELD_TYPE_BUG_ID_REV || !$_[0]->{is_mandatory} }

sub is_mandatory { return !$_[0]->nullable }

=over

=item C<clone_bug>

A boolean specifying whether or not this field should be copied on bug clone

=back

=cut

sub clone_bug { return $_[0]->{clone_bug} }

=over

=item C<is_select>

True if this is a C<FIELD_TYPE_SINGLE_SELECT> or C<FIELD_TYPE_MULTI_SELECT>
field. It is only safe to call L</legal_values> if this is true.

=item C<legal_values>

Valid values for this field, as an array of L<Bugzilla::Field::Choice>
objects.

=back

=cut

sub is_select
{
    return ($_[0]->type == FIELD_TYPE_SINGLE_SELECT
        || $_[0]->type == FIELD_TYPE_MULTI_SELECT) ? 1 : 0;
}

sub has_activity { $_[0]->{has_activity} }

sub add_to_deps { $_[0]->type == FIELD_TYPE_BUG_ID && $_[0]->{add_to_deps} }

sub url { $_[0]->{url} }

sub default_value { $_[0]->{default_value} }

sub value_type
{
    my $self = shift;
    return Bugzilla::Field::Choice->type($self);
}

# Includes disabled values is $include_disabled = true
sub legal_values
{
    my $self = shift;
    my ($include_disabled) = @_;
    return [] unless $self->is_select;
    return [ Bugzilla::Field::Choice->type($self)->get_all($include_disabled) ];
}

# Always excludes disabled values
sub legal_value_names
{
    my $self = shift;
    return [] unless $self->is_select;
    return [ map { $_->{name} } @{ Bugzilla::Field::Choice->type($self)->get_all_names } ];
}

sub legal_value_names_with_ids
{
    my $self = shift;
    return [] unless $self->is_select;
    return Bugzilla::Field::Choice->type($self)->get_all_names;
}

# Return the set of possible values for selected $controller_value of controlling field
# Always excludes disabled values
sub restricted_legal_values
{
    my $self = shift;
    my ($controller_value) = @_;
    $controller_value = $controller_value->id if ref $controller_value;
    $controller_value ||= 0;
    my $rc_cache = Bugzilla->rc_cache_fields;
    if (!$rc_cache->{$self}->{restricted_legal_values}->{$controller_value})
    {
        my $hash = Bugzilla->fieldvaluecontrol->{$self->value_field_id}->{values}->{$self->id};
        $rc_cache->{$self}->{restricted_legal_values}->{$controller_value} = [
            grep { $hash->{$_->id} && $hash->{$_->id}->{$controller_value} }
            @{$self->legal_values}
        ];
    }
    return $rc_cache->{$self}->{restricted_legal_values}->{$controller_value};
}

sub visibility_values
{
    my $self = shift;
    return undef if !$self->visibility_field_id;
    my $h = Bugzilla->fieldvaluecontrol
        ->{$self->visibility_field_id}->{fields}->{$self->id};
    return $h && %$h ? $h : undef;
}

sub has_visibility_value
{
    my $self = shift;
    return 1 if !$self->visibility_field_id;
    my ($value) = @_;
    $value = $value->id if ref $value;
    my $hash = Bugzilla->fieldvaluecontrol
        ->{$self->visibility_field_id}->{fields}->{$self->id};
    return $hash && $hash->{$value};
}

sub null_visibility_values
{
    my $self = shift;
    return undef if !$self->null_field_id;
    my $h = Bugzilla->fieldvaluecontrol
        ->{$self->null_field_id}->{null}->{$self->id};
    return $h && %$h ? $h : undef;
}

sub clone_visibility_values
{
    my $self = shift;
    return undef if !$self->clone_field_id;
    my $h = Bugzilla->fieldvaluecontrol
        ->{$self->clone_field_id}->{clone}->{$self->id};
    return $h && %$h ? $h : undef;
}

# Check visibility of field for a bug or for a hashref with default value names
sub check_visibility
{
    my $self = shift;
    my $bug = shift || return 1;
    my $vf = $self->visibility_field || return 1;
    my $value = bug_or_hash_value($bug, $vf);
    return $value ? $self->has_visibility_value($value) : 1;
}

# Check if a field is nullable for a bug or for a hashref with default value names
sub check_is_nullable
{
    my $self = shift;
    $self->nullable || return 0;
    my $vf = $self->null_field || return 1;
    $self->null_visibility_values || return 0;
    my $bug = shift || return 1;
    my $value = bug_or_hash_value($bug, $vf);
    return $value ? $self->null_visibility_values->{$value} : 1;
}

# Check if a field should be copied when cloning $bug
sub check_clone
{
    my $self = shift;
    $self->clone_bug || return 0;
    my $vf = $self->clone_field || return 1;
    $self->clone_visibility_values || return 0;
    my $bug = shift || return 1;
    my $value = bug_or_hash_value($bug, $vf);
    return $value ? $self->clone_visibility_values->{$value} : 1;
}

# Get default value for this field in bug $bug
sub get_default_value
{
    my $self = shift;
    my ($bug, $useGlobal) = @_;
    my $default = $useGlobal ? $self->default_value : undef;
    if ($self->default_field_id)
    {
        my $value = bug_or_hash_value($bug, $self->default_field);
        my $d = Bugzilla->fieldvaluecontrol->{$self->default_field_id}
            ->{defaults}->{$self->id};
        for (ref $value ? @$value : $value)
        {
            $default = $d->{$_} if $d->{$_};
        }
    }
    if ($default && $self->is_select)
    {
        $default = $self->value_type->new_from_list([ split /,/, $default ]);
        $default = $default->[0] if $self->type == FIELD_TYPE_SINGLE_SELECT;
    }
    return $default;
}

sub default_value_hash { $_[0]->is_select ? { map { $_ => 1 } split /,/, $_[0]->{default_value} } : undef }

sub default_value_hash_for
{
    my ($self, $visibility_value_id) = @_;
    return undef if !$self->is_select;
    return { map { $_ => 1 } split /,/, Bugzilla->fieldvaluecontrol
        ->{$self->default_field_id}->{defaults}
        ->{$self->id}->{$visibility_value_id} };
}

=pod

=over

=item C<controls_visibility_of>

An arrayref of C<Bugzilla::Field> objects, representing fields that this
field controls the visibility of.

=back

=cut

sub controls_visibility_of
{
    my $self = shift;
    $self->{controls_visibility_of} ||= [ Bugzilla->get_fields({ visibility_field_id => $self->id, obsolete => 0 }) ];
    return $self->{controls_visibility_of};
}

sub visibility_field_id { $_[0]->{visibility_field_id} }
sub null_field_id { $_[0]->{null_field_id} }
sub default_field_id { $_[0]->{default_field_id} }
sub clone_field_id { $_[0]->{clone_field_id} }

sub value_field_id
{
    my $self = shift;
    return undef if !$self->is_select && $self->type != FIELD_TYPE_BUG_ID_REV;
    return $self->{value_field_id};
}

# Field that controls visibility of this one
sub visibility_field
{
    my $self = shift;
    if ($self->{visibility_field_id})
    {
        return Bugzilla->get_field($self->{visibility_field_id});
    }
    return undef;
}

# Field that controls values of this one, if this one is a select,
# and related direct BUG_ID field, if this one is BUG_ID_REV
sub value_field
{
    my $self = shift;
    if (my $id = $self->value_field_id)
    {
        return Bugzilla->get_field($id);
    }
    return undef;
}

# Field that allows/forbids empty value for this one
sub null_field
{
    my $self = shift;
    if ($self->{null_field_id})
    {
        return Bugzilla->get_field($self->{null_field_id});
    }
    return undef;
}

# Field that controls default values for this one
sub default_field
{
    my $self = shift;
    if ($self->{default_field_id})
    {
        return Bugzilla->get_field($self->{default_field_id});
    }
    return undef;
}

# Field that controls copying the value of this field when cloning
sub clone_field
{
    my $self = shift;
    if ($self->{clone_field_id})
    {
        return Bugzilla->get_field($self->{clone_field_id});
    }
    return undef;
}

=pod

=over

=item C<controls_values_of>

An arrayref of C<Bugzilla::Field> objects, representing fields that this
field controls the values of.

=back

=cut

sub controls_values_of
{
    my $self = shift;
    $self->{controls_values_of} ||= [ Bugzilla->get_fields({ value_field_id => $self->id }) ];
    return $self->{controls_values_of};
}

=pod

=head2 Instance Mutators

These set the particular field that they are named after.

They take a single value--the new value for that field.

They will throw an error if you try to set the values to something invalid.

=over

=item C<set_description>

=item C<set_clone_bug>

=item C<set_obsolete>

=item C<set_nullable>

=item C<set_sortkey>

=item C<set_in_new_bugmail>

=item C<set_visibility_field>

=item C<set_value_field>

=back

=cut

sub set_description    { $_[0]->set('description',   $_[1]); }
sub set_clone_bug      { $_[0]->set('clone_bug',     $_[1]); }
sub set_obsolete       { $_[0]->set('obsolete',      $_[1]); }
sub set_is_mandatory   { $_[0]->set('is_mandatory',  $_[1]); }
sub set_sortkey        { $_[0]->set('sortkey',       $_[1]); }
sub set_in_new_bugmail { $_[0]->set('mailhead',      $_[1]); }
sub set_add_to_deps    { $_[0]->set('add_to_deps',   $_[1]); }
sub set_url            { $_[0]->set('url',           $_[1]); }
sub set_default_value  { $_[0]->set('default_value', $_[1]); }

sub set_visibility_field
{
    my ($self, $value) = @_;
    $self->set('visibility_field_id', $value);
}

sub set_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    update_visibility_values($self, FLAG_VISIBLE, $value_ids);
    return $value_ids && @$value_ids;
}

sub set_null_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    update_visibility_values($self, FLAG_NULLABLE, $value_ids);
    return $value_ids && @$value_ids;
}

sub set_clone_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    update_visibility_values($self, FLAG_CLONED, $value_ids);
    return $value_ids && @$value_ids;
}

sub set_value_field
{
    my ($self, $value) = @_;
    $self->set('value_field_id', $value);
}

sub set_null_field
{
    my ($self, $value) = @_;
    $self->set('null_field_id', $value);
}

sub set_clone_field
{
    my ($self, $value) = @_;
    $self->set('clone_field_id', $value);
}

sub set_default_field
{
    my ($self, $value) = @_;
    $self->set('default_field_id', $value);
}

# This is only used internally by upgrade code in Bugzilla::Field.
sub _set_type
{
    trick_taint($_[1]);
    $_[0]->{type} = int($_[1]);
}

=pod

=head2 Instance Method

=over

=item C<remove_from_db>

Attempts to remove the passed in field from the database.
Deleting a field is only successful if the field is obsolete and
there are no values specified (or EVER specified) for the field.

=back

=cut

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $name = $self->name;

    if (!$self->custom)
    {
        ThrowCodeError('field_not_custom', { name => $name });
    }

    if (!$self->obsolete)
    {
        ThrowUserError('customfield_not_obsolete', { name => $self->name });
    }

    $dbh->bz_start_transaction();

    # Check to see if bugs table has records (slow)
    my $bugs_query = "";

    if ($self->type == FIELD_TYPE_MULTI_SELECT)
    {
        $bugs_query = "SELECT COUNT(*) FROM bug_$name";
    }
    else
    {
        $bugs_query = "SELECT COUNT(*) FROM bugs WHERE $name IS NOT NULL";
        if ($self->type != FIELD_TYPE_BUG_ID && $self->type != FIELD_TYPE_DATETIME)
        {
            $bugs_query .= " AND $name != ''";
        }
    }

    my $has_bugs = $dbh->selectrow_array($bugs_query);
    if ($has_bugs)
    {
        ThrowUserError('customfield_has_contents', { name => $name });
    }

    # Once we reach here, we should be OK to delete.
    $dbh->do('DELETE FROM fielddefs WHERE id = ?', undef, $self->id);

    my $type = $self->type;

    # the values for multi-select are stored in a seperate table
    if ($type != FIELD_TYPE_MULTI_SELECT)
    {
        $dbh->bz_drop_column('bugs', $name);
    }

    if ($self->is_select)
    {
        # Delete the table that holds the legal values for this field.
        $dbh->bz_drop_field_tables($self);
    }

    $self->set_visibility_values(undef);
    $self->set_null_visibility_values(undef);
    $self->set_clone_visibility_values(undef);

    # Update some other field (refresh the cache)
    Bugzilla->get_field('delta_ts')->touch;
    Bugzilla->refresh_cache_fields;

    $dbh->bz_commit_transaction();
}

# Overridden update() method - flushes field cache
sub update
{
    my $self = shift;
    $self->{delta_ts} = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime);
    # FIXME Merge something like VALIDATOR_DEPENDENCIES from 4.4
    if ($self->{type} != FIELD_TYPE_BUG_ID)
    {
        $self->{add_to_deps} = 0;
    }
    if ($self->{type} != FIELD_TYPE_EXTURL)
    {
        $self->{url} = undef;
    }
    my ($changes, $old_self) = $self->SUPER::update(@_);
    Bugzilla->refresh_cache_fields;
    return wantarray ? ($changes, $old_self) : $changes;
}

# Update field change timestamp (needed for cache flushing)
sub touch
{
    my $self = shift;
    $self->update;
}

=pod

=head2 Class Methods

=over

=item C<create>

Just like L<Bugzilla::Object/create>. Takes the following parameters:

=over

=item C<name> B<Required> - The name of the field.

=item C<description> B<Required> - The field label to display in the UI.

=item C<mailhead> - boolean - Whether this field appears at the
top of the bugmail for a newly-filed bug. Defaults to 0.

=item C<custom> - boolean - True if this is a Custom Field. The field
will be added to the C<bugs> table if it does not exist. Defaults to 0.

=item C<sortkey> - integer - The sortkey of the field. Defaults to 0.

C<obsolete> - boolean - Whether this field is obsolete. Defaults to 0.

=back

=back

=cut

sub create
{
    my $class = shift;
    my ($params) = @_;

    # We must set up database schema BEFORE inserting a row into fielddefs!
    $params->{delta_ts} = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime);
    $class->check_required_create_fields($params);
    my $field_values = $class->run_create_validators($params);
    my $obj = bless $field_values, ref($class)||$class;

    my $dbh = Bugzilla->dbh;
    if ($obj->custom)
    {
        my $name = $obj->name;
        my $type = $obj->type;
        if (SQL_DEFINITIONS->{$type})
        {
            # Create the database column that stores the data for this field.
            $dbh->bz_add_column('bugs', $name, SQL_DEFINITIONS->{$type});
        }

        if ($obj->is_select)
        {
            # Create the table that holds the legal values for this field.
            $dbh->bz_add_field_tables($obj);
        }

        # Add foreign keys
        if ($type == FIELD_TYPE_SINGLE_SELECT)
        {
            $dbh->bz_add_fk('bugs', $name, { TABLE => $obj->name, COLUMN => 'id' });
        }
        elsif ($type == FIELD_TYPE_BUG_ID)
        {
            $dbh->bz_add_fk('bugs', $name, { TABLE => 'bugs', COLUMN => 'bug_id' });
        }
    }

    # Call real constructor
    my $self = $class->SUPER::create($params);

    # Refresh fields inside single request
    Bugzilla->refresh_cache_fields;

    return $self;
}

sub run_create_validators
{
    my $class = shift;
    my $dbh = Bugzilla->dbh;
    my $params = $class->SUPER::run_create_validators(@_);

    $params->{name} = $class->_check_name($params->{name}, $params->{custom});
    if (!exists $params->{sortkey})
    {
        $params->{sortkey} = $dbh->selectrow_array("SELECT MAX(sortkey) + 100 FROM fielddefs") || 100;
    }

    my $type = $params->{type} || 0;

    if ($params->{custom} && !$type)
    {
        ThrowCodeError('field_type_not_specified');
    }

    $params->{value_field_id} = $class->_check_value_field_id($params->{value_field_id}, undef, $type);

    # FIXME Merge something like VALIDATOR_DEPENDENCIES from 4.4
    if ($type != FIELD_TYPE_BUG_ID)
    {
        $params->{add_to_deps} = 0;
    }
    if ($type != FIELD_TYPE_EXTURL)
    {
        $params->{url} = undef;
    }

    # Check default value
    if ($type == FIELD_TYPE_SINGLE_SELECT || $type == FIELD_TYPE_MULTI_SELECT ||
        $type == FIELD_TYPE_BUG_ID || $type == FIELD_TYPE_BUG_ID_REV)
    {
        $params->{default_value} = undef;
    }

    return $params;
}

=over

=item C<populate_field_definitions()>

Description: Populates the fielddefs table during an installation
             or upgrade.

Params:      none

Returns:     nothing

=back

=cut

sub populate_field_definitions
{
    my $dbh = Bugzilla->dbh;

    my ($has_clone_bug) = $dbh->selectrow_array('SELECT 1 FROM fielddefs WHERE clone_bug AND NOT custom');

    # Add/update field definitions
    foreach my $def (DEFAULT_FIELDS())
    {
        my $field = new Bugzilla::Field({ name => $def->{name} });
        if ($field)
        {
            $field->set_description($def->{description});
            $field->set_in_new_bugmail($def->{mailhead});
            $field->set_clone_bug($def->{clone_bug}) if !$has_clone_bug;
            $field->set_is_mandatory($def->{is_mandatory}) if $def->{is_mandatory} || $def->{name} eq 'keywords' && $def->{type} ne $field->type;
            $field->set_value_field($dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $def->{value_field})) if $def->{value_field};
            $field->set_null_field($dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $def->{null_field})) if $def->{null_field};
            $field->set_default_field($dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $def->{default_field})) if $def->{default_field};
            $field->_set_type($def->{type}) if $def->{type};
            $field->update();
        }
        else
        {
            Bugzilla::Field->create($def);
        }
    }

    # DELETE fields which were added only accidentally, or which
    # were never tracked in bugs_activity. Note that you should not
    # delete fields which are used by bugs_activity.

    $dbh->do(
        "DELETE FROM fielddefs WHERE name IN ('cc_accessible', 'requesters.login_name',
        'attachments.thedata', 'attach_data.thedata', 'content', 'requestees.login_name',
        'setters.login_name', 'longdescs.isprivate', 'assignee_accessible', 'qacontact_accessible',
        'commenter', 'owner_idle_time', 'attachments.submitter')"
    );

    # MODIFY old field definitions

    # 2005-11-13 LpSolit@gmail.com - Bug 302599
    # One of the field names was a fragment of SQL code, which is DB dependent.
    # We have to rename it to a real name, which is DB independent.
    my $new_field_name = 'days_elapsed';
    my $field_description = 'Days since bug changed';

    my ($old_field_id, $old_field_name) = $dbh->selectrow_array(
        'SELECT id, name FROM fielddefs WHERE description = ?',
        undef, $field_description
    );

    if ($old_field_id && ($old_field_name ne $new_field_name))
    {
        print "SQL fragment found in the 'fielddefs' table...\n";
        print "Old field name: " . $old_field_name . "\n";
        # We have to fix saved searches first. Queries have been escaped
        # before being saved. We have to do the same here to find them.
        $old_field_name = url_quote($old_field_name);
        my $broken_named_queries = $dbh->selectall_arrayref(
            'SELECT userid, name, query FROM namedqueries WHERE ' .
            $dbh->sql_istrcmp('query', '?', 'LIKE'),
            undef, "%=$old_field_name%"
        );

        my $sth_UpdateQueries = $dbh->prepare(
            'UPDATE namedqueries SET query = ? WHERE userid = ? AND name = ?'
        );

        print "Fixing saved searches...\n" if scalar @$broken_named_queries;
        foreach my $named_query (@$broken_named_queries)
        {
            my ($userid, $name, $query) = @$named_query;
            $query =~ s/=\Q$old_field_name\E(&|$)/=$new_field_name$1/gi;
            $sth_UpdateQueries->execute($query, $userid, $name);
        }

        # We now do the same with saved chart series.
        my $broken_series = $dbh->selectall_arrayref(
            'SELECT series_id, query FROM series WHERE ' .
            $dbh->sql_istrcmp('query', '?', 'LIKE'),
            undef, "%=$old_field_name%"
        );

        my $sth_UpdateSeries = $dbh->prepare('UPDATE series SET query = ? WHERE series_id = ?');

        print "Fixing saved chart series...\n" if scalar @$broken_series;
        foreach my $series (@$broken_series)
        {
            my ($series_id, $query) = @$series;
            $query =~ s/=\Q$old_field_name\E(&|$)/=$new_field_name$1/gi;
            $sth_UpdateSeries->execute($query, $series_id);
        }

        # Now that saved searches have been fixed, we can fix the field name.
        print "Fixing the 'fielddefs' table...\n";
        print "New field name: " . $new_field_name . "\n";
        $dbh->do('UPDATE fielddefs SET name = ? WHERE id = ?', undef, $new_field_name, $old_field_id);
    }

    # This field has to be created separately, or the above upgrade code
    # might not run properly.
    unless (new Bugzilla::Field({ name => $new_field_name }))
    {
        Bugzilla::Field->create({
            name => $new_field_name,
            description => $field_description
        });
    }
}

# Get choice value object for a bug or for a hashref with default value names
sub bug_or_hash_value
{
    my ($bug, $vf) = @_;
    my $value;
    if (blessed $bug)
    {
        # Bug object
        $value = $bug->get_ids($vf->name);
    }
    elsif (ref $bug)
    {
        # Hashref with value names
        $value = $bug->{$vf->name};
        if (!ref $value && defined $value)
        {
            # FIXME: This does not allow selecting of fields
            # non-uniquely identified by name, as a visibility
            # controller field (for example, "component")
            $value = Bugzilla::Field::Choice->type($vf)->new({ name => $value });
            $value = $value->id if $value;
        }
    }
    else
    {
        # Just value ID
        $value = $bug;
    }
    return $value;
}

sub flag_field
{
    my ($self, $flag) = @_;
    return $self->value_field if $flag > 0;
    return $self->visibility_field if $flag == FLAG_VISIBLE;
    return $self->null_field if $flag == FLAG_NULLABLE;
    return $self->clone_field if $flag == FLAG_CLONED;
}

# Shared between Bugzilla::Field and Bugzilla::Field::Choice
sub update_visibility_values
{
    my ($controlled_field, $controlled_value_id, $visibility_value_ids) = @_;
    $visibility_value_ids ||= [];
    my $vis_field = $controlled_field->flag_field($controlled_value_id);
    if (!$vis_field)
    {
        return undef;
    }
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $controlled_value_id = int($controlled_value_id);
    if (@$visibility_value_ids)
    {
        my $type = Bugzilla::Field::Choice->type($vis_field);
        $visibility_value_ids = [
            (grep { $_ == 0 } @$visibility_value_ids ? (0) : ()),
            map { $_->id } @{ $type->new_from_list($visibility_value_ids) }
        ];
    }
    Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id=?",
        undef, $controlled_field->id, $controlled_value_id);
    if (@$visibility_value_ids)
    {
        my $f = $controlled_field->id;
        Bugzilla->dbh->do(
            "INSERT INTO fieldvaluecontrol (field_id, value_id, visibility_value_id) VALUES ".
            join(",", map { "($f, $controlled_value_id, $_)" } @$visibility_value_ids)
        );
    }
    # Touch the field
    $controlled_field->touch;
    return 1;
}

sub update_control_lists
{
    my ($controlling_field_id, $controlling_value_id, $params) = @_;
    $controlling_field_id = $controlling_field_id->id if ref $controlling_field_id;
    $controlling_value_id = Bugzilla->get_field($controlling_field_id)->value_type->new($controlling_value_id);
    $controlling_value_id = $controlling_value_id ? $controlling_value_id->id : return undef;
    # Save all visible, nullable and clone flags at once
    my $mod = {};
    for my $f (Bugzilla->get_fields({ obsolete => 0, visibility_field_id => $controlling_field_id }))
    {
        push @{$mod->{$params->{'is_visible_'.$f->name} ? 'add' : 'del'}}, [ $f->id, FLAG_VISIBLE ];
    }
    for my $f (Bugzilla->get_fields({ obsolete => 0, null_field_id => $controlling_field_id }))
    {
        push @{$mod->{$params->{'is_nullable_'.$f->name} ? 'add' : 'del'}}, [ $f->id, FLAG_NULLABLE ];
    }
    for my $f (Bugzilla->get_fields({ obsolete => 0, clone_field_id => $controlling_field_id }))
    {
        push @{$mod->{$params->{'is_cloned_'.$f->name} ? 'add' : 'del'}}, [ $f->id, FLAG_CLONED ];
    }
    if (@{$mod->{del}} || @{$mod->{add}})
    {
        Bugzilla->dbh->do(
            'DELETE FROM fieldvaluecontrol WHERE visibility_value_id=? AND (field_id, value_id) IN ('.
            join(',', map { "($_->[0], $_->[1])" } (@{$mod->{add}}, @{$mod->{del}})).')', undef,
            $controlling_value_id
        );
    }
    if (@{$mod->{add}})
    {
        Bugzilla->dbh->do(
            'INSERT INTO fieldvaluecontrol (visibility_value_id, field_id, value_id) VALUES '.
            join(',', map { "($controlling_value_id, $_->[0], $_->[1])" } @{$mod->{add}})
        );
    }
    # Save all dependent defaults at once
    my $touched = { map { $_->[0] => 1 } (@{$mod->{add}}, @{$mod->{del}}) };
    $mod = {};
    for my $f (Bugzilla->get_fields({ obsolete => 0, default_field_id => $controlling_field_id }))
    {
        next if $f eq 'version' || $f eq 'target_milestone'; # FIXME: default version is hardcoded to depend on component, default milestone is hardcoded to depend on product
        my $default = $params->{'default_'.$f->name};
        $default = $f->_check_default_value($default);
        if (!$default)
        {
            push @{$mod->{del}}, [ $f->id ];
        }
        else
        {
            trick_taint($default);
            push @{$mod->{add}}, [ $f->id, $default ];
        }
        $touched->{$f->id} = 1;
    }
    if (@{$mod->{del}} || @{$mod->{add}})
    {
        Bugzilla->dbh->do(
            'DELETE FROM field_defaults WHERE visibility_value_id=? AND field_id IN ('.
            join(',', map { $_->[0] } (@{$mod->{add}}, @{$mod->{del}})).')',
            undef, $controlling_value_id
        );
    }
    if (@{$mod->{add}})
    {
        Bugzilla->dbh->do(
            'INSERT INTO field_defaults (visibility_value_id, field_id, default_value) VALUES '.
            join(',', map { "($controlling_value_id, $_->[0], ?)" } @{$mod->{add}}),
            undef, map { $_->[1] } @{$mod->{add}}
        );
    }
    # Update metadata timestamp for many fields at once
    if (%$touched)
    {
        Bugzilla->dbh->do(
            'UPDATE fielddefs SET delta_ts=? WHERE id IN ('.
            join(',', keys %$touched).')', undef, POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime)
        );
        Bugzilla->refresh_cache_fields;
    }
}

sub update_controlled_values
{
    my ($controlled_field, $controlled_value_ids, $visibility_value_id) = @_;
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $controlled_value_ids ||= [];
    my $vis_field = $controlled_field->value_field;
    if (!$vis_field)
    {
        return undef;
    }
    $visibility_value_id = int($visibility_value_id);
    Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND visibility_value_id=? AND value_id!=0",
        undef, $controlled_field->id, $visibility_value_id);
    if (@$controlled_value_ids)
    {
        my $type = Bugzilla::Field::Choice->type($controlled_field);
        $controlled_value_ids = [ map { $_->id } @{ $type->new_from_list($controlled_value_ids) } ];
        my $f = $controlled_field->id;
        my $sql = "INSERT INTO fieldvaluecontrol (field_id, visibility_value_id, value_id) VALUES ".
            join(",", map { "($f, $visibility_value_id, $_)" } @$controlled_value_ids);
        Bugzilla->dbh->do($sql);
    }
    # Touch the field
    $controlled_field->touch;
    return 1;
}

sub update_default_values
{
    my ($controlled_field, $visibility_value_id, $default_value) = @_;
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $visibility_value_id = int($visibility_value_id);
    $default_value = $controlled_field->_check_default_value($default_value);
    if (!$default_value)
    {
        Bugzilla->dbh->do(
            'DELETE FROM field_defaults WHERE field_id=? AND visibility_value_id=?',
            undef, $controlled_field->id, $visibility_value_id
        );
    }
    else
    {
        trick_taint($default_value);
        Bugzilla->dbh->do(
            'REPLACE INTO field_defaults (field_id, visibility_value_id, default_value) VALUES (?, ?, ?)',
            undef, $controlled_field->id, $visibility_value_id, $default_value
        );
    }
    # Touch the field
    $controlled_field->touch;
    return 1;
}

# Field and value dependency data, intended for use in client JavaScript
sub json_visibility
{
    my $self = shift;
    my $data = {
        legal => [ map { [ $_->id, $_->name ] } @{$self->legal_values} ],
        visibility_field => $self->visibility_field ? $self->visibility_field->name : undef,
        value_field => $self->value_field ? $self->value_field->name : undef,
        null_field => $self->null_field ? $self->null_field->name : undef,
        default_field => $self->default_field ? $self->default_field->name : undef,
        nullable => $self->nullable ? 1 : 0,
        default_value => $self->default_value || undef,
        fields => {},
        values => {},
        defaults => {},
        null => {},
    };
    my $hash = Bugzilla->fieldvaluecontrol->{$self->id};
    for my $key (qw(fields values defaults null))
    {
        $data->{$key} = { map { Bugzilla->get_field($_)->name => $hash->{$key}->{$_} } keys %{$hash->{$key}} };
    }
    return $data;
}

1;
__END__
