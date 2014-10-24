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

Bugzilla::Field - a particular piece of information about bugs.

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
    { name => 'cf_silly', description => 'Silly', custom => 1 });

  # Instantiate a Field object for an existing field.
  my $field = new Bugzilla::Field({ name => 'target_milestone' });
  if ($field->obsolete)
  {
      print $field->description . " is disabled\n";
  }

=head1 DESCRIPTION

Field.pm defines field objects, which represent the particular pieces
of information that Bugzilla stores about bugs.

B<Bugzilla::Field> is an implementation of L<Bugzilla::Object>, and
so provides all of the methods available in L<Bugzilla::Object>,
in addition to what is documented here.

=cut

package Bugzilla::Field;

use strict;

use base qw(Bugzilla::Object);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Field::Choice;

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

use constant UPDATE_COLUMNS => grep { $_ ne 'id' && $_ ne 'custom' } DB_COLUMNS();

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
    [ 'alias',             'Alias',             0, 1, 0, FIELD_TYPE_FREETEXT ],
    [ 'creation_ts',       'Creation time',     1, 0, 0, FIELD_TYPE_DATETIME ],
    [ 'delta_ts',          'Last changed time', 1, 0, 0, FIELD_TYPE_DATETIME ],

    # Initial bug information
    [ 'short_desc',        'Summary',           1, 1, 1, FIELD_TYPE_FREETEXT ],
    [ 'classification',    'Classification',    1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'product',           'Product',           1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'component',         'Component',         1, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product' ],
    [ 'bug_severity',      'Severity',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'priority',          'Priority',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'rep_platform',      'Platform',          0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'op_sys',            'OS',                0, 1, 1, FIELD_TYPE_SINGLE_SELECT ],
    [ 'bug_file_loc',      'URL',               0, 1, 1 ],
    [ 'version',           'Version',           0, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product', 'product', 'component' ],

    # Responsibility information
    [ 'reporter',          'Reporter',          1, 1, 0 ],
    [ 'assigned_to',       'Assignee',          1, 1, 0 ],
    [ 'qa_contact',        'QA Contact',        0, 1, 0 ],
    [ 'cc',                'CC',                0, 1, 1 ], # reporter/assignee/qa are also added to cloned bug CC
    [ 'flagtypes.name',    'Flags and Requests',0, 0, 0 ],

    # Status information
    [ 'keywords',          'Keywords',          0, 1, 1, FIELD_TYPE_MULTI_SELECT ],
    [ 'see_also',          'See Also',          0, 1, 0, FIELD_TYPE_BUG_URLS ],
    [ 'target_milestone',  'Target Milestone',  0, 1, 1, FIELD_TYPE_SINGLE_SELECT, 'product', 'product', 'product' ],
    [ 'status_whiteboard', 'Status Whiteboard', 0, 1, 1, FIELD_TYPE_FREETEXT ],
    [ 'bug_status',        'Status',            1, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'resolution',        'Resolution',        0, 1, 0, FIELD_TYPE_SINGLE_SELECT ],
    [ 'everconfirmed',     'Ever Confirmed',    0, 0, 0 ],
    [ 'dependson',         'Depends on',        0, 1, 0 ],
    [ 'blocked',           'Blocks',            0, 1, 0 ],
    [ 'dup_id',            'Duplicate of',      0, 1, 0, FIELD_TYPE_BUG_ID ],
    [ 'votes',             'Votes',             0, 1, 0 ],

    [ 'estimated_time',    'Estimated Hours',   0, 1, 0, FIELD_TYPE_NUMERIC ],
    [ 'remaining_time',    'Remaining Hours',   0, 0, 0, FIELD_TYPE_NUMERIC ],
    [ 'work_time',         'Hours Worked',      0, 0, 0 ],
    [ 'deadline',          'Deadline',          0, 1, 1, FIELD_TYPE_DATETIME ],
    [ 'bug_group',         'Group',             0, 0, 0 ], # FIXME maybe clone_bug=1?
    [ 'reporter_accessible', 'Reporter Accessible', 0, 1, 0 ],
    [ 'cclist_accessible', 'CC Accessible',     0, 1, 0 ],

    # Comment (never stored in bugs_activity...)
    [ 'longdesc',          'Comment',           0, 0, 0 ],

    # Attachment fields
    [ 'attachments.description', 'Attachment description', 0, 0, 0 ],
    [ 'attachments.filename',    'Attachment filename',    0, 0, 0 ],
    [ 'attachments.mimetype',    'Attachment mime type',   0, 0, 0 ],
    [ 'attachments.ispatch',     'Attachment is patch',    0, 0, 0 ],
    [ 'attachments.isobsolete',  'Attachment is obsolete', 0, 0, 0 ],
    [ 'attachments.isprivate',   'Attachment is private',  0, 0, 0 ],
));

# Tweaks allowed for standard field properties
use constant CAN_TWEAK => {
    obsolete => { map { $_ => 1 } qw(alias classification op_sys qa_contact rep_platform see_also status_whiteboard target_milestone votes) },
    clone_bug => { map { $_ => 1 } qw(short_desc version rep_platform bug_file_loc op_sys status_whiteboard
        keywords bug_severity priority component assigned_to votes qa_contact dependson blocked target_milestone estimated_time remaining_time see_also) },
    default_value => { map { $_ => 1 } qw(bug_severity deadline keywords op_sys priority rep_platform short_desc status_whiteboard target_milestone version) },
    nullable => { map { $_ => 1 } qw(alias bug_severity deadline keywords op_sys priority rep_platform status_whiteboard target_milestone version) },
    visibility_field_id => { map { $_ => 1 } qw(bug_severity op_sys priority rep_platform status_whiteboard target_milestone version keywords) },
    value_field_id => { map { $_ => 1 } qw(bug_severity op_sys priority rep_platform keywords) },
    default_field_id => { map { $_ => 1 } qw(bug_severity keywords op_sys priority component rep_platform status_whiteboard target_milestone version) },
};

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
    elsif ($type == FIELD_TYPE_KEYWORDS ||
        $type == FIELD_TYPE_BUG_URLS && ref $invocant && $invocant->name ne 'see_also')
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
        $value = @$value ? join(',', sort @$value) : undef;
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

=item B<name>

The name of the field in the database; begins with "cf_" if field
is a custom field, but test the value of the boolean "custom" property
to determine if a given field is a custom field

=item B<description>

A short string describing the field; displayed to Bugzilla users
in several places within Bugzilla's UI, f.e. as the form field label
on the "show bug" page

=item B<type>

An integer specifying the kind of field this is; values correspond to
the FIELD_TYPE_* constants in Constants.pm

=item B<custom>

A boolean specifying whether or not the field is a custom field;
if true, field name should start "cf_", but use this property to determine
which fields are custom fields

=item B<in_new_bugmail>

A boolean specifying whether or not the field is displayed in bugmail
for newly-created bugs

=item B<sortkey>

sortkey is an integer value by which fields are sorted in the bugmail and change history tables

=item B<obsolete>

A boolean specifying whether or not the field is obsolete (disabled and unused in the UI)

=item B<enabled>

The reverse of obsolete

=item B<nullable>

A boolean specifying whether empty value is allowed for this field

=item B<is_mandatory>

The reverse of nullable

=item B<clone_bug>

A boolean specifying whether or not this field should be copied on bug clone

=item B<is_select>

True if this is a B<FIELD_TYPE_SINGLE_SELECT> or B<FIELD_TYPE_MULTI_SELECT>
field. It is only safe to call L</legal_values> if this is true.

=item B<has_activity>

True if this field has records in the bugs_activity table.
Calculated automatically.

=item B<add_to_deps>

Has effect only for FIELD_TYPE_BUG_ID fields. One of 0, BUG_ID_ADD_TO_BLOCKED == 1
or BUG_ID_ADD_TO_DEPENDSON == 2. Indicates whether the value of this field
should be added to the bug dependency tree (blocked/dependson fields)
automatically.

=item B<url>

URL template for FIELD_TYPE_EXTURL fields. $1 is replaced as this field
value in this template.

=item B<default_value>

Global default value for this field. Format is: single ID for single-select
fields; multiple comma-separated IDs for multi-select fields; always empty
for BUG_ID_REV fields; string value for all other types.

=item B<visibility_field_id>, B<visibility_field>

A select field that controls visibility of this one.

=item B<value_field_id>, B<value_field>

Select field that controls values of this one, if this one is also a select,
or related direct BUG_ID field, if this one is BUG_ID_REV type field.

=item B<null_field_id>, B<null_field>

A select field that controls if this one can be empty.

=item B<default_field_id>, B<default_field>

A select field that controls the default value for this field.

=item B<clone_field_id>, B<clone_field>

A select field that enables or disables copying of this field value when cloning bugs.

=back

=cut

sub description         { $_[0]->{description} }
sub type                { $_[0]->{type} }
sub custom              { $_[0]->{custom} }
sub in_new_bugmail      { $_[0]->{mailhead} }
sub sortkey             { $_[0]->{sortkey} }
sub obsolete            { $_[0]->{obsolete} }
sub enabled             { !$_[0]->{obsolete} }
sub nullable            { !$_[0]->type && $_[0]->custom || $_[0]->type == FIELD_TYPE_BUG_ID_REV || !$_[0]->{is_mandatory} }
sub is_mandatory        { !$_[0]->nullable }
sub clone_bug           { $_[0]->{clone_bug} }
sub is_select           { $_[0]->type == FIELD_TYPE_SINGLE_SELECT || $_[0]->type == FIELD_TYPE_MULTI_SELECT }
sub has_activity        { $_[0]->{has_activity} }
sub add_to_deps         { $_[0]->type == FIELD_TYPE_BUG_ID && $_[0]->{add_to_deps} }
sub url                 { $_[0]->{url} }
sub default_value       { $_[0]->{default_value} }
sub visibility_field_id { $_[0]->{visibility_field_id} }
sub value_field_id      { ($_[0]->is_select || $_[0]->type == FIELD_TYPE_BUG_ID_REV) ? $_[0]->{value_field_id} : undef }
sub null_field_id       { $_[0]->{null_field_id} }
sub default_field_id    { $_[0]->{default_field_id} }
sub clone_field_id      { $_[0]->{clone_field_id} }
sub visibility_field    { $_[0]->{visibility_field_id} && Bugzilla->get_field($_[0]->{visibility_field_id}) }
sub value_field         { my $id = $_[0]->value_field_id; return $id && Bugzilla->get_field($id); }
sub null_field          { $_[0]->{null_field_id} && Bugzilla->get_field($_[0]->{null_field_id}) }
sub default_field       { $_[0]->{default_field_id} && Bugzilla->get_field($_[0]->{default_field_id}) }
sub clone_field         { $_[0]->{clone_field_id} && Bugzilla->get_field($_[0]->{clone_field_id}) }

# Value class for this field
sub value_type
{
    my $self = shift;
    return Bugzilla::Field::Choice->type($self);
}

# Checks if a certain property can be changed for this field (either it is custom or standard)
sub can_tweak
{
    my $self = shift;
    my ($prop) = @_;
    return $self->name !~ /^attachments\./ && $self->name ne 'longdesc' if $prop eq 'mailhead';
    $prop = 'clone_bug' if $prop eq 'clone_field_id';
    $prop = 'nullable' if $prop eq 'null_field_id';
    return 0 if !$self->custom && !CAN_TWEAK->{$prop}->{$self->name};
    return $self->type && $self->type != FIELD_TYPE_BUG_ID_REV if $prop eq 'default_value' || $prop eq 'nullable';
    return $self->is_select if $prop eq 'value_field_id';
    return 1;
}

# Return valid values for this field, arrayref of Bugzilla::Field::Choice objects.
# Includes disabled values is $include_disabled == true
sub legal_values
{
    my $self = shift;
    my ($include_disabled) = @_;
    return [] unless $self->is_select;
    return [ $self->value_type->get_all($include_disabled) ];
}

# Returns all valid value names for this field, always excluding disabled values
sub legal_value_names
{
    my $self = shift;
    return [] unless $self->is_select;
    return [ map { $_->{name} } @{ $self->value_type->get_all_names } ];
}

# Returns all valid names with corresponding IDs for this field, always excluding disabled values
sub legal_value_names_with_ids
{
    my $self = shift;
    return [] unless $self->is_select;
    return $self->value_type->get_all_names;
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

# Check if a value is enabled for some controlling value or arrayref of values
sub is_value_enabled
{
    my $self = shift;
    my ($value, $visibility_values) = @_;
    return 1 if !$self->value_field_id;
    ref $value and $value = $value->id;
    my $hash = Bugzilla->fieldvaluecontrol
        ->{$self->value_field_id}
        ->{values}
        ->{$self->id}
        ->{$value};
    return $hash && grep { $hash->{ref $_ ? $_->id : $_} } list $visibility_values;
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

=pod

=head2 Instance Mutators

$field->set_* functions set the particular field that they are named after.

They take a single value - the new value for that field.

They will throw an error if you try to set the values to something invalid.

These are: B<set_description>, B<set_clone_bug>, B<set_obsolete>,
B<set_is_mandatory>, B<set_sortkey>, B<set_in_new_bugmail>, B<set_add_to_deps>,
B<set_url>, B<set_default_value>, B<set_visibility_field>, B<set_value_field>,
B<set_null_field>, B<set_clone_field>, B<set_default_field>.

=cut

sub set_description      { $_[0]->set('description',         $_[1]); }
sub set_clone_bug        { $_[0]->set('clone_bug',           $_[1]); }
sub set_obsolete         { $_[0]->set('obsolete',            $_[1]); }
sub set_is_mandatory     { $_[0]->set('is_mandatory',        $_[1]); }
sub set_sortkey          { $_[0]->set('sortkey',             $_[1]); }
sub set_in_new_bugmail   { $_[0]->set('mailhead',            $_[1]); }
sub set_add_to_deps      { $_[0]->set('add_to_deps',         $_[1]); }
sub set_url              { $_[0]->set('url',                 $_[1]); }
sub set_default_value    { $_[0]->set('default_value',       $_[1]); }
sub set_visibility_field { $_[0]->set('visibility_field_id', $_[1]); }
sub set_value_field      { $_[0]->set('value_field_id',      $_[1]); }
sub set_null_field       { $_[0]->set('null_field_id',       $_[1]); }
sub set_clone_field      { $_[0]->set('clone_field_id',      $_[1]); }
sub set_default_field    { $_[0]->set('default_field_id',    $_[1]); }

# This is only used internally by upgrade code in Bugzilla::Field.
sub _set_type
{
    trick_taint($_[1]);
    $_[0]->{type} = int($_[1]);
}

=pod

=head2 Instance Methods

=over

=item B<remove_from_db()>

Attempts to remove the passed in field from the database.
Deleting a field is only successful if the field is obsolete and
there are no values specified for the field.

=item B<update()>

Saves modifications done with $field->set_* mutators in the DB,
and refreshes field metadata cache.

=item B<touch()>

Just refreshes field metadata cache.

=item B<update_visibility_values($controlled_value_id, $visibility_value_ids)>

Enables $controlled_value_id for, and only for, controlling values specified
by ID array $visibility_value_ids.

$controlled_value_id may be either FLAG_VISIBLE, FLAG_NULLABLE, FLAG_CLONED,
or a positive integer ID of a possible value for this field.

=item B<set_visibility_values($value_ids)>, B<set_null_visibility_values($value_ids)>, B<set_clone_visibility_values($value_ids)>

Same as the above method called with $controlled_value_id == FLAG_VISIBLE, FLAG_NULLABLE,
or FLAG_CLONED respectively.

=item B<update_control_lists($controlling_value_id, $params)>

Given the ID of a possible value for this field, updates all field dependencies
(which are other visible/nullable/cloned fields and default values for other fields
controlled by this field) at once.

=item B<update_controlled_values($controlled_value_ids, $visibility_value_id)>

Sets this field possible values for a value of the value_field $visibility_value_id
to ones identified by IDs $controlled_values.

=item B<update_default_value($visibility_value_id, $default_value)>

Sets the dependent default value for this field to $default_value in case
when the ID of the value of default_field is equal to $visibility_value_id.

=back

=cut

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $name = $self->name;

    if (!$self->custom)
    {
        ThrowUserError('field_not_custom', { name => $name });
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
    if ($self->{name} eq 'classification')
    {
        my $prod = Bugzilla->get_field('product');
        $prod->set_value_field($self->obsolete ? undef : $self->id);
        $prod->update;
    }
    return wantarray ? ($changes, $old_self) : $changes;
}

# Update field change timestamp (needed for cache flushing)
sub touch
{
    my $self = shift;
    $self->update;
}

sub set_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    $self->update_visibility_values(FLAG_VISIBLE, $value_ids);
    return $value_ids && @$value_ids;
}

sub set_null_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    $self->update_visibility_values(FLAG_NULLABLE, $value_ids);
    return $value_ids && @$value_ids;
}

sub set_clone_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    $self->update_visibility_values(FLAG_CLONED, $value_ids);
    return $value_ids && @$value_ids;
}

# Helper, returns the dependency field based on value of fieldvaluecontrol $flag
sub flag_field
{
    my ($self, $flag) = @_;
    return $self->value_field if $flag > 0;
    return $self->visibility_field if $flag == FLAG_VISIBLE;
    return $self->null_field if $flag == FLAG_NULLABLE;
    return $self->clone_field if $flag == FLAG_CLONED;
}

sub clear_value_visibility_values
{
    my $self = shift;
    Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id > 0",
        undef, $self->id
    );
}

sub clear_default_values
{
    my $self = shift;
    Bugzilla->dbh->do("DELETE FROM field_defaults WHERE field_id=?", undef, $self->id);
}

sub update_visibility_values
{
    my $self = shift;
    my ($controlled_value_id, $visibility_value_ids) = @_;
    $visibility_value_ids ||= [];
    my $vis_field = $self->flag_field($controlled_value_id);
    if (!$vis_field)
    {
        return undef;
    }
    $controlled_value_id = int($controlled_value_id);
    if (@$visibility_value_ids)
    {
        my $type = $vis_field->value_type;
        $visibility_value_ids = [
            (grep { $_ == 0 } @$visibility_value_ids ? (0) : ()),
            map { $_->id } @{ $type->new_from_list($visibility_value_ids) }
        ];
    }
    my $h = Bugzilla->fieldvaluecontrol->{$vis_field->id};
    $h = $h->{values}->{$self->id}->{$controlled_value_id} if $controlled_value_id > 0;
    $h = $h->{fields}->{$self->id} if $controlled_value_id == FLAG_VISIBLE;
    $h = $h->{null}->{$self->id} if $controlled_value_id == FLAG_NULLABLE;
    $h = $h->{clone}->{$self->id} if $controlled_value_id == FLAG_CLONED;
    $h = $h ? { %$h } : {};
    my $add = [];
    for (@$visibility_value_ids)
    {
        $h->{$_} ? delete $h->{$_} : push @$add, $_;
    }
    my $del = [ keys %$h ];
    return 0 if !@$add && !@$del;
    if (@$del)
    {
        Bugzilla->dbh->do(
            "DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id=?".
            " AND visibility_value_id IN (".join(", ", @$del).")",
            undef, $self->id, $controlled_value_id
        );
    }
    $self->add_visibility_values($controlled_value_id, $add);
    return 1;
}

sub add_visibility_values
{
    my $self = shift;
    my ($controlled_value_id, $visibility_value_ids) = @_;
    return 0 if !@$visibility_value_ids;
    my $f = $self->id;
    for ($controlled_value_id)
    {
        $_ eq FLAG_VISIBLE or $_ = int($_) or return 0;
    }
    for (@$visibility_value_ids)
    {
        ($_ = int($_)) > 0 or return 0;
    }
    # Ignore duplicate row errors
    eval
    {
        Bugzilla->dbh->do(
            "INSERT INTO fieldvaluecontrol (field_id, value_id, visibility_value_id) VALUES ".
            join(",", map { "($f, $controlled_value_id, $_)" } @$visibility_value_ids)
        );
    };
    my $ok = !$@;
    $self->touch;
    return $ok;
}

sub update_control_lists
{
    my $self = shift;
    my ($controlling_value_id, $params) = @_;
    $controlling_value_id = $self->value_type->new($controlling_value_id);
    $controlling_value_id = $controlling_value_id ? $controlling_value_id->id : return undef;
    # Save all visible, nullable and clone flags at once
    my $mod = { del => [], add => [] };
    my $rpt = {};
    my $h = Bugzilla->fieldvaluecontrol->{$self->id};
    for my $flag ([ 'visibility_field_id', 'is_visible', 'fields', FLAG_VISIBLE ],
        [ 'null_field_id', 'is_nullable', 'null', FLAG_NULLABLE ],
        [ 'clone_field_id', 'is_cloned', 'clone', FLAG_CLONED ])
    {
        for my $f (Bugzilla->get_fields({ obsolete => 0, $flag->[0] => $self->id }))
        {
            if ((1 && $params->{$flag->[1].'_'.$f->name}) != ($h->{$flag->[2]} &&
                $h->{$flag->[2]}->{$f->id} && $h->{$flag->[2]}->{$f->id}->{$controlling_value_id}))
            {
                my $ad = $params->{$flag->[1].'_'.$f->name} ? 'add' : 'del';
                push @{$rpt->{$ad.'_'.$flag->[1]}}, $f->id;
                push @{$mod->{$ad}}, [ $f->id, $flag->[3] ];
            }
        }
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
    my $def = { del => [], add => [] };
    $h = Bugzilla->fieldvaluecontrol->{$self->id}->{defaults};
    for my $f (Bugzilla->get_fields({ obsolete => 0, default_field_id => $self->id }))
    {
        my $default = $params->{'default_'.$f->name};
        $default = $f->_check_default_value($default);
        if ($default ne ($h->{$f->id} && $h->{$f->id}->{$controlling_value_id} || ''))
        {
            if (!$default)
            {
                push @{$def->{del}}, [ $f->id ];
            }
            else
            {
                trick_taint($default);
                push @{$def->{add}}, [ $f->id, $default ];
            }
            $touched->{$f->id} = 1;
        }
    }
    if (@{$def->{del}} || @{$def->{add}})
    {
        Bugzilla->dbh->do(
            'DELETE FROM field_defaults WHERE visibility_value_id=? AND field_id IN ('.
            join(',', map { $_->[0] } (@{$def->{add}}, @{$def->{del}})).')',
            undef, $controlling_value_id
        );
    }
    if (@{$def->{add}})
    {
        Bugzilla->dbh->do(
            'INSERT INTO field_defaults (visibility_value_id, field_id, default_value) VALUES '.
            join(',', map { "($controlling_value_id, $_->[0], ?)" } @{$def->{add}}),
            undef, map { $_->[1] } @{$def->{add}}
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
    if (@{$mod->{add}} || @{$mod->{del}} || @{$def->{del}} || @{$def->{add}})
    {
        Bugzilla->add_result_message({
            message => 'control_lists_updated',
            field_id => $self->id,
            value_id => $controlling_value_id,
            del_defaults => [ map { $_->[0] } @{$def->{del}} ],
            add_defaults => [ map { $_->[0] } @{$def->{add}} ],
            %$rpt,
        });
        return 1;
    }
    return 0;
}

sub update_controlled_values
{
    my $self = shift;
    my ($controlled_value_ids, $visibility_value_id) = @_;
    $controlled_value_ids ||= [];
    $controlled_value_ids = [ $controlled_value_ids ] if !ref $controlled_value_ids;
    my $vis_field = $self->value_field;
    if (!$vis_field)
    {
        return undef;
    }
    $visibility_value_id = int($visibility_value_id);
    Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND visibility_value_id=? AND value_id!=0",
        undef, $self->id, $visibility_value_id);
    if (@$controlled_value_ids)
    {
        my $type = $self->value_type;
        $controlled_value_ids = [ map { $_->id } @{ $type->new_from_list($controlled_value_ids) } ];
        my $f = $self->id;
        my $sql = "INSERT INTO fieldvaluecontrol (field_id, visibility_value_id, value_id) VALUES ".
            join(",", map { "($f, $visibility_value_id, $_)" } @$controlled_value_ids);
        Bugzilla->dbh->do($sql);
    }
    # Touch the field
    $self->touch;
    return 1;
}

sub update_default_value
{
    my $self = shift;
    my ($visibility_value_id, $default_value) = @_;
    $visibility_value_id = int($visibility_value_id);
    $default_value = $self->_check_default_value($default_value);
    if (!$default_value)
    {
        Bugzilla->dbh->do(
            'DELETE FROM field_defaults WHERE field_id=? AND visibility_value_id=?',
            undef, $self->id, $visibility_value_id
        );
    }
    else
    {
        trick_taint($default_value);
        Bugzilla->dbh->do(
            'REPLACE INTO field_defaults (field_id, visibility_value_id, default_value) VALUES (?, ?, ?)',
            undef, $self->id, $visibility_value_id, $default_value
        );
    }
    # Touch the field
    $self->touch;
    return 1;
}

=pod

=head2 Class Methods

=over

=item B<create($params)>

Creates a new field. Takes a single hashref with all instance properties (DB column values).

=item B<populate_field_definitions()>

Populates the fielddefs table with standard fields during an installation or upgrade.

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
    if (($field_values->{type}||0) == FIELD_TYPE_BUG_URLS && $params->{name} ne 'see_also')
    {
        ThrowUserError('useless_customfield_type', { type => $field_values->{type} });
    }
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

    $params->{has_activity} = 0;

    return $params;
}

sub populate_field_definitions
{
    my $dbh = Bugzilla->dbh;

    my ($has_clone_bug) = $dbh->selectrow_array('SELECT 1 FROM fielddefs WHERE clone_bug=1 AND custom=0');

    # Add/update field definitions
    my $i = 0;
    foreach my $def (DEFAULT_FIELDS())
    {
        $i++;
        my $field = new Bugzilla::Field({ name => $def->{name} });
        if ($field)
        {
            $field->_set_type($def->{type}) if $def->{type};
            $field->set_description($def->{description});
            $field->set_sortkey($i*10);
            $field->set_in_new_bugmail($def->{mailhead}) if !$field->can_tweak('mailhead');
            $field->set_clone_bug($def->{clone_bug}) if !$has_clone_bug || !$field->can_tweak('clone_bug');
            if ($def->{is_mandatory} || $def->{name} eq 'keywords' && $def->{type} ne $field->type ||
                !$field->can_tweak('nullable'))
            {
                $field->set_is_mandatory($def->{is_mandatory});
            }
            for (qw(value_field null_field default_field))
            {
                if ($def->{$_} && !$field->{$_.'_id'})
                {
                    $field->set($_.'_id', $dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $def->{$_}));
                }
            }
            $field->update();
        }
        else
        {
            my $copy = { %$def };
            for (qw(value_field null_field default_field))
            {
                $copy->{$_.'_id'} = $dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, delete $copy->{$_});
            }
            Bugzilla::Field->create($copy);
        }
    }

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

    # DELETE fields which were added only accidentally, or which
    # were never (or almost never) tracked in bugs_activity.

    my $names = "name IN ('cc_accessible', 'requesters.login_name',
        'attachments.thedata', 'attach_data.thedata', 'content', 'requestees.login_name',
        'setters.login_name', 'longdescs.isprivate', 'assignee_accessible', 'qacontact_accessible',
        'commenter', 'owner_idle_time', 'attachments.submitter', 'days_elapsed', 'percentage_complete')";
    $dbh->do("DELETE FROM bugs_activity WHERE fieldid IN (SELECT id FROM fielddefs WHERE $names)");
    $dbh->do("DELETE FROM fielddefs WHERE $names");
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
            $value = $vf->value_type->new({ name => $value });
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

1;
__END__
