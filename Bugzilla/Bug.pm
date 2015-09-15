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

use Bugzilla::Diff;
use Bugzilla::CheckerUtils;

use List::Util qw(min);
use Date::Format qw(time2str);
use POSIX qw(floor);
use Scalar::Util qw(blessed);

use base qw(Bugzilla::NewObject Exporter);
@Bugzilla::Bug::EXPORT = qw(RemoveVotes LogActivityEntry);

#####################################################################
# Constants
#####################################################################

use constant DB_TABLE   => 'bugs';
use constant ID_FIELD   => 'bug_id';
use constant NAME_FIELD => 'alias';
use constant LIST_ORDER => ID_FIELD;

sub DB_COLUMNS
{
    my $cache = Bugzilla->cache_fields;
    return @{$cache->{bug_columns}} if defined $cache->{bug_columns};

    my $dbh = Bugzilla->dbh;

    my @columns = qw(
        alias
        assigned_to
        bug_file_loc
        bug_id
        bug_severity
        bug_status
        cclist_accessible
        component_id
        creation_ts
        deadline
        delta_ts
        estimated_time
        everconfirmed
        priority
        product_id
        qa_contact
        remaining_time
        reporter
        reporter_accessible
        resolution
        short_desc
        status_whiteboard
        target_milestone
        version
    );
    # FIXME kill op_sys and rep_platform completely, make them custom fields
    push @columns, 'op_sys' if Bugzilla->get_field('op_sys')->enabled;
    push @columns, 'rep_platform' if Bugzilla->get_field('rep_platform')->enabled;
    push @columns, grep { $_ } map { $_->db_column } Bugzilla->active_custom_fields;

    Bugzilla::Hook::process('bug_columns', { columns => \@columns });

    $cache->{bug_columns} = \@columns;
    return @columns;
}

# Allow to update every valid DB column :-/
*UPDATE_COLUMNS = *DB_COLUMNS;

sub NUMERIC_COLUMNS
{
    my %columns = (
        estimated_time => 1,
        remaining_time => 1,
        (map { $_->db_column => 1 } Bugzilla->get_fields({ custom => 1, type => FIELD_TYPE_NUMERIC })),
    );
    return \%columns;
}

sub DATE_COLUMNS
{
    return { map { $_->db_column => 1 } Bugzilla->get_fields({ custom => 1, type => FIELD_TYPE_DATETIME }) };
}

# This is used by add_comment to know what we validate before putting in the DB
use constant UPDATE_COMMENT_COLUMNS => qw(
    thetext
    who
    bug_when
    work_time
    type
    extra_data
    isprivate
);

# This is used by get_object() to generate $self->product_obj and $self->component_obj
use constant OVERRIDE_ID_FIELD => {
    product => 'product_id',
    component => 'component_id',
};

use constant CUSTOM_FIELD_VALIDATORS => {
    FIELD_TYPE_FREETEXT()       => \&_set_freetext_field,
    FIELD_TYPE_EXTURL()         => \&_set_freetext_field,
    FIELD_TYPE_SINGLE_SELECT()  => \&_set_select_field,
    FIELD_TYPE_MULTI_SELECT()   => \&_set_multi_select_field,
    FIELD_TYPE_TEXTAREA()       => \&_set_default_field,
    FIELD_TYPE_DATETIME()       => \&_set_datetime_field,
    FIELD_TYPE_BUG_ID()         => \&_set_bugid_field,
    FIELD_TYPE_BUG_ID_REV()     => \&_set_bugid_rev_field,
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
        $s->{$field->name} = CUSTOM_FIELD_VALIDATORS->{$field->type};
    }

    $cache->{bug_setters} = $s;
    return $cache->{bug_setters};
};

# These dependencies specify in which order should setters be called for correct validation
sub DEPENDENCIES
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{bug_field_deps} if defined $cache->{bug_field_deps};

    # Hard-coded field dependencies:
    my $deps = {
        component        => {},
        target_milestone => {},
        version          => {},
        # And in fact ALL fields depend on product because all
        # access control and strict_isolation checks apply to products
    };

    foreach my $field (Bugzilla->get_fields({ obsolete => 1 }))
    {
        # Product may have classification value_field, but it's not
        # stored in bugs table so we shouldn't check it
        next if $deps->{$field->name} || $field->name eq 'product';
        for (qw(visibility_field value_field null_field))
        {
            $deps->{$field->name}->{$field->$_->name} = 1 if $field->$_;
        }
    }

    $cache->{bug_field_deps} = $deps;
    return $cache->{bug_field_deps};
}

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

use constant SCALAR_FORMAT => { map { $_ => 1 } qw(
    alias bug_file_loc bug_id dup_id cclist_accessible creation_ts deadline
    delta_ts estimated_time everconfirmed remaining_time reporter_accessible
    short_desc status_whiteboard votes
) };

use constant ARRAY_FORMAT => { map { $_ => 1 } qw(dependson blocked cc see_also) };

use constant USER_FORMAT => { map { $_ => 1 } qw(assigned_to qa_contact reporter) };

#####################################################################

sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my ($param, $return_error) = @_;

    # Constructor for an empty object
    if (!defined $param)
    {
        return bless {}, $class;
    }

    # Remove leading "#" mark if we've just been passed an id.
    if (!ref $param && $param =~ /^#(\d+)$/)
    {
        $param = $1;
    }

    # If we get something that looks like a word (not a number),
    # make it the "name" param.
    if (!ref $param && $param !~ /^\d+$/)
    {
        # But only if aliases are enabled.
        if (Bugzilla->get_field('alias')->enabled && $param)
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

# Check if a bug exists or throw an error
sub check_exists
{
    my ($class, $id) = @_;

    ThrowUserError('improper_bug_id_field_value') unless defined $id;

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
            ThrowUserError('improper_bug_id_field_value', { bug_id => $id });
        }
    }

    return $self;
}

# Check if a bug exists and is visible for the current user or throw an error
sub check
{
    my $class = shift;
    my ($id) = @_;
    my $self = $class->check_exists($id);
    $self->check_is_visible;
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
            my $objects = $type->match({ $param => $names });
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

# Bugzilla::Bug does not support separate create() method anymore.
# To create a bug, you must create an empty object by calling
# $bug = Bugzilla::Bug->new(), fill it using normal setters by calling
# $bug->set('<field>', <value>) and then call $bug->update().
# This approach is cleaner, simpler and allows to remove a lot of duplicate code.
sub create
{
    die "Bugzilla::Bug->create() is an old unsupported interface. Create an empty object and use Bugzilla::Bug->update().";
}

sub update
{
    my $self = shift;
    $self->make_dirty;

    my $method = $self->id ? 'update' : 'create';

    # First check dependent field values
    $self->check_dependent_fields;
    $self->check_strict_isolation;
    $self->check_votes;

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    # FIXME 'shift ||' is just a temporary hack until all updating happens inside this function
    my $delta_ts = shift || $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    # You can't set these fields by hand
    $self->{deadline} =~ s/\s+.*$//so;
    $self->{delta_ts} = $delta_ts;
    delete $self->{votes};
    delete $self->{lastdiffed};

    # Check/set default values
    $self->check_default_values if !$self->id;

    if ($method eq 'update')
    {
        Bugzilla::CheckerUtils::bug_pre_update({ bug => $self });
    }
    Bugzilla::Hook::process("bug_pre_$method", { bug => $self });

    my $old_bug = $self->{_old_self};
    my $changes;

    if ($self->id)
    {
        $old_bug->{deadline} =~ s/\s+.*$//so;
        $changes = $self->_do_update($self->{_old_self});
    }
    else
    {
        $changes = {};
        my $row = {};
        for my $f ($self->DB_COLUMNS)
        {
            next if $f eq 'bug_id';
            $row->{$f} = $self->{$f};
            trick_taint($row->{$f});
            $changes->{$f} = [ '', $row->{$f} ] if $row->{$f} ne '' &&
                (!NUMERIC_COLUMNS->{$f} || $row->{$f} != 0);
        }
        $dbh->do(
            'INSERT INTO '.$self->DB_TABLE.' (' . join(', ', keys %$row) .
            ') VALUES ('.join(', ', ('?') x keys %$row).")", undef, values %$row
        );
        $self->{$self->ID_FIELD} = $dbh->bz_last_key($self->DB_TABLE, $self->ID_FIELD);
    }

    # Transform IDs to names for the activity log
    $self->transform_id_changes($changes);
    delete $changes->{delta_ts};
    delete $changes->{lastdiffed};

    # Add previous assignee and QA to the CC list
    if ($changes->{qa_contact} && $old_bug && $old_bug->qa_contact)
    {
        $self->add_cc($old_bug->qa_contact);
    }
    if ($changes->{assigned_to} && $old_bug && $old_bug->assigned_to)
    {
        $self->add_cc($old_bug->assigned_to);
    }

    # Add/remove CC
    $self->save_cc($changes);

    # Dependencies (blocked, dependson)
    $self->save_dependencies($changes);

    # Groups
    $self->save_groups($changes);

    # Flags
    my ($removed, $added) = Bugzilla::Flag->update_flags(
        $self, $old_bug, $delta_ts,
        $self->{added_comments}->[0] && $self->{added_comments}->[0]->{thetext}
    );
    if ($removed || $added)
    {
        $changes->{'flagtypes.name'} = [ $removed, $added ];
    }

    # Add comments
    $self->save_added_comments($changes);

    # Save changed comments
    $self->save_changed_comments($changes);

    # Insert the values into the multiselect value tables
    $self->save_multiselects($changes);

    # Save reversed bug_id fields
    $self->save_reverse_bugid_fields($changes);

    # See Also
    $self->save_see_also($changes);

    # Save duplicate ID in 'duplicates' table
    $self->save_dup_id($changes);

    if ($method ne 'create')
    {
        # Log bugs_activity items
        foreach my $field (keys %$changes)
        {
            my $change = $changes->{$field};
            my $from = defined $change->[0] ? $change->[0] : '';
            my $to   = defined $change->[1] ? $change->[1] : '';
            LogActivityEntry($self->id, $field, $from, $to, Bugzilla->user->id, $delta_ts);
        }
    }

    Bugzilla::Hook::process("bug_end_of_$method", my $hook_args = {
        bug => $self,
        timestamp => $delta_ts,
        changes => $changes,
        old_bug => $old_bug,
    });
    $method eq 'update' ? Bugzilla::CheckerUtils::bug_end_of_update($hook_args) : Bugzilla::CheckerUtils::bug_end_of_create($hook_args);

    # The only problem with this here is that update() is usually called
    # in the middle of a transaction, and if that transaction is rolled
    # back, this change will *not* be rolled back. As we expect rollbacks
    # to be extremely rare, that is OK for us.
    if ($self->{added_comments} || $changes->{short_desc} ||
        $self->{comment_isprivate} || $self->{edited_comments})
    {
        $self->_sync_fulltext($method eq 'create');
    }

    # Prepare email notifications.
    $self->prepare_mail_results($changes);

    # Remove obsolete internal variables.
    delete $self->{_old_self};
    delete $self->{added_comments};
    delete $self->{edited_comments};

    # Also flush the visible_bugs cache for this bug as the user's
    # relationship with this bug may have changed.
    delete Bugzilla->user->{_visible_bugs_cache}->{$self->id};

    return $changes;
}

sub prepare_mail_results
{
    my $self = shift;
    my ($changes) = @_;

    my %notify_deps;
    if ($self->{_old_self} && $self->bug_status != $self->{_old_self}->bug_status)
    {
        my $old_status = $self->{_old_self}->bug_status_obj;
        my $new_status = $self->bug_status_obj;

        # If this bug has changed from opened to closed or vice-versa,
        # then all of the bugs we block need to be notified.
        if ($old_status->is_open != $new_status->is_open)
        {
            $notify_deps{$_} = 1 foreach @{$self->blocked};
        }

        # We may have zeroed the remaining time, if we moved into a closed
        # status, so we should inform the user about that.
        if (!$new_status->is_open && $changes->{remaining_time} &&
            !$changes->{remaining_time}->[1] &&
            Bugzilla->user->is_timetracker)
        {
            Bugzilla->add_result_message({ message => 'remaining_time_zeroed' });
        }
    }

    # To get a list of all changed dependencies, convert the "changes" arrays
    # into a long string, then collapse that string into unique numbers in
    # a hash.
    my $all_changed_deps = join(', ', @{ $changes->{dependson} || [] });
    $all_changed_deps = join(', ', @{ $changes->{blocked} || [] }, $all_changed_deps);
    my %changed_deps = map { $_ => 1 } split(', ', $all_changed_deps);
    # When clearing one field (say, blocks) and filling in the other
    # (say, dependson), an empty string can get into the hash and cause
    # an error later.
    delete $changed_deps{''};

    my $old_qa  = $changes->{qa_contact}  ? $changes->{qa_contact}->[0] : '';
    my $old_own = $changes->{assigned_to} ? $changes->{assigned_to}->[0] : '';
    my $old_cc  = $changes->{cc}          ? $changes->{cc}->[0] : '';

    # Let the user know the bug was changed and who did and didn't
    # receive email about the change.
    my $type = 'bug';
    if (!$self->{_old_self})
    {
        $type = 'created';
    }
    elsif ($self->{added_comments} && grep { ($_->{type} || CMT_NORMAL) == CMT_POPULAR_VOTES } @{$self->{added_comments}})
    {
        $type = 'votes';
    }
    else
    {
        $type = 'bug';
    }
    Bugzilla->add_result_message({
        message => 'bugmail',
        type => $type,
        bug_id => $self->id,
        mailrecipients => {
            cc        => [ split /[\s,]+/, $old_cc ],
            owner     => $old_own,
            qacontact => $old_qa,
            changer   => Bugzilla->user->login,
        },
    });

    # If the bug was marked as a duplicate, we need to notify users on the
    # other bug of any changes to that bug.
    my $new_dup_id = $changes->{dup_id} ? $changes->{dup_id}->[1] : undef;
    if ($new_dup_id)
    {
        # Let the user know a duplication notation was added to the original bug.
        Bugzilla->add_result_message({
            message => 'bugmail',
            mailrecipients => { changer => Bugzilla->user->login },
            bug_id => $new_dup_id,
            type => 'dupe',
        });
    }

    my %all_dep_changes = (%notify_deps, %changed_deps);
    foreach my $id (sort { $a <=> $b } (keys %all_dep_changes))
    {
        # Let the user (if he is able to see the bug) know we checked to
        # see if we should email notice of this change to users with a
        # relationship to the dependent bug and who did and didn't
        # receive email about it.
        Bugzilla->add_result_message({
            message => 'bugmail',
            type => 'dep',
            mailrecipients => { changer => Bugzilla->user->login },
            bug_id => $id,
        });
    }
}

# There is no guarantee that any setters were called after creating an
# empty object, so we must make sure all fields have allowed values.
sub check_default_values
{
    my $self = shift;
    # Check mandatory fields and/or set default values for new bugs
    for (qw(product component short_desc status_whiteboard assigned_to qa_contact reporter bug_file_loc))
    {
        $self->set($_, $self->$_);
    }
    # Remove NULLs for custom fields
    for my $field (Bugzilla->get_fields({ custom => 1, obsolete => 0 }))
    {
        if (!$self->{$field->db_column} && Bugzilla::Field->SQL_DEFINITIONS->{$field->type} &&
            Bugzilla::Field->SQL_DEFINITIONS->{$field->type}->{NOTNULL})
        {
            $self->set($field->name, undef);
        }
    }
    # Add some default values manually
    if (!$self->id && !exists $self->{groups_in})
    {
        # Add default product groups
        my @gids;
        my $controls = $self->product_obj->group_controls;
        foreach my $gid (keys %$controls)
        {
            if ($controls->{$gid}->{membercontrol} == CONTROLMAPDEFAULT && Bugzilla->user->in_group_id($gid) ||
                $controls->{$gid}->{othercontrol} == CONTROLMAPDEFAULT && !Bugzilla->user->in_group_id($gid))
            {
                push @gids, $gid;
            }
        }
        $self->{groups_in} = \@gids;
    }
    $self->set('groups', [ map { $_->id } @{$self->groups_in} ]);
    $self->{cc} = $self->component_obj->initial_cc if !$self->{cc};
    $self->{everconfirmed} ||= 0;
    $self->{estimated_time} ||= 0;
    $self->{remaining_time} ||= 0;
    $self->{reporter_accessible} = 1 if !defined $self->{reporter_accessible};
    $self->{cclist_accessible} = 1 if !defined $self->{cclist_accessible};
    $self->{creation_ts} = $self->{delta_ts} if !defined $self->{creation_ts};
}

# Check vote count after product change
sub check_votes
{
    my $self = shift;
    if ($self->id && $self->{_old_self}->product_id != $self->product_id)
    {
        my $votes = RemoveVotes($self->id, 0, 'votes_bug_moved');
        $self->{votes} = $votes if defined $votes;
        $self->check_if_voted_confirmed();
    }
}

# FIXME cache it
sub get_dependent_check_order
{
    my %seen = ();
    my %check = map { $_->id => $_ } grep {
        $_->type == FIELD_TYPE_SINGLE_SELECT
            # bug_status and resolution are checked by _check_*
            && $_->name ne 'bug_status' && $_->name ne 'resolution'
            # product may only depend on the classification, but
            # classification isn't stored in bugs table so we don't check it
            && $_->name ne 'product' ||
        $_->type == FIELD_TYPE_MULTI_SELECT ||
        # include these to check them for an empty value
        $_->name eq 'deadline' || $_->name eq 'status_whiteboard' || $_->name eq 'alias' ||
        $_->custom && $_->type != FIELD_TYPE_BUG_ID_REV
    } Bugzilla->get_fields({ obsolete => 0 });
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

    # Run some checks that previously were in old validators
    $self->_check_bug_status;
    $self->_check_resolution;
    $self->_check_dup_id;

    # Run remaining checks in the correct order!
    for my $field_obj (get_dependent_check_order())
    {
        my $fn = $field_obj->name;
        # Do not validate classification because it's not stored as a bug property
        next if $fn eq 'classification';
        if ($field_obj->obsolete)
        {
            # Do not validate values of obsolete fields, only set empty values for new bugs
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
        # Optionally add the value of BUG_ID custom field to dependencies (CustIS Bug 73054, Bug 75690)
        # This allows to see it as a part of the dependency tree
        if ($field_obj->type == FIELD_TYPE_BUG_ID && $field_obj->add_to_deps &&
            $self->{$fn} && $self->{$fn} != $self->id)
        {
            my $blk = $field_obj->add_to_deps == BUG_ID_ADD_TO_BLOCKED;
            my $to = $blk ? 'blocked' : 'dependson';
            # Get the dependencies from DB
            if (!$self->{dependency_closure})
            {
                $self->{dependency_closure} = ValidateDependencies($self, $self->dependson, $self->blocked);
            }
            # Add the bug if it isn't already in the dependency tree
            if (!$self->{dependency_closure}->{blocked}->{$self->{$fn}} &&
                !$self->{dependency_closure}->{dependson}->{$self->{$fn}})
            {
                push @{$self->{$to}}, $self->{$fn};
            }
        }
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
                    ThrowUserError('object_not_specified', { bug_id => $self->id, class => $field_obj->value_type, field => $field_obj });
                }
            }
            elsif ($field_obj->value_field_id)
            {
                my $vv = $self->get_ids($field_obj->value_field->name);
                my @bad = grep { !ref $_ || !$field_obj->is_value_enabled($_, $vv) } list($value_objs);
                if ($fn eq 'keywords')
                {
                    # Keywords are silently enabled for any new visibility value.
                    $field_obj->add_visibility_values($_->id, [ list $vv ]) for grep { ref $_ } @bad;
                    @bad = grep { !ref $_ } @bad;
                }
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
                ThrowUserError('object_does_not_exist', {
                    class => $field_obj->value_type,
                    name => $bad[0],
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

    # When moving bugs between products, verify groups
    my $verify_bug_groups = undef;
    if ($self->id && $self->{_old_self}->product_id != $self->product_id)
    {
        # FIXME Do not use input_params from Bugzilla::Bug
        if (!Bugzilla->input_params->{verify_bug_groups} &&
            Bugzilla->input_params->{id})
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
                undef, $self->id, $self->product_id, CONTROLMAPNA, CONTROLMAPNA);
            $verify_bug_groups = Bugzilla::Group->new_from_list($gids);
        }

        # Remove groups that aren't valid in the new product and add groups
        # that are mandatory in the new product. This will also have the
        # side effect of removing the bug from groups that aren't active anymore.
        $self->set('groups', [ map { $_->id } @{$self->groups_in} ]);
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
    if (Bugzilla->usage_mode == USAGE_MODE_BROWSER && (%$incorrect_fields || $verify_bug_groups && @$verify_bug_groups) && $self->id)
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

# FIXME It would be good for bug_status to depend on itself (i.e. on the previous value) and be validated using standard method
sub _check_bug_status
{
    my $self = shift;

    my $user = Bugzilla->user;
    my (@valid_statuses, $old_status);
    my $new_status = $self->bug_status_obj;
    my $product = $self->product_obj;

    # We can't use statuses_available because we check status transitions using an OLD value,
    # but we check assigned_to and allows_unconfirmed using NEW values.
    if ($self->{_old_self})
    {
        $old_status = $self->{_old_self}->bug_status_obj;
        @valid_statuses = @{$old_status->can_change_to};
    }
    else
    {
        @valid_statuses = @{Bugzilla::Status->can_change_to};
    }

    if (!$product->allows_unconfirmed)
    {
        @valid_statuses = grep { $_->is_confirmed } @valid_statuses;
    }

    my $allow_assigned = 1;
    if (!Bugzilla->params->{assign_to_others} && $self->assigned_to_id && $user->id != $self->assigned_to_id)
    {
        # You can not assign bugs to other people
        $allow_assigned = 0;
        @valid_statuses = grep { !$_->is_assigned } @valid_statuses;
    }

    # Check permissions for users filing new bugs
    if (!$self->id && (!$user->in_group('editbugs', $product->id) &&
        !$user->in_group('canconfirm', $product->id) || !$new_status))
    {
        # A user with no privs cannot choose the initial status.
        # If UNCONFIRMED is possible, use it; else use the first
        # bug status available.
        ($new_status) = grep { !$_->is_confirmed } @valid_statuses;
        if (!$new_status)
        {
            $new_status = $valid_statuses[0];
        }
        $self->set('bug_status', $new_status);
    }

    # We skip this check if we are changing from a status to itself.
    if ((!$old_status || $old_status->id != $new_status->id ||
        !$new_status->is_confirmed && !$product->allows_unconfirmed) &&
        !grep { $_->id == $new_status->id } @valid_statuses)
    {
        ThrowUserError('illegal_bug_status_transition', {
            old => $old_status,
            new => $new_status,
            allow_unconfirmed => $product->allows_unconfirmed,
            allow_assigned => $allow_assigned,
        });
    }

    # Check if a comment is required for this change (also for new bugs).
    # But honor only commentonduplicate if the bug was just marked as duplicate.
    if ((!$old_status || $new_status->comment_required_on_change_from($old_status)) && !@{$self->{added_comments} || []} &&
        (!$self->resolution || $self->resolution_obj->name ne Bugzilla->params->{duplicate_resolution} ||
        $self->{_old_self} && $self->{_old_self}->resolution eq $self->resolution || Bugzilla->params->{commentonduplicate}))
    {
        ThrowUserError('comment_required', { old => $old_status, new => $new_status });
    }

    # Check musthavemilestoneonaccept.
    if ($self->id && $new_status->is_assigned
        && Bugzilla->get_field('target_milestone')->enabled
        && Bugzilla->params->{musthavemilestoneonaccept}
        && !$self->target_milestone)
    {
        ThrowUserError('milestone_required', { bug => $self });
    }

    if ($new_status->is_open)
    {
        # Check for the everconfirmed transition
        if ($new_status->is_confirmed)
        {
            $self->{everconfirmed} = 1;
        }
        $self->set('resolution', undef);
    }
    else
    {
        # Changing between closed statuses zeroes the remaining time.
        if ($old_status && $new_status->id != $old_status->id && $self->remaining_time != 0)
        {
            $self->set('remaining_time', 0);
        }
    }
}

sub _check_resolution
{
    my $self = shift;

    # Throw a special error for resolving bugs without a resolution
    if (!$self->resolution && !$self->status->is_open)
    {
        ThrowUserError('missing_resolution', { status => $self->status->name });
    }

    if (!$self->{_old_self} && $self->resolution || $self->{_old_self} && ($self->resolution || 0) != ($self->{_old_self}->resolution || 0))
    {
        # Check noresolveonopenblockers.
        if (Bugzilla->params->{noresolveonopenblockers} && $self->resolution && @{$self->dependson})
        {
            my $ids = Bugzilla->dbh->selectcol_arrayref(
                "SELECT bug_id FROM bugs, bug_status WHERE " . Bugzilla->dbh->sql_in('bug_id', $self->dependson) .
                " AND bugs.bug_status=bug_status.id AND bug_status.is_open=1"
            );
            if (@$ids)
            {
                ThrowUserError('still_unresolved_bugs', {
                    dependencies     => $ids,
                    dependency_count => scalar @$ids,
                });
            }
        }

        # Check if they're changing the resolution and need to comment.
        # But honor only commentonduplicate if the bug was just marked as duplicate.
        if (Bugzilla->params->{commentonchange_resolution} && !@{$self->{added_comments} || []} &&
            (!$self->resolution || $self->resolution_obj->name ne Bugzilla->params->{duplicate_resolution} || Bugzilla->params->{commentonduplicate}))
        {
            ThrowUserError('comment_required');
        }

        # MOVED has a special meaning and can only be used when really moving bugs to another installation.
        # FIXME Remove hardcode MOVED resolution
        ThrowCodeError('no_manual_moved') if $self->resolution && $self->resolution_obj->name eq 'MOVED' && !$self->{moving};
    }

    # We don't check if we're entering or leaving the dup resolution here,
    # because we could be moving from being a dup of one bug to being a dup
    # of another, theoretically. Note that this code block will also run
    # when going between different closed states.
    if ($self->resolution && $self->resolution_obj->name eq Bugzilla->params->{duplicate_resolution})
    {
        if (!$self->dup_id)
        {
            ThrowUserError('dupe_id_required');
        }
        # Duplicates should have no remaining time left.
        if ($self->remaining_time != 0)
        {
            $self->set('remaining_time', 0);
        }
    }
    else
    {
        $self->set('dup_id', undef);
    }
}

sub _check_dup_id
{
    my $self = shift;

    my $cur_dup = $self->dup_id || 0;
    my $old_dup = $self->{_old_self} ? $self->{_old_self}->dup_id || 0 : 0;

    if ($cur_dup != $old_dup)
    {
        if (Bugzilla->params->{commentonduplicate} && !@{ $self->{added_comments} || [] })
        {
            ThrowUserError('comment_required');
        }

        if ($cur_dup)
        {
            # Make sure that we add a duplicate comment on *this* bug.
            # (Change an existing comment into a dup comment, if there is one, or add an empty dup comment)
            my @normal = grep { !defined $_->{type} || $_->{type} == CMT_NORMAL } @{ $self->{added_comments} || [] };
            if (@normal)
            {
                # Turn the last one into a dup comment.
                $normal[-1]->{type} = CMT_DUPE_OF;
                $normal[-1]->{extra_data} = $cur_dup;
            }
            else
            {
                $self->add_comment('', { type => CMT_DUPE_OF, extra_data => $cur_dup });
            }
        }
    }
}

sub transform_id_changes
{
    my ($self, $changes) = @_;

    # Transform select field value IDs to names
    if ($changes->{product_id})
    {
        $changes->{product} = [ $self->{_old_self} ? $self->{_old_self}->product_obj->name : '', $self->product_obj->name ];
        delete $changes->{product_id};
    }
    if ($changes->{component_id})
    {
        $changes->{component} = [ $self->{_old_self} ? $self->{_old_self}->component_obj->name : '', $self->component_obj->name ];
        delete $changes->{component_id};
    }
    for my $f (Bugzilla->get_fields({ type => FIELD_TYPE_SINGLE_SELECT }))
    {
        my $name = $f->name;
        next if $name eq 'product' || $name eq 'component' || $name eq 'classification' || !$changes->{$name};
        $changes->{$name}->[0] = $self->{_old_self}->get_string($name) if $changes->{$name}->[0];
        $changes->{$name}->[1] = $self->get_string($name) if $changes->{$name}->[1];
    }

    # Transform user IDs to names
    foreach my $field (qw(qa_contact assigned_to reporter))
    {
        if ($changes->{$field})
        {
            my $from = $self->{_old_self} ? $self->{_old_self}->$field : undef;
            my $to = $self->$field;
            $_ = $_ ? $_->login : '' for $from, $to;
            $changes->{$field} = [ $from, $to ];
        }
    }
}

sub save_cc
{
    my ($self, $changes) = @_;

    my %old_cc = $self->{_old_self} ? (map { $_->id => $_ } @{$self->{_old_self}->cc_users}) : ();
    my %new_cc = map { $_->id => $_ } @{$self->cc_users};

    # CustIS Bug 38616 - CC list restriction
    # FIXME Use strict_isolation
    if (my $ccg = $self->product_obj->cc_group)
    {
        $self->{restricted_cc} = [];
        for (values %new_cc)
        {
            if (!$_->in_group_id($ccg))
            {
                delete $new_cc{$_->id};
                push @{$self->{restricted_cc}}, $_;
            }
        }
        if (@{$self->{restricted_cc}})
        {
            Bugzilla->add_result_message({
                message => 'cc_list_restricted',
                restricted_cc => [ map { $_->login } @{ $self->{restricted_cc} } ],
                cc_restrict_group => $self->product_obj->cc_group_obj->name,
            });
        }
        else
        {
            $self->{restricted_cc} = undef;
        }
    }

    my $removed_cc = [ grep { !$new_cc{$_} } keys %old_cc ];
    my $added_cc = [ grep { !$old_cc{$_} } keys %new_cc ];
    if (scalar @$removed_cc)
    {
        Bugzilla->dbh->do('DELETE FROM cc WHERE bug_id = ? AND '.Bugzilla->dbh->sql_in('who', $removed_cc), undef, $self->id);
    }
    foreach my $user_id (@$added_cc)
    {
        Bugzilla->dbh->do('INSERT INTO cc (bug_id, who) VALUES (?,?)', undef, $self->id, $user_id);
    }

    # Remember changes to log them in activity table
    if (scalar @$removed_cc || scalar @$added_cc)
    {
        my $removed_names = join(', ', (map { $old_cc{$_}->login } @$removed_cc));
        my $added_names   = join(', ', (map { $new_cc{$_}->login } @$added_cc));
        $changes->{cc} = [ $removed_names, $added_names ];
    }
}

sub save_dependencies
{
    my ($self, $changes) = @_;

    my (@rm_deps, @add_deps, %touch_bugs);
    foreach my $pair ([qw(dependson blocked)], [qw(blocked dependson)])
    {
        my ($type, $other) = @$pair;
        my $old = $self->{_old_self} ? $self->{_old_self}->$type : [];
        my $new = $self->$type;
        my ($removed, $added) = diff_arrays($old, $new);
        for (@$removed)
        {
            push @rm_deps, { $type => $_, $other => $self->id };
            $touch_bugs{$_} = 1;
            LogActivityEntry($_, $other, $self->id, '', Bugzilla->user->id, $self->{delta_ts});
        }
        for (@$added)
        {
            push @add_deps, { $type => $_, $other => $self->id };
            $touch_bugs{$_} = 1;
            LogActivityEntry($_, $other, '', $self->id, Bugzilla->user->id, $self->{delta_ts});
        }
        if (scalar(@$removed) || scalar(@$added))
        {
            $changes->{$type} = [ join(', ', @$removed), join(', ', @$added) ];
        }
    }
    if (@rm_deps || @add_deps)
    {
        # Prevent races by deleting everything we insert (InnoDB helps us with gap locks)
        Bugzilla->dbh->do(
            'DELETE FROM dependencies WHERE (blocked, dependson) IN ('.
            join(', ', map { "($_->{blocked}, $_->{dependson})" } (@rm_deps, @add_deps)).')'
        );
    }
    if (@add_deps)
    {
        Bugzilla->dbh->do(
            'INSERT INTO dependencies (blocked, dependson) VALUES '.
            join(', ', map { "($_->{blocked}, $_->{dependson})" } @add_deps)
        );
    }
    if (%touch_bugs)
    {
        # Touch other bugs so that we trigger mid-airs
        # FIXME Maybe check it and trigger mid-air before updating?
        Bugzilla->dbh->do(
            'UPDATE bugs SET delta_ts=? WHERE bug_id IN ('.
            join(', ', keys %touch_bugs).')', undef, $self->{delta_ts}
        );
    }
}

sub save_reverse_bugid_fields
{
    my ($self, $changes) = @_;

    for my $field (Bugzilla->get_fields({ custom => 1, obsolete => 0, type => FIELD_TYPE_BUG_ID_REV }))
    {
        my $name = $field->name;
        next if !defined $self->{$name};
        my $vf = $field->value_field->name;
        my ($removed, $added) = diff_arrays($self->{_old_self} ? $self->{_old_self}->$name : [], $self->$name);
        my @up = (map { ($_, undef) } @$removed), (map { ($_, $self->id) } @$added);
        my $bug_obj = { map { $_->id => $_ } @{$self->{$name.'_obj'}} };
        # FIXME Maybe trigger mid-air collisions before updating?
        if (@$removed)
        {
            my $old_bugs = {};
            my $user = Bugzilla->user;
            if ($self->{_old_self} && $self->{_old_self}->{$name.'_obj'})
            {
                $old_bugs->{$_->id} = $_ for @{$self->{_old_self}->{$name.'_obj'}};
            }
            else
            {
                $old_bugs = { map { $_->id => $_ } Bugzilla::Bug->new_from_list($removed) };
            }
            for (@$removed)
            {
                $old_bugs->{$_}->check_is_visible;
                if (!$user->can_edit_bug($old_bugs->{$_}))
                {
                    ThrowUserError('illegal_change_bugid_rev_field', { field => $field, bug_id => $old_bugs->{$_}->id });
                }
            }
            Bugzilla->dbh->do(
                'UPDATE bugs SET delta_ts=?, '.$vf.'=NULL'.
                ' WHERE bug_id IN ('.join(', ', @$removed).')', undef, $self->{delta_ts}
            );
            for (@$removed)
            {
                LogActivityEntry($_, $vf, $self->id, '', Bugzilla->user->id, $self->{delta_ts});
            }
        }
        for (@$added)
        {
            $bug_obj->{$_}->set($vf, $self->id);
            $bug_obj->{$_}->update;
        }
    }
}

sub save_groups
{
    my ($self, $changes) = @_;

    my %old_groups = $self->{_old_self} ? (map { $_->id => $_ } @{$self->{_old_self}->groups_in}) : ();
    my %new_groups = map { $_->id => $_ } @{$self->groups_in};
    my ($removed_gr, $added_gr) = diff_arrays([ keys %old_groups ], [ keys %new_groups ] );
    if (scalar @$removed_gr || scalar @$added_gr)
    {
        if (@$removed_gr)
        {
            Bugzilla->dbh->do(
                'DELETE FROM bug_group_map WHERE bug_id=? AND group_id IN ('.
                join(',', ('?') x @$removed_gr).')', undef, $self->id, @$removed_gr
            );
        }
        if (@$added_gr)
        {
            Bugzilla->dbh->do(
                'INSERT INTO bug_group_map (bug_id, group_id) VALUES '.
                join(', ', ('(?, ?)') x @$added_gr), undef, (map { ($self->id, $_) } @$added_gr)
            );
        }
        my @removed_names = map { $old_groups{$_}->name } @$removed_gr;
        my @added_names   = map { $new_groups{$_}->name } @$added_gr;
        $changes->{bug_group} = [ join(', ', @removed_names), join(', ', @added_names) ];
    }
}

sub save_multiselects
{
    my ($self, $changes) = @_;

    my @multi_selects = Bugzilla->get_fields({ obsolete => 0, type => FIELD_TYPE_MULTI_SELECT });
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
                join_escaped(', ', ',', map { $old{$_}->name } @$removed),
                join_escaped(', ', ',', map { $new{$_}->name } @$added),
            ];
            Bugzilla->dbh->do("DELETE FROM ".$field->rel_table." WHERE bug_id = ?", undef, $self->id);
            if (@{$self->$name})
            {
                Bugzilla->dbh->do(
                    "INSERT INTO ".$field->rel_table." (bug_id, value_id) VALUES ".
                    join(',', ('(?, ?)') x @{$self->$name}),
                    undef, map { ($self->id, $_) } @{$self->$name}
                );
            }
        }
    }
}

sub save_see_also
{
    my ($self, $changes) = @_;

    my ($removed_see, $added_see) = diff_arrays($self->{_old_self} ? $self->{_old_self}->see_also : [], $self->see_also);
    if (scalar @$removed_see)
    {
        Bugzilla->dbh->do(
            'DELETE FROM bug_see_also WHERE bug_id = ? AND '
            . Bugzilla->dbh->sql_in('value', [('?') x @$removed_see]),
            undef, $self->id, @$removed_see
        );
    }
    foreach my $url (@$added_see)
    {
        Bugzilla->dbh->do('INSERT INTO bug_see_also (bug_id, value) VALUES (?, ?)', undef, $self->id, $url);
    }
    if (scalar @$removed_see || scalar @$added_see)
    {
        $changes->{see_also} = [ join(', ', @$removed_see), join(', ', @$added_see) ];
    }
}

sub save_dup_id
{
    my ($self, $changes) = @_;

    # Check if we have to update the duplicates table and the other bug.
    my ($old_dup, $cur_dup) = ($self->{_old_self} ? $self->{_old_self}->dup_id || 0 : 0, $self->dup_id || 0);
    if ($old_dup != $cur_dup)
    {
        Bugzilla->dbh->do("DELETE FROM duplicates WHERE dupe = ?", undef, $self->id);
        if ($cur_dup)
        {
            Bugzilla->dbh->do('INSERT INTO duplicates (dupe, dupe_of) VALUES (?, ?)', undef, $self->id, $cur_dup);
            if (my $update_dup = delete $self->{_dup_for_update})
            {
                $update_dup->update();
            }
        }
        $changes->{dup_id} = [ $old_dup || undef, $cur_dup || undef ];
    }
}

sub save_added_comments
{
    my ($self, $changes) = @_;

    delete $self->{comments} if @{$self->{added_comments} || []};
    foreach my $comment (@{$self->{added_comments} || []})
    {
        # FIXME Do not use input_params from Bugzilla::Bug
        if (Bugzilla->input_params->{commentsilent} &&
            Bugzilla->params->{allow_commentsilent})
        {
            # Log silent comments
            SilentLog($self->id, $comment->{thetext});
        }
        $comment->{bug_id} = $self->id;
        $comment->{who} ||= Bugzilla->user->id;
        $comment->{bug_when} = $self->{delta_ts} if !$comment->{bug_when} || $comment->{bug_when} gt $self->{delta_ts};
        my $columns = join(',', keys %$comment);
        my $qmarks = join(',', ('?') x keys %$comment);
        Bugzilla->dbh->do("INSERT INTO longdescs ($columns) VALUES ($qmarks)", undef, values %$comment);
        if (0+$comment->{work_time} != 0)
        {
            # Log worktime
            $changes->{work_time} ||= [ '', 0 ];
            $changes->{work_time}->[1] += $comment->{work_time};
        }
    }
}

sub save_changed_comments
{
    my ($self, $changes) = @_;

    # FIXME Merge following loops
    foreach my $comment_id (keys %{$self->{comment_isprivate} || {}})
    {
        Bugzilla->dbh->do(
            "UPDATE longdescs SET isprivate=? WHERE comment_id=?",
            undef, $self->{comment_isprivate}->{$comment_id}, $comment_id
        );
        # FIXME It'd be nice to track this in the bug activity.
    }

    foreach my $comment_id (keys %{$self->{comment_type} || {}})
    {
        Bugzilla->dbh->do(
            "UPDATE longdescs SET type=? WHERE comment_id=?",
            undef, $self->{comment_type}->{$comment_id}, $comment_id
        );
        # FIXME It'd be nice to track this in the bug activity.
    }

    # Save changed comments
    foreach my $edited_comment (@{$self->{edited_comments} || []})
    {
        my $c_comment = Bugzilla::Comment->new($edited_comment->{comment_id});
        if (!$c_comment->is_private || Bugzilla->user->is_insider)
        {
            Bugzilla->dbh->do(
                "UPDATE longdescs SET thetext = ? WHERE comment_id = ?",
                undef, $edited_comment->{thetext}, $edited_comment->{comment_id}
            );
            $edited_comment->{bug_id} = $self->id;
            $edited_comment->{who} = Bugzilla->user->id;
            $edited_comment->{bug_when} = $self->{delta_ts};
            # number count of the comment
            my ($comment_count) = Bugzilla->dbh->selectrow_array(
                'SELECT count(*) FROM longdescs WHERE bug_id = ? AND comment_id <= ? ORDER BY bug_when ASC',
                undef, $self->id, $edited_comment->{comment_id}
            );
            $edited_comment->{comment_count} = ($comment_count-1);
            my $columns = join(',', keys %$edited_comment);
            my @values  = values %$edited_comment;
            my $qmarks  = join(',', ('?') x @values);
            Bugzilla->dbh->do("INSERT INTO longdescs_history ($columns) VALUES ($qmarks)", undef, @values);
        }
    }
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
            if ($self->$_ && !$self->$_->in_group_id($ccg))
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
            $related_users{$self->$_->id} ||= $self->$_;
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
    # Determine if we are using Sphinx or MySQL/PostgreSQL/SQLite fulltext search
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
        $id_field = $dbh->FULLTEXT_ID_FIELD;
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

    $dbh->do("DELETE FROM bugs WHERE bug_id = ?", undef, $self->id);

    # The only table that requires manual delete cascading is bugs_fulltext (MyISAM)
    $dbh->do("DELETE FROM bugs_fulltext WHERE ".$dbh->FULLTEXT_ID_FIELD." = ?", undef, $self->id);

    # Now this bug no longer exists
    $self->DESTROY;
    return $self;
}

#####################################################################
# Validators/setters
#####################################################################

# Set all field values from $params
sub set_all
{
    my ($self, $params) = @_;
    if (!$self->product || $params->{product})
    {
        # First set product because all access control checks depend on it
        $self->set('product', delete $params->{product});
    }
    $self->SUPER::set_all($params);
}

sub _set_alias
{
    my ($self, $alias) = @_;
    $alias = trim($alias);
    return undef if !Bugzilla->get_field('alias')->enabled;
    return $self->{alias} = undef if !$alias;

    # Make sure the alias isn't too long.
    if (length($alias) > 255)
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
    if ($other_bug && (!$self->id || $other_bug->id != $self->id))
    {
        ThrowUserError('alias_in_use', { alias => $alias, bug_id => $other_bug->id });
    }

    return $alias;
}

sub _set_assigned_to
{
    my ($self, $assignee) = @_;

    my $user = Bugzilla->user;

    my $is_new = !$self->id;
    if ($is_new && (!$user->in_group('editbugs', $self->product_id) || !$assignee))
    {
        # If this is a new bug, you can only set the assignee if you have editbugs.
        # If you didn't specify the assignee, we use the default assignee.
        $self->{assigned_to_obj} = $self->component_obj && $self->component_obj->default_assignee;
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

    return $self->{assigned_to_obj} && $self->{assigned_to_obj}->id;
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

sub _set_bug_status
{
    my ($self, $new_status) = @_;

    # Time to validate the bug status.
    $new_status = Bugzilla::Status->check($new_status) unless ref $new_status;

    $self->{status} = $new_status;
    delete $self->{statuses_available};

    return $new_status->id;
}

sub _set_cc
{
    my ($self, $ccs) = @_;

    # Allow comma-separated input as well as arrayrefs.
    $ccs = [ grep { $_ } split /[\s,]+/, trim($ccs) ] if !ref $ccs;
    my $users = Bugzilla::User->match({ login_name => $ccs });
    $ccs = { map { lc($_) => 1 } @$ccs };
    for (@$users)
    {
        delete $ccs->{lc $_->login};
    }
    ($ccs) = keys %$ccs;
    if ($ccs)
    {
        ThrowUserError('invalid_username', { name => $ccs });
    }

    $self->{cc_users} = $users;
    return undef;
}

sub _set_component
{
    my ($self, $name) = @_;
    my $obj;
    if (!ref $name)
    {
        $name = trim($name);
        $name || ThrowUserError('require_component');
        # Don't allow to set invalid components for new bugs
        my $m = $self->id ? 'new' : 'check';
        $obj = Bugzilla::Component->$m({ product => $self->product_obj, name => $name });
    }
    else
    {
        $obj = $name;
    }
    if (!$obj)
    {
        $self->{_unknown_dependent_values}->{component} = [ $name ];
        return undef;
    }
    if (($self->component_id || 0) != $obj->id)
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
    if (!$date || $date =~ /^0000-00-00/)
    {
        $self->{deadline} = undef;
        return undef;
    }

    $date =~ s/\s+.*//s;
    validate_date($date) || ThrowUserError('illegal_date', { date => $date, format => 'YYYY-MM-DD' });
    return $date;
}

sub _set_dup_id
{
    my ($self, $dupe_of) = @_;

    $dupe_of = defined $dupe_of ? trim($dupe_of) : undef;
    if (($dupe_of || 0) == ($self->dup_id || 0))
    {
        return undef;
    }
    if (!$dupe_of)
    {
        return $self->{dup_id} = undef;
    }

    # Validate the bug ID and check visibility.
    my $dupe_of_bug = Bugzilla::Bug->check_exists($dupe_of);
    $dupe_of = $dupe_of_bug->id;

    # If the dupe is unchanged, we have nothing more to check.
    return $dupe_of if $self->dup_id && $self->dup_id == $dupe_of;

    $dupe_of_bug->check_is_visible;

    # Make sure a loop isn't created when marking this bug as duplicate.
    my %dupes;
    my $this_dup = $dupe_of;
    my $add_dup_cc;
    my $dbh = Bugzilla->dbh;
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
        # FIXME Do not use input_params from Bugzilla::Bug
        # If we've already confirmed whether the user should be added...
        my $add_confirmed = Bugzilla->input_params->{confirm_add_duplicate};
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

    return $dupe_of;
}

sub _set_groups
{
    my ($self, $group_ids) = @_;

    my $user = Bugzilla->user;

    my %new_groups;
    my $controls = $self->product_obj->group_controls;

    foreach my $id (@$group_ids)
    {
        my $group = new Bugzilla::Group($id) || ThrowUserError('invalid_group_ID');

        unless ($group->is_active && $group->is_bug_group)
        {
            ThrowCodeError('inactive_group', { name => $group->name })
        }

        my $membercontrol = $controls->{$id} && $controls->{$id}->{membercontrol};
        my $othercontrol  = $controls->{$id} && $controls->{$id}->{othercontrol};

        my $permit = $user->in_group($group->name) ? $membercontrol : $othercontrol;

        # Format for $self->groups and $self->groups_in
        if ($permit)
        {
            $new_groups{$id} = {
                bit => $id,
                name => $group->name,
                ison => 1,
                ingroup => $user->in_group_id($id),
                mandatory => $permit == CONTROLMAPMANDATORY,
                description => $group->description,
            };
        }
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
            $new_groups{$id} = {
                bit => $id,
                name => $controls->{$id}->{group}->name,
                ison => 1,
                ingroup => $user->in_group_id($id),
                mandatory => 1,
                description => $controls->{$id}->{group}->description,
            };
        }
        elsif ($user->in_group_id($id) && !$new_groups{$id})
        {
            # Group is disabled, add for $self->groups consistency
            $new_groups{$id} = {
                bit => $id,
                name => $controls->{$id}->{group}->name,
                ison => 0,
                ingroup => 1,
                mandatory => 0,
                description => $controls->{$id}->{group}->description,
            };
        }
    }

    $self->{groups_in} = [ map { $controls->{$_->{bit}}->{group} } grep { $_->{ison} } values %new_groups ];
    $self->{groups} = [ values %new_groups ];
    return undef;
}

# For keyword autocreation:
# set('keywords', { 'keywords' => 'kw1, kw2, ...', 'descriptions' => { kw1 => 'desc1', ... } }
sub _set_keywords
{
    my ($self, $data) = @_;

    $data = { keywords => $data, descriptions => {} } if !ref $data;

    my $old = $self->get_object('keywords');
    my $new = $old;

    my $privs;
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
            if ($keyword_string ne '')
            {
                $keyword_string = [ split /[\s,]*,[\s,]*/, $keyword_string ];
                my $kw = Bugzilla::Keyword->match({ value => $keyword_string });
                $kw = { map { lc($_->name) => $_ } @$kw };
                for my $name (@$keyword_string)
                {
                    if (!$kw->{lc $name} && $data->{descriptions}->{$name})
                    {
                        # CustIS Bug 66910 - Keyword autocreation
                        my $obj = Bugzilla::Keyword->create({
                            value => $name,
                            description => $data->{descriptions}->{$name},
                        });
                        $kw->{lc $name} = $obj;
                    }
                }
                $new = [ values %$kw ];
            }
            else
            {
                $new = [];
            }
        }
        # Make sure we retain the sort order.
        $new = [ sort { lc($a->name) cmp lc($b->name) } @$new ];
        $self->{keywords_obj} = $new;
        $self->{keywords} = [ map { $_->id } @$new ];
    }
    else
    {
        # Silently ignore the error
#        ThrowUserError('illegal_change', {
#            field    => 'keywords',
#            oldvalue => $self->get_string('keywords'),
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
    if ($self->product_obj && $self->product_obj->name eq $name)
    {
        return undef;
    }
    # Check that the product exists and that the user
    # is allowed to enter bugs into this product.
    Bugzilla->user->can_enter_product($name, THROW_ERROR);
    # can_enter_product already does everything that Bugzilla::Product->check
    # would do for us, so we don't need to use it.
    my $product = new Bugzilla::Product({ name => $name });
    if (($self->product_id || 0) != $product->id)
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
        $priority = undef;
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
        # Bugs get no QA Contact on creation if qa_contact is off.
        return undef if !Bugzilla->get_field('qa_contact')->enabled;

        # Set the default QA Contact if one isn't specified or if the
        # user doesn't have editbugs.
        if (!Bugzilla->user->in_group('editbugs', $self->product_id) || !$qa_contact)
        {
            $self->{qa_contact_obj} = $self->component_obj && $self->component_obj->default_qa_contact;
            $id = $self->{qa_contact_obj} && $self->{qa_contact_obj}->id;
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
        $reporter = $self->reporter;
    }
    else
    {
        # On bug creation, the reporter is the logged in user
        # (meaning that he must be logged in first!).
        $reporter = Bugzilla->user;
        $reporter || ThrowCodeError('invalid_user');
    }
    if ($reporter && $self->id)
    {
        # CustIS Bug 38616
        # FIXME Use strict_isolation
        # Clean reporter when moving external bug into internal product with protected CC group
        my $ccg = $self->product_obj->cc_group;
        if ($ccg && !$reporter->in_group_id($ccg))
        {
            ThrowUserError('cc_group_restriction', { user => $reporter->login });
        }
    }
    $self->{reporter_obj} = $reporter;
    return $reporter->id;
}

sub _set_resolution
{
    my ($self, $resolution) = @_;
    $resolution = trim($resolution) || undef;
    return $self->_set_select_field($resolution, 'resolution');
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
    if (!Bugzilla->get_field('target_milestone')->enabled)
    {
        # Don't change value if the field is disabled
        return undef;
    }
    $target = trim($target);
    my $field_obj = Bugzilla->get_field('target_milestone');
    if (!defined $target || $target eq '')
    {
        $self->{target_milestone_obj} = undef;
        $self->{target_milestone} = undef;
        return undef;
    }
    # FIXME use set_select_field
    my $object = Bugzilla::Milestone->new({ product => $self->product_obj, name => $target });
    if (!$object)
    {
        $self->{_unknown_dependent_values}->{target_milestone} = [ $target ];
        return undef;
    }
    $self->{target_milestone_obj} = $object;
    return $object->id;
}

sub _set_version
{
    my ($self, $version) = @_;
    $version = trim($version);
    my $field_obj = Bugzilla->get_field('version');
    if (!$field_obj->enabled)
    {
        return undef;
    }
    if (!defined $version || $version eq '')
    {
        $self->{version_obj} = undef;
        $self->{version} = undef;
        return undef;
    }
    # FIXME use set_select_field
    my $object = Bugzilla::Version->new({ product => $self->product_obj, name => $version });
    if (!$object)
    {
        $self->{_unknown_dependent_values}->{version} = [ $version ];
        return undef;
    }
    $self->{version_obj} = $object;
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
    if (!$self->id && $self->remaining_time == 0 && $v)
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
    if (!$self->id && $v == 0 && $self->estimated_time != 0)
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
    if (($date_time || '') =~ /^[\s0[:punct:]]*$/)
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
    ($text) = (($text || 0) =~ /^(-?\d+(\.\d+)?)$/so);
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
    $values = defined $values ? [ $values ] : [] if !ref $values;
    if (!$values || !@$values)
    {
        $self->{$field.'_obj'} = [];
        return [];
    }
    my $field_obj = Bugzilla->get_field($field);
    my $t = $field_obj->value_type;
    my $value_objs = $t->match({ $t->NAME_FIELD => $values });
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
    my $t = $field_obj->value_type;
    if (!defined $value || !length $value)
    {
        # We allow empty values only for nullable or invisible fields,
        # but it's done later in check_dependent_fields when the
        # visibility status is known for sure.
        $self->{_unknown_dependent_values}->{$field} = undef;
        $self->{$field.'_obj'} = undef;
        return $self->{$field} = undef;
    }
    my $value_obj = ref $value ? $value : $t->new({ name => $value });
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
        $r = Bugzilla::Bug->check($value)->id;
    }

    return $r;
}

sub _set_bugid_rev_field
{
    my ($self, $bug_ids, $field) = @_;
    return [] if !$bug_ids;
    $bug_ids = [ $bug_ids ] if !ref $bug_ids;
    $self->{$field.'_obj'} = Bugzilla::Bug->new_from_list($bug_ids);
    my $user = Bugzilla->user;
    for my $bug (@{$self->{$field.'_obj'}})
    {
        $bug->check_is_visible;
        if (!$user->can_edit_bug($bug))
        {
            ThrowUserError('illegal_change_bugid_rev_field', { field => $field, bug_id => $bug->id });
        }
    }
    return [ map { $_->id } @{ $self->{$field.'_obj'} } ];
}

#############################################################
# Custom setters - add/remove something, edit comments, etc #
#############################################################

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

sub set_flags
{
    my ($self, $flags, $new_flags) = @_;
    $self->make_dirty;
    Bugzilla::Flag->set_flag($self, $_) foreach @$flags, @$new_flags;
}

# Takes hashref with two comma/space-separated strings, like:
# { dependson => string|arrayref, blocked => string|arrayref }
# This can't be a normal setter because $self has no getter for 'dependencies',
# and it is required by check_field_permission.
sub set_dependencies
{
    my ($self, $deps_in) = @_;

    if (!$self->id && !Bugzilla->user->in_group('editbugs', $self->product_id))
    {
        # Only editbugs users can set dependencies on bug entry.
        return undef;
    }

    $self->make_dirty;

    foreach my $type (qw(dependson blocked))
    {
        my @bugs = ref($deps_in->{$type}) ? @{$deps_in->{$type}} : split(/[\s,]+/, $deps_in->{$type});
        # Eliminate nulls.
        @bugs = grep { $_ } @bugs;
        # We do this up here to make sure all aliases are converted to IDs.
        @bugs = map { Bugzilla::Bug->check_exists($_) } @bugs;

        my %check_access;
        my @bug_ids = map { $_->id } @bugs;

        # When we're updating a bug, only added or removed bug_ids are
        # checked for whether or not we can see/edit those bugs.
        if ($self->id)
        {
            my $old = $self->$type;
            my ($removed, $added) = diff_arrays($old, \@bug_ids);
            %check_access = map { $_ => 1 } @$added, @$removed;
        }
        else
        {
            %check_access = map { $_->id => 1 } @bugs;
        }

        # Check field permissions if we've changed anything.
        if (%check_access)
        {
            my $privs;
            if (!$self->check_can_change_field($type, 0, 1, \$privs))
            {
                ThrowUserError('illegal_change', { field => $type, privs => $privs });
            }
        }

        my $user = Bugzilla->user;
        foreach my $delta_bug (@bugs)
        {
            if ($check_access{$delta_bug->id})
            {
                $delta_bug->check_is_visible;
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

# Accepts a User object or a username. Adds the user only if they
# don't already exist as a CC on the bug.
sub add_cc
{
    my ($self, $user_or_name) = @_;
    return if !$user_or_name;
    my $user = ref $user_or_name ? $user_or_name : Bugzilla::User->check($user_or_name);
    my $cc_users = $self->cc_users;
    if (!grep { $_->id == $user->id } @$cc_users)
    {
        $self->make_dirty;
        push @$cc_users, $user;
    }
}

# Accepts a User object or a username. Removes the User if they exist
# in the list, but doesn't throw an error if they don't exist.
sub remove_cc
{
    my ($self, $user_or_name) = @_;
    my $user = ref $user_or_name ? $user_or_name : Bugzilla::User->check($user_or_name);
    my $cc_users = $self->cc_users;
    if (grep { $_->id == $user->id } @$cc_users)
    {
        $self->make_dirty;
        @$cc_users = grep { $_->id != $user->id } @$cc_users;
    }
}

sub _check_comment_text
{
    my ($text) = @_;
    $text = '' unless defined $text;

    # Remove any trailing whitespace. Leading whitespace could be
    # a valid part of the comment.
    $text =~ s/\s*$//s;
    $text =~ s/\r\n?/\n/g; # Get rid of \r.

    ThrowUserError('comment_too_long') if length $text > MAX_COMMENT_LENGTH;

    return $text;
}

# $bug->add_comment('<text>', { work_time => 0, isprivate => 0, type => CMT_WORKTIME });
sub add_comment
{
    my ($self, $text, $params) = @_;

    $params ||= {};
    $params->{thetext} = _check_comment_text($text);

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
        # FIXME validate SuperWorkTime privileges
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

    $self->make_dirty;

    $self->{added_comments} ||= [];

    # We only want to copy fields that we know about - we don't want
    # to accidentally let somebody set some field that's not OK to set!
    my $add_comment = {};
    foreach my $field (UPDATE_COMMENT_COLUMNS)
    {
        if (defined $params->{$field})
        {
            $add_comment->{$field} = $params->{$field};
            trick_taint($add_comment->{$field});
        }
    }
    push @{$self->{added_comments}}, $add_comment;

    return undef;
}

# Edit a comment
sub edit_comment
{
    my ($self, $comment_id, $comment) = @_;

    my ($db_comment) = grep { $comment_id == $_->id } @{ $self->comments };
    # Only allow to edit bug description or user's own comments,
    # and only if it is not private or if the user is the insider
    if (!$db_comment || $db_comment->is_private && !Bugzilla->user->is_insider)
    {
        ThrowUserError('comment_id_invalid', { id => $comment_id });
    }
    elsif ($db_comment->{count} && $db_comment->who != Bugzilla->user->id)
    {
        ThrowUserError('comment_invalid_edit', { id => $comment_id });
    }

    my $old_comment = $db_comment->body;
    $comment = _check_comment_text($comment);

    if ($old_comment ne $comment)
    {
        $self->make_dirty;
        $self->{edited_comments} ||= [];
        push @{$self->{edited_comments}}, {
            comment_id => $comment_id,
            oldthetext => $old_comment,
            thetext => $comment,
        };
    }
}

# Edit comment 'isprivate' flag
sub set_comment_is_private
{
    my ($self, $comment_id, $isprivate) = @_;
    return unless Bugzilla->user->is_insider;
    my ($comment) = grep { $comment_id == $_->id } @{ $self->comments };
    ThrowUserError('comment_invalid_isprivate', { id => $comment_id }) if !$comment;
    $isprivate = $isprivate ? 1 : 0;
    if ($isprivate != $comment->is_private)
    {
        $self->make_dirty;
        $self->{comment_isprivate} ||= {};
        $self->{comment_isprivate}->{$comment_id} = $isprivate;
    }
}

# Make comment 'worktimeonly' or back normal
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
        $self->make_dirty;
        $self->{comment_type}->{$comment_id} = $type;
    }
}

# $action: one of 'add', 'delete', or 'makeexact' (default)
sub modify_keywords
{
    my ($self, $keywords, $descriptions, $action) = @_;
    $keywords = [ split /[\s,]*,[\s,]*/, $keywords ] if !ref $keywords;
    if ($action eq 'delete')
    {
        my $old_kw = $self->keywords_obj;
        my $kw = { map { lc($_->name) => $_ } @$old_kw };
        delete $kw->{lc $_} for @$keywords;
        $self->set('keywords', { keyword_objects => [ values %$kw ] });
    }
    else
    {
        if ($action eq 'add')
        {
            push @$keywords, map { $_->name } @{$self->get_object('keywords')};
        }
        $self->set('keywords', {
            keywords => join(', ', @$keywords),
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
        next if $line =~ /^#/;
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
        $self->make_dirty;
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
    $self->make_dirty;
    $self->{see_also} = \@new_see_also;
}

#####################################################################
# Instance Accessors
#####################################################################

# These subs are in alphabetical order, as much as possible.
# If you add a new sub, please try to keep it in alphabetical order
# with the other ones.

sub name
{
    my $self = shift;
    return $self->alias && Bugzilla->get_field('alias')->enabled ? $self->alias : $self->id;
}

sub dup_id
{
    my ($self) = @_;
    return $self->{dup_id} if exists $self->{dup_id};
    $self->{dup_id} = undef;
    if ($self->resolution_obj && $self->resolution_obj->name eq Bugzilla->params->{duplicate_resolution} && $self->id)
    {
        my $dbh = Bugzilla->dbh;
        $self->{dup_id} = $dbh->selectrow_array(
            "SELECT dupe_of FROM duplicates WHERE dupe = ?",
            undef, $self->id
        );
    }
    return $self->{dup_id};
}

sub deadline
{
    my ($self) = @_;
    my $s = $self->{deadline} || '';
    $s =~ s/\s+.*//s;
    return $s eq '0000-00-00' ? '' : $s;
}

sub actual_time
{
    my ($self) = @_;
    return $self->{actual_time} if exists $self->{actual_time} || !$self->id;

    if (!Bugzilla->user->is_timetracker)
    {
        $self->{actual_time} = undef;
        return $self->{actual_time};
    }

    ($self->{actual_time}) = Bugzilla->dbh->selectrow_array(
        "SELECT SUM(work_time) FROM longdescs WHERE longdescs.bug_id=?",
        undef, $self->id
    );
    return $self->{actual_time};
}

sub estimated_time
{
    my ($self) = @_;
    return format_time_decimal($self->{estimated_time} || 0);
}

sub remaining_time
{
    my ($self) = @_;
    return format_time_decimal($self->{remaining_time} || 0);
}

sub any_flags_requesteeble
{
    my ($self) = @_;
    # FIXME flush it when setting flags?
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
    return [] if !$self->id;

    $self->{attachments} = Bugzilla::Attachment->get_attachments_by_bug($self->id, { preload => 1 });
    return $self->{attachments};
}

# FIXME Try to load 'blocked' and 'dependson' using one query
sub blocked
{
    my ($self) = @_;
    return $self->{blocked} if exists $self->{blocked};
    return [] if !$self->id;
    $self->{blocked} = EmitDependList('dependson', 'blocked', $self->id);
    return $self->{blocked};
}

sub dependson
{
    my ($self) = @_;
    return $self->{dependson} if exists $self->{dependson};
    return [] if !$self->id;
    $self->{dependson} = EmitDependList('blocked', 'dependson', $self->id);
    return $self->{dependson};
}

sub bug_id { $_[0]->{bug_id} }

sub failed_checkers { $_[0]->{failed_checkers} }

sub cc
{
    my ($self) = @_;
    return [ map { $_->login } @{$self->cc_users} ];
}

# FIXME Eventually this will become the standard "cc" method used everywhere.
sub cc_users
{
    my $self = shift;
    return $self->{cc_users} if exists $self->{cc_users};
    return $self->{cc_users} = [] if !$self->id;

    my $dbh = Bugzilla->dbh;
    my $cc_ids = $dbh->selectcol_arrayref('SELECT who FROM cc WHERE bug_id = ?', undef, $self->id);
    $self->{cc_users} = Bugzilla::User->new_from_list($cc_ids);
    return $self->{cc_users};
}

# FIXME This should eventually be replaced by the "product_obj" subroutine.
sub product
{
    my ($self) = @_;
    return $self->product_obj && $self->product_obj->name;
}

sub component
{
    my ($self) = @_;
    return $self->component_obj && $self->component_obj->name;
}

sub classification_id
{
    my ($self) = @_;
    return $self->product_obj && $self->product_obj->classification_id;
}

sub classification_obj
{
    my ($self) = @_;
    return $self->product_obj && $self->product_obj->classification_obj;
}

sub classification
{
    my ($self) = @_;
    return $self->product_obj && $self->product_obj->classification_obj->name;
}

sub flag_types
{
    my ($self) = @_;
    return $self->{flag_types} if exists $self->{flag_types};

    my $vars = {
        target_type  => 'bug',
        product_id   => $self->{product_id},
        component_id => $self->{component_id},
        bug_id       => $self->id,
        bug_obj      => $self,
    };

    $self->{flag_types} = Bugzilla::Flag->_flag_types($vars);

    return $self->{flag_types};
}

sub flags
{
    my $self = shift;

    # FIXME (Is it true?) Don't cache it as it must be in sync with ->flag_types.
    $self->{flags} = [ map { @{$_->{flags}} } @{$self->flag_types} ];
    return $self->{flags};
}

sub isopened
{
    my $self = shift;
    return $self->bug_status_obj->is_open;
}

sub comments
{
    my ($self, $params) = @_;
    return [] if !$self->id;

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

sub assigned_to_id
{
    return $_[0]->{assigned_to};
}

sub qa_contact_id
{
    return $_[0]->{qa_contact};
}

sub reporter_id
{
    return $_[0]->{reporter};
}

sub assigned_to
{
    my ($self) = @_;
    return $self->{assigned_to_obj} if exists $self->{assigned_to_obj} || !$self->{assigned_to};
    $self->{assigned_to_obj} ||= new Bugzilla::User($self->{assigned_to});
    return $self->{assigned_to_obj};
}

sub qa_contact
{
    my ($self) = @_;
    return $self->{qa_contact_obj} if exists $self->{qa_contact_obj} || !$self->{qa_contact};
    if (Bugzilla->get_field('qa_contact')->enabled && $self->{qa_contact})
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
    return $self->{reporter_obj} if exists $self->{reporter_obj} || !$self->{reporter};
    $self->{reporter_obj} ||= new Bugzilla::User($self->{reporter});
    return $self->{reporter_obj};
}

sub see_also
{
    my ($self) = @_;
    return $self->{see_also} if $self->{see_also};
    return [] if !$self->id;
    $self->{see_also} = Bugzilla->dbh->selectcol_arrayref('SELECT value FROM bug_see_also WHERE bug_id = ?', undef, $self->id);
    return $self->{see_also};
}

sub status
{
    my $self = shift;
    return undef if !$self->{bug_status};
    if (!$self->{status})
    {
        ($self->{status}) = grep { $_->id == $self->{bug_status} } Bugzilla::Status->get_all(1);
    }
    return $self->{status};
}
*bug_status_obj = *status;

# This is ONLY intended for presenting the available choices to user,
# but NOT for the server-side validation (see _check_bug_status).
sub statuses_available
{
    my $self = shift;
    return $self->{statuses_available} if defined $self->{statuses_available};

    my @statuses = @{ $self->status->can_change_to };

    # UNCONFIRMED is only a valid status if it is enabled in this product.
    if (!$self->product_obj->allows_unconfirmed)
    {
        @statuses = grep { $_->is_confirmed } @statuses;
    }

    # *Only* users with (product-specific) "canconfirm" privs can confirm bugs.
    if (!$self->status->is_confirmed && !Bugzilla->user->in_group('canconfirm', $self->product_id))
    {
        @statuses = grep { !$_->is_confirmed } @statuses;
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
        bug_id       => $self->id,
    });

    $self->{show_attachment_flags} = $num_attachment_flag_types || $num_attachment_flags;

    return $self->{show_attachment_flags};
}

sub use_votes
{
    my ($self) = @_;
    return Bugzilla->get_field('votes')->enabled && $self->product_obj->votes_per_user > 0;
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
        " CASE WHEN bug_group_map.group_id IS NOT NULL THEN 1 ELSE 0 END," .
        " CASE WHEN groups.id IN ($grouplist) THEN 1 ELSE 0 END," .
        " isactive, membercontrol, othercontrol" .
        " FROM groups" .
        " LEFT JOIN bug_group_map ON bug_group_map.group_id = groups.id AND bug_id = ?" .
        " LEFT JOIN group_control_map ON group_control_map.group_id = groups.id" .
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
        || (Bugzilla->get_field('qa_contact')->enabled && $self->{qa_contact} && $user->id == $self->{qa_contact});
    my $canconfirm = $unknown_privileges || $user->in_group('canconfirm', $prod_id);
    my $isreporter = $user->id && $user->id == $self->{reporter};

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
        $dbh->sql_group_by('bug_id'), undef, $self->id
    );
    $self->{votes} ||= 0;
    return $self->{votes};
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
        push @user_ids, map { $_->id } @{$self->cc_users};
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
        WHERE p.is_enabled = 1 AND p.disable_mail = 0 AND p.userid in (".join(",", @user_ids).")
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

# Join with bug_status and bugs tables to show bugs with open statuses first, and then the others
sub EmitDependList
{
    my ($myfield, $targetfield, $bug_id) = (@_);
    my $dbh = Bugzilla->dbh;
    my $list_ref = $dbh->selectcol_arrayref(
        "SELECT $targetfield FROM dependencies".
        " INNER JOIN bugs ON dependencies.$targetfield = bugs.bug_id".
        " INNER JOIN bug_status ON bugs.bug_status = bug_status.id".
        " WHERE $myfield = ?".
        " ORDER BY is_open DESC, $targetfield",
        undef, $bug_id
    );
    return $list_ref;
}

sub ValidateTime
{
    my ($time, $field) = @_;

    $time = trim($time) || 0;
    $time =~ tr/,/./;

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

sub get_activity
{
    my $self = shift;
    return GetBugActivity($self->id, @_);
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
        $datepart = "AND a.bug_when > ?";
    }

    my $attachpart = "";
    if ($attach_id)
    {
        push @args, $attach_id;
        $attachpart = "AND a.attach_id = ?";
    }
    else
    {
        # For UNION longdescs_history
        push @args, $bug_id;
        push @args, $starttime if defined $starttime;
    }

    # Only includes attachments the user is allowed to see.
    my $suppjoins = "";
    my $suppwhere = "";
    if (!Bugzilla->user->is_insider)
    {
        $suppjoins = "LEFT JOIN attachments ON attachments.attach_id = a.attach_id";
        $suppwhere = "AND COALESCE(attachments.isprivate, 0) = 0";
    }

    my $query =
        "SELECT fielddefs.name field_name, fielddefs.sortkey field_desc, a.attach_id, " . $dbh->sql_date_format('a.bug_when') .
            " bug_when, a.removed, a.added, profiles.login_name, null AS comment_id, null AS comment_count" .
        " FROM bugs_activity a $suppjoins".
        " LEFT JOIN fielddefs ON a.fieldid = fielddefs.id".
        " INNER JOIN profiles ON profiles.userid = a.who".
        " WHERE a.bug_id = ? $datepart $attachpart $suppwhere";
    if (!$attach_id)
    {
        $query = "$query UNION ALL SELECT 'longdesc' field_name, 0 field_desc, null, " . $dbh->sql_date_format('a.bug_when') .
            " bug_when, a.oldthetext removed, a.thetext added, profile1.login_name, a.comment_id, a.comment_count".
            " FROM longdescs_history a".
            " INNER JOIN profiles profile1 ON profile1.userid = a.who".
            " WHERE a.bug_id = ? $datepart";
    }
    $query .= " ORDER BY bug_when, field_desc";

    my $list = $dbh->selectall_arrayref($query, undef, @args);

    my @operations;
    my $operation = {};
    my $changes = [];
    my $incomplete_data = 0;

    foreach my $entry (@$list)
    {
        my ($fieldname, $fielddesc, $attachid, $when, $removed, $added, $who, $comment_id, $comment_count) = @$entry;
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

    for (my $i = 0; $i < scalar @operations; $i++)
    {
        my $lines = 0;
        for (my $j = 0; $j < scalar @{$operations[$i]{changes}}; $j++)
        {
            my $change = $operations[$i]{changes}[$j];
            my $field = Bugzilla->get_field($change->{fieldname});
            if ($change->{fieldname} eq 'longdesc' || $field->{type} eq FIELD_TYPE_TEXTAREA)
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

# If a bug is moved to a product which allows less votes per bug
# compared to the previous product, extra votes need to be removed.
sub RemoveVotes
{
    my ($id, $who, $reason) = (@_);

    my $dbh = Bugzilla->dbh;
    my $rows = $dbh->selectall_arrayref(
        "SELECT profiles.userid, votes.vote_count," .
        " products.votesperuser, products.maxvotesperbug FROM profiles" .
        " LEFT JOIN votes ON profiles.userid = votes.who" .
        " LEFT JOIN bugs ON votes.bug_id = bugs.bug_id" .
        " LEFT JOIN products ON products.id = bugs.product_id" .
        " WHERE votes.bug_id = ?" .
        ($who ? " AND votes.who = ?" : ""), undef, $id, ($who ? $who : ())
    );

    if (@$rows)
    {
        my $mails = [];
        foreach my $ref (@$rows)
        {
            my ($userid, $oldvotes, $votesperuser, $maxvotesperbug) = (@$ref);

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
            push @$mails, {
                userid => $userid,
                reason => $reason,
                votesremoved => $removedvotes,
                votesold => $oldvotes,
                votesnew => $newvotes,
            };
        }
        if (@$mails)
        {
            Bugzilla->add_result_message({
                message => 'votes-removed',
                bug_id => $id,
                notify_data => $mails,
            });
        }

        my $votes = $dbh->selectrow_array(
            "SELECT SUM(vote_count) FROM votes WHERE bug_id = ?", undef, $id
        ) || 0;
        $dbh->do("UPDATE bugs SET votes = ? WHERE bug_id = ?", undef, $votes, $id);
        return $votes;
    }
    return undef;
}

# If a user votes for a bug, or the number of votes required to
# confirm a bug has been reduced, check if the bug is now confirmed.
sub check_if_voted_confirmed
{
    my $bug = shift;
    my $ret = 0;
    if (!$bug->everconfirmed && $bug->product_obj->votes_to_confirm &&
        $bug->votes >= $bug->product_obj->votes_to_confirm)
    {
        $bug->add_comment('', { type => CMT_POPULAR_VOTES });

        if (!$bug->bug_status_obj->is_confirmed)
        {
            # Get a valid open state.
            my $new_status;
            foreach my $state (@{$bug->status->can_change_to})
            {
                if ($state->is_open && $state->is_confirmed)
                {
                    $new_status = $state->name;
                    last;
                }
            }
            ThrowCodeError('no_open_bug_status') unless $new_status;

            # We cannot call $bug->set() here, because a user without
            # canconfirm privs should still be able to confirm a bug by
            # popular vote. We already know the new status is valid, so it's safe.
            $bug->{bug_status} = $new_status;
            $bug->{everconfirmed} = 1;
            delete $bug->{status}; # Contains the status object.
            $ret = 1;
        }
        else
        {
            # If the bug is in a closed state, only set everconfirmed to 1.
            # Do not call $bug->set(), for the same reason as above.
            $bug->{everconfirmed} = 1;
        }
    }
    return $ret;
}

# FIXME Find a better way of checking per-field permissions,
# because it's not so good to parse old/new values one more time in check_can_change_field...
sub _check_field_permission
{
    my ($self, $field) = @_;
    my $old = $self->{_old_self} ? $self->{_old_self}->$field : undef;
    my $value = $self->$field;
    my $privs;
    my $can = $self->check_can_change_field($field, $old, $value, \$privs);
    if (!$can)
    {
        if ($field eq 'assigned_to' || $field eq 'qa_contact')
        {
            $old = $self->{_old_self} && $self->{_old_self}->$field;
            $value = $self->$field;
            $_ = $_ && $_->login for $old, $value;
        }
        ThrowUserError('illegal_change', {
            field    => $field,
            oldvalue => $old,
            newvalue => $value,
            privs    => $privs,
        });
    }
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

    # Parse values
    for ($oldvalue, $newvalue)
    {
        if (!defined $_)
        {
            $_ = '';
        }
        elsif (!ref $_)
        {
            $_ = trim($_);
        }
        elsif (ref $_ eq 'ARRAY')
        {
            $_ = [ map { blessed $_ && $_->isa('Bugzilla::Object') ? $_->id : $_ } @$_ ];
        }
        elsif (blessed $_ && $_->isa('Bugzilla::Object'))
        {
            $_ = $_->id;
        }
    }

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
    # numeric fields need to be compared using ==
    elsif (($field eq 'estimated_time' || $field eq 'remaining_time') && $oldvalue == $newvalue)
    {
        return 1;
    }

    # Allow anyone to change comments.
    if ($field eq 'longdesc')
    {
        return 1;
    }

    # Allow anyone with (product-specific) "editbugs" privs to change anything.
    if ($user->in_group('editbugs', $self->{product_id}))
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

    # *Only* users with (product-specific) "canconfirm" privs can confirm bugs.
    if ($field eq 'bug_status' && !$self->everconfirmed &&
        grep { $newvalue eq $_->name && !$_->is_confirmed } @{ Bugzilla->get_field('bug_status')->legal_values })
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
    if (Bugzilla->get_field('qa_contact')->enabled &&
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
    if ($field eq 'bug_status' &&
        (grep { $_->is_open && $_->name eq $oldvalue } Bugzilla::Status->get_all) &&
        (grep { $_->is_open && $_->name eq $newvalue } Bugzilla::Status->get_all))
    {
        $$PrivilegesRequired = 2;
        return 0;
    }

    # The reporter is allowed to change anything else.
    if ($self->{reporter} == $user->id)
    {
        return 1;
    }

    # If we haven't returned by this point, then the user doesn't
    # have the necessary permissions to change this field.
    $$PrivilegesRequired = 1;
    return 0;
}

#
# Procedural helper, used in importxls.cgi and email_in.pl
#

# Create or update a bug
sub create_or_update
{
    my ($fields_in) = @_;
    my $bug = $fields_in->{bug_id} && Bugzilla::Bug->new(delete $fields_in->{bug_id}) || Bugzilla::Bug->new;
    # We still rely on product and component being set first
    my @set_fields = (
        (exists $fields_in->{product} || !$bug->id ? 'product' : ()),
        (exists $fields_in->{component} || !$bug->id ? 'component' : ()),
        (grep {
            $_ ne 'product' && $_ ne 'component' && $_ ne 'comment' && $_ ne 'work_time' &&
            $_ ne 'blocked' && $_ ne 'dependson'
        } keys %$fields_in)
    );
    # Allow comma-separated values for multi-selects
    for my $f (Bugzilla->get_fields({ type => FIELD_TYPE_MULTI_SELECT, obsolete => 0 }))
    {
        $f = $f->name;
        # FIXME: Can't autocreate keywords from this function
        if ($f ne 'keywords' && defined $fields_in->{$f} && !ref $fields_in->{$f})
        {
            $fields_in->{$f} = [ split ',', $fields_in->{$f} ];
        }
    }
    $bug->set($_ => $fields_in->{$_}) for @set_fields;
    if (exists $fields_in->{comment})
    {
        $bug->add_comment($fields_in->{comment}, {
            work_time => $fields_in->{work_time},
        });
        delete $fields_in->{comment};
        delete $fields_in->{work_time};
    }
    if (exists $fields_in->{blocked} || exists $fields_in->{dependson})
    {
        $fields_in->{blocked} ||= join ',', @{ $bug->blocked };
        $fields_in->{dependson} ||= join ',', @{ $bug->dependson };
        $bug->set_dependencies({ dependson => $fields_in->{dependson}, blocked => $fields_in->{blocked} });
        delete $fields_in->{blocked};
        delete $fields_in->{dependson};
    }
    $bug->update;
    return $bug;
}

#
# Field Validation
#

# 1) Check bug dependencies for loops
# 2) Return recursive dependencies
sub ValidateDependencies
{
    my ($invocant, $dependson, $blocked) = @_;
    my $id = ref($invocant) ? $invocant->id || 0 : 0;
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

# Get id(s) of value(s) of a select field
sub get_ids
{
    my $self = shift;
    my ($fn) = @_;
    my $field = Bugzilla->get_field($fn);
    $fn = $field->name;
    $fn = OVERRIDE_ID_FIELD->{$fn} || $fn;
    if ($field && $field->type == FIELD_TYPE_SINGLE_SELECT)
    {
        return $self->{$fn};
    }
    elsif ($field && ($field->type == FIELD_TYPE_MULTI_SELECT || $field->type == FIELD_TYPE_BUG_ID_REV))
    {
        return $self->$fn;
    }
    else
    {
        die "Invalid join requested - ".__PACKAGE__."::$fn";
    }
}

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
    elsif ($field && $field->type == FIELD_TYPE_BUG_ID_REV)
    {
        $self->{$attr} = Bugzilla::Bug->new_from_list($self->$fn);
    }
    else
    {
        die "Invalid join requested - ".__PACKAGE__."::$attr";
    }
    return $self->{$attr};
}

# Format value(s) of a field in plain text
sub get_string
{
    my $self = shift;
    my ($field) = @_;
    my $f = ref $field ? $field->name : $field;
    $field = Bugzilla->get_field($field) if !ref $field;
    my $value;
    if ($field && $field->type == FIELD_TYPE_SINGLE_SELECT)
    {
        $value = $self->get_object($f);
        $value = $value && $value->name;
    }
    elsif ($field && $field->type == FIELD_TYPE_MULTI_SELECT)
    {
        $value = join ', ', map { $_->name } @{$self->get_object($f)};
    }
    elsif ($field && $field->type == FIELD_TYPE_BUG_ID_REV)
    {
        $value = join ', ', @{ $self->$f };
    }
    elsif (ARRAY_FORMAT->{$f})
    {
        $value = join ', ', @{$self->$f};
    }
    elsif (USER_FORMAT->{$f})
    {
        $value = $self->$f && $self->$f->login;
    }
    elsif ($field && $field->type != FIELD_TYPE_UNKNOWN || SCALAR_FORMAT->{$f})
    {
        $value = $self->$f;
    }
    elsif ($f eq 'bug_group')
    {
        $value = join ', ', map { $_->name } @{$self->groups_in};
    }
    elsif ($f eq 'work_time')
    {
        $value = $self->actual_time;
    }
    else
    {
        warn "Don't know how to format field in text: $f";
        return '';
    }
    return $value;
}

# Get attribute value in the default format
sub get_value
{
    my ($self, $attr) = @_;
    my $field = Bugzilla->get_field($attr);

    if (defined $self->{$attr})
    {
        $self->{$attr} =~ s/((\.\d*[1-9])|\.)0+$/$2/so if $field && $field->type == FIELD_TYPE_NUMERIC;
        return $self->{$attr};
    }

    if ($attr =~ /^(.*)_obj$/s)
    {
        return $self->get_object($1);
    }

    if ($field)
    {
        if ($field->type == FIELD_TYPE_MULTI_SELECT)
        {
            $self->{$attr} ||= Bugzilla->dbh->selectcol_arrayref(
                "SELECT id FROM bug_$attr, $attr WHERE value_id=id AND bug_id=? ORDER BY value",
                undef, $self->id);
            return $self->{$attr};
        }
        elsif ($field->type == FIELD_TYPE_BUG_ID_REV)
        {
            $self->{$attr} ||= Bugzilla->dbh->selectcol_arrayref(
                "SELECT bug_id FROM bugs WHERE ".$field->value_field->name." = ".$self->id
            );
            return $self->{$attr};
        }
    }

    return '';
}

# FIXME WTF this is needed for? bugzilla.dtd? maybe it should be autogenerated?
sub fields
{
    my $class = shift;

    my @fields =
    (
        $class->DB_COLUMNS,

        # Fields not listed in DB columns
        qw(component product classification classification_id
           dup_id see_also dependson blocked votes cc actual_time),

        # Multi-select and BUG_ID_REV custom fields (also not in DB columns)
        map { $_->name } Bugzilla->get_fields({
            obsolete => 0,
            custom => 1,
            type => [ FIELD_TYPE_MULTI_SELECT, FIELD_TYPE_BUG_ID_REV ],
        }),
    );
    Bugzilla::Hook::process('bug_fields', { fields => \@fields });

    return @fields;
}

# Determines whether an attribute access may be trapped by the AUTOLOAD function
# is for a valid bug attribute. Bug attributes are properties and methods
# predefined by this module as well as bug fields for which an accessor
# can be defined by AUTOLOAD at runtime when the accessor is first accessed.
sub _validate_attribute
{
    my ($attr) = @_;

    my $cache = Bugzilla->cache_fields;
    if (!$cache->{valid_bug_attributes})
    {
        # Field data may change, but we generate methods on the fly anyway,
        # so don't care about refreshing this value on a per-request basis
        $cache->{valid_bug_attributes} = {
            # every DB column may be returned via an autoloaded accessor
            (map { $_ => 1 } Bugzilla::Bug->DB_COLUMNS),
            # multiselect, bug_id_rev fields
            (map { $_->name => 1 } Bugzilla->get_fields({ type => [ FIELD_TYPE_MULTI_SELECT, FIELD_TYPE_BUG_ID_REV ] })),
            # get_object accessors
            (map { $_->name.'_obj' => 1 } Bugzilla->get_fields({ type => [ FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT ] })),
        };
    }

    return $cache->{valid_bug_attributes}->{$attr} ? 1 : 0;
}

our $AUTOLOAD;
sub AUTOLOAD
{
    my $attr = $AUTOLOAD;

    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;

    if (!_validate_attribute($attr))
    {
        die "invalid bug attribute $attr";
    }

    no strict 'refs';
    *$AUTOLOAD = sub { $_[0]->get_value($attr) };
    goto &$AUTOLOAD;
}

1;
__END__
