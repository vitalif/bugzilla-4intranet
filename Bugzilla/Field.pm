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
  my $field = new Bugzilla::Field({name => 'qacontact_accessible'});
  if ($field->obsolete) {
      print $field->description . " is obsolete\n";
  }

  # Validation Routines
  $fieldid = get_field_id($fieldname);

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
@Bugzilla::Field::EXPORT = qw(get_field_id update_visibility_values);

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
    nullable
    enter_bug
    clone_bug
    buglist
    visibility_field_id
    value_field_id
    delta_ts
    has_activity
    add_to_deps
    url
);

use constant REQUIRED_CREATE_FIELDS => qw(name description);

use constant VALIDATORS => {
    custom      => \&Bugzilla::Object::check_boolean,
    description => \&_check_description,
    enter_bug   => \&Bugzilla::Object::check_boolean,
    clone_bug   => \&Bugzilla::Object::check_boolean,
    buglist     => \&Bugzilla::Object::check_boolean,
    mailhead    => \&Bugzilla::Object::check_boolean,
    obsolete    => \&Bugzilla::Object::check_boolean,
    nullable    => \&Bugzilla::Object::check_boolean,
    sortkey     => \&_check_sortkey,
    type        => \&_check_type,
    visibility_field_id => \&_check_visibility_field_id,
    add_to_deps => \&_check_add_to_deps,
};

use constant UPDATE_VALIDATORS => {
    value_field_id      => \&_check_value_field_id,
};

use constant UPDATE_COLUMNS => qw(
    description
    mailhead
    sortkey
    obsolete
    nullable
    enter_bug
    clone_bug
    buglist
    visibility_field_id
    value_field_id
    type
    delta_ts
    has_activity
    add_to_deps
    url
);

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
use constant DEFAULT_FIELDS => (
    {name => 'bug_id',       desc => 'Bug ID',     buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'short_desc',   desc => 'Summary',    buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_FREETEXT, clone_bug => 0},
    {name => 'classification', desc => 'Classification', buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 0},
    {name => 'product',      desc => 'Product',    buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 0},
    {name => 'version',      desc => 'Version',    buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 1, value_field_id => 4},
    {name => 'rep_platform', desc => 'Platform',   buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 0},
    {name => 'bug_file_loc', desc => 'URL',        buglist => 1, in_new_bugmail => 1, clone_bug => 1},
    {name => 'op_sys',       desc => 'OS/Version', buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 1},
    {name => 'bug_status',   desc => 'Status',     buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 0},
    {name => 'status_whiteboard', desc => 'Status Whiteboard', buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_FREETEXT, clone_bug => 1},
    {name => 'keywords',     desc => 'Keywords',   buglist => 1, in_new_bugmail => 1, clone_bug => 1},
    {name => 'resolution',   desc => 'Resolution', buglist => 1, nullable => 1,       type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 0},
    {name => 'bug_severity', desc => 'Severity',   buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 1},
    {name => 'priority',     desc => 'Priority',   buglist => 1, in_new_bugmail => 1, nullable => 1, type => FIELD_TYPE_SINGLE_SELECT, clone_bug => 1},
    {name => 'component',    desc => 'Component',  buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_SINGLE_SELECT, value_field_id => 4, clone_bug => 1},
    {name => 'assigned_to',  desc => 'Assignee',   buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'reporter',     desc => 'Reporter',   buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'votes',        desc => 'Votes',      buglist => 1, clone_bug => 0},
    {name => 'qa_contact',   desc => 'QA Contact', buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'cc',           desc => 'CC',         buglist => 1, in_new_bugmail => 1, clone_bug => 1}, # Also reporter/assigned_to/qa are added to cloned bug...
    {name => 'dependson',    desc => 'Depends on', buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'blocked',      desc => 'Blocks',     buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'dup_id',       desc => 'Duplicate of', buglist => 1, in_new_bugmail => 1, type => FIELD_TYPE_BUG_ID, clone_bug => 0},

    {name => 'attachments.description', desc => 'Attachment description', clone_bug => 0},
    {name => 'attachments.filename',    desc => 'Attachment filename',    clone_bug => 0},
    {name => 'attachments.mimetype',    desc => 'Attachment mime type',   clone_bug => 0},
    {name => 'attachments.ispatch',     desc => 'Attachment is patch',    clone_bug => 0},
    {name => 'attachments.isobsolete',  desc => 'Attachment is obsolete', clone_bug => 0},
    {name => 'attachments.isprivate',   desc => 'Attachment is private',  clone_bug => 0},
    {name => 'attachments.submitter',   desc => 'Attachment creator',     clone_bug => 0},

    {name => 'target_milestone',      desc => 'Target Milestone',    buglist => 1, nullable => 1, type => FIELD_TYPE_SINGLE_SELECT, value_field_id => 4, clone_bug => 1},
    {name => 'creation_ts',           desc => 'Creation time',       buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'delta_ts',              desc => 'Last changed time',   buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'longdesc',              desc => 'Comment',             clone_bug => 0},
    {name => 'longdescs.isprivate',   desc => 'Comment is private',  clone_bug => 0},
    {name => 'alias',                 desc => 'Alias',               buglist => 1, clone_bug => 0},
    {name => 'everconfirmed',         desc => 'Ever Confirmed',      clone_bug => 0},
    {name => 'reporter_accessible',   desc => 'Reporter Accessible', clone_bug => 0},
    {name => 'cclist_accessible',     desc => 'CC Accessible',       clone_bug => 0},
    {name => 'bug_group',             desc => 'Group',               in_new_bugmail => 1, clone_bug => 0}, # FIXME maybe clone_bug=1?
    {name => 'estimated_time',        desc => 'Estimated Hours',     buglist => 1, in_new_bugmail => 1, clone_bug => 0},
    {name => 'remaining_time',        desc => 'Remaining Hours',     buglist => 1, clone_bug => 0},
    {name => 'deadline',              desc => 'Deadline',            buglist => 1, in_new_bugmail => 1, clone_bug => 1},
    {name => 'commenter',             desc => 'Commenter',           clone_bug => 0},
    {name => 'flagtypes.name',        desc => 'Flags and Requests',  buglist => 1, clone_bug => 0},
    {name => 'requestees.login_name', desc => 'Flag Requestee',      clone_bug => 0},
    {name => 'setters.login_name',    desc => 'Flag Setter',         clone_bug => 0},
    {name => 'work_time',             desc => 'Hours Worked',        buglist => 1, clone_bug => 0},
    {name => 'percentage_complete',   desc => 'Percentage Complete', buglist => 1, clone_bug => 0},
    {name => 'content',               desc => 'Content',             clone_bug => 0},
    {name => 'attach_data.thedata',   desc => 'Attachment data',     clone_bug => 0},
    {name => 'owner_idle_time',       desc => 'Time Since Assignee Touched', clone_bug => 0},
    {name => 'see_also',              desc => 'See Also',            buglist => 1, type => FIELD_TYPE_BUG_URLS, clone_bug => 0},
);

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
    my $saved_type = $type;
    # The constant here should be updated every time a new,
    # higher field type is added.
    if (!detaint_natural($type) || $type > FIELD_TYPE__BOUNDARY)
    {
        ThrowCodeError('invalid_customfield_type', { type => $saved_type });
    }
    return $type;
}

sub _check_value_field_id
{
    my ($invocant, $field_id, $is_select) = @_;
    $is_select = $invocant->is_select if !defined $is_select;
    if ($field_id && !$is_select)
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

a boolean specifying whether NULL value is allowed for this field

=back

=cut

sub nullable { return $_[0]->type != FIELD_TYPE_SINGLE_SELECT || $_[0]->{nullable} }

=over

=item C<enter_bug>

A boolean specifying whether this field should appear on enter_bug.cgi

=back

=cut

sub enter_bug { return $_[0]->{enter_bug} }

=over

=item C<clone_bug>

A boolean specifying whether or not this field should be copied on bug clone

=back

=cut

sub clone_bug { return $_[0]->{clone_bug} }

=over

=item C<buglist>

A boolean specifying whether or not this field is selectable
as a display or order column in buglist.cgi

=back

=cut

sub buglist { return $_[0]->{buglist} }

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

sub value_type
{
    my $self = shift;
    return Bugzilla::Field::Choice->type($self);
}

sub new_choice
{
    my $self = shift;
    return $self->value_type->new(@_);
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

# Always excludes disabled values
sub restricted_legal_values
{
    my $self = shift;
    my ($controller_value) = @_;
    $controller_value = $controller_value->id if ref $controller_value;
    return $self->legal_values unless $controller_value && $self->value_field_id;
    my $rc_cache = Bugzilla->rc_cache_fields;
    if (!$rc_cache->{$self}->{restricted_legal_values}->{$controller_value})
    {
        my $hash = Bugzilla->fieldvaluecontrol_hash->{$self->value_field_id}->{values}->{$self->id};
        $rc_cache->{$self}->{restricted_legal_values}->{$controller_value} = [
            grep {
                $_->is_static || !exists $hash->{$_->id} ||
                !%{$hash->{$_->id}} || $hash->{$_->id}->{$controller_value}
            } @{$self->legal_values}
        ];
    }
    return $rc_cache->{$self}->{restricted_legal_values}->{$controller_value};
}

# Select default values for a named value of controlling field
sub get_default_values
{
    my $self = shift;
    my ($controller_value) = @_;
    return [] unless $self->value_field;
    my @values;
    my $field_values = $self->value_field->legal_values;
    foreach my $field_value (@$field_values)
    {
        if ($field_value->{name} eq $controller_value)
        {
            my $cvalues = $self->legal_values;
            foreach my $value (@$cvalues)
            {
                push @values, $value->{value} if $value->is_default_controlled_value($field_value->{id}) && !$value->is_static;
            }
            last;
        }
    }
    return \@values;
}

=pod

=over

=item C<visibility_field>

What field controls this field's visibility? Returns a C<Bugzilla::Field>
object representing the field that controls this field's visibility.

Returns undef if there is no field that controls this field's visibility.

=back

=cut

sub visibility_field
{
    my $self = shift;
    if ($self->{visibility_field_id})
    {
        return Bugzilla->get_field($self->{visibility_field_id});
    }
    return undef;
}

sub visibility_field_id
{
    my $self = shift;
    return $self->{visibility_field_id};
}

sub visibility_values
{
    my $self = shift;
    return undef if !$self->visibility_field_id;
    my $f;
    if ($self->visibility_field && !($f = $self->{visibility_values}))
    {
        $f = [ keys %{Bugzilla->fieldvaluecontrol_hash
            ->{$self->visibility_field_id}
            ->{fields}
            ->{$self->id} || {} } ];
        if (@$f)
        {
            my $type = Bugzilla::Field::Choice->type($self->visibility_field);
            $f = $type->match({ id => $f });
        }
        $self->{visibility_values} = $f;
    }
    return $f;
}

sub has_visibility_value
{
    my $self = shift;
    return 1 if !$self->visibility_field_id;
    my ($value) = @_;
    $value = $value->id if ref $value;
    my $hash = Bugzilla->fieldvaluecontrol_hash
        ->{$self->visibility_field_id}
        ->{fields}
        ->{$self->id};
    return !$hash || !%$hash || $hash->{$value};
}

sub has_all_visibility_values
{
    my $self = shift;
    return 1 if !$self->visibility_field_id;
    my $hash = Bugzilla->fieldvaluecontrol_hash
        ->{$self->visibility_field_id}
        ->{fields}
        ->{$self->id};
    return !$hash || !%$hash;
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

=pod

=over

=item C<value_field>

The Bugzilla::Field that controls the list of values for this field.

Returns undef if there is no field that controls this field's visibility.

=back

=cut

sub value_field
{
    my $self = shift;
    if (my $id = $self->value_field_id)
    {
        $self->{value_field} ||= Bugzilla::Field->new($id);
    }
    return $self->{value_field};
}

sub value_field_id
{
    my $self = shift;
    return undef if !$self->is_select;
    return $self->{value_field_id};
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

=item C<set_enter_bug>

=item C<set_clone_bug>

=item C<set_obsolete>

=item C<set_nullable>

=item C<set_sortkey>

=item C<set_in_new_bugmail>

=item C<set_buglist>

=item C<set_visibility_field>

=item C<set_value_field>

=back

=cut

sub set_description    { $_[0]->set('description', $_[1]); }
sub set_enter_bug      { $_[0]->set('enter_bug',   $_[1]); }
sub set_clone_bug      { $_[0]->set('clone_bug',   $_[1]); }
sub set_obsolete       { $_[0]->set('obsolete',    $_[1]); }
sub set_nullable       { $_[0]->set('nullable',    $_[1]); }
sub set_sortkey        { $_[0]->set('sortkey',     $_[1]); }
sub set_in_new_bugmail { $_[0]->set('mailhead',    $_[1]); }
sub set_buglist        { $_[0]->set('buglist',     $_[1]); }
sub set_add_to_deps    { $_[0]->set('add_to_deps', $_[1]); }
sub set_url            { $_[0]->set('url',         $_[1]); }

sub set_visibility_field
{
    my ($self, $value) = @_;
    $self->set('visibility_field_id', $value);
    delete $self->{visibility_field};
    delete $self->{visibility_values};
}

sub set_visibility_values
{
    my $self = shift;
    my ($value_ids) = @_;
    update_visibility_values($self, 0, $value_ids);
    delete $self->{visibility_values};
    return $value_ids && @$value_ids;
}

sub set_value_field
{
    my ($self, $value) = @_;
    $self->set('value_field_id', $value);
    delete $self->{value_field};
}

# This is only used internally by upgrade code in Bugzilla::Field.
sub _set_type { $_[0]->set('type', $_[1]); }

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

    # Check to see if bug activity table has records (should be fast with index)
    my $has_activity = $dbh->selectrow_array("SELECT COUNT(*) FROM bugs_activity WHERE fieldid = ?", undef, $self->id);
    if ($has_activity)
    {
        ThrowUserError('customfield_has_activity', { name => $name });
    }

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
        # Ignore the empty single select value
        if ($self->type == FIELD_TYPE_SINGLE_SELECT)
        {
            $bugs_query .= " AND $name IS NOT NULL";
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
    my ($changes, $old_self) = $self->SUPER::update(@_);
    Bugzilla->refresh_cache_fields;
    return wantarray ? ($changes, $old_self) : $changes;
}

# Update field change timestamp (needed for cache flushing)
sub touch
{
    my $self = shift;
    $self->{delta_ts} = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime);
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

=item C<enter_bug> - boolean - Whether this field is
editable on the bug creation form. Defaults to 0.

=item C<buglist> - boolean - Whether this field is
selectable as a display or order column in bug lists. Defaults to 0.

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

    $params->{value_field_id} = $class->_check_value_field_id(
        $params->{value_field_id},
        ($type == FIELD_TYPE_SINGLE_SELECT || $type == FIELD_TYPE_MULTI_SELECT) ? 1 : 0
    );
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

    my ($has_nullable) = $dbh->selectrow_array('SELECT 1 FROM fielddefs WHERE nullable AND NOT custom');

    # Add/update field definitions
    foreach my $def (DEFAULT_FIELDS)
    {
        my $field = new Bugzilla::Field({ name => $def->{name} });
        if ($field)
        {
            $field->set_description($def->{desc});
            $field->set_in_new_bugmail($def->{in_new_bugmail});
            $field->set_buglist($def->{buglist});
            $field->_set_type($def->{type}) if $def->{type};
            $field->set_clone_bug($def->{clone_bug}) if !$has_nullable;
            $field->set_nullable($def->{nullable}) if !$has_nullable;
            $field->update();
        }
        else
        {
            if (exists $def->{in_new_bugmail})
            {
                $def->{mailhead} = $def->{in_new_bugmail};
                delete $def->{in_new_bugmail};
            }
            $def->{description} = delete $def->{desc};
            Bugzilla::Field->create($def);
        }
    }

    # DELETE fields which were added only accidentally, or which
    # were never tracked in bugs_activity. Note that you can never
    # delete fields which are used by bugs_activity.

    # Oops. Bug 163299
    $dbh->do("DELETE FROM fielddefs WHERE name='cc_accessible'");
    # Oops. Bug 215319
    $dbh->do("DELETE FROM fielddefs WHERE name='requesters.login_name'");
    # This field was never tracked in bugs_activity, so it's safe to delete.
    $dbh->do("DELETE FROM fielddefs WHERE name='attachments.thedata'");

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

=pod

=over

=item C<get_field_id($fieldname)>

Description: Returns the ID of the specified field name and throws
             an error if this field does not exist.

Params:      $name - a field name

Returns:     the corresponding field ID or an error if the field name
             does not exist.

=back

=cut

sub get_field_id
{
    my ($name) = @_;
    trick_taint($name);
    my $field = Bugzilla->get_field($name);
    ThrowCodeError('invalid_field_name', { field => $name }) unless $field;
    return $field->id;
}

# Get choice value object for a bug or for a hashref with default value names
sub bug_or_hash_value
{
    my ($bug, $vf) = @_;
    my $value;
    if (blessed $bug)
    {
        $value = $bug->get_ids($vf->name);
    }
    else
    {
        $value = $bug->{$vf->name};
        if (!ref $value)
        {
            # FIXME: This does not allow selecting of fields
            # non-uniquely identified by name, as a visibility
            # controller field (for example, "component")
            $value = Bugzilla::Field::Choice->type($vf)->new({ name => $value });
        }
    }
    return $value;
}

# Shared between Bugzilla::Field and Bugzilla::Field::Choice
sub update_visibility_values
{
    my ($controlled_field, $controlled_value_id, $visibility_value_ids) = @_;
    $visibility_value_ids ||= [];
    my $vis_field = $controlled_value_id
        ? $controlled_field->value_field
        : $controlled_field->visibility_field;
    if (!$vis_field)
    {
        return undef;
    }
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $controlled_value_id = int($controlled_value_id);
    if (@$visibility_value_ids)
    {
        my $type = Bugzilla::Field::Choice->type($vis_field);
        $visibility_value_ids = [ map { $_->id } @{ $type->new_from_list($visibility_value_ids) } ];
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

sub update_controlled_values
{
    my ($controlled_field, $controlled_value_ids, $visibility_value_id, $default_value_ids) = @_;
    $controlled_value_ids ||= [];
    my $vis_field = $controlled_value_ids
        ? $controlled_field->value_field
        : $controlled_field->visibility_field;
    if (!$vis_field)
    {
        return undef;
    }
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $visibility_value_id = int($visibility_value_id);
    if ($visibility_value_id)
    {
        my $type = Bugzilla::Field::Choice->type($vis_field);
        $visibility_value_id = $type->new($visibility_value_id)->{id};
    }
    Bugzilla->dbh->do(
        "DELETE FROM fieldvaluecontrol WHERE field_id=? AND visibility_value_id=? AND value_id!=0",
        undef, $controlled_field->id, $visibility_value_id);
    if (@$controlled_value_ids)
    {
        my $type = Bugzilla::Field::Choice->type($controlled_field);
        $controlled_value_ids = [ map { $_->id } @{ $type->new_from_list($controlled_value_ids) } ];
        if ($default_value_ids)
        {
            my $type = Bugzilla::Field::Choice->type($controlled_field);
            $default_value_ids = { map { $_->id => 1 } @{ $type->new_from_list($default_value_ids) } };
        }
        my $f = $controlled_field->id;
        my $sql = "INSERT INTO fieldvaluecontrol (field_id, visibility_value_id, value_id, is_default) VALUES ".
            join(",", map { "($f, $visibility_value_id, $_, " . ($default_value_ids->{$_} ? '1' : '0') . ')' } @$controlled_value_ids);
        Bugzilla->dbh->do($sql);
    }
    # Touch the field
    $controlled_field->touch;
    return 1;
}

sub update_default_values
{
    my ($controlled_field, $visibility_value_id, $default_value_ids) = @_;
    $controlled_field = Bugzilla->get_field($controlled_field) if !ref $controlled_field;
    $visibility_value_id = int($visibility_value_id);
    $default_value_ids = [ map { int $_ } @$default_value_ids || (0) ];
    Bugzilla->dbh->do(
        'UPDATE fieldvaluecontrol SET is_default=(value_id IN ('.join(', ', @$default_value_ids).
        ')) WHERE field_id=? AND visibility_value_id=? AND value_id!=0',
        undef, $controlled_field->id, $visibility_value_id
    );
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
        nullable => $self->nullable ? 1 : 0,
        fields => {},
        values => {},
    };
    my $hash = Bugzilla->fieldvaluecontrol_hash->{$self->id};
    $data->{fields} = { map { Bugzilla->get_field($_)->name => $hash->{fields}->{$_} } keys %{$hash->{fields}} };
    $data->{values} = { map { Bugzilla->get_field($_)->name => $hash->{values}->{$_} } keys %{$hash->{values}} };
    return $data;
}

1;
__END__
