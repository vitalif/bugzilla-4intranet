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

Bugzilla::Field - a particular piece of information about objects.

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
    class_id
    name
    description
    type
    value_class_id
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

use constant REQUIRED_CREATE_FIELDS => qw(class_id name description);

use constant VALIDATORS => {
    class_id            => \&_check_class_id,
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

use constant NO_UPDATE => { id => 1, name => 1, custom => 1, class_id => 1, value_class_id => 1 };
use constant UPDATE_COLUMNS => grep { !NO_UPDATE->{$_} } DB_COLUMNS();

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
    FIELD_TYPE_NUMERIC,       { TYPE => 'DECIMAL(30,10)', NOTNULL => 1, DEFAULT => '0' },
    FIELD_TYPE_INTEGER,       { TYPE => 'INT4',    NOTNULL => 1, DEFAULT => '0' },
    FIELD_TYPE_BOOLEAN,       { TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 'FALSE' },
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

# Field is uniquely identified by class+name, not by just name
sub _init
{
    my $class = shift;
    my ($param) = @_;
    if (ref $param eq 'HASH' && defined $param->{name})
    {
        my $cl = delete $param->{class_id} || Bugzilla->get_class('bug')->id;
        $param->{condition} = Bugzilla->dbh->sql_istrcmp('name', '?').' AND class_id=?';
        $param->{values} = [ delete $param->{name}, $cl ]
    }
    return $class->SUPER::_init($param);
}

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

sub _check_class_id
{
    my ($invocant, $class) = @_;
    $class = Bugzilla->get_class($class || 'bug');
    $class || ThrowUserError('field_unknown_class');
    return $class->id;
}

sub _check_description
{
    my ($invocant, $desc) = @_;
    $desc = clean_text($desc);
    $desc || ThrowUserError('field_missing_description');
    return $desc;
}

sub _check_name
{
    my ($params, $name) = @_;
    $name = lc(clean_text($name));
    $name || ThrowUserError('field_missing_name');
    $name ne 'id' || ThrowUserError('field_special_name', { name => $name });

    my $is_bug = $params->{class_id} == Bugzilla->get_class('bug')->id;
    # FIXME . is still allowed in some standard bug fields
    my $name_regex = $params->{custom} || !$is_bug ? qr/^[a-zA-Z0-9_]+$/ : qr/^[\w\.]+$/;
    # Bug fields can't be named just "cf_"
    if ($name !~ $name_regex || $is_bug && $name eq "cf_")
    {
        ThrowUserError('field_invalid_name', { name => $name });
    }

    # If it's a custom bug field, prepend cf_ to the custom field name to distinguish
    # it from standard fields.
    if ($is_bug && $name !~ /^cf_/ && $params->{custom})
    {
        $name = 'cf_' . $name;
    }

    # Assure the name is unique. Names can't be changed, so we don't have
    # to worry about what to do on updates.
    my $field = Bugzilla->get_class_field($name, $params->{class_id});
    ThrowUserError('field_already_exists', { field => $field }) if $field;

    return $name;
}

sub _check_sortkey
{
    my ($invocant, $sortkey) = @_;
    !defined($sortkey) || detaint_natural($sortkey) || ThrowUserError('field_invalid_sortkey', { sortkey => $sortkey });
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
        $type > FIELD_TYPE_INTEGER)
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
    my ($params, $field_id) = @_;
    my $type = $params->{type} || 0;
    if ($type == FIELD_TYPE_REVERSE)
    {
        # For reverse relationship fields value_field is the corresponding direct relationship
        my $field = Bugzilla->get_field(trim($field_id));
        if (!$field || !($field->type == FIELD_TYPE_SINGLE ||
            Bugzilla->get_class($params->{class_id})->name eq 'bug' && $field->type == FIELD_TYPE_BUG_ID) ||
            $field->value_class_id != $params->{class_id})
        {
            ThrowUserError('direct_field_needed_for_reverse');
        }
        for (Bugzilla->get_fields({ class_id => $params->{class_id}, type => FIELD_TYPE_REVERSE, value_field_id => $field->id }))
        {
            if (!ref $params || $_->id != $params->id)
            {
                ThrowUserError('duplicate_reverse_field');
            }
        }
        return $field->id;
    }
    if ($field_id && $type != FIELD_TYPE_SINGLE && $type != FIELD_TYPE_MULTI)
    {
        ThrowUserError('field_value_control_select_only');
    }
    return _check_visibility_field_id($params, $field_id);
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
    if ($invocant->{class_id} != $field->class_id)
    {
        ThrowUserError('field_control_other_class', { field => $field });
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
    if ($self->type == FIELD_TYPE_SINGLE)
    {
        # ID
        detaint_natural($value) || undef;
    }
    elsif ($self->type == FIELD_TYPE_MULTI)
    {
        # Array of IDs
        $value = [ $value ] if !ref $value;
        detaint_natural($_) for @$value;
        $value = @$value ? join(',', sort @$value) : undef;
    }
    elsif ($self->type == FIELD_TYPE_REVERSE)
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

=item B<db_column>

Name of the DB column of object table this field value is stored in, if appropriate

FIXME: db_column is now equal to field name, and current code relies on it in many places

=item B<rel_table>

Only for many-to-many ("multiselect") fields. Name of the DB table ID pairs
are stored in.

=item B<class_id>, B<class>

Class that this field is a property of

=item B<description>

A short string describing the field; displayed to Bugzilla users
in several places within Bugzilla's UI, f.e. as the form field label
on the "show bug" page

=item B<type>

An integer specifying the kind of field this is; values correspond to
the FIELD_TYPE_* constants in Constants.pm

=item B<value_class_id>, B<value_class>, B<value_type>

Type ID, Bugzilla::Class object and package name of value class
for FIELD_TYPE_SINGLE and FIELD_TYPE_MULTI fields

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

=item C<type>

an integer specifying the kind of field this is; values correspond to
the FIELD_TYPE_* constants in Constants.pm

=item C<custom>

a boolean specifying whether or not the field is a custom field;
if true, field name should start "cf_", but use this property to determine
which fields are custom fields

=item C<in_new_bugmail>

a boolean specifying whether or not the field is displayed in bugmail
for newly-created bugs;

=item C<sortkey>

an integer specifying the sortkey of the field

=item C<obsolete>

a boolean specifying whether or not the field is obsolete (disabled and unused in the UI)

=item C<enabled>

the reverse of obsolete

=item C<nullable>

a boolean specifying whether empty value is allowed for this field

=item C<is_mandatory>

the reverse of nullable

=back

=cut

sub class_id            { $_[0]->{class_id} }
sub class               { Bugzilla->get_class($_[0]->{class_id}) }
sub description         { $_[0]->{description} }
sub type                { $_[0]->{type} }
sub value_class_id      { $_[0]->{value_class_id} }
sub value_class         { $_[0]->{value_class_id} && Bugzilla->get_class($_[0]->{value_class_id}) }
sub custom              { $_[0]->{custom} }
sub in_new_bugmail      { $_[0]->{mailhead} }
sub sortkey             { $_[0]->{sortkey} }
sub obsolete            { $_[0]->{obsolete} }
sub enabled             { !$_[0]->{obsolete} }
sub nullable            { !$_[0]->type && $_[0]->custom || $_[0]->type == FIELD_TYPE_BUG_ID_REV || !$_[0]->{is_mandatory} }
sub is_mandatory        { !$_[0]->nullable }
sub clone_bug           { $_[0]->{clone_bug} }
sub is_select           { $_[0]->type == FIELD_TYPE_SINGLE || $_[0]->type == FIELD_TYPE_MULTI }
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

sub db_column
{
    my $self = shift;
    return undef if $self->{type} == FIELD_TYPE_MULTI || $self->{type} == FIELD_TYPE_REVERSE;
    return $self->{name}.'_id' if
        $self->class->name eq 'bug' && ($self->{name} eq 'component' || $self->{name} eq 'product') ||
        $self->class->name eq 'product' && $self->{name} eq 'classification';
    return $self->{name};
}

# Methods describing relationship table for multi-select fields
sub rel_table
{
    $_[0]->{type} == FIELD_TYPE_MULTI ? $_[0]->class->name.'_'.$_[0]->{name} : undef
}

sub rel_object_id
{
    my $self = shift;
    return 'component_id' if $self->name eq 'cc' && $self->class->name eq 'component';
    return 'bug_id' if $self->class->name eq 'bug';
    return 'object_id';
}

sub rel_value_id
{
    my $self = shift;
    return 'user_id' if $self->name eq 'cc' && $self->class->name eq 'component';
    return 'object_id';
}

# Value class for this field
sub value_type
{
    my $self = shift;
    return $self->value_class->type if $self->{value_class_id};
}

# Checks if a certain property can be changed for this field (either it is custom or standard)
sub can_tweak
{
    my $self = shift;
    my ($prop) = @_;
    $prop = 'clone_bug' if $prop eq 'clone_field_id';
    $prop = 'nullable' if $prop eq 'null_field_id';
    if ($self->class->name eq 'bug')
    {
        return $self->name !~ /^attachments\./ && $self->name ne 'longdesc' if $prop eq 'mailhead';
        return 0 if !$self->custom && !CAN_TWEAK->{$prop}->{$self->name};
    }
    return $self->type && $self->type != FIELD_TYPE_BUG_ID_REV if $prop eq 'default_value' || $prop eq 'nullable';
    return $self->is_select if $prop eq 'value_field_id';
    return 1;
}

# Return valid values for this field as an arrayref of value type objects.
# Includes disabled values if $include_disabled == true
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

# Check visibility of field for an object or for a hashref with default value names
sub check_visibility
{
    my $self = shift;
    my $bug = shift || return 1;
    my $vf = $self->visibility_field || return 1;
    my $value = bug_or_hash_value($bug, $vf);
    return $value ? $self->has_visibility_value($value) : 1;
}

# Check if a field is nullable for an object or for a hashref with default value names
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

# Check if a field should be copied when cloning an object
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

# Get default value for this field in object $bug
sub get_default_value
{
    my $self = shift;
    my ($bug, $use_global) = @_;
    my $default = $use_global ? $self->default_value : undef;
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
there are no values specified for it.

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

    if ($self->type != FIELD_TYPE_REVERSE)
    {
        # Check to see if object table has records
        my $sql = "";
        if ($self->type == FIELD_TYPE_MULTI)
        {
            $sql = "SELECT COUNT(*) FROM ".$self->rel_table;
        }
        else
        {
            $sql = "SELECT COUNT(*) FROM ".$self->class->db_table." WHERE ".$self->db_column." IS NOT NULL";
            if ($self->type != FIELD_TYPE_SINGLE &&
                $self->type != FIELD_TYPE_BUG_ID && $self->type != FIELD_TYPE_DATETIME)
            {
                $sql .= " AND ".$self->db_column." != ''";
            }
        }
        my ($has_objects) = $dbh->selectrow_array($sql);
        if ($has_objects)
        {
            ThrowUserError('customfield_has_contents', { field => $self });
        }
    }

    # Once we reach here, we should be OK to delete.
    $dbh->do('DELETE FROM fielddefs WHERE id = ?', undef, $self->id);

    # the values for multi-select are stored in a separate table
    if ($self->type == FIELD_TYPE_MULTI)
    {
        $dbh->bz_drop_table($self->rel_table);
    }
    if (SQL_DEFINITIONS->{$self->type})
    {
        $dbh->bz_drop_column($self->class->db_table, $self->db_column);
    }

    # Update some other field (refresh the cache)
    Bugzilla->get_class_field($self->class->type->ID_FIELD, $self->class->id)->touch;

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
    if ($self->{name} eq 'classification' && $self->class->name eq 'bug')
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
    my ($value_ids, $skip_invisible) = @_;
    $self->update_visibility_values(FLAG_VISIBLE, $value_ids, $skip_invisible);
    return $value_ids && @$value_ids;
}

sub set_null_visibility_values
{
    my $self = shift;
    my ($value_ids, $skip_invisible) = @_;
    $self->update_visibility_values(FLAG_NULLABLE, $value_ids, $skip_invisible);
    return $value_ids && @$value_ids;
}

sub set_clone_visibility_values
{
    my $self = shift;
    my ($value_ids, $skip_invisible) = @_;
    $self->update_visibility_values(FLAG_CLONED, $value_ids, $skip_invisible);
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

sub count_value_objects
{
    my $self = shift;
    return 0 if !$self->is_select || $self->class->name eq 'bug' && $self->name eq 'classification'; # FIXME classification should not be a field of bugs
    my ($value_id) = @_;
    my ($n) = Bugzilla->dbh->selectrow_array(
        "SELECT COUNT(*) FROM ".
        ($self->type == FIELD_TYPE_MULTI ? $self->rel_table : $self->class->db_table).
        " WHERE ".($self->type == FIELD_TYPE_MULTI ? $self->rel_value_id : $self->db_column)."=?",
        undef, $value_id
    );
    return $n;
}

sub update_visibility_values
{
    my $self = shift;
    my ($controlled_value_id, $visibility_value_ids, $skip_invisible) = @_;
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
            (grep($_ == 0, @$visibility_value_ids) ? (0) : ()),
            (map { $_->id } @{ $type->new_from_list($visibility_value_ids) })
        ];
    }
    my $h = Bugzilla->fieldvaluecontrol->{$vis_field->id};
    $h = $h->{values}->{$self->id}->{$controlled_value_id} if $controlled_value_id > 0;
    $h = $h->{fields}->{$self->id} if $controlled_value_id == FLAG_VISIBLE;
    $h = $h->{null}->{$self->id} if $controlled_value_id == FLAG_NULLABLE;
    $h = $h->{clone}->{$self->id} if $controlled_value_id == FLAG_CLONED;
    $h = $h ? { %$h } : {};
    if ($skip_invisible)
    {
        # Do not affect visibility values the user can't see
        # so he can't damage other user's visibility values for the same field value
        my $allowed = { map { $_->id => 1 } @{$vis_field->legal_values} };
        for (keys %$h)
        {
            delete $h->{$_} if !$allowed->{$_};
        }
    }
    my $add = [];
    for (@$visibility_value_ids)
    {
        $h->{$_} ? delete $h->{$_} : push @$add, $_;
    }
    my $del = [ keys %$h ];
    return 0 if !@$add && !@$del;
    $self->delete_visibility_values($controlled_value_id, $del, 1);
    $self->add_visibility_values($controlled_value_id, $add);
    return 1;
}

sub delete_visibility_values
{
    my $self = shift;
    my ($controlled_value_id, $visibility_value_ids, $dont_touch) = @_;
    return 0 if !@$visibility_value_ids;
    my $ok = Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id=?".
        " AND visibility_value_id IN (".join(", ", map { int($_) } @$visibility_value_ids).")",
        undef, $self->id, $controlled_value_id
    );
    $self->touch if !$dont_touch;
    return $ok;
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
        $_ = int($_);
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
    my %p = (class_id => $self->class_id, obsolete => 0);
    my $mod = { del => [], add => [] };
    my $rpt = {};
    my $h = Bugzilla->fieldvaluecontrol->{$self->id};
    # Include field ID in parameter names so control lists of the same object
    # for different fields could be edited from the page
    my $suff = '_'.$self->id.'_';
    for my $flag ([ 'visibility_field_id', 'is_visible', 'fields', FLAG_VISIBLE ],
        [ 'null_field_id', 'is_nullable', 'null', FLAG_NULLABLE ],
        [ 'clone_field_id', 'is_cloned', 'clone', FLAG_CLONED ])
    {
        for my $f (Bugzilla->get_fields({ %p, $flag->[0] => $self->id }))
        {
            if ((1 && $params->{$flag->[1].$suff.$f->name}) != ($h->{$flag->[2]} &&
                $h->{$flag->[2]}->{$f->id} && $h->{$flag->[2]}->{$f->id}->{$controlling_value_id}))
            {
                my $ad = $params->{$flag->[1].$suff.$f->name} ? 'add' : 'del';
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
    for my $f (Bugzilla->get_fields({ %p, default_field_id => $self->id }))
    {
        my $default = $params->{'default'.$suff.$f->name};
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
        # Check if we need to make a value class for this field
        if ($obj->is_select && !$obj->value_class_id)
        {
            my $def = Bugzilla::Class->STD_SELECT_CLASS;
            my $cl = Bugzilla::Class->new;
            $cl->set('name', $obj->name);
            $cl->set('description', $obj->description);
            $cl->update;
            for my $f (@{$def->{fields}})
            {
                Bugzilla::Field->create({
                    class_id    => $cl->id,
                    name        => $f->[0],
                    description => $f->[1],
                    type        => $f->[2],
                    custom      => 1,
                });
            }
            $params->{value_class_id} = $cl->id;
            $cl->set('name_field_id', $def->{name_field_id});
            $cl->set('list_order', $def->{list_order});
            $cl->update;
        }
        my $type = $obj->type;
        if (SQL_DEFINITIONS->{$type})
        {
            # Create the database column that stores the data for this field.
            $dbh->bz_add_column($obj->class->db_table, $obj->db_column, SQL_DEFINITIONS->{$type});
            # Add foreign key
            if ($type == FIELD_TYPE_SINGLE || $type == FIELD_TYPE_BUG_ID)
            {
                my $vt = $type == FIELD_TYPE_SINGLE ? $obj->value_type : 'Bugzilla::Bug';
                $dbh->bz_add_fk($obj->class->db_table, $obj->db_column, {
                    TABLE => $obj->value_type->DB_TABLE,
                    COLUMN => $obj->value_type->ID_FIELD,
                });
            }
        }
        elsif ($type == FIELD_TYPE_MULTI)
        {
            # Add many-to-many relationship table
            my $ms_table = $obj->rel_table;
            $dbh->_bz_add_field_table($ms_table, {
                FIELDS => [
                    $obj->rel_object_id => {TYPE => 'INT4', NOTNULL => 1},
                    $obj->rel_value_id => {TYPE => 'INT4', NOTNULL => 1, DEFAULT => 0},
                ],
                INDEXES => [
                    PRIMARY => [ $obj->rel_object_id, $obj->rel_value_id ],
                ],
            });
            $dbh->bz_add_fk($ms_table, $obj->rel_object_id, {
                TABLE => $obj->class->db_table,
                COLUMN => $obj->class->type->ID_FIELD,
                DELETE => 'CASCADE',
            });
            $dbh->bz_add_fk($ms_table, $obj->rel_value_id, {
                TABLE => $obj->value_class->db_table,
                COLUMN => $obj->value_type->ID_FIELD,
                DELETE => 'CASCADE',
            });
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

    $params->{name} = _check_name($params, $params->{name});
    if (!exists $params->{sortkey})
    {
        $params->{sortkey} = $dbh->selectrow_array(
            "SELECT MAX(sortkey) + 100 FROM fielddefs WHERE class_id=?",
            undef, $params->{class_id}
        ) || 100;
    }

    my $type = $params->{type} || 0;
    my $is_bug = Bugzilla->get_class($params->{class_id})->name eq 'bug';

    if (($params->{custom} || !$is_bug) && !$type)
    {
        ThrowCodeError('field_type_not_specified');
    }
    if ($type == FIELD_TYPE_BUG_ID && !$is_bug)
    {
        ThrowUserError('invalid_customfield_type', { type => FIELD_TYPE_BUG_ID });
    }

    $params->{value_field_id} = _check_value_field_id($params, $params->{value_field_id});

    # FIXME Merge something like VALIDATOR_DEPENDENCIES from 4.4
    if ($type != FIELD_TYPE_BUG_ID)
    {
        $params->{add_to_deps} = 0;
    }
    if ($type != FIELD_TYPE_EXTURL)
    {
        $params->{url} = undef;
    }

    # Check value class
    if (($type == FIELD_TYPE_SINGLE || $type == FIELD_TYPE_MULTI) &&
        $params->{value_class_id})
    {
        my $cl = Bugzilla->get_class($params->{value_class_id});
        if (!$cl)
        {
            ThrowUserError('field_unknown_value_class');
        }
        $params->{value_class_id} = $cl->id;
    }

    # Initial default value is empty for all select fields
    if ($type == FIELD_TYPE_SINGLE || $type == FIELD_TYPE_MULTI ||
        $type == FIELD_TYPE_BUG_ID_REV)
    {
        $params->{default_value} = undef;
    }

    $params->{has_activity} = 0;

    return $params;
}

sub populate_field_definitions
{
    my $dbh = Bugzilla->dbh;

    my $cl;
    if (!($cl = Bugzilla->get_class('bug')))
    {
        $cl = Bugzilla::Class->new;
        $cl->set_all({
            name => 'bug',
            description => 'Bug',
        });
        $cl->update;
    }

    my ($has_clone_bug) = $dbh->selectrow_array(
        'SELECT 1 FROM fielddefs WHERE class_id=? AND clone_bug=1 AND custom=0', undef, $cl->id
    );

    # Add/update field definitions
    my $i = 0;
    foreach my $def (DEFAULT_FIELDS())
    {
        $i++;
        my $field = new Bugzilla::Field({ class_id => $cl->id, name => $def->{name} });
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
                    $field->set($_.'_id', $dbh->selectrow_array(
                        'SELECT id FROM fielddefs WHERE class_id=? AND name=?',
                        undef, $cl->id, $def->{$_}
                    ));
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
            $copy->{class_id} = $cl->id;
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
            class_id => $cl->id,
            name => $new_field_name,
            description => $field_description
        });
    }

    # DELETE fields which were added only accidentally, or which
    # were never (or almost never) tracked in bugs_activity.

    my $names = "class_id=".int($cl->id)." AND name IN ('cc_accessible', 'requesters.login_name',
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
