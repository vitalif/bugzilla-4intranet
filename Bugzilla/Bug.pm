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
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Dawn Endico    <endico@mozilla.org>
#                 Terry Weissman <terry@mozilla.org>
#                 Chris Yeh      <cyeh@bluemartini.com>
#                 Bradley Baetz  <bbaetz@acm.org>
#                 Dave Miller    <justdave@bugzilla.org>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Lance Larsh <lance.larsh@oracle.com>
#
# Deep refactoring by Vitaliy Filippov <vitalif@mail.ru> -- see http://wiki.4intra.net

package Bugzilla::Bug;

use utf8;
use strict;

use Bugzilla::Attachment;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Flag;
use Bugzilla::FlagType;
use Bugzilla::FlagType::UserList;
use Bugzilla::Hook;
use Bugzilla::Keyword;
use Bugzilla::Milestone;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Version;
use Bugzilla::Error;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Group;
use Bugzilla::Status;
use Bugzilla::Comment;

use List::Util qw(min);
use Storable qw(dclone);
use URI;
use URI::QueryParam;
use Date::Format qw(time2str);
use POSIX qw(floor);
use Scalar::Util qw(blessed);

use base qw(Bugzilla::Object Exporter);
@Bugzilla::Bug::EXPORT = qw(
    bug_alias_to_id
    RemoveVotes CheckIfVotedConfirmed
    LogActivityEntry
    editable_bug_fields
);
@Bugzilla::Bug::EXPORT_OK = @Bugzilla::Bug::EXPORT;

#####################################################################
# Constants
#####################################################################

use constant DB_TABLE   => 'bugs';
use constant ID_FIELD   => 'bug_id';
use constant NAME_FIELD => 'alias';
use constant LIST_ORDER => ID_FIELD;

# FIXME define NUMERIC_COLUMNS based on custom field types

sub DB_COLUMNS
{
    my $cache = Bugzilla->cache_fields;
    return @{$cache->{bug_columns}} if defined $cache->{bug_columns};

    my $dbh = Bugzilla->dbh;
    my @custom = grep {$_->type != FIELD_TYPE_MULTI_SELECT} Bugzilla->active_custom_fields;
    my @custom_names = map {$_->name} @custom;

    my @columns = (qw(
        alias
        assigned_to
        bug_file_loc
        bug_id
        bug_severity
        bug_status
        cclist_accessible
        component_id
        delta_ts
        estimated_time
        everconfirmed
        priority
        product_id
        qa_contact
        remaining_time
        reporter_accessible
        resolution
        short_desc
        status_whiteboard
        target_milestone
        version
    ),
    # FIXME kill op_sys and rep_platform completely, make them custom fields
    (Bugzilla->params->{useopsys} ? 'op_sys' : ()),
    (Bugzilla->params->{useplatform} ? 'rep_platform' : ()),
    'reporter AS reporter_id',
    $dbh->sql_date_format('creation_ts', '%Y.%m.%d %H:%i') . ' AS creation_ts',
    $dbh->sql_date_format('deadline', '%Y-%m-%d') . ' AS deadline',
    @custom_names);

    Bugzilla::Hook::process("bug_columns", { columns => \@columns });

    $cache->{bug_columns} = \@columns;
    return @columns;
}

use constant REQUIRED_CREATE_FIELDS => qw(
    component
    product
    short_desc
    version
);

our $CUSTOM_FIELD_VALIDATORS = {
    FIELD_TYPE_FREETEXT()       => \&_set_freetext_field,
    FIELD_TYPE_EXTURL()         => \&_set_freetext_field,
    FIELD_TYPE_SINGLE_SELECT()  => \&_set_select_field,
    FIELD_TYPE_MULTI_SELECT()   => \&_set_multi_select_field,
    FIELD_TYPE_TEXTAREA()       => \&_set_default_field,
    FIELD_TYPE_DATETIME()       => \&_set_datetime_field,
    FIELD_TYPE_BUG_ID()         => \&_set_bugid_field,
    FIELD_TYPE_BUG_URLS()       => \&_set_default_field,
    FIELD_TYPE_NUMERIC()        => \&_set_numeric_field,
};

sub SETTERS
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{bug_setters} if defined $cache->{bug_setters};

    my $s = {
        alias               => \&_set_alias,
        short_desc          => \&_set_short_desc,
        add_comment         => \&_set_add_comment,
        bug_file_loc        => \&_set_bug_file_loc,

        product             => \&_set_product,
        component           => \&_set_component,
        version             => \&_set_version,
        target_milestone    => \&_set_target_milestone,
        status_whiteboard   => \&_set_status_whiteboard,
        priority            => \&_set_priority,
        keywords            => \&_set_keywords,

        bug_status          => \&_set_bug_status,
        resolution          => \&_set_resolution,
        dup_id              => \&_set_dup_id,
        dependencies        => \&_set_dependencies,
        everconfirmed       => \&Bugzilla::Object::check_boolean,

        deadline            => \&_set_deadline,
        estimated_time      => \&_set_estimated_time,
        remaining_time      => \&_set_remaining_time,

        reporter            => \&_set_reporter,
        assigned_to         => \&_set_assigned_to,
        qa_contact          => \&_set_qa_contact,
        cc                  => \&_set_cc,
        groups              => \&_set_groups,
        reporter_accessible => \&Bugzilla::Object::check_boolean,
        cclist_accessible   => \&Bugzilla::Object::check_boolean,
    };

    # op_sys and rep_platform will get here if enabled
    for my $field (Bugzilla->get_fields({ obsolete => 0 }))
    {
        next if $s->{$field->name} || !$field->type;
        $s->{$field->name} = $CUSTOM_FIELD_VALIDATORS->{$field->type};
    }

    $cache->{bug_setters} = $s;
    return $cache->{bug_setters};
};

sub DEPENDENCIES
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{bug_field_deps} if defined $cache->{bug_field_deps};

    # Hard-coded field dependencies:
    my $deps = {
        component        => {},
        target_milestone => {},
        version          => {},
        bug_status       => { assigned_to => 1, add_comment => 1 },
        resolution       => { bug_status => 1 },
        dup_id           => { add_comment => 1 },
        # And in fact ALL fields depend on product because all
        # access control and strict_isolation checks apply to products
    };

    foreach my $field (Bugzilla->get_fields({ obsolete => 1 }))
    {
        # Product may have classification value_field, but it's not
        # stored in bugs table so we shouldn't check it
        next if $deps->{$field->name} || $field->name eq 'product';
        if ($field->visibility_field)
        {
            $deps->{$field->name}->{$field->visibility_field->name} = 1;
        }
        if ($field->value_field)
        {
            $deps->{$field->name}->{$field->value_field->name} = 1;
        }
    }

    $cache->{bug_field_deps} = $deps;
    return $cache->{bug_field_deps};
}

sub UPDATE_COLUMNS
{
    my @custom = grep { $_->type != FIELD_TYPE_MULTI_SELECT } Bugzilla->active_custom_fields;
    my @custom_names = map { $_->name } @custom;
    my @columns = qw(
        alias
        assigned_to
        bug_file_loc
        bug_severity
        bug_status
        cclist_accessible
        component_id
        deadline
        estimated_time
        everconfirmed
        priority
        product_id
        qa_contact
        remaining_time
        reporter_accessible
        resolution
        short_desc
        status_whiteboard
        target_milestone
        version
    );
    push @columns, 'op_sys' if Bugzilla->params->{useopsys};
    push @columns, 'rep_platform' if Bugzilla->params->{useplatform};
    push @columns, @custom_names;
    return @columns;
};

use constant NUMERIC_COLUMNS => qw(
    estimated_time
    remaining_time
);

sub DATE_COLUMNS
{
    my @fields = Bugzilla->get_fields({ custom => 1, type => FIELD_TYPE_DATETIME });
    return map { $_->name } @fields;
}

# This is used by add_comment to know what we validate before putting in
# the DB.
use constant UPDATE_COMMENT_COLUMNS => qw(
    thetext
    work_time
    type
    extra_data
    isprivate
);

# This maps the names of internal Bugzilla bug fields to things that would
# make sense to somebody who's not intimately familiar with the inner workings
# of Bugzilla. (These are the field names that the WebService and email_in.pl
# use.)
use constant FIELD_MAP => {
    creation_time    => 'creation_ts',
    description      => 'comment',
    id               => 'bug_id',
    last_change_time => 'delta_ts',
    platform         => 'rep_platform',
    severity         => 'bug_severity',
    status           => 'bug_status',
    summary          => 'short_desc',
    url              => 'bug_file_loc',
    whiteboard       => 'status_whiteboard',

    # These are special values for the WebService Bug.search method.
    limit            => 'LIMIT',
    offset           => 'OFFSET',
};

#####################################################################

sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my ($param, $return_error) = @_;

    # Remove leading "#" mark if we've just been passed an id.
    if (!ref $param && $param =~ /^#(\d+)$/)
    {
        $param = $1;
    }

    # If we get something that looks like a word (not a number),
    # make it the "name" param.
    if (!defined $param || (!ref $param && $param !~ /^\d+$/))
    {
        # But only if aliases are enabled.
        if (Bugzilla->params->{usebugaliases} && $param)
        {
            $param = { name => $param };
        }
        else
        {
            # Aliases are off, and we got something that's not a number.
            return { error => 'InvalidBugId', bug_id => $param } if $return_error;
            return undef;
        }
    }

    my $self = $class->SUPER::new($param);

    if (!$self && $return_error)
    {
        my $error = {};
        if (ref $param)
        {
            $error->{bug_id} = $param->{name};
            $error->{error}  = 'InvalidBugId';
        }
        else
        {
            $error->{bug_id} = $param;
            $error->{error}  = 'NotFound';
        }
        return $error;
    }

    return $self;
}

sub check
{
    my $class = shift;
    my ($id, $field) = @_;

    ThrowUserError('improper_bug_id_field_value', { field => $field }) unless defined $id;

    my $self = $class->new(trim($id), RETURN_ERROR);
    if ($self->{error})
    {
        $id = $self->{bug_id};
        if ($self->{error} eq 'NotFound')
        {
            ThrowUserError('bug_id_does_not_exist', { bug_id => $id });
        }
        if ($self->{error} eq 'InvalidBugId')
        {
            ThrowUserError('improper_bug_id_field_value', { bug_id => $id, field => $field });
        }
    }

    # FIXME Remove Bugzilla::Bug->check(, field) hardcode
    unless ($field && $field =~ /^(dependson|blocked|dup_id)$/)
    {
        $self->check_is_visible;
    }

    return $self;
}

sub check_is_visible
{
    my $self = shift;
    my $user = Bugzilla->user;

    if (!$user->can_see_bug($self->id))
    {
        # The error the user sees depends on whether or not they are
        # logged in (i.e. $user->id contains the user's positive integer ID).
        my $err_args = { bug_id => $self->id };
        if ($user->id)
        {
            if (Bugzilla->params->{unauth_bug_details})
            {
                $err_args->{product} = $self->product;
            }
            ThrowUserError('bug_access_denied', $err_args);
        }
        else
        {
            ThrowUserError('bug_access_query', $err_args);
        }
    }
}

# FIXME Bugzilla::Bug->match is only used in Bugzilla::WebService::Bug and should be replaced by Search
sub match
{
    my $class = shift;
    my ($params) = @_;

    # Allow matching certain fields by name (in addition to matching by ID).
    my %translate_fields = (
        assigned_to => 'Bugzilla::User',
        qa_contact  => 'Bugzilla::User',
        reporter    => 'Bugzilla::User',
        product     => 'Bugzilla::Product',
        component   => 'Bugzilla::Component',
    );
    my %translated;

    foreach my $field (keys %translate_fields)
    {
        my @ids;
        # Convert names to ids. We use "exists" everywhere since people can
        # legally specify "undef" to mean IS NULL (even though most of these
        # fields can't be NULL, people can still specify it...).
        if (exists $params->{$field})
        {
            my $names = $params->{$field};
            my $type = $translate_fields{$field};
            my $param = $type eq 'Bugzilla::User' ? 'login_name' : 'name';
            # We call Bugzilla::Object::match directly to avoid the
            # Bugzilla::User::match implementation which is different.
            my $objects = Bugzilla::Object::match($type, { $param => $names });
            push(@ids, map { $_->id } @$objects);
        }
        # You can also specify ids directly as arguments to this function,
        # so include them in the list if they have been specified.
        if (exists $params->{"${field}_id"})
        {
            my $current_ids = $params->{"${field}_id"};
            my @id_array = ref $current_ids ? @$current_ids : ($current_ids);
            push(@ids, @id_array);
        }
        # We do this "or" instead of a "scalar(@ids)" to handle the case
        # when people passed only invalid object names. Otherwise we'd
        # end up with a SUPER::match call with zero criteria (which dies).
        if (exists $params->{$field} or exists $params->{"${field}_id"})
        {
            $translated{$field} = scalar(@ids) == 1 ? $ids[0] : \@ids;
        }
    }

    # The user fields don't have an _id on the end of them in the database,
    # but the product & component fields do, so we have to have separate
    # code to deal with the different sets of fields here.
    foreach my $field (qw(assigned_to qa_contact reporter))
    {
        delete $params->{"${field}_id"};
        $params->{$field} = $translated{$field} if exists $translated{$field};
    }
    foreach my $field (qw(product component))
    {
        delete $params->{$field};
        $params->{"${field}_id"} = $translated{$field} if exists $translated{$field};
    }

    return $class->SUPER::match(@_);
}

# Docs for create() (there's no POD in this file yet, but we very
# much need this documented right now):
#
# The same as Bugzilla::Object->create. Parameters are only required
# if they say so below.
#
# Params:
#
# C<product>     - B<Required> The name of the product this bug is being
#                  filed against.
# C<component>   - B<Required> The name of the component this bug is being
#                  filed against.
#
# C<bug_severity> - B<Required> The severity for the bug, a string.
# C<creation_ts>  - B<Required> A SQL timestamp for when the bug was created.
# C<short_desc>   - B<Required> A summary for the bug.
# C<op_sys>       - The OS the bug was found against.
# C<priority>     - B<Required> The initial priority for the bug.
# C<rep_platform> - The platform the bug was found against.
# C<version>      - B<Required> The version of the product the bug was found in.
#
# C<alias>        - An alias for this bug. Will be ignored if C<usebugaliases>
#                   is off.
# C<target_milestone> - When this bug is expected to be fixed.
# C<status_whiteboard> - A string.
# C<bug_status>   - The initial status of the bug, a string.
# C<bug_file_loc> - The URL field.
#
# C<assigned_to> - The full login name of the user who the bug is
#                  initially assigned to.
# C<qa_contact>  - The full login name of the QA Contact for this bug.
#                  Will be ignored if C<useqacontact> is off.
#
# C<estimated_time> - For time-tracking. Will be ignored if
#                     C<timetrackinggroup> is not set, or if the current
#                     user is not a member of the timetrackinggroup.
# C<work_time>      - For time-tracking. Will be ignored for the same
#                     reasons as C<estimated_time>.
# C<deadline>       - For time-tracking. Will be ignored for the same
#                     reasons as C<estimated_time>.
sub create
{
    die "Unsupported old interface";
}

# Check values of dependent fields
sub check_dependent_fields
{
    my $self = shift;
    my $incorrect_fields = {};

    # Run checks in a correct order
    my %seen = ();
    my @check = map { field_with_deps($_->name, DEPENDENCIES(), \%seen) } Bugzilla->get_fields({ obsolete => 0 });

    for my $fn (@check)
    {
        my $field_obj = Bugzilla->get_field($fn);
        # Check field visibility
        if (!$field_obj->check_visibility($self))
        {
            # Field is invisible, clear value
            $self->set($fn, undef);
            next;
        }
        # Optionally add the value of BUG_ID custom field to dependencies (CustIS Bug 73054, Bug 75690)
        # This allows to see it as a part of the dependency tree
        if ($field_obj->add_to_deps && $self->{$fn} && $self->{$fn} != $self->id)
        {
            my $blk = $field_obj->add_to_deps == BUG_ID_ADD_TO_BLOCKED;
            my $to = $blk ? 'blocked' : 'dependson';
            # Get the dependencies from DB
            if (!$self->{dependency_closure})
            {
                $self->{dependency_closure} = ValidateDependencies($self, [ $self->id ], [ $self->id ]);
            }
            # Add the bug if it isn't already in the dependency tree
            if (!$self->{dependency_closure}->{blocked}->{$value} &&
                !$self->{dependency_closure}->{dependson}->{$value})
            {
                push @{$self->{$to}}, $value;
            }
        }
        # Check dependent field values
        if ($field_obj->value_field_id)
        {
            # $self->{_unknown_dependent_values} may contain names of unidentified values
            my $value_objs = $self->{_unknown_dependent_values}->{$fn} || $self->{$fn.'_obj'};
            $value_objs = [ $value_objs ] if ref $value_objs ne 'ARRAY';
            my @bad = grep { !ref $_ || !$_->check_visibility($self) } @$value_objs;
            if (@bad)
            {
                my $n = $field_obj->value_field->name;
                $incorrect_fields->{$fn} = {
                    field => $field_obj,
                    options => [ map { $_->name } @{ $field_obj->restricted_legal_values($self->$n) } ],
                    values => [ map { ref $_ ? $_ : undef } @bad ],
                    value_names => [ map { ref $_ ? $_ : $_->name } @bad ],
                    controller => $controller,
                };
            }
        }
    }

    delete $self->{_unknown_dependent_values};

    # When moving bugs between products, verify groups
    my $verify_bug_groups = undef;
    if ($self->id && $self->{_old_self}->product_id != $self->product_id)
    {
        # FIXME Do not call CGI from Bugzilla::Bug!
        if (!Bugzilla->cgi->param('verify_bug_groups') &&
            Bugzilla->cgi->param('id'))
        {
            # Display group verification message only for single bug changes
            # Get the ID of groups which are no longer valid in the new product.
            my $gids = Bugzilla->dbh->selectcol_arrayref(
                'SELECT bgm.group_id FROM bug_group_map AS bgm'.
                ' WHERE bgm.bug_id=? AND bgm.group_id NOT IN ('.
                '  SELECT gcm.group_id FROM group_control_map AS gcm'.
                '  WHERE gcm.product_id = ? AND ((gcm.membercontrol != ?'.
                '   AND gcm.group_id IN ('.Bugzilla->user->groups_as_string.')) OR gcm.othercontrol != ?)'.
                ' )',
                undef, $self->id, $self->product_obj->id, CONTROLMAPNA, CONTROLMAPNA);
            $verify_bug_groups = Bugzilla::Group->new_from_list($gids);
        }

        # Remove groups that aren't valid in the new product. This will also
        # have the side effect of removing the bug from groups that aren't
        # active anymore.
        #
        # We copy this array because the original array is modified while we're
        # working, and that confuses "foreach".
        foreach my $group (@{$self->groups_in})
        {
            if (!grep($group->id == $_->id, @{$self->product_obj->groups_valid}))
            {
                $params->remove_group($group);
            }
        }

        # Make sure the bug is in all the mandatory groups for the new product.
        foreach my $group (@{$self->product_obj->groups_mandatory_for(Bugzilla->user)})
        {
            $params->add_group($group);
        }
    }

    # If we're not in browser or this is a new bug, throw an error
    if ((Bugzilla->usage_mode != USAGE_MODE_BROWSER || !$self->id) && %$incorrect_fields)
    {
        ThrowUserError('incorrect_field_values', {
            bug_id           => $self->id,
            incorrect_fields => [ values %$incorrect_fields ],
        });
    }

    # Else display UI for value checking
    if (Bugzilla->usage_mode == USAGE_MODE_BROWSER && (%$incorrect_fields || $verify_bug_groups) && $self->id)
    {
        Bugzilla->template->process('bug/process/verify-field-values.html.tmpl', {
            product => $verify_bug_groups && $self->product_obj,
            old_groups => $verify_bug_groups,
            verify_bug_groups => $verify_bug_groups && 1,
            incorrect_fields => [ values %$incorrect_fields ],
            incorrect_field_descs => [ map { $_->{field}->description } values %$incorrect_fields ],
            exclude_params_re => '^(' . join('|', keys %$incorrect_fields) . ')$',
        });
        Bugzilla->dbh->rollback;
        exit;
    }
}

sub update
{
    my $self = shift;

    my $method = $self->id ? 'update' : 'create';

    # First check dependent field values
    $self->check_dependent_fields;
    $self->check_strict_isolation;

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    # FIXME 'shift ||' is just a temporary hack until all updating happens inside this function
    my $delta_ts = shift || $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    Bugzilla::Hook::process("bug_pre_$method", { bug => $self });

    my $old_bug = $self->{_old_self};
    my $changes;

    # You can't set these fields by hand
    $self->{delta_ts} = $delta_ts;
    delete $params->{votes};
    delete $params->{lastdiffed};

    if ($self->id)
    {
        ($changes, $old_bug) = $self->SUPER::update(@_);
    }
    else
    {
        $self->{bug_severity} = Bugzilla->params->{defaultseverity} if !$self->{bug_severity};
        $self->{priority} = Bugzilla->params->{defaultpriority}     if !$self->{priority};
        $self->{op_sys} = Bugzilla->params->{defaultopsys}          if Bugzilla->params->{useopsys} && !$self->{op_sys};
        $self->{rep_platform} = Bugzilla->params->{defaultplatform} if Bugzilla->params->{useplatform} && !$self->{rep_platform};
        $self->{everconfirmed} ||= 0;
        $self->set('reporter', undef);
        $self->{creation_ts} = $delta_ts;

        $params->{comment} = '' unless defined $params->{comment};
        $self->{work_time} = $class->_check_time($params->{work_time}, 'work_time');

        $changes = [];
        my $row = {};
        for my $f ($self->DB_COLUMNS)
        {
            $row->{$f} = $self->{$f};
        }
        $dbh->do(
            'INSERT INTO '.$self->DB_TABLE.' (' . join(', ', keys %$row) .
            ') VALUES ('.join(', ', ('?') x keys %$row).")", undef, values %$row
        );
        $self->{$self->ID_FIELD} = $dbh->bz_last_key($self->DB_TABLE, $self->ID_FIELD);
    }

    # Transform ID values to names (for the activity log)
    if ($changes->{product_id})
    {
        $changes->{product} = [ $old_bug->product_obj->name, $self->product_obj->name ];
        delete $changes->{product_id};
    }
    if ($changes->{component_id})
    {
        $changes->{component} = [ $old_bug->component_obj->name, $self->component_obj->name ];
        delete $changes->{component_id};
    }
    for my $f (Bugzilla->get_fields({ type => FIELD_TYPE_SINGLE_SELECT }))
    {
        my $name = $f->name;
        next if $name eq 'product' || $name eq 'component' || $name eq 'classification' || !$changes->{$name};
        $changes->{$name}->[0] = $f->new_choice($changes->{$name}->[0])->name if $changes->{$name}->[0];
        $changes->{$name}->[1] = $f->new_choice($changes->{$name}->[1])->name if $changes->{$name}->[1];
    }
    # Transform user fields to names + add previous values to CC list
    foreach my $field (qw(qa_contact assigned_to))
    {
        if ($changes->{$field})
        {
            my ($from, $to) = @{ $changes->{$field} };
            if ($from)
            {
                $from = $old_bug->$field->login;
                $self->add_cc($from);
            }
            if ($to)
            {
                $to = $self->$field->login;
            }
            $changes->{$field} = [ $from, $to ];
        }
    }

    # Add/remove CC
    my @old_cc = $old_bug ? (map { $_->id } @{$old_bug->cc_users}) : ();
    my @new_cc = @{$self->cc_users};

    # CustIS Bug 38616 - CC list restriction
    # FIXME Use strict_isolation
    if ($self->product_obj->cc_group)
    {
        $self->{restricted_cc} = $self->product_obj->restrict_cc(\@new_cc);
    }

    @new_cc = map { $_->id } @new_cc;
    my ($removed_cc, $added_cc) = diff_arrays(\@old_cc, \@new_cc);

    if (scalar @$removed_cc)
    {
        $dbh->do('DELETE FROM cc WHERE bug_id = ? AND '.$dbh->sql_in('who', $removed_cc), undef, $self->id);
    }
    foreach my $user_id (@$added_cc)
    {
        $dbh->do('INSERT INTO cc (bug_id, who) VALUES (?,?)', undef, $self->id, $user_id);
    }

    # Remember changes to log them in activity table
    if (scalar @$removed_cc || scalar @$added_cc)
    {
        my $removed_users = Bugzilla::User->new_from_list($removed_cc);
        my $added_users   = Bugzilla::User->new_from_list($added_cc);
        my $removed_names = join(', ', (map { $_->login } @$removed_users));
        my $added_names   = join(', ', (map { $_->login } @$added_users));
        $changes->{cc} = [ $removed_names, $added_names ];
    }

    # Keywords
    my @old_kw_ids = $old_bug ? (map { $_->id } @{$old_bug->keyword_objects}) : ();
    my @new_kw_ids = map { $_->id } @{$self->keyword_objects};
    my ($removed_kw, $added_kw) = diff_arrays(\@old_kw_ids, \@new_kw_ids);
    if (scalar @$removed_kw)
    {
        $dbh->do('DELETE FROM keywords WHERE bug_id = ? AND ' . $dbh->sql_in('keywordid', $removed_kw), undef, $self->id);
    }
    foreach my $keyword_id (@$added_kw)
    {
        $dbh->do('INSERT INTO keywords (bug_id, keywordid) VALUES (?,?)', undef, $self->id, $keyword_id);
    }
    $dbh->do('UPDATE bugs SET keywords = ? WHERE bug_id = ?', undef, $self->keywords, $self->id);

    # Remember changes to log them in activity table
    if (scalar @$removed_kw || scalar @$added_kw)
    {
        my $removed_keywords = Bugzilla::Keyword->new_from_list($removed_kw);
        my $added_keywords   = Bugzilla::Keyword->new_from_list($added_kw);
        my $removed_names = join(', ', (map { $_->name } @$removed_keywords));
        my $added_names   = join(', ', (map { $_->name } @$added_keywords));
        $changes->{keywords} = [ $removed_names, $added_names ];
    }

    # Dependencies
    foreach my $pair ([qw(dependson blocked)], [qw(blocked dependson)])
    {
        my ($type, $other) = @$pair;
        my $old = $old_bug ? $old_bug->$type : [];
        my $new = $self->$type;

        my ($removed, $added) = diff_arrays($old, $new);
        foreach my $removed_id (@$removed)
        {
            $dbh->do("DELETE FROM dependencies WHERE $type = ? AND $other = ?", undef, $removed_id, $self->id);
            # Add an activity entry for the other bug.
            LogActivityEntry($removed_id, $other, $self->id, '', $user->id, $delta_ts);
            # Update delta_ts on the other bug so that we trigger mid-airs.
            $dbh->do('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?', undef, $delta_ts, $removed_id);
        }
        foreach my $added_id (@$added)
        {
            $dbh->do("INSERT INTO dependencies ($type, $other) VALUES (?,?)", undef, $added_id, $self->id);
            # Add an activity entry for the other bug.
            LogActivityEntry($added_id, $other, '', $self->id, $user->id, $delta_ts);
            # Update delta_ts on the other bug so that we trigger mid-airs.
            $dbh->do('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?', undef, $delta_ts, $added_id);
        }

        if (scalar(@$removed) || scalar(@$added))
        {
            $changes->{$type} = [join(', ', @$removed), join(', ', @$added)];
        }
    }

    # Groups
    my %old_groups = $old_bug ? (map { $_->id => $_ } @{$old_bug->groups_in}) : ();
    my %new_groups = map { $_->id => $_ } @{$self->groups_in};
    my ($removed_gr, $added_gr) = diff_arrays([keys %old_groups], [keys %new_groups]);
    if (scalar @$removed_gr || scalar @$added_gr)
    {
        if (@$removed_gr)
        {
            my $qmarks = join(',', ('?') x @$removed_gr);
            $dbh->do("DELETE FROM bug_group_map WHERE bug_id = ? AND group_id IN ($qmarks)", undef, $self->id, @$removed_gr);
        }
        my $sth_insert = $dbh->prepare('INSERT INTO bug_group_map (bug_id, group_id) VALUES (?,?)');
        foreach my $gid (@$added_gr)
        {
            $sth_insert->execute($self->id, $gid);
        }
        my @removed_names = map { $old_groups{$_}->name } @$removed_gr;
        my @added_names   = map { $new_groups{$_}->name } @$added_gr;
        $changes->{bug_group} = [join(', ', @removed_names), join(', ', @added_names)];
    }

    # Flags
    my ($removed, $added) = Bugzilla::Flag->update_flags($self, $old_bug, $delta_ts);
    if ($removed || $added)
    {
        $changes->{'flagtypes.name'} = [$removed, $added];
    }

    # Comments
    foreach my $comment (@{$self->{added_comments} || []})
    {
        if (Bugzilla->cgi->param('commentsilent'))
        {
            # Log silent comments
            SilentLog($self->bug_id, $comment->{thetext});
        }
        $comment->{bug_id} = $self->bug_id;
        $comment->{who} ||= $user->id;
        $comment->{bug_when} = $delta_ts if !$comment->{bug_when} || $comment->{bug_when} gt $delta_ts;
        my $columns = join(',', keys %$comment);
        my @values = values %$comment;
        my $qmarks = join(',', ('?') x @values);
        $dbh->do("INSERT INTO longdescs ($columns) VALUES ($qmarks)", undef, @values);
        if (0+$comment->{work_time} != 0)
        {
            # Log worktime
            $changes->{work_time} ||= [ '', 0 ];
            $changes->{work_time}->[1] += $comment->{work_time};
        }
    }

    # FIXME Merge next two loops
    foreach my $comment_id (keys %{$self->{comment_isprivate} || {}})
    {
        $dbh->do(
            "UPDATE longdescs SET isprivate = ? WHERE comment_id = ?",
            undef, $self->{comment_isprivate}->{$comment_id}, $comment_id
        );
        # FIXME It'd be nice to track this in the bug activity.
    }

    foreach my $comment_id (keys %{$self->{comment_type} || {}})
    {
        $dbh->do(
            "UPDATE longdescs SET type = ? WHERE comment_id = ?",
            undef, $self->{comment_type}->{$comment_id}, $comment_id
        );
        # FIXME It'd be nice to track this in the bug activity.
    }

    # Save changed comments
    foreach my $edited_comment (@{$self->{edited_comments} || []})
    {
        my $c_comment = Bugzilla::Comment->new($edited_comment->{comment_id});
        if (!$c_comment->is_private || $user->is_insider)
        {
            $dbh->do(
                "UPDATE longdescs SET thetext = ? WHERE comment_id = ?",
                undef, $edited_comment->{thetext}, $edited_comment->{comment_id}
            );
            $edited_comment->{bug_id} = $self->bug_id;
            $edited_comment->{who} = $user->id;
            $edited_comment->{bug_when} = $delta_ts;
            # number count of the comment
            my ($comment_count) = Bugzilla->dbh->selectrow_array(
                'SELECT count(*) FROM longdescs WHERE bug_id = ? AND comment_id <= ? ORDER BY bug_when ASC',
                undef, $self->id, $edited_comment->{comment_id}
            );
            $edited_comment->{comment_count} = ($comment_count-1);
            my $columns = join(',', keys %$edited_comment);
            my @values  = values %$edited_comment;
            my $qmarks  = join(',', ('?') x @values);
            $dbh->do("INSERT INTO longdescs_history ($columns) VALUES ($qmarks)", undef, @values);
        }
    }

    # Insert the values into the multiselect value tables
    my @multi_selects = grep { $_->type == FIELD_TYPE_MULTI_SELECT } Bugzilla->active_custom_fields;
    foreach my $field (@multi_selects)
    {
        my $name = $field->name;
        my ($removed, $added) = diff_arrays($old_bug ? $old_bug->$name : [], $self->$name);
        if (scalar @$removed || scalar @$added)
        {
            $changes->{$name} = [
                join(', ', map { $_->name } @{$field->value_type->new_from_list($removed)}),
                join(', ', map { $_->name } @{$field->value_type->new_from_list($added)})
            ];
            $dbh->do("DELETE FROM bug_$name where bug_id = ?", undef, $self->id);
            if (@{$self->$name})
            {
                $dbh->do(
                    "INSERT INTO bug_$name (bug_id, value_id) VALUES ".
                    join(',', ('(?, ?)') x @{$self->$name}),
                    undef, map { ($self->bug_id, $_) } @{$self->$name}
                );
            }
        }
    }

    # See Also
    my ($removed_see, $added_see) = diff_arrays($old_bug ? $old_bug->see_also : [], $self->see_also);
    if (scalar @$removed_see)
    {
        $dbh->do(
            'DELETE FROM bug_see_also WHERE bug_id = ? AND '
            . $dbh->sql_in('value', [('?') x @$removed_see]),
            undef, $self->id, @$removed_see
        );
    }
    foreach my $url (@$added_see)
    {
        $dbh->do('INSERT INTO bug_see_also (bug_id, value) VALUES (?, ?)', undef, $self->id, $url);
    }
    if (scalar @$removed_see || scalar @$added_see)
    {
        $changes->{see_also} = [ join(', ', @$removed_see), join(', ', @$added_see) ];
    }

    # Log bugs_activity items
    # FIXME Also track dupe_id here (see below)
    foreach my $field (keys %$changes)
    {
        my $change = $changes->{$field};
        my $from = defined $change->[0] ? $change->[0] : '';
        my $to   = defined $change->[1] ? $change->[1] : '';
        LogActivityEntry($self->id, $field, $from, $to, Bugzilla->user->id, $delta_ts);
    }

    # Check if we have to update the duplicates table and the other bug.
    my ($old_dup, $cur_dup) = ($old_bug ? $old_bug->dup_id || 0 : 0, $self->dup_id || 0);
    if ($old_dup != $cur_dup)
    {
        $dbh->do("DELETE FROM duplicates WHERE dupe = ?", undef, $self->id);
        if ($cur_dup)
        {
            $dbh->do('INSERT INTO duplicates (dupe, dupe_of) VALUES (?, ?)', undef, $self->id, $cur_dup);
            if (my $update_dup = delete $self->{_dup_for_update})
            {
                $update_dup->update();
            }
        }
        $changes->{dup_id} = [$old_dup || undef, $cur_dup || undef];
    }

    Bugzilla::Hook::process("bug_end_of_$method", {
        bug => $self,
        timestamp => $delta_ts,
        changes => $changes,
        old_bug => $old_bug,
    });

    # The only problem with this here is that update() is often called
    # in the middle of a transaction, and if that transaction is rolled
    # back, this change will *not* be rolled back. As we expect rollbacks
    # to be extremely rare, that is OK for us.
    if ($self->{added_comments} || $changes->{short_desc} ||
        $self->{comment_isprivate} || $self->{edited_comments})
    {
        $self->_sync_fulltext($method eq 'create');
    }

    # Remove obsolete internal variables.
    delete $self->{_old_self};
    delete $self->{added_comments};
    delete $self->{edited_comments};

    # Also flush the visible_bugs cache for this bug as the user's
    # relationship with this bug may have changed.
    delete Bugzilla->user->{_visible_bugs_cache}->{$self->id};

    return $changes;
}

# Check strict isolation for $self:
# Throw an error when trying to modify bug in such way that someone of
# its reporter/assignee/QA/CC are not permitted to see its product.
# We always check all users, so in theory some bugs may become "blocked"
# for further modifications if their reporter can't see the product.
# It is intended to work like that.
sub check_strict_isolation
{
    my $self = shift;

    # CustIS Bug 38616 - CC list restriction
    my $ccg = $self->product_obj->cc_group;
    if ($ccg)
    {
        for (qw(assigned_to reporter qa_contact))
        {
            if ($self->$_ && !$self->$_->in_group($ccg))
            {
                ThrowUserError('cc_group_restriction', { user => $self->$_->login });
            }
        }
    }

    return unless Bugzilla->params->{strict_isolation};

    my $old = $self->{_old_self};

    my %related_users;
    $related_users{$_->id} = $_ for @{$self->cc_users};

    for (qw(assigned_to reporter qa_contact))
    {
        if ($self->$_)
        {
            $related_users->{$self->$_->id} ||= $self->$_;
        }
    }

    my @blocked_users;
    my $product = $self->product_obj;
    foreach my $related_user (values %related_users)
    {
        if (!$related_user->can_see_product($product->name))
        {
            push @blocked_users, $related_user->login;
        }
    }
    if (@blocked_users)
    {
        my %vars = (
            users   => \@blocked_users,
            product => $product->name,
        );
        if ($self->id)
        {
            $vars{bug_id} = $self->id;
        }
        else
        {
            $vars{new} = 1;
        }
        ThrowUserError("invalid_user_group", \%vars);
    }
}

# Should be called any time you update short_desc or change a comment.
sub _sync_fulltext
{
    my ($self, $new_bug) = @_;
    my $dbh = Bugzilla->dbh;
    my ($short_desc) = $dbh->selectrow_array(
        "SELECT short_desc FROM bugs WHERE bug_id=?", undef, $self->id
    );
    my ($nopriv, $priv) = ([], []);
    for (@{ $dbh->selectall_arrayref(
        "SELECT thetext, isprivate FROM longdescs WHERE bug_id=?",
        undef, $self->id
    ) || [] })
    {
        $_->[1] ? push @$priv, $_->[0] : push @$nopriv, $_->[0];
    }
    $nopriv = join "\n", @$nopriv;
    $priv = join "\n", @$priv;
    my $row = [ $short_desc, $nopriv, $priv ];
    # Determine if we are using Sphinx or MySQL fulltext search
    my ($sph, $id_field);
    my $index = Bugzilla->localconfig->{sphinx_index};
    my $table = $index;
    if ($index)
    {
        $sph = Bugzilla->dbh_sphinx;
        return unless $sph; # Do not die if Sphinx is restarting...
        $id_field = 'id';
        $_ = $sph->quote($_) for @$row;
    }
    else
    {
        $table = 'bugs_fulltext';
        $sph = $dbh;
        $id_field = 'bug_id';
        $_ = $dbh->quote_fulltext($_) for @$row;
    }
    my $sql;
    if ($new_bug || $index)
    {
        $sql = ($index ? 'REPLACE' : 'INSERT')." INTO $table ($id_field, short_desc, comments, comments_private)".
            " VALUES (".join(',', $self->id, @$row).")";
    }
    else
    {
        $sql = "UPDATE $table SET short_desc=$row->[0],".
            " comments=$row->[1], comments_private=$row->[2] WHERE $id_field=".$self->id;
    }
    return $sph->do($sql);
}

# This is the correct way to delete bugs from the DB.
# No bug should be deleted from anywhere else except from here.
sub remove_from_db
{
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;

    my $bug_id = $self->{bug_id};

    # tables having 'bugs.bug_id' as a foreign key:
    # - attachments
    # - bug_group_map
    # - bugs
    # - bugs_activity
    # - bugs_fulltext
    # - cc
    # - dependencies
    # - duplicates
    # - flags
    # - keywords
    # - longdescs
    # - votes

    # Also, the attach_data table uses attachments.attach_id as a foreign
    # key, and so indirectly depends on a bug deletion too.

    $dbh->bz_start_transaction();

    $dbh->do("DELETE FROM bug_group_map WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM bugs_activity WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM cc WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM dependencies WHERE blocked = ? OR dependson = ?", undef, ($bug_id, $bug_id));
    $dbh->do("DELETE FROM duplicates WHERE dupe = ? OR dupe_of = ?", undef, ($bug_id, $bug_id));
    $dbh->do("DELETE FROM flags WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM keywords WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM votes WHERE bug_id = ?", undef, $bug_id);

    # The attach_data table doesn't depend on bugs.bug_id directly.
    my $attach_ids = $dbh->selectcol_arrayref("SELECT attach_id FROM attachments WHERE bug_id = ?", undef, $bug_id);

    if (scalar(@$attach_ids))
    {
        $dbh->do("DELETE FROM attach_data WHERE ".$dbh->sql_in('id', $attach_ids));
    }

    # Several of the previous tables also depend on attach_id.
    $dbh->do("DELETE FROM attachments WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM bugs WHERE bug_id = ?", undef, $bug_id);
    $dbh->do("DELETE FROM longdescs WHERE bug_id = ?", undef, $bug_id);

    $dbh->bz_commit_transaction();

    # The bugs_fulltext table doesn't support transactions.
    $dbh->do("DELETE FROM bugs_fulltext WHERE bug_id = ?", undef, $bug_id);

    # Now this bug no longer exists
    $self->DESTROY;
    return $self;
}

#####################################################################
# Validators/setters
#####################################################################

sub set
{
    my ($self, $field, $value) = @_;
    if (my $setter = SETTERS->{$field})
    {
        if ($self->id && !$self->{_dirty})
        {
            $self->{_old_self} = bless { %$self }, 'Bugzilla::Bug';
            $self->{_dirty} = 1;
        }
        $value = $self->$setter($value, $field);
        $self->{$field} = $value if defined $value;
        return $value;
    }
    return undef;
}

sub field_with_deps
{
    my ($field, $deps, $seen) = @_;
    if (!$seen->{$field})
    {
        $seen->{$field} = 1;
        return ((map { field_with_deps($_, $deps, $seen) } @{$deps->{$field} || []}), $field);
    }
    return ();
}

# Set all field values from $params, in the correct order
sub set_all
{
    my ($self, $params) = @_;
    my %seen = (product => 1);
    my @set = map { field_with_deps($_, DEPENDENCIES(), \%seen) } keys %$params;
    # First set product because basically ALL other fields depend on it
    unshift @set, 'product' if !$self->product || $params->{product};
    for my $field (@set)
    {
        $self->set($field, $params->{$field});
    }
}

sub _set_alias
{
    my ($self, $alias) = @_;
    $alias = trim($alias);
    return undef if !Bugzilla->params->{usebugaliases} || !$alias;

    # Make sure the alias isn't too long.
    if (length($alias) > 20)
    {
        ThrowUserError('alias_too_long');
    }
    # Make sure the alias isn't just a number.
    if ($alias =~ /^\d+$/)
    {
        ThrowUserError('alias_is_numeric', { alias => $alias });
    }
    # Make sure the alias has no commas or spaces.
    if ($alias =~ /[, ]/)
    {
        ThrowUserError('alias_has_comma_or_space', { alias => $alias });
    }
    # Make sure the alias is unique, or that it's already our alias.
    my $other_bug = new Bugzilla::Bug($alias);
    if ($other_bug && (!ref $invocant || $other_bug->id != $invocant->id))
    {
        ThrowUserError('alias_in_use', { alias => $alias, bug_id => $other_bug->id });
    }

    return $alias;
}

sub _set_assigned_to
{
    my ($self, $assignee) = @_;

    my $user = Bugzilla->user;
    my $component = $self->component;

    my $is_new = !$self->id;
    if ($is_new && (!$user->in_group('editbugs', $component->product_id) || !$assignee))
    {
        # If this is a new bug, you can only set the assignee if you have editbugs.
        # If you didn't specify the assignee, we use the default assignee.
        $self->{assigned_to_obj} = $component->default_assignee;
    }
    else
    {
        if (!ref $assignee)
        {
            $assignee = trim($assignee);
            # When updating a bug, assigned_to can't be empty.
            ThrowUserError('reassign_to_empty') if !$is_new && !$assignee;
            $assignee = Bugzilla::User->check($assignee);
        }
        $self->{assigned_to_obj} = $assignee;
    }

    return $self->{assigned_to_obj}->id;
}

sub _set_bug_file_loc
{
    my ($self, $url) = @_;
    $url = '' if !defined($url);
    # If bug_file_loc is "http://", the default, use an empty value instead.
    if ($url eq 'http://')
    {
        $url = '';
    }
    return $url;
}

# TODO bug_status должен зависеть сам от себя и валидироваться стандартным методом
sub _set_bug_status
{
    my ($self, $new_status) = @_;
    my $user = Bugzilla->user;
    my @valid_statuses;
    my $old_status = $self->status;

    if ($self->id)
    {
        @valid_statuses = @{$self->statuses_available};
    }
    else
    {
        @valid_statuses = @{Bugzilla::Status->can_change_to()};
        if (!$product->allows_unconfirmed)
        {
            @valid_statuses = grep { $_->name ne 'UNCONFIRMED' } @valid_statuses;
        }
    }
    my $comment = $self->{added_comments} || [];
    $comment = $comment->[-1];
    my $product = $self->product_obj;

    if ($self->{assigned_to} && $user->id != $self->{assigned_to})
    {
        # You can not assign bugs to other people
        @valid_statuses = grep { $_->name ne 'ASSIGNED' } @valid_statuses;
    }

    # Check permissions for users filing new bugs.
    if (!$self->{id})
    {
        if ($user->in_group('editbugs', $product->id)
            || $user->in_group('canconfirm', $product->id))
        {
            # If the user with privs hasn't selected another status,
            # select the first one of the list.
            unless ($new_status)
            {
                if (scalar(@valid_statuses) == 1)
                {
                    $new_status = $valid_statuses[0];
                }
                else
                {
                    $new_status = ($valid_statuses[0]->name ne 'UNCONFIRMED') ? $valid_statuses[0] : $valid_statuses[1];
                }
            }
        }
        else
        {
            # A user with no privs cannot choose the initial status.
            # If UNCONFIRMED is valid for this product, use it; else
            # use the first bug status available.
            if (grep { $_->name eq 'UNCONFIRMED' } @valid_statuses)
            {
                $new_status = 'UNCONFIRMED';
            }
            else
            {
                $new_status = $valid_statuses[0];
            }
        }
    }

    # Time to validate the bug status.
    $new_status = Bugzilla::Status->check($new_status) unless ref($new_status);
    # We skip this check if we are changing from a status to itself.
    if ((!$old_status || $old_status->id != $new_status->id)
        && !grep {$_->name eq $new_status->name} @valid_statuses)
    {
        ThrowUserError('illegal_bug_status_transition', { old => $old_status, new => $new_status });
    }

    # Check if a comment is required for this change.
    if ($new_status->comment_required_on_change_from($old_status) && !$comment)
    {
        ThrowUserError('comment_required', { old => $old_status, new => $new_status });
    }

    if ($self->id && $new_status->name eq 'ASSIGNED'
        && Bugzilla->params->{usetargetmilestone}
        && Bugzilla->params->{musthavemilestoneonaccept}
        # musthavemilestoneonaccept applies only if at least two
        # target milestones are defined for the product.
        && scalar(@{ $product->milestones }) > 1
        && $invocant->target_milestone eq $product->default_milestone)
    {
        ThrowUserError('milestone_required', { bug => $invocant });
    }

    $self->{status} = $new_status;
    delete $self->{statuses_available};

    if ($new_status->is_open)
    {
        # Check for the everconfirmed transition
        $self->set('everconfirmed', $new_status->name eq 'UNCONFIRMED' ? 0 : 1);
        $self->set('resolution', undef);
    }
    else
    {
        # Changing between closed statuses zeros the remaining time.
        if ($new_status->id != $old_status->id && $self->remaining_time != 0)
        {
            $self->set('remaining_time', 0);
        }
    }

    return $new_status->id;
}

sub _set_cc
{
    my ($self, $ccs) = @_;
    return [ map { $_->id } @{$self->component->initial_cc} ] unless $ccs;

    # Allow comma-separated input as well as arrayrefs.
    $ccs = [ split /[\s,]+/, $ccs ] if !ref $ccs;

    # CustIS Bug 38616
    # FIXME use strict_isolation
    my %cc_ids;
    my $ccg = $self->product->cc_group;
    foreach my $person (@$ccs)
    {
        next unless $person;
        my $id = login_to_id($person, THROW_ERROR);
        my $user = Bugzilla::User->new($id);
        next if $ccg && !$user->in_group($ccg);
        $cc_ids{$id} = 1;
    }

    # CustIS Bug 55095: Don't enforce default CC
    ## Enforce Default CC
    #$cc_ids{$_->id} = 1 foreach (@{$component->initial_cc});

    return [ keys %cc_ids ];
}

# $bug->set('add_comment', { thetext => '', work_time => 0, isprivate => 0, type => CMT_WORKTIME });
sub _set_add_comment
{
    my ($self, $params) = @_;

    $params->{thetext} = '' unless defined $params->{thetext};

    # Remove any trailing whitespace. Leading whitespace could be
    # a valid part of the comment.
    $params->{thetext} =~ s/\s*$//s;
    $params->{thetext} =~ s/\r\n?/\n/g; # Get rid of \r.

    ThrowUserError('comment_too_long') if length($params->{thetext}) > MAX_COMMENT_LENGTH;

    if (exists $params->{work_time})
    {
        if (!Bugzilla->user->is_timetracker)
        {
            delete $params->{work_time};
        }
        else
        {
            $params->{work_time} = ValidateTime($params->{work_time}, 'work_time');
            if ($params->{thetext} eq '' && $params->{work_time} != 0 &&
                (!exists $params->{type} ||
                $params->{type} != CMT_WORKTIME &&
                $params->{type} != CMT_BACKDATED_WORKTIME))
            {
                ThrowUserError('comment_required');
            }
        }
    }
    if (exists $params->{type})
    {
        detaint_natural($params->{type}) || ThrowCodeError('bad_arg', { argument => 'type' });
    }
    if ($params->{isprivate} && !Bugzilla->user->is_insider)
    {
        ThrowUserError('user_not_insider');
    }
    $params->{isprivate} = $params->{isprivate} ? 1 : 0;

    # FIXME We really should check extra_data, too.

    if ($params->{thetext} eq '' && !($params->{type} || $params->{work_time}))
    {
        return;
    }

    # So we really want to comment. Make sure we are allowed to do so.
    my $privs;
    $self->check_can_change_field('longdesc', 0, 1, \$privs)
        || ThrowUserError('illegal_change', { field => 'longdesc', privs => $privs });

    $self->{added_comments} ||= [];

    # We only want to trick_taint fields that we know about--we don't
    # want to accidentally let somebody set some field that's not OK
    # to set!
    my $add_comment = dclone($params);
    foreach my $field (UPDATE_COMMENT_COLUMNS)
    {
        trick_taint($add_comment->{$field}) if defined $add_comment->{$field};
    }
    push @{$self->{added_comments}}, $add_comment;

    return undef;
}

sub _set_component
{
    my ($self, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError('require_component');
    my $obj = Bugzilla::Component->new({ product => $self->product_obj, name => $name });
    if (!$obj)
    {
        $self->{_unknown_dependent_values}->{component} = [ $name ];
        return undef;
    }
    if ($self->component->id != $obj->id)
    {
        $self->{component_id}  = $obj->id;
        $self->{component}     = $obj->name;
        $self->{component_obj} = $obj;
        # CustIS Bug 55095: Don't enforce default CC
        ## Add the Default CC of the new Component
        #foreach my $cc (@{$component->initial_cc})
        #{
        #    $self->add_cc($cc);
        #}
    }
    return undef;
}

sub _set_deadline
{
    my ($self, $date) = @_;

    # Check time-tracking permissions.
    # deadline() returns '' instead of undef if no deadline is set.
    my $current = $self->deadline;
    return $current unless Bugzilla->user->is_timetracker;

    # Validate entered deadline
    $date = trim($date);
    return undef if !$date;

    validate_date($date) || ThrowUserError('illegal_date', { date => $date, format => 'YYYY-MM-DD' });
    return $date;
}

# Takes hashref with two comma/space-separated strings, like:
# { dependson => string|arrayref, blocked => string|arrayref }
sub _set_dependencies
{
    my ($self, $deps_in) = @_;

    if (!$self->id && !Bugzilla->user->in_group('editbugs', $self->product->id))
    {
        # Only editbugs users can set dependencies on bug entry.
        return undef;
    }

    foreach my $type (qw(dependson blocked))
    {
        my @bug_ids = ref($deps_in->{$type}) ? @{$deps_in->{$type}} : split(/[\s,]+/, $deps_in->{$type});
        # Eliminate nulls.
        @bug_ids = grep {$_} @bug_ids;
        # We do this up here to make sure all aliases are converted to IDs.
        @bug_ids = map { $self->check($_, $type)->id } @bug_ids;

        my @check_access = @bug_ids;
        # When we're updating a bug, only added or removed bug_ids are
        # checked for whether or not we can see/edit those bugs.
        if ($self->id)
        {
            my $old = $self->$type;
            my ($removed, $added) = diff_arrays($old, \@bug_ids);
            @check_access = (@$added, @$removed);

            # Check field permissions if we've changed anything.
            if (@check_access)
            {
                my $privs;
                if (!$self->check_can_change_field($type, 0, 1, \$privs))
                {
                    ThrowUserError('illegal_change', { field => $type, privs => $privs });
                }
            }
        }

        my $user = Bugzilla->user;
        foreach my $modified_id (@check_access)
        {
            my $delta_bug = Bugzilla::Bug->check($modified_id);
            # Under strict isolation, you can't modify a bug if you can't
            # edit it, even if you can see it.
            # FIXME WTF??
            if (Bugzilla->params->{strict_isolation})
            {
                if (!$user->can_edit_bug($delta_bug))
                {
                    ThrowUserError('illegal_change_deps', { field => $type });
                }
            }
        }

        $deps_in->{$type} = \@bug_ids;
    }

    # And finally, check for dependency loops.
    $self->{dependency_closure} = ValidateDependencies($self, $deps_in->{dependson}, $deps_in->{blocked});

    # These may already be detainted, but all setters are supposed to
    # detaint their input if they've run a validator (just as though
    # we had used Bugzilla::Object::set), so we do that here.
    detaint_natural($_) foreach (@{$deps_in->{dependson}}, @{$deps_in->{blocked}});
    $self->{dependson} = $deps_in->{dependson};
    $self->{blocked}   = $deps_in->{blocked};

    return undef;
}

sub _set_dup_id
{
    my ($self, $dupe_of) = @_;
    my $dbh = Bugzilla->dbh;

    $dupe_of = trim($dupe_of);
    $dupe_of || ThrowCodeError('undefined_field', { field => 'dup_id' });
    # Validate the bug ID. The second argument will force check() to only
    # make sure that the bug exists, and convert the alias to the bug ID
    # if a string is passed. Group restrictions are checked below.
    my $dupe_of_bug = $self->check($dupe_of, 'dup_id');
    $dupe_of = $dupe_of_bug->id;

    # If the dupe is unchanged, we have nothing more to check.
    return $dupe_of if $self->dup_id && $self->dup_id == $dupe_of;

    # If we come here, then the duplicate is new. We have to make sure
    # that we can view/change it (issue A on bug 96085).
    $dupe_of_bug->check_is_visible;

    # Make sure a loop isn't created when marking this bug
    # as duplicate.
    my %dupes;
    my $this_dup = $dupe_of;
    my $add_dup_cc;
    my $sth = $dbh->prepare('SELECT dupe_of FROM duplicates WHERE dupe = ?');

    while ($this_dup)
    {
        if ($this_dup == $self->id)
        {
            ThrowUserError('dupe_loop_detected', { bug_id  => $self->id, dupe_of => $dupe_of });
        }
        # If $dupes{$this_dup} is already set to 1, then a loop
        # already exists which does not involve this bug.
        # As the user is not responsible for this loop, do not
        # prevent him from marking this bug as a duplicate.
        last if exists $dupes{$this_dup};
        $dupes{$this_dup} = 1;
        $this_dup = $dbh->selectrow_array($sth, undef, $this_dup);
    }

    my $cur_dup = $self->dup_id || 0;
    if ($cur_dup != $dupe_of && Bugzilla->params->{commentonduplicate} && !$self->{added_comments})
    {
        ThrowUserError('comment_required');
    }

    # Should we add the reporter to the CC list of the new bug?
    # If he can see the bug...
    if ($self->reporter->can_see_bug($dupe_of))
    {
        # We only add him if he's not the reporter of the other bug.
        $add_dup_cc = 1 if $dupe_of_bug->reporter->id != $self->reporter->id;
    }
    # What if the reporter currently can't see the new bug? In the browser
    # interface, we prompt the user. In other interfaces, we default to
    # not adding the user, as the safest option.
    elsif (Bugzilla->usage_mode == USAGE_MODE_BROWSER)
    {
        # FIXME Не обращаться к cgi из Bugzilla::Bug
        # If we've already confirmed whether the user should be added...
        my $cgi = Bugzilla->cgi;
        my $add_confirmed = $cgi->param('confirm_add_duplicate');
        if (defined $add_confirmed)
        {
            $add_dup_cc = $add_confirmed;
        }
        else
        {
            # Note that here we don't check if he user is already the reporter
            # of the dupe_of bug, since we already checked if he can *see*
            # the bug, above. People might have reporter_accessible turned
            # off, but cclist_accessible turned on, so they might want to
            # add the reporter even though he's already the reporter of the
            # dup_of bug.
            my $vars = {};
            my $template = Bugzilla->template;
            # Ask the user what they want to do about the reporter.
            $vars->{cclist_accessible} = $dupe_of_bug->cclist_accessible;
            $vars->{original_bug_id} = $dupe_of;
            $vars->{duplicate_bug_id} = $self->id;
            $cgi->send_header();
            $template->process("bug/process/confirm-duplicate.html.tmpl", $vars)
                || ThrowTemplateError($template->error);
            exit;
        }
    }

    # Update the other bug object and save it to call update() then.
    if ($add_dup_cc)
    {
        $dupe_of_bug->add_cc($self->reporter);
    }
    $dupe_of_bug->add_comment("", { type => CMT_HAS_DUPE, extra_data => $self->id });
    $self->{_dup_for_update} = $dupe_of_bug;

    # Now make sure that we add a duplicate comment on *this* bug.
    # (Change an existing comment into a dup comment, if there is one,
    # or add an empty dup comment.)
    # FIXME: depends on add_comment call
    my @normal = grep { !defined $_->{type} || $_->{type} == CMT_NORMAL } @{ $self->{added_comments} || [] };
    if (@normal)
    {
        # Turn the last one into a dup comment.
        $normal[-1]->{type} = CMT_DUPE_OF;
        $normal[-1]->{extra_data} = $self->dup_id;
    }
    else
    {
        $self->add_comment('', { type => CMT_DUPE_OF, extra_data => $self->dup_id });
    }

    return $dupe_of;
}

sub _set_groups
{
    my ($self, $group_ids) = @_;

    my $user = Bugzilla->user;

    my %add_groups;
    my $controls = $self->product->group_controls;

    foreach my $id (@$group_ids)
    {
        my $group = new Bugzilla::Group($id) || ThrowUserError('invalid_group_ID');

        unless ($group->is_active && $group->is_bug_group)
        {
            ThrowCodeError('inactive_group', { name => $group->name })
        }

        my $membercontrol = $controls->{$id} && $controls->{$id}->{membercontrol};
        my $othercontrol  = $controls->{$id} && $controls->{$id}->{othercontrol};

        my $permit = ($membercontrol && $user->in_group($group->name)) || $othercontrol;

        $add_groups{$id} = 1 if $permit;
    }

    foreach my $id (keys %$controls)
    {
        next unless $controls->{$id}->{group}->is_active;
        my $membercontrol = $controls->{$id}->{membercontrol} || 0;
        my $othercontrol  = $controls->{$id}->{othercontrol}  || 0;

        # Add groups required
        if ($membercontrol == CONTROLMAPMANDATORY ||
            ($othercontrol == CONTROLMAPMANDATORY && !$user->in_group_id($id)))
        {
            # User had no option, bug needs to be in this group.
            $add_groups{$id} = 1;
        }
    }

    return [ keys %add_groups ];
}

# For keyword autocreation:
# set('keywords', { 'keywords' => 'kw1, kw2, ...', 'descriptions' => { kw1 => 'desc1', ... } }
sub _set_keywords
{
    my ($self, $data) = @_;

    my $old = $self->keyword_objects;
    my $new = $old;

    if ($self->check_can_change_field('keywords', 0, 1, \$privs))
    {
        if ($data->{keyword_objects})
        {
            $new = [ grep { ref($_) eq 'Bugzilla::Keyword' } @{$data->{keyword_objects}} ];
        }
        else
        {
            my $keyword_string = $data->{keywords};
            $keyword_string =~ s/^[\s,]+//s;
            $keyword_string =~ s/[\s,]+$//s;
            if ($keyword_string)
            {
                my $kw = Bugzilla::Keyword->match({ name => [ split /[\s,]*,[\s,]*/, $keyword_string ] });
                $kw = { map { lc($_->name) => $_ } @$kw };
                for my $name (@$keyword_string)
                {
                    if (!$kw->{lc $name} && $data->{descriptions}->{$name})
                    {
                        # CustIS Bug 66910 - Keyword autocreation
                        my $obj = Bugzilla::Keyword->create({
                            name => $name,
                            description => $data->{descriptions}->{$name},
                        });
                        $kw->{lc $name} = $obj;
                    }
                }
                $new = [ values %$kw ];
            }
        }
        # Make sure we retain the sort order.
        $new = [ sort { lc($a->name) cmp lc($b->name) } @$new ];
        $self->{keyword_objects} = $new;
    }
    else
    {
        # Silently ignore the error
#        ThrowUserError('illegal_change', {
#            field    => 'keywords',
#            oldvalue => $self->keywords,
#            newvalue => join(', ', map { $_->name } @$new),
#            privs    => $privs,
#        });
    }

    return undef;
}

sub _set_product
{
    my ($self, $name) = @_;
    $name = trim($name);
    # If we're updating the bug and they haven't changed the product, always allow it.
    if ($self->product_obj->name eq $name)
    {
        return undef;
    }
    # Check that the product exists and that the user
    # is allowed to enter bugs into this product.
    Bugzilla->user->can_enter_product($name, THROW_ERROR);
    # can_enter_product already does everything that check_product
    # would do for us, so we don't need to use it.
    my $product = new Bugzilla::Product({ name => $name });
    if ($self->product->id != $product->id)
    {
        $self->{product_id}  = $product->id;
        $self->{product}     = $product->name;
        $self->{product_obj} = $product;
    }
    return undef;
}

sub _set_priority
{
    my ($self, $priority) = @_;
    if (!$self->id && !Bugzilla->params->{letsubmitterchoosepriority})
    {
        $priority = Bugzilla->params->{defaultpriority};
    }
    return $self->_set_select_field($priority, 'priority');
}

sub _set_qa_contact
{
    my ($self, $qa_contact) = @_;

    $qa_contact = trim($qa_contact) if !ref $qa_contact;

    my $id;
    if (!$self->id)
    {
        # Bugs get no QA Contact on creation if useqacontact is off.
        return undef if !Bugzilla->params->{useqacontact};

        # Set the default QA Contact if one isn't specified or if the
        # user doesn't have editbugs.
        if (!Bugzilla->user->in_group('editbugs', $component->product_id) || !$qa_contact)
        {
            $id = $component->default_qa_contact->id;
            $self->{qa_contact_obj} = $component->default_qa_contact;
        }
    }

    # If a QA Contact was specified or if we're updating, check
    # the QA Contact for validity.
    if (!defined $id && $qa_contact)
    {
        $qa_contact = Bugzilla::User->check($qa_contact) if !ref $qa_contact;
        $id = $qa_contact->id;
        $self->{qa_contact_obj} = $qa_contact;
    }

    # "0" always means "undef", for QA Contact.
    return $id || undef;
}

sub _set_reporter
{
    my $self = shift;
    my $reporter;
    if ($self->id)
    {
        # You cannot change the reporter of a bug.
        $reporter = $self->reporter->id;
    }
    else
    {
        # On bug creation, the reporter is the logged in user
        # (meaning that he must be logged in first!).
        $reporter = Bugzilla->user->id;
        $reporter || ThrowCodeError('invalid_user');
    }
    if ($reporter && $self->id)
    {
        # CustIS Bug 38616
        # FIXME Use strict_isolation
        # Clean reporter when moving external bug into internal product with protected CC group
        my $ccg = $self->product_obj->cc_group;
        my $user = Bugzilla::User->new($reporter);
        if ($ccg && !$user->in_group($ccg))
        {
            ThrowUserError('cc_group_restriction', { user => $user->login });
        }
    }
    return $reporter;
}

sub _set_resolution
{
    my ($self, $resolution) = @_;
    $resolution = trim($resolution) || undef;

    # Don't allow open bugs to have resolutions.
    $resolution = undef if $self->status->is_open;

    # Throw a special error for resolving bugs without a resolution
    ThrowUserError('missing_resolution', { status => $self->status->name })
        if !$resolution && !$self->status->is_open;

    my $old_res = $self->resolution;
    my $old_res_id = $old_res ? $old_res->id : undef;

    # Make sure this is a valid resolution.
    $resolution = $self->_set_select_field($resolution, 'resolution');

    my $new_res = $self->resolution;

    # Check noresolveonopenblockers.
    if (Bugzilla->params->{noresolveonopenblockers}
        && $new_res && (!$old_res || $new_res->id != $old_res->id))
    {
        my @dependencies = CountOpenDependencies($self->id);
        if (@dependencies)
        {
            ThrowUserError('still_unresolved_bugs', {
                dependencies     => \@dependencies,
                dependency_count => scalar @dependencies,
            });
        }
    }

    # Check if they're changing the resolution and need to comment.
    if (Bugzilla->params->{commentonchange_resolution}
        && $old_res && $new_res && $old_res->id ne $new_res->id
        && !$self->{added_comments})
    {
        ThrowUserError('comment_required');
    }

    if ($resolution != $old_res_id)
    {
        # MOVED has a special meaning and can only be used when
        # really moving bugs to another installation.
        ThrowCodeError('no_manual_moved') if $new_res && $new_res->name eq 'MOVED' && !$params->{moving};

        # Clear the dup_id if we're leaving the dup resolution.
        if ($old_res && $old_res->name eq 'DUPLICATE')
        {
            $self->set('dup_id', undef);
        }
        # Duplicates should have no remaining time left.
        elsif ($new_res && $new_res->name eq 'DUPLICATE' && $self->remaining_time != 0)
        {
            $self->set('remaining_time', 0);
        }
    }

    # We don't check if we're entering or leaving the dup resolution here,
    # because we could be moving from being a dup of one bug to being a dup
    # of another, theoretically. Note that this code block will also run
    # when going between different closed states.
    if ($new_res && $new_res->name eq 'DUPLICATE')
    {
        if ($params->{dupe_of})
        {
            $self->set('dup_id', $params->{dupe_of});
        }
        elsif (!$self->dup_id)
        {
            ThrowUserError('dupe_id_required');
        }
    }

    return $resolution;
}

sub _set_short_desc
{
    my ($self, $short_desc) = @_;
    # Set the parameter to itself, but cleaned up
    $short_desc = clean_text($short_desc) if $short_desc;
    if (!defined $short_desc || $short_desc eq '')
    {
        ThrowUserError('require_summary');
    }
    return $short_desc;
}

sub _set_status_whiteboard
{
    my ($self, $value) = @_;
    return defined $value ? $value : '';
}

sub _set_target_milestone
{
    my ($self, $target) = @_;
    $product = $self->product_obj;
    $target = trim($target);
    # Reporters can move bugs between products but not set the TM.
    # So reset it to the default value.
    if (!defined $target || !Bugzilla->params->{usetargetmilestone} ||
        $self->{id} && !$self->check_can_change_field('target_milestone', 0, 1))
    {
        $target = $product->default_milestone;
    }
    if ((!defined $target || !length $target) && Bugzilla->get_field('target_milestone')->nullable)
    {
        $self->{target_milestone_obj} = undef;
        return $self->{target_milestone} = undef;
    }
    # FIXME use set_select_field
    my $object = Bugzilla::Milestone->new({ product => $product, name => $target });
    if (!$object)
    {
        $self->{_unknown_dependent_values}->{target_milestone} = [ $target ];
        return undef;
    }
    return $object->id;
}

sub _set_version
{
    my ($self, $version) = @_;
    $version = trim($version);
    if ((!defined $version || !length $version) && Bugzilla->get_field('version')->nullable)
    {
        $self->{version_obj} = undef;
        return $self->{version} = undef;
    }
    # FIXME use set_select_field
    my $object = Bugzilla::Version->new({ product => $self->product_obj, name => $version });
    if (!$object)
    {
        $self->{_unknown_dependent_values}->{version} = [ $version ];
        return undef;
    }
    return $object->id;
}

sub _set_time
{
    my ($self, $time, $field) = @_;

    return $self->$field unless Bugzilla->user->is_timetracker;

    return ValidateTime($time, $field);
}

sub _set_estimated_time
{
    my ($self, $time, $field) = @_;
    my $v = $self->_set_time($time, $field);
    if (!$self->id && !$self->remaining_time && $v)
    {
        # Set remaining_time == estimated_time on new bugs if it was empty
        $self->{remaining_time} = $v;
    }
    return $v;
}

sub _set_remaining_time
{
    my ($self, $time, $field) = @_;
    my $v = $self->_set_time($time, $field);
    if (!$self->id && !$v && $self->estimated_time)
    {
        # Set remaining_time == estimated_time on new bugs if it was empty
        $v = $self->estimated_time;
    }
    return $v;
}

# Custom Field Validators/Setters

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

sub _set_freetext_field
{
    my ($self, $text) = @_;
    $text = (defined $text) ? trim($text) : '';
    if (length($text) > MAX_FREETEXT_LENGTH)
    {
        ThrowUserError('freetext_too_long', { text => $text });
    }
    return $text;
}

sub _set_multi_select_field
{
    my ($self, $values, $field) = @_;

    # FIXME Move splitting of multiselect on ',' into email_in.pl itself!
    # Allow users (mostly email_in.pl) to specify multi-selects as
    # comma-separated values.
    if (defined $values && !ref $values)
    {
        # We don't split on spaces because multi-select values can and often
        # do have spaces in them. (Theoretically they can have commas in them
        # too, but that's much less common and people should be able to work
        # around it pretty cleanly, if they want to use email_in.pl.)
        $values = [ split ',', $values ];
    }

    if (!$values || !@$values)
    {
        $self->{$field.'_obj'} = [];
        return [];
    }

    my $field_obj = Bugzilla->get_field($field);
    my $t = Bugzilla::Field::Choice->type($field_obj);
    my $value_objs = $t->match({ name => $values });
    my $h = { map { lc($_->name) => $_ } @$value_objs };
    my @bad = grep { !$h->{lc $_} } @$values;
    if (@bad)
    {
        $self->{_unknown_dependent_values}->{$field} = \@bad;
        return undef;
    }

    $self->{$field.'_obj'} = $value_objs;
    return [ map { $_->id } @$value_objs ];
}

sub _set_select_field
{
    my ($self, $value, $field) = @_;
    my $field_obj = Bugzilla->get_field($field);
    # Allow empty values, but only for nullable or invisible fields
    if ((!defined $value || !length $value) &&
        ($field_obj->nullable || !$field_obj->check_visibility($self)))
    {
        $self->{$field.'_obj'} = undef;
        return $self->{$field} = undef;
    }
    my $t = Bugzilla::Field::Choice->type($field_obj);
    my $value_obj = $t->new({ name => $value });
    if (!$value_obj)
    {
        $self->{_unknown_dependent_values}->{$field} = [ $value ];
        return undef;
    }
    $self->{$field.'_obj'} = $value_obj;
    return $value_obj->id;
}

sub _set_bugid_field
{
    my ($self, $value, $field) = @_;
    return $self->{$field} = undef if !$value;

    my $r;
    if ($self->{$field} eq $value)
    {
        # If there is no change, do not check the bug id, as it may be invisible for current user
        $r = $self->{$field};
    }
    else
    {
        $r = Bugzilla::Bug->check($value, $field)->id;
    }

    return $r;
}

#####################################################################
# Class Accessors
#####################################################################

sub fields
{
    my $class = shift;

    # FIXME bugzilla.dtd should be autogenerated
    # FIXME change useplatform/useopsys/useqacontact to "field(xxx).is_obsolete"
    my @fields =
    (
        # Standard Fields
        # Keep this ordering in sync with bugzilla.dtd.
        qw(bug_id alias creation_ts short_desc delta_ts
           reporter_accessible cclist_accessible
           classification_id classification
           product component version),
        # Use platform?
        Bugzilla->params->{useplatform} ? "rep_platform" : (),
        # Use OS?
        Bugzilla->params->{useopsys} ? "op_sys" : (),
        # Standard Fields continued...
        qw(bug_status resolution dup_id see_also
           bug_file_loc status_whiteboard keywords
           priority bug_severity target_milestone
           dependson blocked votes everconfirmed
           reporter assigned_to cc estimated_time
           remaining_time actual_time deadline),

        # Use QA contact?
        Bugzilla->params->{useqacontact} ? "qa_contact" : (),

        # Custom Fields
        map { $_->name } Bugzilla->active_custom_fields
    );
    Bugzilla::Hook::process('bug_fields', { fields => \@fields });

    return @fields;
}

#####################################################################
# Mutators
#####################################################################

# To run check_can_change_field.
sub _set_global_validator
{
    my ($self, $value, $field) = @_;
    my $current = $self->$field;
    my $privs;
    if (ref $current && ref($current) ne 'ARRAY' && $current->isa('Bugzilla::Object'))
    {
        $current = $current->id;
    }
    if (ref $value && ref($value) ne 'ARRAY' && $value->isa('Bugzilla::Object'))
    {
        $value = $value->id;
    }
    my $can = $self->check_can_change_field($field, $current, $value, \$privs);
    if (!$can)
    {
        if ($field eq 'assigned_to' || $field eq 'qa_contact')
        {
            $value   = user_id_to_login($value);
            $current = user_id_to_login($current);
        }
        ThrowUserError('illegal_change', {
            field    => $field,
            oldvalue => $current,
            newvalue => $value,
            privs    => $privs,
        });
    }
}

#################
# "Set" Methods #
#################

sub reset_assigned_to
{
    my $self = shift;
    $self->set('assigned_to', $self->component_obj->default_assignee);
}

sub reset_qa_contact
{
    my $self = shift;
    $self->set('qa_contact', $self->component_obj->default_qa_contact);
}

sub set_comment_is_private
{
    my ($self, $comment_id, $isprivate) = @_;
    return unless Bugzilla->user->is_insider;
    my ($comment) = grep { $comment_id == $_->id } @{ $self->comments };
    ThrowUserError('comment_invalid_isprivate', { id => $comment_id }) if !$comment;
    $isprivate = $isprivate ? 1 : 0;
    if ($isprivate != $comment->is_private)
    {
        $self->{comment_isprivate} ||= {};
        $self->{comment_isprivate}->{$comment_id} = $isprivate;
    }
}

sub set_comment_worktimeonly
{
    my ($self, $comment_id, $type) = @_;
    my ($comment) = grep $comment_id == $_->id, @{ $self->comments };
    if (!$comment || $comment->type != CMT_NORMAL && $comment->type != CMT_WORKTIME ||
        $comment->who != Bugzilla->user->id && !Bugzilla->user->in_group('worktimeadmin'))
    {
        ThrowUserError('comment_invalid_worktimeonly', { id => $comment_id })
    }
    $type = $type ? CMT_WORKTIME : CMT_NORMAL;
    if ($type != $comment->type)
    {
        $self->{comment_type}->{$comment_id} = $type;
    }
}

sub set_flags
{
    my ($self, $flags, $new_flags) = @_;

    Bugzilla::Flag->set_flag($self, $_) foreach @$flags, @$new_flags;
}

########################
# "Add/Remove" Methods #
########################

# These are in alphabetical order by field name.

# Accepts a User object or a username. Adds the user only if they
# don't already exist as a CC on the bug.
sub add_cc
{
    my ($self, $user_or_name) = @_;
    return if !$user_or_name;
    my $user = ref $user_or_name ? $user_or_name : Bugzilla::User->check($user_or_name);
    my $cc_users = $self->cc_users;
    push @$cc_users, $user if !grep { $_->id == $user->id } @$cc_users;
}

# Accepts a User object or a username. Removes the User if they exist
# in the list, but doesn't throw an error if they don't exist.
sub remove_cc
{
    my ($self, $user_or_name) = @_;
    my $user = ref $user_or_name ? $user_or_name : Bugzilla::User->check($user_or_name);
    my $cc_users = $self->cc_users;
    @$cc_users = grep { $_->id != $user->id } @$cc_users;
}

# Edit a comment
sub edit_comment
{
    my ($self, $comment_id, $comment) = @_;

    my $db_comment = Bugzilla::Comment->new($comment_id);
    my $old_comment = $self->_check_comment($db_comment->body);
    $comment = $self->_check_comment($comment);
    $self->{edited_comments} ||= [];

    if ($old_comment ne $comment)
    {
        push @{$self->{edited_comments}}, {
            comment_id => $comment_id,
            oldthetext => $old_comment,
            thetext => $comment,
        };
    }
}

# $action: one of 'add', 'delete', or 'makeexact' (default)
sub modify_keywords
{
    my ($self, $keywords, $descriptions, $action) = @_;

    my $old_kw = $self->keyword_objects;
    if ($action eq 'delete')
    {
        my $kw = { map { lc($_->name) => $_ } @$old_kw };
        delete $kw->{lc $_} for split /[\s,]*,[\s,]*/, $keywords;
        $self->set('keywords', { keyword_objects => [ values %$kw ] });
    }
    else
    {
        if ($action eq 'add')
        {
            $keywords .= ', '.$self->keywords;
        }
        $self->set('keywords', {
            keywords => $keywords,
            descriptions => http_decode_query($descriptions),
        });
    }
}

sub add_see_also
{
    my ($self, $input) = @_;
    $input = trim($input);
    my $result;

    my $regexes = Bugzilla->params->{see_also_url_regexes};
    my $found = 0;
    for my $line (split /\n/, $regexes)
    {
        next if /^#/;
        my ($regex, $replacement) = split /\s+/, $line;
        if ($regex && $input =~ /$regex/)
        {
            my @starts = @-;
            my @ends = @+;
            $result = $replacement;
            $result =~ s/(^|[^\\](?:\\\\)*)\$(\d+)/$1.(defined $starts[$2] ? substr($input, $starts[$2], $ends[$2]-$starts[$2]) : '$'.$2)/gsoe;
            trick_taint($result);
            $found = 1;
            last;
        }
    }

    if (!$found)
    {
        ThrowUserError('bug_url_invalid', { url => $input });
    }

    if (length($result) > MAX_BUG_URL_LENGTH)
    {
        ThrowUserError('bug_url_too_long', { url => $result });
    }

    # We only add the new URI if it hasn't been added yet. URIs are
    # case-sensitive, but most of our DBs are case-insensitive, so we do
    # this check case-insensitively.
    if (!grep { lc($_) eq lc($result) } @{ $self->see_also })
    {
        my $privs;
        my $can = $self->check_can_change_field('see_also', '', $result, \$privs);
        if (!$can)
        {
            ThrowUserError('illegal_change', {
                field    => 'see_also',
                newvalue => $result,
                privs    => $privs,
            });
        }

        push @{ $self->see_also }, $result;
    }
}

sub remove_see_also
{
    my ($self, $url) = @_;
    my $see_also = $self->see_also;
    my @new_see_also = grep { lc($_) ne lc($url) } @$see_also;
    my $privs;
    my $can = $self->check_can_change_field('see_also', $see_also, \@new_see_also, \$privs);
    if (!$can)
    {
        ThrowUserError('illegal_change', {
            field    => 'see_also',
            oldvalue => $url,
            privs    => $privs,
        });
    }
    $self->{see_also} = \@new_see_also;
}

#####################################################################
# Instance Accessors
#####################################################################

# These subs are in alphabetical order, as much as possible.
# If you add a new sub, please try to keep it in alphabetical order
# with the other ones.

sub dup_id
{
    my ($self) = @_;
    return $self->{dup_id} if exists $self->{dup_id};
    $self->{dup_id} = undef;
    if ($self->{resolution} eq 'DUPLICATE')
    {
        my $dbh = Bugzilla->dbh;
        $self->{dup_id} = $dbh->selectrow_array(
            "SELECT dupe_of FROM duplicates WHERE dupe = ?",
            undef, $self->{bug_id}
        );
    }
    return $self->{dup_id};
}

sub actual_time
{
    my ($self) = @_;
    return $self->{actual_time} if exists $self->{actual_time};

    if (!Bugzilla->user->is_timetracker)
    {
        $self->{actual_time} = undef;
        return $self->{actual_time};
    }

    ($self->{actual_time}) = Bugzilla->dbh->selectrow_array(
        "SELECT SUM(work_time) FROM longdescs WHERE longdescs.bug_id=?",
        undef, $self->{bug_id}
    );
    return $self->{actual_time};
}

sub any_flags_requesteeble
{
    my ($self) = @_;
    return $self->{any_flags_requesteeble} if exists $self->{any_flags_requesteeble};

    my $any_flags_requesteeble = grep { $_->is_requestable && $_->is_requesteeble } @{$self->flag_types};
    # Useful in case a flagtype is no longer requestable but a requestee
    # has been set before we turned off that bit.
    $any_flags_requesteeble ||= grep { $_->requestee_id } @{$self->flags};
    $self->{any_flags_requesteeble} = $any_flags_requesteeble;

    return $self->{any_flags_requesteeble};
}

sub attachments
{
    my ($self) = @_;
    return $self->{attachments} if exists $self->{attachments};

    $self->{attachments} = Bugzilla::Attachment->get_attachments_by_bug($self->bug_id, { preload => 1 });
    return $self->{attachments};
}

sub assigned_to
{
    my ($self) = @_;
    return $self->{assigned_to_obj} if exists $self->{assigned_to_obj};
    $self->{assigned_to_obj} ||= new Bugzilla::User($self->{assigned_to});
    return $self->{assigned_to_obj};
}

sub blocked
{
    my ($self) = @_;
    return $self->{blocked} if exists $self->{blocked};
    $self->{blocked} = EmitDependList('dependson', 'blocked', $self->bug_id);
    return $self->{blocked};
}

sub bug_id { $_[0]->{bug_id}; }

sub failed_checkers { $_[0]->{failed_checkers} }

sub cc
{
    my ($self) = @_;
    return $self->{cc} if exists $self->{cc};

    my $dbh = Bugzilla->dbh;
    $self->{cc} = $dbh->selectcol_arrayref(
        "SELECT profiles.login_name FROM cc, profiles".
        " WHERE bug_id = ? AND cc.who = profiles.userid".
        " ORDER BY profiles.login_name",
        undef, $self->bug_id
    );

    $self->{cc} = undef if !@{$self->{cc}};

    return $self->{cc};
}

# FIXME Eventually this will become the standard "cc" method used everywhere.
sub cc_users
{
    my $self = shift;
    return $self->{cc_users} if exists $self->{cc_users};

    my $dbh = Bugzilla->dbh;
    my $cc_ids = $dbh->selectcol_arrayref('SELECT who FROM cc WHERE bug_id = ?', undef, $self->id);
    $self->{cc_users} = Bugzilla::User->new_from_list($cc_ids);
    return $self->{cc_users};
}

# FIXME This should eventually be replaced by the "product_obj" subroutine.
sub product
{
    my ($self) = @_;
    return $self->product_obj->name;
}

sub component
{
    my ($self) = @_;
    return $self->component_obj->name;
}

sub classification_id
{
    my ($self) = @_;
    return $self->product_obj->classification_id;
}

sub classification
{
    my ($self) = @_;
    return $self->product_obj->classification_obj->name;
}

sub dependson
{
    my ($self) = @_;
    return $self->{dependson} if exists $self->{dependson};
    $self->{dependson} = EmitDependList('blocked', 'dependson', $self->bug_id);
    return $self->{dependson};
}

sub flag_types
{
    my ($self) = @_;
    return $self->{flag_types} if exists $self->{flag_types};

    my $vars = {
        target_type  => 'bug',
        product_id   => $self->{product_id},
        component_id => $self->{component_id},
        bug_id       => $self->bug_id,
        bug_obj      => $self,
    };

    $self->{flag_types} = Bugzilla::Flag->_flag_types($vars);

    return $self->{flag_types};
}

sub flags
{
    my $self = shift;

    # Don't cache it as it must be in sync with ->flag_types.
    $self->{flags} = [ map { @{$_->{flags}} } @{$self->flag_types} ];
    return $self->{flags};
}

sub isopened
{
    my $self = shift;
    return is_open_state($self->{bug_status}) ? 1 : 0;
}

sub keywords
{
    my ($self) = @_;
    return join(', ', (map { $_->name } @{$self->keyword_objects}));
}

# FIXME At some point, this should probably replace the normal "keywords" sub.
sub keyword_objects
{
    my $self = shift;
    return $self->{keyword_objects} if defined $self->{keyword_objects};

    my $dbh = Bugzilla->dbh;
    my $ids = $dbh->selectcol_arrayref(
         "SELECT keywordid FROM keywords WHERE bug_id = ?", undef, $self->id
    );
    $self->{keyword_objects} = Bugzilla::Keyword->new_from_list($ids);
    return $self->{keyword_objects};
}

sub comments
{
    my ($self, $params) = @_;
    $params ||= {};

    if (!defined $self->{comments})
    {
        $self->{comments} = Bugzilla::Comment->match({ bug_id => $self->id });
        my $count = 0;
        foreach my $comment (@{$self->{comments}})
        {
            $comment->{count} = $count++ if $comment->type != CMT_BACKDATED_WORKTIME;
            $comment->{bug} = $self;
        }
        Bugzilla::Comment->preload($self->{comments});
    }
    my @comments = @{$self->{comments}};

    my $order = $params->{order} || Bugzilla->user->settings->{comment_sort_order}->{value};
    if ($order ne 'oldest_to_newest')
    {
        @comments = reverse @comments;
        if ($order eq 'newest_to_oldest_desc_first')
        {
            unshift @comments, pop @comments;
        }
    }

    if ($params->{after})
    {
        my $from = datetime_from($params->{after});
        @comments = grep { datetime_from($_->creation_ts) > $from } @comments;
    }
    elsif ($params->{start_at})
    {
        splice(@comments, 0, $params->{start_at});
    }
    if ($params->{to})
    {
        my $to = datetime_from($params->{to});
        @comments = grep { datetime_from($_->creation_ts) <= $to } @comments;
    }
    return \@comments;
}

sub qa_contact
{
    my ($self) = @_;
    return $self->{qa_contact_obj} if exists $self->{qa_contact_obj};
    if (Bugzilla->params->{useqacontact} && $self->{qa_contact})
    {
        $self->{qa_contact_obj} = new Bugzilla::User($self->{qa_contact});
    }
    else
    {
        $self->{qa_contact_obj} = undef;
    }
    return $self->{qa_contact_obj};
}

sub reporter
{
    my ($self) = @_;
    return $self->{reporter} if exists $self->{reporter};
    $self->{reporter} ||= new Bugzilla::User($self->{reporter_id});
    return $self->{reporter};
}

sub see_also
{
    my ($self) = @_;
    $self->{see_also} ||= Bugzilla->dbh->selectcol_arrayref('SELECT value FROM bug_see_also WHERE bug_id = ?', undef, $self->id);
    return $self->{see_also};
}

sub status
{
    my $self = shift;
    $self->{status} ||= new Bugzilla::Status($self->{bug_status});
    return $self->{status};
}

sub statuses_available
{
    my $self = shift;
    return $self->{statuses_available} if defined $self->{statuses_available};

    my @statuses = @{ $self->status->can_change_to };

    # UNCONFIRMED is only a valid status if it is enabled in this product.
    if (!$self->product_obj->allows_unconfirmed)
    {
        @statuses = grep { $_->name ne 'UNCONFIRMED' } @statuses;
    }

    my @available;
    foreach my $status (@statuses)
    {
        # Make sure this is a legal status transition
        next if !$self->check_can_change_field('bug_status', $self->status->name, $status->name);
        push @available, $status;
    }

    # If this bug has an inactive status set, it should still be in the list.
    if (!grep { $_->name eq $self->status->name } @available)
    {
        unshift @available, $self->status;
    }

    $self->{statuses_available} = \@available;
    return $self->{statuses_available};
}

sub show_attachment_flags
{
    my ($self) = @_;
    return $self->{show_attachment_flags} if exists $self->{show_attachment_flags};

    # The number of types of flags that can be set on attachments to this bug
    # and the number of flags on those attachments.  One of these counts must be
    # greater than zero in order for the "flags" column to appear in the table
    # of attachments.
    my $num_attachment_flag_types = Bugzilla::FlagType::count({
        target_type  => 'attachment',
        product_id   => $self->{product_id},
        component_id => $self->{component_id},
    });
    my $num_attachment_flags = Bugzilla::Flag->count({
        target_type  => 'attachment',
        bug_id       => $self->bug_id,
    });

    $self->{show_attachment_flags} = $num_attachment_flag_types || $num_attachment_flags;

    return $self->{show_attachment_flags};
}

sub use_votes
{
    my ($self) = @_;
    return Bugzilla->params->{usevotes} && $self->product_obj->votes_per_user > 0;
}

sub groups
{
    my $self = shift;
    return $self->{groups} if exists $self->{groups};

    my $dbh = Bugzilla->dbh;
    my @groups;

    # Some of this stuff needs to go into Bugzilla::User

    # For every group, we need to know if there is ANY bug_group_map
    # record putting the current bug in that group and if there is ANY
    # user_group_map record putting the user in that group.
    # The LEFT JOINs are checking for record existence.
    #
    my $grouplist = Bugzilla->user->groups_as_string;
    my $sth = $dbh->prepare(
        "SELECT DISTINCT groups.id, name, description," .
        " CASE WHEN bug_group_map.group_id IS NOT NULL" .
        " THEN 1 ELSE 0 END," .
        " CASE WHEN groups.id IN($grouplist) THEN 1 ELSE 0 END," .
        " isactive, membercontrol, othercontrol" .
        " FROM groups" .
        " LEFT JOIN bug_group_map" .
        " ON bug_group_map.group_id = groups.id" .
        " AND bug_id = ?" .
        " LEFT JOIN group_control_map" .
        " ON group_control_map.group_id = groups.id" .
        " AND group_control_map.product_id = ? " .
        " WHERE isbuggroup = 1" .
        " ORDER BY description"
    );
    $sth->execute($self->{bug_id}, $self->{product_id});

    while (my ($groupid, $name, $description, $ison, $ingroup, $isactive, $membercontrol, $othercontrol) = $sth->fetchrow_array())
    {
        $membercontrol ||= 0;

        # For product groups, we only want to use the group if either
        # (1) The bit is set and not required, or
        # (2) The group is Shown or Default for members and
        #     the user is a member of the group.
        if ($ison || $isactive && $ingroup &&
            ($membercontrol == CONTROLMAPDEFAULT || $membercontrol == CONTROLMAPSHOWN))
        {
            my $ismandatory = $isactive && ($membercontrol == CONTROLMAPMANDATORY);

            push @groups, {
                bit => $groupid,
                name => $name,
                ison => $ison,
                ingroup => $ingroup,
                mandatory => $ismandatory,
                description => $description,
            };
        }
    }

    return $self->{groups} = \@groups;
}

sub groups_in
{
    my $self = shift;
    return $self->{groups_in} if exists $self->{groups_in};
    my $group_ids = Bugzilla->dbh->selectcol_arrayref(
        'SELECT group_id FROM bug_group_map WHERE bug_id = ?', undef, $self->id
    );
    $self->{groups_in} = Bugzilla::Group->new_from_list($group_ids);
    return $self->{groups_in};
}

sub user
{
    my $self = shift;
    return $self->{user} if exists $self->{user};

    my $user = Bugzilla->user;
    my $canmove = Bugzilla->params->{'move-enabled'} && $user->is_mover;

    my $prod_id = $self->{product_id};

    my $unknown_privileges = $user->in_group('editbugs', $prod_id);
    my $canedit = $unknown_privileges || $user->id == $self->{assigned_to}
        || (Bugzilla->params->{useqacontact} && $self->{qa_contact} && $user->id == $self->{qa_contact});
    my $canconfirm = $unknown_privileges || $user->in_group('canconfirm', $prod_id);
    my $isreporter = $user->id && $user->id == $self->{reporter_id};

    $self->{user} = {
        canmove    => $canmove,
        canconfirm => $canconfirm,
        canedit    => $canedit,
        isreporter => $isreporter,
    };
    return $self->{user};
}

sub votes
{
    my ($self) = @_;
    return $self->{votes} if defined $self->{votes};

    my $dbh = Bugzilla->dbh;
    $self->{votes} = $dbh->selectrow_array(
        'SELECT SUM(vote_count) FROM votes WHERE bug_id = ? '.
        $dbh->sql_group_by('bug_id'), undef, $self->bug_id
    );
    $self->{votes} ||= 0;
    return $self->{votes};
}

# Convenience Function. If you need speed, use this. If you need
# other Bug fields in addition to this, just create a new Bug with
# the alias.
# Queries the database for the bug with a given alias, and returns
# the ID of the bug if it exists or the undefined value if it doesn't.
sub bug_alias_to_id
{
    my ($alias) = @_;
    return undef unless Bugzilla->params->{usebugaliases};
    my $dbh = Bugzilla->dbh;
    trick_taint($alias);
    return $dbh->selectrow_array('SELECT bug_id FROM bugs WHERE alias = ?', undef, $alias);
}

# Get users who can access this bug (for displaying it to the user)
sub get_access_user_list
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $count_groups = scalar @{$self->groups};
    if (!$count_groups)
    {
        return [];
    }
    my @user_ids;

    push @user_ids, $self->assigned_to->id if $self->assigned_to;
    push @user_ids, $self->qa_contact->id if $self->qa_contact;
    if ($self->reporter_accessible)
    {
        push @user_ids, $self->reporter->id;
    }
    if ($self->cclist_accessible)
    {
        my $cc_list = $dbh->selectall_arrayref("SELECT cc.who FROM cc cc WHERE cc.bug_id = ?", undef, $self->bug_id);
        foreach my $cc_item (@$cc_list)
        {
            push @user_ids, $cc_item->[0];
        }
    }

    my $user_ids_group = {};
    foreach my $group (@{$self->groups})
    {
        my @childgroups = @{Bugzilla::Group->flatten_group_membership($group->{bit})};
        my $group_users = $dbh->selectall_arrayref("SELECT DISTINCT user_id FROM user_group_map WHERE isbless = 0 AND group_id IN (".join(",", @childgroups).")");
        foreach my $users (@$group_users)
        {
            $user_ids_group->{$users->[0]}++;
        }
    }

    push @user_ids, grep { $user_ids_group->{$_} == $count_groups } keys %$user_ids_group;

    return $dbh->selectall_arrayref("
        SELECT p.userid, p.login_name, p.realname
        FROM profiles p
        WHERE p.disabledtext = '' AND p.disable_mail = 0 AND p.userid in (".join(",", @user_ids).")
        ORDER BY p.realname");
}

sub depscompletedpercent  { $_[0]->checkdepsinfo; $_[0]->{depscompletedpercent}; }
sub lastchangeddeps       { $_[0]->checkdepsinfo; $_[0]->{lastchangeddeps}; }

sub checkdepsinfo
{
    my $self = shift;
    my $dep = $self->dependson;
    return if defined $self->{lastchangeddeps} || !$dep || !@$dep;
    my $where = "bug_id IN (" . join(",", ("?") x @$dep) . ")";
    my ($last, $rem) = Bugzilla->dbh->selectrow_array(
        "SELECT MAX(delta_ts), SUM(remaining_time)" .
        " FROM bugs WHERE $where", undef, @$dep
    );
    my ($work) = Bugzilla->dbh->selectrow_array(
        "SELECT SUM(work_time) FROM longdescs WHERE $where",
        undef, @$dep
    );
    $self->{lastchangeddeps} = $last;
    $self->{depscompletedpercent} = int(100*$work/($work+$rem || 1));
}

#####################################################################
# Subroutines
#####################################################################

# NB // Vitaliy Filippov <vitalif@mail.ru> 2010-02-01 19:23
# editable_bug_fields() is one more example of incorrect and unused generalization.
# It does not represent which fields from the bugs table are handled by process_bug.cgi,
# because process_bug.cgi itself does not use it at any point. In fact, it was used only
# in 2 places: 1) the field list for boolean charts 2) in BugMail.pm to avoid 'SELECT *'.
# Both of them are not related to "editable" at all.

# FIXME - When Bug::update() will be implemented, we should make this routine a private method.
# Join with bug_status and bugs tables to show bugs with open statuses first, and then the others
sub EmitDependList
{
    my ($myfield, $targetfield, $bug_id) = (@_);
    my $dbh = Bugzilla->dbh;
    my $list_ref = $dbh->selectcol_arrayref(
        "SELECT $targetfield FROM dependencies".
        " INNER JOIN bugs ON dependencies.$targetfield = bugs.bug_id".
        " INNER JOIN bug_status ON bugs.bug_status = bug_status.value".
        " WHERE $myfield = ?".
        " ORDER BY is_open DESC, $targetfield",
        undef, $bug_id
    );
    return $list_ref;
}

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

# Get the activity of a bug, starting from $starttime (if given).
# This routine assumes Bugzilla::Bug->check has been previously called.
sub GetBugActivity
{
    my ($bug_id, $attach_id, $starttime) = @_;
    my $dbh = Bugzilla->dbh;

    # Arguments passed to the SQL query.
    my @args = ($bug_id);

    # Only consider changes since $starttime, if given.
    my $datepart = "";
    if (defined $starttime)
    {
        trick_taint($starttime);
        push @args, $starttime;
        $datepart = "AND bugs_activity.bug_when > ?";
    }

    my $attachpart = "";
    if ($attach_id)
    {
        push @args, $attach_id;
        $attachpart = "AND bugs_activity.attach_id = ?";
    }

    # Only includes attachments the user is allowed to see.
    my $suppjoins = "";
    my $suppwhere = "";
    if (!Bugzilla->user->is_insider)
    {
        $suppjoins = "LEFT JOIN attachments ON attachments.attach_id = bugs_activity.attach_id";
        $suppwhere = "AND COALESCE(attachments.isprivate, 0) = 0";
    }
    # For UNION longdescs_history
    push @args, $bug_id;

    my $query = "SELECT fielddefs.name, bugs_activity.attach_id, " .
        $dbh->sql_date_format('bugs_activity.bug_when', '%Y.%m.%d %H:%i:%s') .
            " bug_when, bugs_activity.removed, bugs_activity.added, profiles.login_name, null as comment_id, null as comment_count
        FROM bugs_activity
            $suppjoins
        LEFT JOIN fielddefs
            ON bugs_activity.fieldid = fielddefs.id
        INNER JOIN profiles
            ON profiles.userid = bugs_activity.who
        WHERE bugs_activity.bug_id = ?
            $datepart
            $attachpart
            $suppwhere
        UNION SELECT
            'longdesc', null, DATE_FORMAT(lh.bug_when, '%Y.%m.%d %H:%i:%s') bug_when, lh.oldthetext removed, lh.thetext added, profile1.login_name, lh.comment_id, lh.comment_count
        FROM longdescs_history lh
        INNER JOIN profiles profile1
            ON profile1.userid = lh.who
        WHERE lh.bug_id = ?
        ORDER BY bug_when
      ";

    my $list = $dbh->selectall_arrayref($query, undef, @args);

    my @operations;
    my $operation = {};
    my $changes = [];
    my $incomplete_data = 0;

    foreach my $entry (@$list)
    {
        my ($fieldname, $attachid, $when, $removed, $added, $who, $comment_id, $comment_count) = @$entry;
        my %change;
        my $activity_visible = 1;

        # check if the user should see this field's activity
        if ($fieldname eq 'remaining_time'
            || $fieldname eq 'estimated_time'
            || $fieldname eq 'work_time'
            || $fieldname eq 'deadline')
        {
            $activity_visible = Bugzilla->user->is_timetracker;
        }
        else
        {
            $activity_visible = 1;
        }

        if ($activity_visible)
        {
            # Check for the results of an old Bugzilla data corruption bug
            # FIXME This should probably be killed?
            if ($added =~ /^\?( |$)/ || $removed =~ /^\?( |$)/)
            {
                $incomplete_data = 1;
            }

            # An operation, done by 'who' at time 'when', has a number of
            # 'changes' associated with it.
            # If this is the start of a new operation, store the data from the
            # previous one, and set up the new one.
            if ($operation->{who} && ($who ne $operation->{who} || $when ne $operation->{when}))
            {
                $operation->{changes} = $changes;
                push @operations, $operation;

                # Create new empty anonymous data structures.
                $operation = {};
                $changes = [];
            }

            $operation->{who} = $who;
            $operation->{when} = $when;

            $change{fieldname} = $fieldname;
            $change{attachid} = $attachid;
            $change{removed} = $removed;
            $change{added} = $added;
            $change{comment_id} = $comment_id;
            $change{comment_count} = $comment_count;
            push @$changes, \%change;
        }
    }

    if ($operation->{who})
    {
        $operation->{changes} = $changes;
        push @operations, $operation;
    }

    return (\@operations, $incomplete_data);
}

# Write into additional log file for silent comments
sub SilentLog
{
    my ($bugid, $comment) = @_;
    my $datadir = bz_locations()->{datadir};
    my $fd;
    if (-w "$datadir/silentlog")
    {
        my $mesg = "";
        $comment =~ s/\r*\n+/|/gso;
        $mesg .= "Silent comment> " . time2str("%D %H:%M:%S ", time());
        $mesg .= " Bug $bugid User: " . Bugzilla->user->login;
        $mesg .= " (".remote_ip().") ";
        $mesg .= " // $comment ";
        if (open $fd, ">>$datadir/silentlog")
        {
            print $fd "$mesg\n";
            close $fd;
        }
    }
}

# Update the bugs_activity table to reflect changes made in bugs.
sub LogActivityEntry
{
    my ($bug_id, $col, $removed, $added, $whoid, $timestamp, $attach_id) = @_;
    my $f = Bugzilla->get_field($col);
    die "BUG: Invalid field passed to LogActivityEntry" if !$f;
    if (!$f->{has_activity})
    {
        $f->{has_activity} = 1;
        $f->update;
    }
    my $dbh = Bugzilla->dbh;
    $dbh->do(
        "INSERT INTO bugs_activity (bug_id, who, bug_when, fieldid, removed, added, attach_id)".
        " VALUES (?, ?, ".($timestamp ? "?" : "NOW()").", ?, ?, ?, ?)", undef,
        $bug_id, $whoid, ($timestamp ? ($timestamp) : ()), $f->id, $removed, $added, $attach_id
    );
}

# Convert WebService API and email_in.pl field names to internal DB field names.
sub map_fields
{
    my ($params) = @_;
    my %field_values;
    foreach my $field (keys %$params)
    {
        my $field_name = FIELD_MAP->{$field} || $field;
        $field_values{$field_name} = $params->{$field};
    }
    return \%field_values;
}

# CountOpenDependencies counts the number of open dependent bugs for a
# list of bugs and returns a list of bug_id's and their dependency count
# It takes one parameter:
#  - A list of bug numbers whose dependencies are to be checked
sub CountOpenDependencies
{
    my (@bug_list) = @_;

    my @dependencies;

    my $dbh = Bugzilla->dbh;
    my $sth = $dbh->prepare(
        "SELECT blocked, COUNT(bug_status) FROM bugs, bug_status, dependencies" .
        " WHERE " . $dbh->sql_in('blocked', \@bug_list) .
        " AND bugs.bug_id=dependson AND bugs.bug_status=bug_status.id AND bug_status.is_open=1" .
        $dbh->sql_group_by('blocked')
    );
    $sth->execute;

    while (my ($bug_id, $dependencies) = $sth->fetchrow_array)
    {
        push @dependencies, {
            bug_id       => $bug_id,
            dependencies => $dependencies,
        };
    }

    return @dependencies;
}

# If a bug is moved to a product which allows less votes per bug
# compared to the previous product, extra votes need to be removed.
sub RemoveVotes
{
    my ($id, $who, $reason) = (@_);

    my $dbh = Bugzilla->dbh;
    my $rows = $dbh->selectall_arrayref(
        "SELECT profiles.login_name, profiles.userid, votes.vote_count," .
        " products.votesperuser, products.maxvotesperbug FROM profiles" .
        " LEFT JOIN votes ON profiles.userid = votes.who" .
        " LEFT JOIN bugs ON votes.bug_id = bugs.bug_id" .
        " LEFT JOIN products ON products.id = bugs.product_id" .
        " WHERE votes.bug_id = ?" .
        ($who ? " AND votes.who = $who" : "")
    );

    # @messages stores all emails which have to be sent, if any.
    # This array is passed to the caller which will send these emails itself.
    my @messages = ();

    if (@$rows)
    {
        foreach my $ref (@$rows)
        {
            my ($name, $userid, $oldvotes, $votesperuser, $maxvotesperbug) = (@$ref);

            $maxvotesperbug = min($votesperuser, $maxvotesperbug);

            # If this product allows voting and the user's votes are in
            # the acceptable range, then don't do anything.
            next if $votesperuser && $oldvotes <= $maxvotesperbug;

            # If the user has more votes on this bug than this product
            # allows, then reduce the number of votes so it fits
            my $newvotes = $maxvotesperbug;

            my $removedvotes = $oldvotes - $newvotes;

            if ($newvotes)
            {
                $dbh->do(
                    "UPDATE votes SET vote_count = ? WHERE bug_id = ? AND who = ?",
                    undef, $newvotes, $id, $userid
                );
            }
            else
            {
                $dbh->do(
                    "DELETE FROM votes WHERE bug_id = ? AND who = ?",
                    undef, $id, $userid
                );
            }

            # Notice that we did not make sure that the user fit within the $votesperuser
            # range.  This is considered to be an acceptable alternative to losing votes
            # during product moves.  Then next time the user attempts to change their votes,
            # they will be forced to fit within the $votesperuser limit.

            # Now lets send the e-mail to alert the user to the fact that their votes have
            # been reduced or removed.
            my $vars = {
                to => $name . Bugzilla->params->{emailsuffix},
                bugid => $id,
                reason => $reason,
                votesremoved => $removedvotes,
                votesold => $oldvotes,
                votesnew => $newvotes,
            };

            my $voter = new Bugzilla::User($userid);
            my $template = Bugzilla->template_inner($voter->settings->{lang}->{value});

            my $msg;
            $template->process("email/votes-removed.txt.tmpl", $vars, \$msg);
            push @messages, $msg;
        }
        Bugzilla->template_inner('');

        my $votes = $dbh->selectrow_array(
            "SELECT SUM(vote_count) FROM votes WHERE bug_id = ?", undef, $id
        ) || 0;
        $dbh->do("UPDATE bugs SET votes = ? WHERE bug_id = ?", undef, $votes, $id);
    }

    # Now return the array containing emails to be sent.
    return @messages;
}

# If a user votes for a bug, or the number of votes required to
# confirm a bug has been reduced, check if the bug is now confirmed.
sub CheckIfVotedConfirmed
{
    my $id = shift;
    my $bug = new Bugzilla::Bug($id);

    my $ret = 0;
    if (!$bug->everconfirmed && $bug->product_obj->votes_to_confirm &&
        $bug->votes >= $bug->product_obj->votes_to_confirm)
    {
        $bug->add_comment('', { type => CMT_POPULAR_VOTES });

        if ($bug->bug_status eq 'UNCONFIRMED')
        {
            # Get a valid open state.
            my $new_status;
            foreach my $state (@{$bug->status->can_change_to})
            {
                if ($state->is_open && $state->name ne 'UNCONFIRMED')
                {
                    $new_status = $state->name;
                    last;
                }
            }
            ThrowCodeError('no_open_bug_status') unless $new_status;

            # We cannot call $bug->set_status() here, because a user without
            # canconfirm privs should still be able to confirm a bug by
            # popular vote. We already know the new status is valid, so it's safe.
            $bug->{bug_status} = $new_status;
            $bug->{everconfirmed} = 1;
            delete $bug->{status}; # Contains the status object.
        }
        else
        {
            # If the bug is in a closed state, only set everconfirmed to 1.
            # Do not call $bug->set(), for the same reason as above.
            $bug->{everconfirmed} = 1;
        }
        $bug->update();

        $ret = 1;
    }
    return $ret;
}

################################################################################
# check_can_change_field() defines what users are allowed to change. You
# can add code here for site-specific policy changes, according to the
# instructions given in the Bugzilla Guide and below. Note that you may also
# have to update the Bugzilla::Bug::user() function to give people access to the
# options that they are permitted to change.
#
# check_can_change_field() returns true if the user is allowed to change this
# field, and false if they are not.
#
# The parameters to this method are as follows:
# $field    - name of the field in the bugs table the user is trying to change
# $oldvalue - what they are changing it from
# $newvalue - what they are changing it to
# $PrivilegesRequired - return the reason of the failure, if any
################################################################################
sub check_can_change_field
{
    my $self = shift;
    my ($field, $oldvalue, $newvalue, $PrivilegesRequired) = (@_);
    my $user = Bugzilla->user;

    $oldvalue = defined($oldvalue) ? $oldvalue : '';
    $newvalue = defined($newvalue) ? $newvalue : '';

    # Return true if they haven't changed this field at all.
    if ($oldvalue eq $newvalue)
    {
        return 1;
    }
    elsif (ref($newvalue) eq 'ARRAY' && ref($oldvalue) eq 'ARRAY')
    {
        my ($removed, $added) = diff_arrays($oldvalue, $newvalue);
        return 1 if !scalar(@$removed) && !scalar(@$added);
    }
    elsif (trim($oldvalue) eq trim($newvalue))
    {
        return 1;
    }
    # numeric fields need to be compared using ==
    elsif (($field eq 'estimated_time' || $field eq 'remaining_time') && $oldvalue == $newvalue)
    {
        return 1;
    }

    # Allow anyone to change comments.
    if ($field =~ /^longdesc/)
    {
        return 1;
    }

    # If the user isn't allowed to change a field, we must tell him who can.
    # We store the required permission set into the $PrivilegesRequired
    # variable which gets passed to the error template.
    #
    # $PrivilegesRequired = 0 : no privileges required;
    # $PrivilegesRequired = 1 : the reporter, assignee or an empowered user;
    # $PrivilegesRequired = 2 : the assignee or an empowered user;
    # $PrivilegesRequired = 3 : an empowered user.

    # Only users in the time-tracking group can change time-tracking fields.
    if (grep { $_ eq $field } qw(deadline estimated_time remaining_time))
    {
        if (!$user->is_timetracker)
        {
            $$PrivilegesRequired = 3;
            return 0;
        }
    }

    # Allow anyone with (product-specific) "editbugs" privs to change anything.
    if ($user->in_group('editbugs', $self->{product_id}))
    {
        return 1;
    }

    # *Only* users with (product-specific) "canconfirm" privs can confirm bugs.
    if ($self->_changes_everconfirmed($field, $oldvalue, $newvalue))
    {
        $$PrivilegesRequired = 3;
        return $user->in_group('canconfirm', $self->{product_id});
    }

    # Allow the assignee to change anything else.
    if ($self->{assigned_to} == $user->id ||
        $self->{_old_self} && $self->{_old_self}->{assigned_to} == $user->id)
    {
        return 1;
    }

    # Allow the QA contact to change anything else.
    if (Bugzilla->params->{useqacontact} &&
        ($self->{qa_contact} && $self->{qa_contact} == $user->id ||
        $self->{_old_self} && $self->{_old_self}->{qa_contact} == $user->id))
    {
        return 1;
    }

    # At this point, the user is either the reporter or an
    # unprivileged user. We first check for fields the reporter
    # is not allowed to change.

    # The reporter may not:
    # - reassign bugs, unless the bugs are assigned to him;
    #   in that case we will have already returned 1 above
    #   when checking for the assignee of the bug.
    if ($field eq 'assigned_to')
    {
        $$PrivilegesRequired = 2;
        return 0;
    }
    # - change the QA contact
    if ($field eq 'qa_contact')
    {
        $$PrivilegesRequired = 2;
        return 0;
    }
    # - change the target milestone
    if ($field eq 'target_milestone')
    {
        $$PrivilegesRequired = 2;
        return 0;
    }
    # - change the priority (unless he could have set it originally)
    if ($field eq 'priority' && !Bugzilla->params->{letsubmitterchoosepriority})
    {
        $$PrivilegesRequired = 2;
        return 0;
    }
    # - unconfirm bugs (confirming them is handled above)
    if ($field eq 'everconfirmed')
    {
        $$PrivilegesRequired = 2;
        return 0;
    }
    # - change the status from one open state to another
    if ($field eq 'bug_status' && is_open_state($oldvalue) && is_open_state($newvalue))
    {
        $$PrivilegesRequired = 2;
        return 0;
    }

    # The reporter is allowed to change anything else.
    if ($self->{reporter_id} == $user->id)
    {
        return 1;
    }

    # If we haven't returned by this point, then the user doesn't
    # have the necessary permissions to change this field.
    $$PrivilegesRequired = 1;
    return 0;
}

# A helper for check_can_change_field
sub _changes_everconfirmed
{
    my ($self, $field, $old, $new) = @_;
    return 1 if $field eq 'everconfirmed';
    if ($field eq 'bug_status')
    {
        if ($self->everconfirmed)
        {
            # Moving a confirmed bug to UNCONFIRMED will change everconfirmed.
            return 1 if $new eq 'UNCONFIRMED';
        }
        else
        {
            # Moving an unconfirmed bug to an open state that isn't
            # UNCONFIRMED will confirm the bug.
            return 1 if (is_open_state($new) and $new ne 'UNCONFIRMED');
        }
    }
    return 0;
}

#
# Field Validation
#

# 1) Check bug dependencies for loops
# 2) Return recursive dependencies
sub ValidateDependencies
{
    my ($invocant, $dependson, $blocked) = @_;
    my $id = ref($invocant) ? $invocant->id : 0;
    return unless defined $dependson || defined $blocked;

    # These can be arrayrefs or they can be strings.
    my $fields = { dependson => $dependson, blocked => $blocked };
    for (qw(blocked dependson))
    {
        $fields->{$_} = [ split /[\s,]+/, $fields->{$_} ] if !ref $fields->{$_};
    }

    # Load dependencies from DB
    my $dbh = Bugzilla->dbh;
    my $closure = {
        blocked => { map { $_ => 1 } @{$fields->{blocked}} },
        dependson => { map { $_ => 1 } @{$fields->{dependson}} },
    };

    if ($closure->{blocked}->{$id} || $closure->{dependson}->{$id})
    {
        ThrowUserError('dependency_loop_single');
    }

    # We want to know on which bugs 'dependson' depends, so it's 'blocked' and vice versa
    my $stack = {
        blocked => { map { $_ => 1 } @{$fields->{dependson}} },
        dependson => { map { $_ => 1 } @{$fields->{blocked}} },
    };
    my ($rows, $old);
    while (%{$stack->{blocked}} || %{$stack->{dependson}})
    {
        # Ignore any current dependencies involving this bug,
        # as they will be overwritten with data from the form
        my $query = join(' OR ',
            map { "$_ IN (".join(',', map { int($_) } keys %{$stack->{$_}}).")" }
            grep { %{$stack->{$_}} } keys %$stack
        );
        $rows = $dbh->selectall_arrayref(
            "SELECT blocked, dependson FROM dependencies".
            " WHERE blocked != $id AND dependson != $id AND ($query)"
        );
        $old = $stack;
        $stack = { blocked => {}, dependson => {} };
        for (@$rows)
        {
            if ($old->{blocked}->{$_->[0]} && !$closure->{dependson}->{$_->[1]})
            {
                $stack->{blocked}->{$_->[1]} = 1;
                $closure->{dependson}->{$_->[1]} = 1;
            }
            if ($old->{dependson}->{$_->[1]} && !$closure->{blocked}->{$_->[0]})
            {
                $stack->{dependson}->{$_->[0]} = 1;
                $closure->{blocked}->{$_->[0]} = 1;
            }
        }
    }

    my @intersect = grep { $closure->{blocked}->{$_} } keys %{$closure->{dependson}};
    if (@intersect)
    {
        ThrowUserError('dependency_loop_multi', { deps => \@intersect });
    }

    # Remember closure, will be used to check BUG_ID add_to_deps custom fields
    return $closure;
}

#####################################################################
# Autoloaded Accessors
#####################################################################

use constant OVERRIDE_ID_FIELD => {
    product => 'product_id',
    component => 'component_id',
};

# Get value(s) of a select field as object(s)
sub get_object
{
    my $self = shift;
    my ($fn) = @_;
    my $attr = $fn.'_obj';
    return $self->{$attr} if exists $self->{$attr};
    my $field = Bugzilla->get_field($fn);
    $fn = OVERRIDE_ID_FIELD->{$fn} || $fn;
    if ($field && $field->type == FIELD_TYPE_SINGLE_SELECT)
    {
        $self->{$attr} = $self->{$fn} ? $field->value_type->new($self->{$fn}) : undef;
    }
    elsif ($field && $field->type == FIELD_TYPE_MULTI_SELECT)
    {
        $self->{$attr} = $field->value_type->new_from_list($self->$fn);
    }
    else
    {
        die "Invalid join requested - ".__PACKAGE__."::$attr";
    }
    return $self->{$attr};
}

# Determines whether an attribute access trapped by the AUTOLOAD function
# is for a valid bug attribute.  Bug attributes are properties and methods
# predefined by this module as well as bug fields for which an accessor
# can be defined by AUTOLOAD at runtime when the accessor is first accessed.
#
# FIXME Strangely, some predefined attributes are on the list, but others aren't,
# and the original code didn't specify why that is.  Presumably the only
# attributes that need to be on this list are those that aren't predefined;
# we should verify that and update the list accordingly.
#
sub _validate_attribute
{
    my ($attribute) = @_;

    my @valid_attributes = (
        # Miscellaneous properties and methods.
        qw(error groups product_id component_id
           comments milestoneurl attachments isopened
           flag_types num_attachment_flag_types
           show_attachment_flags any_flags_requesteeble),

        # Bug fields.
        Bugzilla::Bug->fields,

        map { $_->name.'_obj' } Bugzilla->get_fields({ type => [ FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT ] }),
    );

    return grep($attribute eq $_, @valid_attributes) ? 1 : 0;
}

sub AUTOLOAD
{
    use vars qw($AUTOLOAD);
    my $attr = $AUTOLOAD;

    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;
    if (!_validate_attribute($attr))
    {
        die "invalid bug attribute $attr";
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

        my $field = Bugzilla->get_field($attr);
        if ($field && $field->type == FIELD_TYPE_MULTI_SELECT)
        {
            $self->{$attr} ||= Bugzilla->dbh->selectcol_arrayref(
                "SELECT id FROM bug_$attr, $attr WHERE value_id=id AND bug_id=? ORDER BY value",
                undef, $self->id);
            return $self->{$attr};
        }

        return '';
    };

    goto &$AUTOLOAD;
}

1;
__END__
