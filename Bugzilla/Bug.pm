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
#                 Elliotte Martin <elliotte_martin@yahoo.com>
#                 Christian Legnitto <clegnitto@mozilla.com>

package Bugzilla::Bug;

use utf8;
use strict;

use Bugzilla::Attachment;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Flag;
use Bugzilla::FlagType;
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
use Bugzilla::BugUrl;

use List::MoreUtils qw(firstidx uniq part);
use List::Util qw(min max first);
use Storable qw(dclone);
use URI;
use URI::QueryParam;
use Date::Format qw(time2str);
use POSIX qw(floor);
use Scalar::Util qw(blessed);

use base qw(Bugzilla::Object Exporter);
@Bugzilla::Bug::EXPORT = qw(
    bug_alias_to_id
    LogActivityEntry
);
@Bugzilla::Bug::EXPORT_OK = @Bugzilla::Bug::EXPORT;

#####################################################################
# Constants
#####################################################################

use constant DB_TABLE   => 'bugs';
use constant ID_FIELD   => 'bug_id';
use constant NAME_FIELD => 'alias';
use constant LIST_ORDER => ID_FIELD;
# Bugs have their own auditing table, bugs_activity.
use constant AUDIT_UPDATES => 0;

# This is a sub because it needs to call other subroutines.
sub DB_COLUMNS
{
    my $cache = Bugzilla->cache_fields;
    return @{$cache->{bug_columns}} if defined $cache->{bug_columns};

    my $dbh = Bugzilla->dbh;
    my @custom = grep {$_->type != FIELD_TYPE_MULTI_SELECT}
                      Bugzilla->active_custom_fields;
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
        lastdiffed
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
    'reporter    AS reporter_id',
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
    FIELD_TYPE_UNKNOWN()        => \&_check_default_field,
    FIELD_TYPE_FREETEXT()       => \&_check_freetext_field,
    FIELD_TYPE_EXTURL()         => \&_check_freetext_field,
    FIELD_TYPE_SINGLE_SELECT()  => \&_check_select_field,
    FIELD_TYPE_MULTI_SELECT()   => \&_check_multi_select_field,
    FIELD_TYPE_TEXTAREA()       => \&_check_default_field,
    FIELD_TYPE_DATETIME()       => \&_check_datetime_field,
    FIELD_TYPE_BUG_ID()         => \&_check_bugid_field,
    FIELD_TYPE_BUG_URLS()       => \&_check_default_field,
    FIELD_TYPE_NUMERIC()        => \&_check_numeric_field,
};

# There are also other, more complex validators that are called
# from run_create_validators.
sub VALIDATORS {
    my $cache = Bugzilla->cache_fields;
    return $cache->{bug_validators} if defined $cache->{bug_validators};

    my $validators = {
        alias          => \&_check_alias,
        assigned_to    => \&_check_assigned_to,
        blocked        => \&_check_dependencies,
        bug_file_loc   => \&_check_bug_file_loc,
        bug_severity   => \&_check_select_field,
        creation_ts    => \&_check_creation_ts,
        comment        => \&_check_comment,
        deadline       => \&_check_deadline,
        dependson      => \&_check_dependencies,
        dup_id         => \&_check_dup_id,
        estimated_time => \&_check_time_field,
        everconfirmed  => \&Bugzilla::Object::check_boolean,
        op_sys         => \&_check_select_field,
        priority       => \&_check_priority,
        product        => \&_check_product,
        remaining_time => \&_check_time_field,
        rep_platform   => \&_check_select_field,
        short_desc     => \&_check_short_desc,
        status_whiteboard => \&_check_status_whiteboard,
    };

    $validators->{op_sys} = \&_check_select_field if Bugzilla->params->{useopsys};
    $validators->{rep_platform} = \&_check_select_field if Bugzilla->params->{useplatform};

    # Set up validators for custom fields.
    foreach my $field (Bugzilla->active_custom_fields) {
        $validators->{$field->name} = $CUSTOM_FIELD_VALIDATORS->{$field->type};
    }

    return $validators;
};

use constant UPDATE_VALIDATORS => {
    reporter            => \&_check_reporter,
    assigned_to         => \&_check_assigned_to,
    bug_status          => \&_check_bug_status,
    cclist_accessible   => \&Bugzilla::Object::check_boolean,
    dup_id              => \&_check_dup_id,
    everconfirmed       => \&Bugzilla::Object::check_boolean,
    qa_contact          => \&_check_qa_contact,
    reporter_accessible => \&Bugzilla::Object::check_boolean,
    resolution          => \&_check_resolution,
    target_milestone    => \&_check_target_milestone,
    version             => \&_check_version,
};

sub UPDATE_COLUMNS {
    my @custom = grep {$_->type != FIELD_TYPE_MULTI_SELECT}
                      Bugzilla->active_custom_fields;
    my @custom_names = map {$_->name} @custom;
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

sub DATE_COLUMNS {
    my @fields = @{ Bugzilla->fields({ type => FIELD_TYPE_DATETIME }) };
    return map { $_->name } @fields;
}

# Used in LogActivityEntry(). Gives the max length of lines in the
# activity table.
use constant MAX_LINE_LENGTH => 254;

# This maps the names of internal Bugzilla bug fields to things that would
# make sense to somebody who's not intimately familiar with the inner workings
# of Bugzilla. (These are the field names that the WebService and email_in.pl
# use.)
use constant FIELD_MAP => {
    blocks           => 'blocked',
    cc_accessible    => 'cclist_accessible',
    commentprivacy   => 'comment_is_private',
    creation_time    => 'creation_ts',
    creator          => 'reporter',
    description      => 'comment',
    depends_on       => 'dependson',
    dupe_of          => 'dup_id',
    id               => 'bug_id',
    is_confirmed     => 'everconfirmed',
    is_cc_accessible => 'cclist_accessible',
    is_creator_accessible => 'reporter_accessible',
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

use constant REQUIRED_FIELD_MAP => {};

# Creation timestamp is here because it needs to be validated
# but it can be NULL in the database (see comments in create above)
#
# Target Milestone is here because it has a default that the validator
# creates (product.defaultmilestone) that is different from the database
# default.
#
# CC is here because it is a separate table, and has a validator-created
# default of the component initialcc.
#
# QA Contact is allowed to be NULL in the database, so it wouldn't normally
# be caught by _required_create_fields. However, it always has to be validated,
# because it has a default of the component.defaultqacontact.
#
# Groups are in a separate table, but must always be validated so that
# mandatory groups get set on bugs.
use constant EXTRA_REQUIRED_FIELDS => qw(creation_ts target_milestone cc qa_contact groups);

#####################################################################

# This and "new" catch every single way of creating a bug, so that we
# can call _create_cf_accessors.
sub _do_list_select {
    my $invocant = shift;
    $invocant->_create_cf_accessors();
    return $invocant->SUPER::_do_list_select(@_);
}

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $param = shift;

    $class->_create_cf_accessors();

    # Remove leading "#" mark if we've just been passed an id.
    if (!ref $param && $param =~ /^#(\d+)$/) {
        $param = $1;
    }

    # If we get something that looks like a word (not a number),
    # make it the "name" param.
    if (!defined $param || (!ref($param) && $param !~ /^\d+$/)) {
        if ($param) {
            $param = { name => $param };
        }
        else {
            # We got something that's not a number.
            my $error_self = {};
            bless $error_self, $class;
            $error_self->{'bug_id'} = $param;
            $error_self->{'error'}  = 'InvalidBugId';
            return $error_self;
        }
    }

    unshift @_, $param;
    my $self = $class->SUPER::new(@_);

    # Bugzilla::Bug->new always returns something, but sets $self->{error}
    # if the bug wasn't found in the database.
    if (!$self) {
        my $error_self = {};
        if (ref $param) {
            $error_self->{bug_id} = $param->{name};
            $error_self->{error}  = 'InvalidBugId';
        }
        else {
            $error_self->{bug_id} = $param;
            $error_self->{error}  = 'NotFound';
        }
        bless $error_self, $class;
        return $error_self;
    }

    return $self;
}

sub check {
    my $class = shift;
    my ($id, $field) = @_;

    ThrowUserError('improper_bug_id_field_value', { field => $field }) unless defined $id;

    # Bugzilla::Bug throws lots of special errors, so we don't call
    # SUPER::check, we just call our new and do our own checks.
    my $self = $class->new(trim($id));
    # For error messages, use the id that was returned by new(), because
    # it's cleaned up.
    $id = $self->id;

    if ($self->{error}) {
        if ($self->{error} eq 'NotFound') {
             ThrowUserError("bug_id_does_not_exist", { bug_id => $id });
        }
        if ($self->{error} eq 'InvalidBugId') {
            ThrowUserError("improper_bug_id_field_value",
                              { bug_id => $id,
                                field  => $field });
        }
    }

    unless ($field && $field =~ /^(dependson|blocked|dup_id)$/) {
        $self->check_is_visible;
    }
    return $self;
}

sub check_for_edit {
    my $class = shift;
    my $bug = $class->check(@_);

    Bugzilla->user->can_edit_product($bug->product_id)
        || ThrowUserError("product_edit_denied", { product => $bug->product });

    return $bug;
}

sub check_is_visible {
    my $self = shift;
    my $user = Bugzilla->user;

    if (!$user->can_see_bug($self->id)) {
        # The error the user sees depends on whether or not they are
        # logged in (i.e. $user->id contains the user's positive integer ID).
        my $err_args = { bug_id => $self->id };
        if ($user->id) {
            if (Bugzilla->params->{unauth_bug_details}) {
                $err_args->{product} = $self->product;
            }
            ThrowUserError("bug_access_denied", $err_args);
        } else {
            ThrowUserError("bug_access_query", $err_args);
        }
    }
}

sub match {
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

    foreach my $field (keys %translate_fields) {
        my @ids;
        # Convert names to ids. We use "exists" everywhere since people can
        # legally specify "undef" to mean IS NULL (even though most of these
        # fields can't be NULL, people can still specify it...).
        if (exists $params->{$field}) {
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
        if (exists $params->{"${field}_id"}) {
            my $current_ids = $params->{"${field}_id"};
            my @id_array = ref $current_ids ? @$current_ids : ($current_ids);
            push(@ids, @id_array);
        }
        # We do this "or" instead of a "scalar(@ids)" to handle the case
        # when people passed only invalid object names. Otherwise we'd
        # end up with a SUPER::match call with zero criteria (which dies).
        if (exists $params->{$field} or exists $params->{"${field}_id"}) {
            $translated{$field} = scalar(@ids) == 1 ? $ids[0] : \@ids;
        }
    }

    # The user fields don't have an _id on the end of them in the database,
    # but the product & component fields do, so we have to have separate
    # code to deal with the different sets of fields here.
    foreach my $field (qw(assigned_to qa_contact reporter)) {
        delete $params->{"${field}_id"};
        $params->{$field} = $translated{$field}
            if exists $translated{$field};
    }
    foreach my $field (qw(product component)) {
        delete $params->{$field};
        $params->{"${field}_id"} = $translated{$field}
            if exists $translated{$field};
    }

    return $class->SUPER::match(@_);
}

# Helps load up information for bugs for show_bug.cgi and other situations
# that will need to access info on lots of bugs.
sub preload {
    my ($class, $bugs) = @_;
    my $user = Bugzilla->user;

    # It would be faster but MUCH more complicated to select all the
    # deps for the entire list in one SQL statement. If we ever have
    # a profile that proves that that's necessary, we can switch over
    # to the more complex method.
    my @all_dep_ids;
    foreach my $bug (@$bugs) {
        push(@all_dep_ids, @{ $bug->blocked }, @{ $bug->dependson });
        push(@all_dep_ids, @{ $bug->duplicate_ids });
    }
    @all_dep_ids = uniq @all_dep_ids;
    # If we don't do this, can_see_bug will do one call per bug in
    # the dependency and duplicate lists, in Bugzilla::Template::get_bug_link.
    $user->visible_bugs(\@all_dep_ids);
}

sub possible_duplicates {
    my ($class, $params) = @_;
    my $short_desc = $params->{summary};
    my $products = $params->{products} || [];
    my $limit = $params->{limit} || MAX_POSSIBLE_DUPLICATES;
    $limit = MAX_POSSIBLE_DUPLICATES if $limit > MAX_POSSIBLE_DUPLICATES;
    $products = [$products] if !ref($products) eq 'ARRAY';

    my $orig_limit = $limit;
    detaint_natural($limit) 
        || ThrowCodeError('param_must_be_numeric', 
                          { function => 'possible_duplicates',
                            param    => $orig_limit });

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    my @words = split(/[\b\s]+/, $short_desc || '');
    # Exclude punctuation from the array.
    @words = map { /(\w+)/; $1 } @words;
    # And make sure that each word is longer than 2 characters.
    @words = grep { defined $_ and length($_) > 2 } @words;

    return [] if !@words;

    my ($where_sql, $relevance_sql);
    if ($dbh->FULLTEXT_OR) {
        my $joined_terms = join($dbh->FULLTEXT_OR, @words);
        ($where_sql, $relevance_sql) = 
            $dbh->sql_fulltext_search('bugs_fulltext.short_desc', 
                                      $joined_terms, 1);
        $relevance_sql ||= $where_sql;
    }
    else {
        my (@where, @relevance);
        my $count = 0;
        foreach my $word (@words) {
            $count++;
            my ($term, $rel_term) = $dbh->sql_fulltext_search(
                'bugs_fulltext.short_desc', $word, $count);
            push(@where, $term);
            push(@relevance, $rel_term || $term);
        }

        $where_sql = join(' OR ', @where);
        $relevance_sql = join(' + ', @relevance);
    }

    my $product_ids = join(',', map { $_->id } @$products);
    my $product_sql = $product_ids ? "AND product_id IN ($product_ids)" : "";

    # Because we collapse duplicates, we want to get slightly more bugs
    # than were actually asked for.
    my $sql_limit = $limit + 5;

    my $possible_dupes = $dbh->selectall_arrayref(
        "SELECT bugs.bug_id AS bug_id, bugs.resolution AS resolution,
                ($relevance_sql) AS relevance
           FROM bugs
                INNER JOIN bugs_fulltext ON bugs.bug_id = bugs_fulltext.bug_id
          WHERE ($where_sql) $product_sql
       ORDER BY relevance DESC, bug_id DESC " .
          $dbh->sql_limit($sql_limit), {Slice=>{}});

    my @actual_dupe_ids;
    # Resolve duplicates into their ultimate target duplicates.
    foreach my $bug (@$possible_dupes) {
        my $push_id = $bug->{bug_id};
        if ($bug->{resolution} && $bug->{resolution} eq 'DUPLICATE') {
            $push_id = _resolve_ultimate_dup_id($bug->{bug_id});
        }
        push(@actual_dupe_ids, $push_id);
    }
    @actual_dupe_ids = uniq @actual_dupe_ids;
    if (scalar @actual_dupe_ids > $limit) {
        @actual_dupe_ids = @actual_dupe_ids[0..($limit-1)];
    }

    my $visible = $user->visible_bugs(\@actual_dupe_ids);
    return $class->new_from_list($visible);
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
# C<alias>        - An alias for this bug.
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
sub create {
    my ($class, $params) = @_;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    # These fields have default values which we can use if they are undefined.
    $params->{bug_severity} = Bugzilla->params->{defaultseverity}
        if !defined $params->{bug_severity};
    $params->{priority} = Bugzilla->params->{defaultpriority}
        if !defined $params->{priority};
    $params->{op_sys} = Bugzilla->params->{defaultopsys}
        if Bugzilla->params->{useopsys} && !defined $params->{op_sys};
    $params->{rep_platform} = Bugzilla->params->{defaultplatform}
        if Bugzilla->params->{useplatform} && !defined $params->{rep_platform};
    # Make sure a comment is always defined.
    $params->{comment} = '' unless defined $params->{comment};

    $class->check_required_create_fields($params);
    $params = $class->run_create_validators($params);

    # These are not a fields in the bugs table, so we don't pass them to
    # insert_create_data.
    my $cc_ids           = delete $params->{cc};
    my $groups           = delete $params->{groups};
    my $depends_on       = delete $params->{dependson};
    my $blocked          = delete $params->{blocked};
    my $keywords         = delete $params->{keywords};
    my ($work_time, $comment, $privacy) = ($params->{work_time}, $params->{comment}, $params->{comment_is_private});
    delete $params->{work_time};
    delete $params->{comment};
    delete $params->{comment_is_private};

    # We don't want the bug to appear in the system until it's correctly
    # protected by groups.
    my $timestamp = delete $params->{creation_ts}; 

    my $ms_values = $class->_extract_multi_selects($params);
    my $bug = $class->insert_create_data($params);

    # CustIS Bug 38616 - CC list restriction
    if ($bug->product_obj->cc_restrict_group)
    {
        $bug->{restricted_cc} = $bug->product_obj->restrict_cc($cc_ids, 'id');
    }

    # Add the group restrictions
    my $sth_group = $dbh->prepare(
        'INSERT INTO bug_group_map (bug_id, group_id) VALUES (?, ?)');
    foreach my $group (@$groups) {
        $sth_group->execute($bug->bug_id, $group->id);
    }

    $dbh->do('UPDATE bugs SET creation_ts = ? WHERE bug_id = ?', undef,
             $timestamp, $bug->bug_id);
    # Update the bug instance as well
    $bug->{creation_ts} = $timestamp;

    # Add the CCs
    my $sth_cc = $dbh->prepare('INSERT INTO cc (bug_id, who) VALUES (?,?)');
    foreach my $user_id (@$cc_ids)
    {
        $sth_cc->execute($bug->bug_id, $user_id);
    }

    # Add in keywords
    my $sth_keyword = $dbh->prepare(
        'INSERT INTO keywords (bug_id, keywordid) VALUES (?, ?)');
    foreach my $keyword_id (map($_->id, @$keywords)) {
        $sth_keyword->execute($bug->bug_id, $keyword_id);
    }

    # Set up dependencies (blocked/dependson)
    my $sth_deps = $dbh->prepare(
        'INSERT INTO dependencies (blocked, dependson) VALUES (?, ?)');
    my $sth_bug_time = $dbh->prepare('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?');

    foreach my $depends_on_id (@$depends_on) {
        $sth_deps->execute($bug->bug_id, $depends_on_id);
        # Log the reverse action on the other bug.
        LogActivityEntry($depends_on_id, 'blocked', '', $bug->bug_id,
                         $bug->{reporter_id}, $timestamp);
        $sth_bug_time->execute($timestamp, $depends_on_id);
    }
    foreach my $blocked_id (@$blocked) {
        $sth_deps->execute($blocked_id, $bug->bug_id);
        # Log the reverse action on the other bug.
        LogActivityEntry($blocked_id, 'dependson', '', $bug->bug_id,
                         $bug->{reporter_id}, $timestamp);
        $sth_bug_time->execute($timestamp, $blocked_id);
    }

    # Insert the values into the multiselect value tables
    foreach my $field (keys %$ms_values) {
        $dbh->do("DELETE FROM bug_$field where bug_id = ?",
                undef, $bug->bug_id);
        if (@{$ms_values->{$field}})
        {
            $dbh->do(
                "INSERT INTO bug_$field (bug_id, value_id) SELECT ?, id FROM $field".
                " WHERE value IN (".join(',', ('?') x @{$ms_values->{$field}}).")",
                undef, $bug->bug_id, @{$ms_values->{$field}}
            );
        }
    }

    # Comment #0 handling...

    # We now have a bug id so we can fill this out
    $comment->{'bug_id'} = $bug->id;

    # Insert the comment. We always insert a comment on bug creation,
    # but sometimes it's blank.
    Bugzilla::Comment->insert_create_data($comment);

    Bugzilla::Hook::process('bug_end_of_create', { bug => $bug,
                                                   timestamp => $timestamp,
                                                 });

    $dbh->bz_commit_transaction();

    # Because MySQL doesn't support transactions on the fulltext table,
    # we do this after we've committed the transaction. That way we're
    # sure we're inserting a good Bug ID.
    $bug->_sync_fulltext('new bug');

    return $bug;
}

my $dependent_validators;
sub run_create_validators
{
    my $class  = shift;
    my $params = $class->SUPER::run_create_validators(@_);

    my $product = $params->{product};
    $params->{product_id} = $product->id;

    ($params->{bug_status}, $params->{everconfirmed})
        = $class->_check_bug_status($params->{bug_status}, $product,
                                    $params->{comment}, $params->{assigned_to});

    if ($params->{bug_status} eq 'RESOLVED')
    {
        check_field('resolution', trim($params->{resolution}));
    }

    $params->{target_milestone} = $class->_check_target_milestone(
        $params->{target_milestone}, $product);

    $params->{version} = $class->_check_version($params->{version}, $product);

    $params->{keywords} = $class->_check_keywords($params->{keywords}, $params->{keywords_description}, $product);

    $params->{groups} = $class->_check_groups($params->{groups}, $product);

    my $component = $class->_check_component($params->{component}, $product);

    if ($component)
    {
        $params->{component_id} = $component->id;
        $params->{assigned_to} =
            $class->_check_assigned_to($params->{assigned_to}, $component);
        $params->{qa_contact} =
            $class->_check_qa_contact($params->{qa_contact}, $component);
        $params->{cc} = $class->_check_cc($component, $params->{cc});
    }

    # Callers cannot set reporter, creation_ts, or delta_ts.
    $params->{reporter} = $class->_check_reporter();
    $params->{delta_ts} = $params->{creation_ts};

    if ($params->{estimated_time}) {
        $params->{remaining_time} = $params->{estimated_time};
    }

    $params->{work_time} = $class->_check_time($params->{work_time}, 'work_time');

    $class->_check_strict_isolation($params->{cc}, $params->{assigned_to},
                                    $params->{qa_contact}, $product);

    # You can't set these fields.
    delete $params->{lastdiffed};
    delete $params->{resolution} if $params->{bug_status} ne 'RESOLVED';

    # Check dependent field values and die on errors
    check_dependent_fields($dependent_validators, $params);

    # These are converted into IDs
    delete $params->{product};
    delete $params->{component};

    # used for keywords only
    delete $params->{keywords_description};

    Bugzilla::Hook::process('bug_end_of_create_validators',
                            { params => $params });

    my @mandatory_fields = @{ Bugzilla->fields({ is_mandatory => 1,
                                                 enter_bug    => 1,
                                                 obsolete     => 0 }) };
    foreach my $field (@mandatory_fields) {
        $class->_check_field_is_mandatory($params->{$field->name}, $field,
                                          $params);
    }

    # And this is not a valid DB field, it's just used as part of 
    # _check_dependencies to avoid running it twice for both blocked 
    # and dependson.
    delete $params->{_dependencies_validated};

    return $params;
}

# Check values of the dependent fields
sub check_dependent_fields
{
    my ($validators, $params) = @_;
    my $incorrect_fields = {};
    foreach my $field_name (keys %{$validators || {}})
    {
        next if $field_name eq 'dependencies'; # this is not really a field, see add_to_deps
        my $value = $validators->{$field_name};
        my $field = Bugzilla->get_field($field_name);
        # Check field visibility
        if (!$field->check_visibility($params))
        {
            # Field is invisible and must be cleared
            if ($field->type == FIELD_TYPE_SINGLE_SELECT)
            {
                $params->{$field_name} = '---';
            }
            elsif ($field->type == FIELD_TYPE_MULTI_SELECT)
            {
                $params->{$field_name} = [];
            }
            elsif ($field->type == FIELD_TYPE_BUG_ID)
            {
                $params->{$field_name} = undef;
            }
            else
            {
                $params->{$field_name} = '';
            }
            next;
        }
        # CustIS Bug 73054, Bug 75690 (TODO maybe move to hooks)
        # Add field value to dependency tree when FIELD_TYPE_BUG_ID with add_to_deps
        # "Add to dependency tree" means add, if current bug isn't depending on / blocked by
        # added bug directly or through arbitrary number of other bugs.
        # This allows to easily view BUG_ID custom fields as the part of dependency tree,
        # without redundant dependencies.
        if ($field->type == FIELD_TYPE_BUG_ID && $field->add_to_deps &&
            $value != $params->{bug_id})
        {
            if (!$validators->{dependencies})
            {
                # Check if ValidateDependencies wasn't called yet
                ValidateDependencies($params, $params->{dependson}, $params->{blocked});
            }
            my $blk = $field->add_to_deps == BUG_ID_ADD_TO_BLOCKED;
            my $to = $blk ? 'blocked' : 'dependson';
            # Add the bug if it isn't already in dependency tree
            if (!$validators->{dependencies}->{blocked}->{$value} &&
                !$validators->{dependencies}->{dependson}->{$value})
            {
                push @{$params->{$to}}, $value;
            }
        }
        # Check field value visibility for select fields
        if (my $f = $field->value_field)
        {
            my $n = $f->name;
            $value = [ $value ] if !ref $value || blessed $value;
            foreach (@$value)
            {
                if (!ref $_ || !$_->check_visibility($params))
                {
                    # Field value is incorrect for the value of controlling field and must be modified
                    if (!$incorrect_fields->{$field_name})
                    {
                        my $controller = blessed $params ? $params->$n : $params->{$n};
                        if (!blessed $controller)
                        {
                            $controller = Bugzilla::Field::Choice->type($f)->new({ name => $controller });
                        }
                        $incorrect_fields->{$field_name} = {
                            field => $field,
                            options => [ map { $_->name } @{ $field->restricted_legal_values($controller) } ],
                            values => [],
                            value_names => [],
                            controller => $controller,
                        };
                    }
                    push @{$incorrect_fields->{$field_name}->{values}}, $_;
                    push @{$incorrect_fields->{$field_name}->{value_names}}, ref $_ ? $_->name : $_;
                }
            }
        }
    }
    # When moving bugs between products, verify groups
    my $verify_bug_groups = undef;
    if (blessed $params && $params->{product_changed})
    {
        # FIXME do not refer to cgi here?
        if (!Bugzilla->cgi->param('verify_bug_groups') &&
            Bugzilla->cgi->param('id'))
        {
            # Display group verification message only for single bug changes
            # Get the ID of groups which are no longer valid in the new product.
            my $gids = Bugzilla->dbh->selectcol_arrayref(
                'SELECT bgm.group_id
                   FROM bug_group_map AS bgm
                  WHERE bgm.bug_id=?
                    AND bgm.group_id NOT IN
                        (SELECT gcm.group_id
                           FROM group_control_map AS gcm
                           WHERE gcm.product_id = ?
                                 AND ( (gcm.membercontrol != ?
                                        AND gcm.group_id IN ('
                                        . Bugzilla->user->groups_as_string . '))
                                       OR gcm.othercontrol != ?) )',
                undef, $params->id, $params->product_obj->id, CONTROLMAPNA, CONTROLMAPNA);
            $verify_bug_groups = Bugzilla::Group->new_from_list($gids);
        }
        # Remove groups that aren't valid in the new product. This will also
        # have the side effect of removing the bug from groups that aren't
        # active anymore.
        #
        # We copy this array because the original array is modified while we're
        # working, and that confuses "foreach".
        my @current_groups = @{$params->groups_in};
        foreach my $group (@current_groups) {
            if (!grep($group->id == $_->id, @{$params->product_obj->groups_valid})) {
                $params->remove_group($group);
            }
        }
        # Make sure the bug is in all the mandatory groups for the new product.
        foreach my $group (@{$params->product_obj->groups_mandatory_for(Bugzilla->user)}) {
            $params->add_group($group);
        }
    }

    # If we're not in browser, throw an error
    if ((Bugzilla->usage_mode != USAGE_MODE_BROWSER || !blessed $params) && %$incorrect_fields)
    {
        ThrowUserError('incorrect_field_values', {
            bug_id           => blessed $params ? $params->bug_id : undef,
            incorrect_fields => [ values %$incorrect_fields ],
        });
    }

    # Else display UI for value checking
    if (Bugzilla->usage_mode == USAGE_MODE_BROWSER && (%$incorrect_fields || $verify_bug_groups) && blessed $params)
    {
        Bugzilla->template->process('bug/process/verify-field-values.html.tmpl', {
            product => $verify_bug_groups && $params->product_obj,
            old_groups => $verify_bug_groups,
            verify_bug_groups => $verify_bug_groups && 1,
            incorrect_fields => [ values %$incorrect_fields ],
            incorrect_field_descs => [ map { $_->{field}->description } values %$incorrect_fields ],
            exclude_params_re => '^(' . join('|', keys %$incorrect_fields) . ')$',
        });
        Bugzilla->dbh->rollback;
        exit;
    }

    # Clear $validators
    $_[0] = undef;
}

sub update
{
    my $self = shift;

    # First check dependent field values
    if ($self->{dependent_validators})
    {
        check_dependent_fields($self->{dependent_validators}, $self);
    }

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    # XXX This is just a temporary hack until all updating happens
    # inside this function.
    my $delta_ts = shift || $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    Bugzilla::Hook::process('bug_pre_update', { bug => $self });

    my ($changes, $old_bug) = $self->SUPER::update(@_);

    # Certain items in $changes have to be fixed so that they hold
    # a name instead of an ID.
    foreach my $field (qw(product_id component_id)) {
        my $change = delete $changes->{$field};
        if ($change) {
            my $new_field = $field;
            $new_field =~ s/_id$//;
            $changes->{$new_field} =
                [$self->{"_old_${new_field}_name"}, $self->$new_field];
        }
    }

    foreach my $field (qw(qa_contact assigned_to))
    {
        if ($changes->{$field})
        {
            my ($from, $to) = @{ $changes->{$field} };
            if ($from)
            {
                $from = $old_bug->$field->login;
                # Add previous Assignee and QA to CC list
                $self->add_cc($from);
            }
            if ($to)
            {
                $to = $self->$field->login;
            }
            $changes->{$field} = [$from, $to];
        }
    }

    # CC
    my @old_cc = map {$_->id} @{$old_bug->cc_users};
    my @new_cc = @{$self->cc_users};

    # CustIS Bug 38616 - CC list restriction
    if ($self->product_obj->cc_restrict_group)
    {
        $self->{restricted_cc} = $self->product_obj->restrict_cc(\@new_cc);
    }

    @new_cc = map {$_->id} @new_cc;
    my ($removed_cc, $added_cc) = diff_arrays(\@old_cc, \@new_cc);

    if (scalar @$removed_cc) {
        $dbh->do('DELETE FROM cc WHERE bug_id = ? AND '
                 . $dbh->sql_in('who', $removed_cc), undef, $self->id);
    }
    foreach my $user_id (@$added_cc) {
        $dbh->do('INSERT INTO cc (bug_id, who) VALUES (?,?)',
                 undef, $self->id, $user_id);
    }
    # If any changes were found, record it in the activity log
    if (scalar @$removed_cc || scalar @$added_cc) {
        my $removed_users = Bugzilla::User->new_from_list($removed_cc);
        my $added_users   = Bugzilla::User->new_from_list($added_cc);
        my $removed_names = join(', ', (map {$_->login} @$removed_users));
        my $added_names   = join(', ', (map {$_->login} @$added_users));
        $changes->{cc} = [$removed_names, $added_names];
    }

    # Keywords
    my @old_kw_ids = map { $_->id } @{$old_bug->keyword_objects};
    my @new_kw_ids = map { $_->id } @{$self->keyword_objects};

    my ($removed_kw, $added_kw) = diff_arrays(\@old_kw_ids, \@new_kw_ids);

    if (scalar @$removed_kw) {
        $dbh->do('DELETE FROM keywords WHERE bug_id = ? AND '
                 . $dbh->sql_in('keywordid', $removed_kw), undef, $self->id);
    }
    foreach my $keyword_id (@$added_kw) {
        $dbh->do('INSERT INTO keywords (bug_id, keywordid) VALUES (?,?)',
                 undef, $self->id, $keyword_id);
    }
    # If any changes were found, record it in the activity log
    if (scalar @$removed_kw || scalar @$added_kw) {
        my $removed_keywords = Bugzilla::Keyword->new_from_list($removed_kw);
        my $added_keywords   = Bugzilla::Keyword->new_from_list($added_kw);
        my $removed_names = join(', ', (map {$_->name} @$removed_keywords));
        my $added_names   = join(', ', (map {$_->name} @$added_keywords));
        $changes->{keywords} = [$removed_names, $added_names];
    }

    # Dependencies
    foreach my $pair ([qw(dependson blocked)], [qw(blocked dependson)]) {
        my ($type, $other) = @$pair;
        my $old = $old_bug->$type;
        my $new = $self->$type;

        my ($removed, $added) = diff_arrays($old, $new);
        foreach my $removed_id (@$removed) {
            $dbh->do("DELETE FROM dependencies WHERE $type = ? AND $other = ?",
                     undef, $removed_id, $self->id);

            # Add an activity entry for the other bug.
            LogActivityEntry($removed_id, $other, $self->id, '',
                             $user->id, $delta_ts);
            # Update delta_ts on the other bug so that we trigger mid-airs.
            $dbh->do('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?',
                     undef, $delta_ts, $removed_id);
        }
        foreach my $added_id (@$added) {
            $dbh->do("INSERT INTO dependencies ($type, $other) VALUES (?,?)",
                     undef, $added_id, $self->id);

            # Add an activity entry for the other bug.
            LogActivityEntry($added_id, $other, '', $self->id,
                             $user->id, $delta_ts);
            # Update delta_ts on the other bug so that we trigger mid-airs.
            $dbh->do('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?',
                     undef, $delta_ts, $added_id);
        }

        if (scalar(@$removed) || scalar(@$added)) {
            $changes->{$type} = [join(', ', @$removed), join(', ', @$added)];
        }
    }

    # Groups
    my %old_groups = map {$_->id => $_} @{$old_bug->groups_in};
    my %new_groups = map {$_->id => $_} @{$self->groups_in};
    my ($removed_gr, $added_gr) = diff_arrays([keys %old_groups],
                                              [keys %new_groups]);
    if (scalar @$removed_gr || scalar @$added_gr) {
        if (@$removed_gr) {
            my $qmarks = join(',', ('?') x @$removed_gr);
            $dbh->do("DELETE FROM bug_group_map
                       WHERE bug_id = ? AND group_id IN ($qmarks)", undef,
                     $self->id, @$removed_gr);
        }
        my $sth_insert = $dbh->prepare(
            'INSERT INTO bug_group_map (bug_id, group_id) VALUES (?,?)');
        foreach my $gid (@$added_gr) {
            $sth_insert->execute($self->id, $gid);
        }
        my @removed_names = map { $old_groups{$_}->name } @$removed_gr;
        my @added_names   = map { $new_groups{$_}->name } @$added_gr;
        $changes->{'bug_group'} = [join(', ', @removed_names),
                                   join(', ', @added_names)];
    }

    # Flags
    my ($removed, $added) = Bugzilla::Flag->update_flags($self, $old_bug, $delta_ts);
    if ($removed || $added) {
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
        my @values  = values %$comment;
        my $qmarks  = join(',', ('?') x @values);
        $dbh->do("INSERT INTO longdescs ($columns) VALUES ($qmarks)", undef, @values);
        if (0+$comment->{work_time} != 0)
        {
            # Log worktime
            $changes->{work_time} ||= [ '', 0 ];
            $changes->{work_time}->[1] += $comment->{work_time};
        }
    }

    # Comment Privacy
    foreach my $comment_id (keys %{$self->{comment_isprivate} || {}})
    {
        $dbh->do("UPDATE longdescs SET isprivate = ? WHERE comment_id = ?",
                 undef, $self->{comment_isprivate}->{$comment_id}, $comment_id);
        # FIXME It'd be nice to track this in the bug activity.
    }

    foreach my $comment_id (keys %{$self->{comment_type} || {}})
    {
        $dbh->do("UPDATE longdescs SET type = ? WHERE comment_id = ?",
                 undef, $self->{comment_type}->{$comment_id}, $comment_id);
        # FIXME It'd be nice to track this in the bug activity.
    }


    # Save changed comments
    foreach my $edited_comment (@{$self->{edited_comments} || []})
    {
        my $c_comment = Bugzilla::Comment->new($edited_comment->{comment_id});
        if (!$c_comment->is_private || $user->is_insider)
        {
            $dbh->do("UPDATE longdescs SET thetext = ? WHERE comment_id = ?",
                     undef, $edited_comment->{thetext}, $edited_comment->{comment_id});
            $edited_comment->{bug_id} = $self->bug_id;
            $edited_comment->{who} = $user->id;
            $edited_comment->{bug_when} = $delta_ts;
            # number count of the comment
            my $comment_count = scalar Bugzilla->dbh->selectrow_array(
                'SELECT count(*) FROM longdescs WHERE bug_id = ? AND comment_id <= ? ORDER BY bug_when ASC',
                undef, $self->id, $edited_comment->{comment_id});
            $edited_comment->{comment_count} = ($comment_count-1);
            my $columns = join(',', keys %$edited_comment);
            my @values  = values %$edited_comment;
            my $qmarks  = join(',', ('?') x @values);
            $dbh->do("INSERT INTO longdescs_history ($columns) VALUES ($qmarks)", undef, @values);
        }
    }

    # Insert the values into the multiselect value tables
    my @multi_selects = grep {$_->type == FIELD_TYPE_MULTI_SELECT}
                             Bugzilla->active_custom_fields;
    foreach my $field (@multi_selects) {
        my $name = $field->name;
        my ($removed, $added) = diff_arrays($old_bug->$name, $self->$name);
        if (scalar @$removed || scalar @$added) {
            $changes->{$name} = [join(', ', @$removed), join(', ', @$added)];

            $dbh->do("DELETE FROM bug_$name where bug_id = ?",
                     undef, $self->id);
            if (@{$self->$name})
            {
                $dbh->do(
                    "INSERT INTO bug_$name (bug_id, value_id) SELECT ?, id FROM $name".
                    " WHERE value IN (".join(',', ('?') x @{$self->$name}).")",
                    undef, $self->bug_id, @{$self->$name}
                );
            }
        }
    }

    # See Also

    my ($removed_see, $added_see) =
        diff_arrays($old_bug->see_also, $self->see_also, 'name');

    $_->remove_from_db foreach @$removed_see;
    $_->insert_create_data($_) foreach @$added_see;

    # If any changes were found, record it in the activity log
    if (scalar @$removed_see || scalar @$added_see) {
        $changes->{see_also} = [join(', ', map { $_->name } @$removed_see),
                                join(', ', map { $_->name } @$added_see)];
    }

    $_->update foreach @{ $self->{_update_ref_bugs} || [] };
    delete $self->{_update_ref_bugs};

    # Log bugs_activity items
    # XXX Eventually, when bugs_activity is able to track the dupe_id,
    # this code should go below the duplicates-table-updating code below.
    foreach my $field (keys %$changes) {
        my $change = $changes->{$field};
        my $from = defined $change->[0] ? $change->[0] : '';
        my $to   = defined $change->[1] ? $change->[1] : '';
        LogActivityEntry($self->id, $field, $from, $to, Bugzilla->user->id,
                         $delta_ts);
    }

    # Check if we have to update the duplicates table and the other bug.
    my ($old_dup, $cur_dup) = ($old_bug->dup_id || 0, $self->dup_id || 0);
    if ($old_dup != $cur_dup) {
        $dbh->do("DELETE FROM duplicates WHERE dupe = ?", undef, $self->id);
        if ($cur_dup) {
            $dbh->do('INSERT INTO duplicates (dupe, dupe_of) VALUES (?,?)',
                     undef, $self->id, $cur_dup);
            if (my $update_dup = delete $self->{_dup_for_update}) {
                $update_dup->update();
            }
        }

        $changes->{'dup_id'} = [$old_dup || undef, $cur_dup || undef];
    }

    Bugzilla::Hook::process('bug_end_of_update', 
        { bug => $self, timestamp => $delta_ts, changes => $changes,
          old_bug => $old_bug });

    # If any change occurred, refresh the timestamp of the bug.
    if (scalar(keys %$changes) || $self->{added_comments}
        || $self->{comment_isprivate})
    {
        $dbh->do('UPDATE bugs SET delta_ts = ? WHERE bug_id = ?',
                 undef, ($delta_ts, $self->id));
        $self->{delta_ts} = $delta_ts;
    }

    Bugzilla::Hook::process('bug_end_of_update',
        { bug => $self, timestamp => $delta_ts, changes => $changes,
          old_bug => $old_bug });

    # The only problem with this here is that update() is often called
    # in the middle of a transaction, and if that transaction is rolled
    # back, this change will *not* be rolled back. As we expect rollbacks
    # to be extremely rare, that is OK for us.
    $self->_sync_fulltext()
        if $self->{added_comments} || $changes->{short_desc}
           || $self->{comment_isprivate} || $self->{edited_comments};

    # Remove obsolete internal variables.
    delete $self->{'_old_assigned_to'};
    delete $self->{'_old_qa_contact'};
    delete $self->{added_comments};
    delete $self->{edited_comments};

    # Also flush the visible_bugs cache for this bug as the user's
    # relationship with this bug may have changed.
    delete Bugzilla->user->{_visible_bugs_cache}->{$self->id};

    return $changes;
}

# Used by create().
# We need to handle multi-select fields differently than normal fields,
# because they're arrays and don't go into the bugs table.
sub _extract_multi_selects {
    my ($invocant, $params) = @_;

    my @multi_selects = grep {$_->type == FIELD_TYPE_MULTI_SELECT}
                             Bugzilla->active_custom_fields;
    my %ms_values;
    foreach my $field (@multi_selects) {
        my $name = $field->name;
        if (exists $params->{$name}) {
            my $array = delete($params->{$name}) || [];
            $ms_values{$name} = $array;
        }
    }
    return \%ms_values;
}

# Should be called any time you update short_desc or change a comment.
sub _sync_fulltext
{
    use utf8;
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
    $_ = $dbh->quote_fulltext($_) for @$row;
    ## O_o Don't know how can it be tainted here, sometimes it was. Checking if it goes away.
    #trick_taint($row);
    my $sql;
    if ($new_bug)
    {
        $sql = "INSERT INTO bugs_fulltext (bug_id, short_desc, comments, comments_private)".
            " VALUES (".join(',', $self->id, @$row).")";
    }
    else
    {
        $sql = "UPDATE bugs_fulltext SET short_desc=$row->[0],".
            " comments=$row->[1], comments_private=$row->[2] WHERE bug_id=".$self->id;
    }
    return $dbh->do($sql);
}

sub remove_from_db {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;

    ThrowCodeError("bug_error", { bug => $self }) if $self->{'error'};

    my $bug_id = $self->{'bug_id'};
    $self->SUPER::remove_from_db();
    # The bugs_fulltext table doesn't support foreign keys.
    $dbh->do("DELETE FROM bugs_fulltext WHERE bug_id = ?", undef, $bug_id);
}

#####################################################################
# Validators
#####################################################################

sub _check_alias {
   my ($invocant, $alias) = @_;
   $alias = trim($alias);
   return undef if (!$alias);

    # Make sure the alias isn't too long.
    if (length($alias) > 20) {
        ThrowUserError("alias_too_long");
    }
    # Make sure the alias isn't just a number.
    if ($alias =~ /^\d+$/) {
        ThrowUserError("alias_is_numeric", { alias => $alias });
    }
    # Make sure the alias has no commas or spaces.
    if ($alias =~ /[, ]/) {
        ThrowUserError("alias_has_comma_or_space", { alias => $alias });
    }
    # Make sure the alias is unique, or that it's already our alias.
    my $other_bug = new Bugzilla::Bug($alias);
    if (!$other_bug->{error}
        && (!ref $invocant || $other_bug->id != $invocant->id))
    {
        ThrowUserError("alias_in_use", { alias => $alias,
                                         bug_id => $other_bug->id });
    }

   return $alias;
}

sub _check_assigned_to {
    my ($invocant, $assignee, $component) = @_;
    my $user = Bugzilla->user;
   
    # Default assignee is the component owner.
    my $id;
    # If this is a new bug, you can only set the assignee if you have editbugs.
    # If you didn't specify the assignee, we use the default assignee.
    if (!ref $invocant
        && (!$user->in_group('editbugs', $component->product_id) || !$assignee))
    {
        $id = $component->default_assignee->id;
    } else {
        if (!ref $assignee) {
            $assignee = trim($assignee);
            # When updating a bug, assigned_to can't be empty.
            ThrowUserError("reassign_to_empty") if ref $invocant && !$assignee;
            $assignee = Bugzilla::User->check($assignee);
        }
        $id = $assignee->id;
        # create() checks this another way, so we don't have to run this
        # check during create().
        $invocant->_check_strict_isolation_for_user($assignee) if ref $invocant;
        my $prod = ref $invocant ? $invocant->product_obj : $component->product;
        my ($ccg) = $prod->description =~ /\[[CС]{2}:\s*([^\]]+)\s*\]/iso;
        if ($ccg && !$assignee->in_group($ccg))
        {
            ThrowUserError("cc_group_restriction", { user => $assignee->login });
        }
    }
    return $id;
}

sub _check_bug_file_loc {
    my ($invocant, $url) = @_;
    $url = '' if !defined($url);
    # On bug entry, if bug_file_loc is "http://", the default, use an
    # empty value instead. However, on bug editing people can set that
    # back if they *really* want to.
    if (!ref $invocant && $url eq 'http://') {
        $url = '';
    }
    return $url;
}

sub _check_bug_status {
    my ($invocant, $new_status, $product, $comment, $assigned_to) = @_;
    my $user = Bugzilla->user;
    my @valid_statuses;
    my $old_status; # Note that this is undef for new bugs.

    if (ref $invocant) {
        @valid_statuses = @{$invocant->statuses_available};
        $product = $invocant->product_obj;
        $old_status = $invocant->status;
        my $comments = $invocant->{added_comments} || [];
        $comment = $comments->[-1];
    }
    else {
        @valid_statuses = @{Bugzilla::Status->can_change_to()};
        if (!$product->allows_unconfirmed) {
            @valid_statuses = grep {$_->name ne 'UNCONFIRMED'} @valid_statuses;
        }
    }

    if ($assigned_to && $user->email ne $assigned_to)
    {
        # You can not assign bugs to other people
        @valid_statuses = grep {$_->name ne 'ASSIGNED'} @valid_statuses;
    }

    # Check permissions for users filing new bugs.
    if (!ref $invocant) {
        if ($user->in_group('editbugs', $product->id)
            || $user->in_group('canconfirm', $product->id)) {
            # If the user with privs hasn't selected another status,
            # select the first one of the list.
            unless ($new_status) {
                if (scalar(@valid_statuses) == 1) {
                    $new_status = $valid_statuses[0];
                }
                else {
                    $new_status = ($valid_statuses[0]->name ne 'UNCONFIRMED') ?
                                  $valid_statuses[0] : $valid_statuses[1];
                }
            }
        }
        else {
            # A user with no privs cannot choose the initial status.
            # If UNCONFIRMED is valid for this product, use it; else
            # use the first bug status available.
            if (grep {$_->name eq 'UNCONFIRMED'} @valid_statuses) {
                $new_status = 'UNCONFIRMED';
            }
            else {
                $new_status = $valid_statuses[0];
            }
        }
    }

    # Time to validate the bug status.
    $new_status = Bugzilla::Status->check($new_status) unless ref($new_status);
    # We skip this check if we are changing from a status to itself.
    if ( (!$old_status || $old_status->id != $new_status->id)
          && !grep {$_->name eq $new_status->name} @valid_statuses)
    {
        ThrowUserError('illegal_bug_status_transition',
                       { old => $old_status, new => $new_status });
    }

    # Check if a comment is required for this change.
    if ($new_status->comment_required_on_change_from($old_status) && !$comment)
    {
        ThrowUserError('comment_required',
          { old => $old_status->name, new => $new_status->name,
            field => 'bug_status' });
    }

    if (ref $invocant 
        && ($new_status->name eq 'IN_PROGRESS'
            # Backwards-compat for the old default workflow.
            or $new_status->name eq 'ASSIGNED')
        && Bugzilla->params->{"usetargetmilestone"}
        && Bugzilla->params->{"musthavemilestoneonaccept"}
        # musthavemilestoneonaccept applies only if at least two
        # target milestones are defined for the product.
        && scalar(@{ $product->milestones }) > 1
        && $invocant->target_milestone eq $product->default_milestone)
    {
        ThrowUserError("milestone_required", { bug => $invocant });
    }

    return ($new_status->name, $new_status->name eq 'UNCONFIRMED' ? 0 : 1);
}

sub _check_cc {
    my ($invocant, $component, $ccs) = @_;
    return [map {$_->id} @{$component->initial_cc}] unless $ccs;

    # Allow comma-separated input as well as arrayrefs.
    $ccs = [split(/[,;]+/, $ccs)] if !ref $ccs;

    my %cc_ids;
    my ($ccg) = $component->product->description =~ /\[[CС]{2}:\s*([^\]]+)\s*\]/iso;
    foreach my $person (@$ccs) {
        $person = trim($person);
        next unless $person;
        my $id = login_to_id($person, THROW_ERROR);
        my $user = Bugzilla::User->new($id);
        next if $ccg && !$user->in_group($ccg);
        $cc_ids{$id} = 1;
    }

    # CustIS Bug 55095: Don't enforce default CC
    ## Enforce Default CC
    #$cc_ids{$_->id} = 1 foreach (@{$component->initial_cc});

    return [keys %cc_ids];
}

sub _check_comment {
    my ($invocant, $comment_txt, undef, $params) = @_;

    # Comment can be empty. We should force it to be empty if the text is undef
    if (!defined $comment_txt) {
        $comment_txt = '';
    }

    # Load up some data
    my $isprivate = delete $params->{comment_is_private};
    my $timestamp = $params->{creation_ts};

    # Create the new comment so we can check it
    my $comment = {
        thetext  => $comment_txt,
        bug_when => $timestamp,
    };

    # We don't include the "isprivate" column unless it was specified. 
    # This allows it to fall back to its database default.
    if (defined $isprivate) {
        $comment->{isprivate} = $isprivate;
    }

    # Validate comment. We have to do this special as a comment normally
    # requires a bug to be already created. For a new bug, the first comment
    # obviously can't get the bug if the bug is created after this
    # (see bug 590334)
    Bugzilla::Comment->check_required_create_fields($comment);
    $comment = Bugzilla::Comment->run_create_validators($comment,
                                                        { skip => ['bug_id'] }
    );

    return $comment; 
}

sub _check_commenton {
    my ($invocant, $new_value, $field, $params) = @_;

    my $has_comment =
        ref($invocant) ? $invocant->{added_comments}
                       : (defined $params->{comment}
                          and $params->{comment}->{thetext} ne '');

    my $is_changing = ref($invocant) ? $invocant->$field ne $new_value
                                     : $new_value ne '';

    if ($is_changing && !$has_comment) {
        my $old_value = ref($invocant) ? $invocant->$field : undef;
        ThrowUserError('comment_required',
            { field => $field, old => $old_value, new => $new_value });
    }
}

sub _check_comment_type {
    my ($invocant, $type) = @_;
    detaint_natural($type)
      || ThrowCodeError('bad_arg', { argument => 'type',
                                     function => caller });
    return $type;
}

sub _check_component
{
    my ($invocant, $name, $product) = @_;
    $name = trim($name);
    $name || ThrowUserError("require_component");
    ($product = $invocant->product_obj) if ref $invocant;
    my $obj = Bugzilla::Component->new({ product => $product, name => $name });
    if (!$obj)
    {
        $invocant->dependent_validators->{component} = $name;
        return '';
    }
    return $obj;
}

sub _check_creation_ts {
    return Bugzilla->dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');
}

sub _check_deadline {
    my ($invocant, $date) = @_;

    # When filing bugs, we're forgiving and just return undef if
    # the user isn't a timetracker. When updating bugs, check_can_change_field
    # controls permissions, so we don't want to check them here.
    if (!ref $invocant and !Bugzilla->user->is_timetracker) {
        return undef;
    }

    # Validate entered deadline
    $date = trim($date);
    return undef if !$date;
    validate_date($date)
        || ThrowUserError('illegal_date', { date   => $date,
                                            format => 'YYYY-MM-DD' });
    return $date;
}

# Takes two comma/space-separated strings and returns arrayrefs
# of valid bug IDs.
sub _check_dependencies {
    my ($invocant, $value, $field, $params) = @_;

    return $value if $params->{_dependencies_validated};

    if (!ref $invocant) {
        # Only editbugs users can set dependencies on bug entry.
        return ([], []) unless Bugzilla->user->in_group(
            'editbugs', $params->{product}->id);
    }

    # This is done this way so that dependson and blocked can be in
    # VALIDATORS, meaning that they can be in VALIDATOR_DEPENDENCIES,
    # which means that they can be checked in the right order during
    # bug creation.
    my $opposite = $field eq 'dependson' ? 'blocked' : 'dependson';
    my %deps_in = ($field => $value || '',
                   $opposite => $params->{$opposite} || '');

    foreach my $type (qw(dependson blocked)) {
        my @bug_ids = ref($deps_in{$type}) 
            ? @{$deps_in{$type}} 
            : split(/[\s,]+/, $deps_in{$type});
        # Eliminate nulls.
        @bug_ids = grep {$_} @bug_ids;
        # We do this up here to make sure all aliases are converted to IDs.
        @bug_ids = map { $invocant->check($_, $type)->id } @bug_ids;

        my @check_access = @bug_ids;
        # When we're updating a bug, only added or removed bug_ids are
        # checked for whether or not we can see/edit those bugs.
        if (ref $invocant) {
            my $old = $invocant->$type;
            my ($removed, $added) = diff_arrays($old, \@bug_ids);
            @check_access = (@$added, @$removed);

            # Check field permissions if we've changed anything.
            if (@check_access) {
                my $privs;
                if (!$invocant->check_can_change_field($type, 0, 1, \$privs)) {
                    ThrowUserError('illegal_change', { field => $type,
                                                       privs => $privs });
                }
            }
        }

        my $user = Bugzilla->user;
        foreach my $modified_id (@check_access) {
            my $delta_bug = $invocant->check($modified_id);
            # Under strict isolation, you can't modify a bug if you can't
            # edit it, even if you can see it.
            if (Bugzilla->params->{"strict_isolation"}) {
                if (!$user->can_edit_bug($delta_bug)) {
                    ThrowUserError("illegal_change_deps", {field => $type});
                }
            }
        }

        $deps_in{$type} = \@bug_ids;
    }

    # And finally, check for dependency loops.
    my $bug_id = ref($invocant) ? $invocant->id : 0;
    my %deps = ValidateDependencies($deps_in{dependson}, $deps_in{blocked},
                                    $bug_id);

    $params->{$opposite} = $deps{$opposite};
    $params->{_dependencies_validated} = 1;
    return $deps{$field};
}

sub _check_dup_id {
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
    return $dupe_of if ($self->dup_id && $self->dup_id == $dupe_of);

    # If we come here, then the duplicate is new. We have to make sure
    # that we can view/change it (issue A on bug 96085).
    $dupe_of_bug->check_is_visible;

    # Make sure a loop isn't created when marking this bug
    # as duplicate.
   _resolve_ultimate_dup_id($self->id, $dupe_of, 1);

    my $cur_dup = $self->dup_id || 0;
    if ($cur_dup != $dupe_of && Bugzilla->params->{'commentonduplicate'}
        && !$self->{added_comments})
    {
        ThrowUserError('comment_required');
    }

    # Should we add the reporter to the CC list of the new bug?
    # If he can see the bug...
    if ($self->reporter->can_see_bug($dupe_of)) {
        # We only add him if he's not the reporter of the other bug.
        $self->{_add_dup_cc} = 1
            if $dupe_of_bug->reporter->id != $self->reporter->id;
    }
    # What if the reporter currently can't see the new bug? In the browser
    # interface, we prompt the user. In other interfaces, we default to
    # not adding the user, as the safest option.
    elsif (Bugzilla->usage_mode == USAGE_MODE_BROWSER) {
        # If we've already confirmed whether the user should be added...
        my $cgi = Bugzilla->cgi;
        my $add_confirmed = $cgi->param('confirm_add_duplicate');
        if (defined $add_confirmed) {
            $self->{_add_dup_cc} = $add_confirmed;
        }
        else {
            # Note that here we don't check if he user is already the reporter
            # of the dupe_of bug, since we already checked if he can *see*
            # the bug, above. People might have reporter_accessible turned
            # off, but cclist_accessible turned on, so they might want to
            # add the reporter even though he's already the reporter of the
            # dup_of bug.
            my $vars = {};
            my $template = Bugzilla->template;
            # Ask the user what they want to do about the reporter.
            $vars->{'cclist_accessible'} = $dupe_of_bug->cclist_accessible;
            $vars->{'original_bug_id'} = $dupe_of;
            $vars->{'duplicate_bug_id'} = $self->id;
            $cgi->send_header();
            $template->process("bug/process/confirm-duplicate.html.tmpl", $vars)
              || ThrowTemplateError($template->error());
            exit;
        }
    }

    return $dupe_of;
}

sub _check_groups {
    my ($invocant, $group_names, undef, $params) = @_;

    my $bug_id = blessed($invocant) ? $invocant->id : undef;
    my $product = blessed($invocant) ? $invocant->product_obj 
                                     : $params->{product};
    my %add_groups;
    my $controls = $product->group_controls;

    foreach my $id (@$group_ids) {
        my $group = new Bugzilla::Group($id)
            || ThrowUserError("invalid_group_ID");

        # First check all the groups they chose to set.
        my %args = ( product => $product->name, bug_id => $bug_id, action => 'add' );
        foreach my $name (@$group_names) {
            my $group = Bugzilla::Group->check_no_disclose({ %args, name => $name });

            if (!$product->group_is_settable($group)) {
                ThrowUserError('group_restriction_not_allowed', { %args, name => $name });
            }
            $add_groups{$group->id} = $group;
        }
    }

    # Now enforce mandatory groups.
    $add_groups{$_->id} = $_ foreach @{ $product->groups_mandatory };

    my @add_groups = values %add_groups;
    return \@add_groups;
}

sub _check_keywords {
    my ($invocant, $keyword_string, $keyword_description_string, $product) = @_;
    $keyword_string = trim($keyword_string);
    return [] if !$keyword_string;

    # On creation, only editbugs users can set keywords.
    if (!ref $invocant) {
        return [] if !Bugzilla->user->in_group('editbugs', $product->id);
    }

    # CustIS Bug 66910 - Adding new keyword to DB
    my %keyword_descriptions;
    trick_taint($keyword_description_string);
    foreach my $kd (split(/\@+/, trim($keyword_description_string))) {
        my @this_kd = map { $_ = url_decode($_); Encode::_utf8_on($_); $_ } split /=+/, $kd;
        $keyword_descriptions{$this_kd[0]} = $this_kd[1];
    }

    my %keywords;
    foreach my $keyword (split(/[\s,]+/, $keyword_string)) {
        next unless $keyword;
        my $obj = new Bugzilla::Keyword({ name => $keyword });

        if (!$obj)
        {
            my $this_kd = "";
            if (exists($keyword_descriptions{$keyword}))
            {
                $this_kd = $keyword_descriptions{$keyword};
            }

            my $obj = Bugzilla::Keyword->create({
                name => $keyword,
                description => $this_kd,
            });
            $keywords{$obj->id} = $obj;
        }
        else
        {
            $keywords{$obj->id} = $obj;
        }
    }
    return [values %keywords];
}

sub _check_product {
    my ($invocant, $name) = @_;
    $name = trim($name);
    # If we're updating the bug and they haven't changed the product,
    # always allow it.
    if (ref $invocant && lc($invocant->product_obj->name) eq lc($name)) {
        return $invocant->product_obj;
    }
    # Check that the product exists and that the user
    # is allowed to enter bugs into this product.
    Bugzilla->user->can_enter_product($name, THROW_ERROR);
    # can_enter_product already does everything that check_product
    # would do for us, so we don't need to use it.
    return new Bugzilla::Product({ name => $name });
}

sub _check_priority {
    my ($invocant, $priority) = @_;
    if (!ref $invocant && !Bugzilla->params->{'letsubmitterchoosepriority'}) {
        $priority = Bugzilla->params->{'defaultpriority'};
    }
    return $invocant->_check_select_field($priority, 'priority');
}

sub _check_qa_contact {
    my ($invocant, $qa_contact, $component) = @_;
    $qa_contact = trim($qa_contact) if !ref $qa_contact;

    my $id;
    if (!ref $invocant) {
        # Bugs get no QA Contact on creation if useqacontact is off.
        return undef if !Bugzilla->params->{useqacontact};
        # Set the default QA Contact if one isn't specified or if the
        # user doesn't have editbugs.
        if (!Bugzilla->user->in_group('editbugs', $component->product_id)
            || !$qa_contact)
        {
            $id = $component->default_qa_contact->id;
        }
    }
    
    # If a QA Contact was specified or if we're updating, check
    # the QA Contact for validity.
    if (!defined $id && $qa_contact) {
        $qa_contact = Bugzilla::User->check($qa_contact) if !ref $qa_contact;
        $id = $qa_contact->id;
        # create() checks this another way, so we don't have to run this
        # check during create().
        # If there is no QA contact, this check is not required.
        $invocant->_check_strict_isolation_for_user($qa_contact)
            if (ref $invocant && $id);
    }

    # "0" always means "undef", for QA Contact.
    return $id || undef;
}

sub _check_reporter {
    my $invocant = shift;
    my $reporter;
    if (ref $invocant) {
        # You cannot change the reporter of a bug.
        $reporter = $invocant->reporter->id;
    }
    else {
        # On bug creation, the reporter is the logged in user
        # (meaning that he must be logged in first!).
        $reporter = Bugzilla->user->id;
    }
    if ($reporter && ref $invocant)
    {
        # Custis Bug 38616
        # For situations of moving external bugs into internal
        my $prod = $invocant->product_obj;
        my ($ccg) = $prod->description =~ /\[[CС]{2}:\s*([^\]]+)\s*\]/iso;
        my $user = Bugzilla::User->new($reporter);
        if ($ccg && !$user->in_group($ccg))
        {
            ThrowUserError("cc_group_restriction", { user => $user->login });
        }
    }
    return $reporter;
}

sub _check_resolution {
    my ($invocant, $resolution, undef, $params) = @_;
    $resolution = trim($resolution);
    my $status = ref($invocant) ? $invocant->status->name 
                                : $params->{bug_status};
    my $is_open = ref($invocant) ? $invocant->status->is_open 
                                 : is_open_state($status);
    
    # Throw a special error for resolving bugs without a resolution
    # (or trying to change the resolution to '' on a closed bug without
    # using clear_resolution).
    ThrowUserError('missing_resolution', { status => $status })
        if !$resolution && !$is_open;
    
    # Make sure this is a valid resolution.
    $resolution = $invocant->_check_select_field($resolution, 'resolution');

    # Don't allow open bugs to have resolutions.
    ThrowUserError('resolution_not_allowed') if $is_open;
    
    # Check noresolveonopenblockers.
    my $dependson = ref($invocant) ? $invocant->dependson
                                   : ($params->{dependson} || []);
    if (Bugzilla->params->{"noresolveonopenblockers"}
        && $resolution eq 'FIXED'
        && (!ref $invocant or !$invocant->resolution 
            or $resolution ne $invocant->resolution)
        && scalar @$dependson)
    {
        my $dep_bugs = Bugzilla::Bug->new_from_list($dependson);
        my $count_open = grep { $_->isopened } @$dep_bugs;
        if ($count_open) {
            my $bug_id = ref($invocant) ? $invocant->id : undef;
            ThrowUserError("still_unresolved_bugs",
                           { bug_id => $bug_id, dep_count => $count_open });
        }
    }

    # Check if they're changing the resolution and need to comment.
    if (Bugzilla->params->{'commentonchange_resolution'}) {
        $invocant->_check_commenton($resolution, 'resolution', $params);
    }

    return $resolution;
}

sub _check_short_desc {
    my ($invocant, $short_desc) = @_;
    # Set the parameter to itself, but cleaned up
    $short_desc = clean_text($short_desc) if $short_desc;

    if (!defined $short_desc || $short_desc eq '') {
        ThrowUserError("require_summary");
    }
    if (length($short_desc) > MAX_FREETEXT_LENGTH) {
        ThrowUserError('freetext_too_long', 
                       { field => 'short_desc', text => $short_desc });
    }
    return $short_desc;
}

sub _check_status_whiteboard { return defined $_[1] ? $_[1] : ''; }

# Unlike other checkers, this one doesn't return anything.
sub _check_strict_isolation {
    my ($invocant, $ccs, $assignee, $qa_contact, $product) = @_;
    return unless Bugzilla->params->{'strict_isolation'};

    if (ref $invocant) {
        my $original = $invocant->new($invocant->id);

        # We only check people if they've been added. This way, if
        # strict_isolation is turned on when there are invalid users
        # on bugs, people can still add comments and so on.
        my @old_cc = map { $_->id } @{$original->cc_users};
        my @new_cc = map { $_->id } @{$invocant->cc_users};
        my ($removed, $added) = diff_arrays(\@old_cc, \@new_cc);
        $ccs = Bugzilla::User->new_from_list($added);

        $assignee = $invocant->assigned_to
            if $invocant->assigned_to->id != $original->assigned_to->id;
        if ($invocant->qa_contact
            && (!$original->qa_contact
                || $invocant->qa_contact->id != $original->qa_contact->id))
        {
            $qa_contact = $invocant->qa_contact;
        }
        $product = $invocant->product_obj;
    }

    my @related_users = @$ccs;
    push(@related_users, $assignee) if $assignee;

    if (Bugzilla->params->{'useqacontact'} && $qa_contact) {
        push(@related_users, $qa_contact);
    }

    @related_users = @{Bugzilla::User->new_from_list(\@related_users)}
        if !ref $invocant;

    # For each unique user in @related_users...(assignee and qa_contact
    # could be duplicates of users in the CC list)
    my %unique_users = map {$_->id => $_} @related_users;
    my @blocked_users;
    foreach my $id (keys %unique_users) {
        my $related_user = $unique_users{$id};
        if (!$related_user->can_edit_product($product->id) ||
            !$related_user->can_see_product($product->name)) {
            push (@blocked_users, $related_user->login);
        }
    }
    if (scalar(@blocked_users)) {
        my %vars = ( users   => \@blocked_users,
                     product => $product->name );
        if (ref $invocant) {
            $vars{'bug_id'} = $invocant->id;
        }
        else {
            $vars{'new'} = 1;
        }
        ThrowUserError("invalid_user_group", \%vars);
    }
}

# This is used by various set_ checkers, to make their code simpler.
sub _check_strict_isolation_for_user {
    my ($self, $user) = @_;
    return unless Bugzilla->params->{"strict_isolation"};
    if (!$user->can_edit_bug($self)) {
        ThrowUserError('invalid_user_group',
                       { users   => $user->login,
                         product => $self->product,
                         bug_id  => $self->id });
    }
}

sub _check_tag_name {
    my ($invocant, $tag) = @_;

    $tag = clean_text($tag);
    $tag || ThrowUserError('no_tag_to_edit');
    ThrowUserError('tag_name_too_long') if length($tag) > MAX_LEN_QUERY_NAME;
    trick_taint($tag);
    # Tags are all lowercase.
    return lc($tag);
}

sub _check_target_milestone
{
    my ($invocant, $target, $product) = @_;
    $product = $invocant->product_obj if ref $invocant;
    $target = trim($target);
    # Reporters can move bugs between products but not set the TM.
    # So reset it to the default value.
    if (!defined $target || !Bugzilla->params->{usetargetmilestone} ||
        blessed $invocant && !$invocant->check_can_change_field('target_milestone', 0, 1))
    {
        $target = $product->default_milestone;
    }
    my $object = Bugzilla::Milestone->new({ product => $product, name => $target });
    if (!$object)
    {
        $invocant->dependent_validators->{target_milestone} = $target;
        return '';
    }
    return $object->name;
}

sub _check_time {
    my ($invocant, $time, $field) = @_;

    my $current = 0;
    if (ref $invocant && $field ne 'work_time') {
        $current = $invocant->$field;
    }
    return $current unless Bugzilla->user->is_timetracker;

    $time = ValidateTime($time, $field);
    return $time;
}

sub _check_work_time {
    return $_[0]->_check_time($_[1], 'work_time');
}

sub _check_time_field {
    my ($invocant, $value, $field, $params) = @_;

    # When filing bugs, we're forgiving and just return 0 if
    # the user isn't a timetracker. When updating bugs, check_can_change_field
    # controls permissions, so we don't want to check them here.
    if (!ref $invocant and !Bugzilla->user->is_timetracker) {
        return 0;
    }

    # check_time is in Bugzilla::Object.
    return $invocant->check_time($value, $field, $params);
}

sub _check_version {
    my ($invocant, $version, $product) = @_;
    $version = trim($version);
    ($product = $invocant->product_obj) if ref $invocant;
    my $object = Bugzilla::Version->new({ product => $product, name => $version }) if length $version;
    if (!$object)
    {
        $invocant->dependent_validators->{version} = $version;
        return '';
    }
    return $object->name;
}

# Custom Field Validators

sub _check_field_is_mandatory {
    my ($invocant, $value, $field, $params) = @_;

    if (!blessed($field)) {
        $field = Bugzilla::Field->new({ name => $field });
        return if !$field;
    }

    return if !$field->is_mandatory;

    return if !$field->is_visible_on_bug($params || $invocant);

    if (ref($value) eq 'ARRAY') {
        $value = join('', @$value);
    }

    $value = trim($value);
    if (!defined($value)
        or $value eq ""
        or ($value eq '---' and $field->type == FIELD_TYPE_SINGLE_SELECT)
        or ($value =~ EMPTY_DATETIME_REGEX
            and $field->type == FIELD_TYPE_DATETIME))
    {
        ThrowUserError('required_field', { field => $field });
    }
}

sub _check_datetime_field {
    my ($invocant, $date_time) = @_;

    # Empty datetimes are empty strings or strings only containing
    # 0's, whitespace, and punctuation.
    if ($date_time =~ /^[\s0[:punct:]]*$/) {
        return undef;
    }

    $date_time = trim($date_time);
    my ($date, $time) = split(' ', $date_time);
    if ($date && !validate_date($date)) {
        ThrowUserError('illegal_date', { date   => $date,
                                         format => 'YYYY-MM-DD' });
    }
    if ($time && !validate_time($time)) {
        ThrowUserError('illegal_time', { 'time' => $time,
                                         format => 'HH:MM:SS' });
    }
    return $date_time
}

sub _check_default_field { return defined $_[1] ? trim($_[1]) : ''; }

sub _check_numeric_field
{
    my ($invocant, $text) = @_;
    ($text) = $text =~ /^(-?\d+(\.\d+)?)$/so;
    return $text || 0;
}

sub _check_freetext_field {
    my ($invocant, $text, $field) = @_;

    $text = (defined $text) ? trim($text) : '';
    if (length($text) > MAX_FREETEXT_LENGTH) {
        ThrowUserError('freetext_too_long', 
                       { field => $field, text => $text });
    }
    return $text;
}

sub _check_multi_select_field {
    my ($invocant, $values, $field) = @_;

    # Allow users (mostly email_in.pl) to specify multi-selects as
    # comma-separated values.
    if (defined $values and !ref $values) {
        # We don't split on spaces because multi-select values can and often
        # do have spaces in them. (Theoretically they can have commas in them
        # too, but that's much less common and people should be able to work
        # around it pretty cleanly, if they want to use email_in.pl.)
        $values = [split(',', $values)];
    }

    return [] if !$values;
    my @checked_values;
    foreach my $value (@$values) {
        push(@checked_values, $invocant->_check_select_field($value, $field));
    }
    return \@checked_values;
}

sub dependent_validators
{
    my $invocant = shift;
    my $tmp = ref $invocant
        ? ($invocant->{dependent_validators} ||= {})
        : ($dependent_validators ||= {});
    return $tmp;
}

sub _check_select_field
{
    my ($invocant, $value, $field) = @_;
    $field = Bugzilla->get_field($field);
    # Check dependent field values
    if ($field->visibility_field_id || $field->value_field_id)
    {
        my $t = Bugzilla::Field::Choice->type($field);
        my $object = $t->new({ name => $value });
        if (!$object)
        {
            # Save the raw value if it's invalid
            $object = $value;
            trick_taint($value);
        }
        else
        {
            $value = $object->name;
        }
        my $tmp = $invocant->dependent_validators;
        # Remember the call and perform check later
        if ($field->type == FIELD_TYPE_MULTI_SELECT)
        {
            push @{$tmp->{$field->name}}, $object;
        }
        else
        {
            $tmp->{$field->name} = $object;
        }
        return $value;
    }
    my $object = Bugzilla::Field::Choice->type($field)->check($value);
    return $object->name;
}

sub _check_bugid_field
{
    my ($invocant, $value, $field) = @_;
    return undef if !$value;
    
    # check that the value is a valid, visible bug id
    my $checked_id = $invocant->check($value, $field)->id;
    
    # check for loop (can't have a loop if this is a new bug)
    if (ref $invocant) {
        _check_relationship_loop($field, $invocant->bug_id, $checked_id);
    }

    return $checked_id;
}

sub _check_relationship_loop {
    # Generates a dependency tree for a given bug.  Calls itself recursively
    # to generate sub-trees for the bug's dependencies.
    my ($field, $bug_id, $dep_id, $ids) = @_;

    # Don't do anything if this bug doesn't have any dependencies.
    return unless defined($dep_id);

    # Check whether we have seen this bug yet
    $ids = {} unless defined $ids;
    $ids->{$bug_id} = 1;
    if ($ids->{$dep_id}) {
        ThrowUserError("relationship_loop_single", {
            'bug_id' => $bug_id,
            'dep_id' => $dep_id,
            'field_name' => $field});
    }
    
    # Get this dependency's record from the database
    my $dbh = Bugzilla->dbh;
    my $next_dep_id = $dbh->selectrow_array(
        "SELECT $field FROM bugs WHERE bug_id = ?", undef, $dep_id);

    _check_relationship_loop($field, $dep_id, $next_dep_id, $ids);
}

#####################################################################
# Class Accessors
#####################################################################

sub fields {
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
           dependson blocked everconfirmed
           reporter assigned_to cc estimated_time
           remaining_time actual_time deadline),

        # Use QA contact?
        Bugzilla->params->{useqacontact} ? "qa_contact" : (),

        # Custom Fields
        map { $_->name } Bugzilla->active_custom_fields
    );
    Bugzilla::Hook::process('bug_fields', {'fields' => \@fields} );

    return @fields;
}

#####################################################################
# Mutators
#####################################################################

# To run check_can_change_field.
sub _set_global_validator {
    my ($self, $value, $field) = @_;
    my $current = $self->$field;
    my $privs;

    if (ref $current && ref($current) ne 'ARRAY'
        && $current->isa('Bugzilla::Object')) {
        $current = $current->id ;
    }
    if (ref $value && ref($value) ne 'ARRAY'
        && $value->isa('Bugzilla::Object')) {
        $value = $value->id ;
    }
    my $can = $self->check_can_change_field($field, $current, $value, \$privs);
    if (!$can) {
        if ($field eq 'assigned_to' || $field eq 'qa_contact') {
            $value   = user_id_to_login($value);
            $current = user_id_to_login($current);
        }
        ThrowUserError('illegal_change', { field    => $field,
                                           oldvalue => $current,
                                           newvalue => $value,
                                           privs    => $privs });
    }
    $self->_check_field_is_mandatory($value, $field);
}

#################
# "Set" Methods #
#################

# Note that if you are changing multiple bugs at once, you must pass
# other_bugs to set_all in order for it to behave properly.
sub set_all {
    my $self = shift;
    my ($input_params) = @_;
    
    # Clone the data as we are going to alter it, and this would affect
    # subsequent bugs when calling set_all() again, as some fields would
    # be modified or no longer defined.
    my $params = {};
    %$params = %$input_params;

    # You cannot mark bugs as duplicate when changing several bugs at once
    # (because currently there is no way to check for duplicate loops in that
    # situation). You also cannot set the alias of several bugs at once.
    if ($params->{other_bugs} and scalar @{ $params->{other_bugs} } > 1) {
        ThrowUserError('dupe_not_allowed') if exists $params->{dup_id};
        ThrowUserError('multiple_alias_not_allowed') 
            if defined $params->{alias};
    }

    # For security purposes, and because lots of other checks depend on it,
    # we set the product first before anything else.
    my $product_changed; # Used only for strict_isolation checks.
    if (exists $params->{'product'}) {
        $product_changed = $self->_set_product($params->{'product'}, $params);
    }

    # strict_isolation checks mean that we should set the groups
    # immediately after changing the product.
    $self->_add_remove($params, 'groups');

    if (exists $params->{'dependson'} or exists $params->{'blocked'}) {
        my %set_deps;
        foreach my $name (qw(dependson blocked)) {
            my @dep_ids = @{ $self->$name };
            # If only one of the two fields was passed in, then we need to
            # retain the current value for the other one.
            if (!exists $params->{$name}) {
                $set_deps{$name} = \@dep_ids;
                next;
            }

            # Explicitly setting them to a particular value overrides
            # add/remove.
            if (exists $params->{$name}->{set}) {
                $set_deps{$name} = $params->{$name}->{set};
                next;
            }

            foreach my $add (@{ $params->{$name}->{add} || [] }) {
                push(@dep_ids, $add) if !grep($_ == $add, @dep_ids);
            }
            foreach my $remove (@{ $params->{$name}->{remove} || [] }) {
                @dep_ids = grep($_ != $remove, @dep_ids);
            }
            $set_deps{$name} = \@dep_ids;
        }

        $self->set_dependencies($set_deps{'dependson'}, $set_deps{'blocked'});
    }

    if (exists $params->{'keywords'}) {
        # Sorting makes the order "add, remove, set", just like for other
        # fields.
        foreach my $action (sort keys %{ $params->{'keywords'} }) {
            $self->modify_keywords($params->{'keywords'}->{$action}, $action);
        }
    }

    if (exists $params->{'comment'} or exists $params->{'work_time'}) {
        # Add a comment as needed to each bug. This is done early because
        # there are lots of things that want to check if we added a comment.
        $self->add_comment($params->{'comment'}->{'body'},
            { isprivate => $params->{'comment'}->{'is_private'},
              work_time => $params->{'work_time'} });
    }

    my %normal_set_all;
    foreach my $name (keys %$params) {
        # These are handled separately below.
        if ($self->can("set_$name")) {
            $normal_set_all{$name} = $params->{$name};
        }
    }
    $self->SUPER::set_all(\%normal_set_all);

    $self->reset_assigned_to if $params->{'reset_assigned_to'};
    $self->reset_qa_contact  if $params->{'reset_qa_contact'};

    $self->_add_remove($params, 'see_also');

    # And set custom fields.
    my @custom_fields = Bugzilla->active_custom_fields;
    foreach my $field (@custom_fields) {
        my $fname = $field->name;
        if (exists $params->{$fname}) {
            $self->set_custom_field($field, $params->{$fname});
        }
    }

    $self->_add_remove($params, 'cc');

    # Theoretically you could move a product without ever specifying
    # a new assignee or qa_contact, or adding/removing any CCs. So,
    # we have to check that the current assignee, qa, and CCs are still
    # valid if we've switched products, under strict_isolation. We can only
    # do that here, because if they *did* change the assignee, qa, or CC,
    # then we don't want to check the original ones, only the new ones. 
    $self->_check_strict_isolation() if $product_changed;
}

# Helper for set_all that helps with fields that have an "add/remove"
# pattern instead of a "set_" pattern.
sub _add_remove {
    my ($self, $params, $name) = @_;
    my @add    = @{ $params->{$name}->{add}    || [] };
    my @remove = @{ $params->{$name}->{remove} || [] };
    $name =~ s/s$//;
    my $add_method = "add_$name";
    my $remove_method = "remove_$name";
    $self->$add_method($_) foreach @add;
    $self->$remove_method($_) foreach @remove;
}

sub set_alias { $_[0]->set('alias', $_[1]); }
sub set_assigned_to {
    my ($self, $value) = @_;
    $self->set('assigned_to', $value);
    # Store the old assignee. check_can_change_field() needs it.
    $self->{'_old_assigned_to'} = $self->{'assigned_to_obj'}->id;
    delete $self->{'assigned_to_obj'};
}
sub reset_assigned_to {
    my $self = shift;
    my $comp = $self->component_obj;
    $self->set_assigned_to($comp->default_assignee);
}
sub set_cclist_accessible { $_[0]->set('cclist_accessible', $_[1]); }
sub set_comment_is_private {
    my ($self, $comment_id, $isprivate) = @_;

    # We also allow people to pass in a hash of comment ids to update.
    if (ref $comment_id) {
        while (my ($id, $is) = each %$comment_id) {
            $self->set_comment_is_private($id, $is);
        }
        return;
    }

    my ($comment) = grep($comment_id == $_->id, @{ $self->comments });
    ThrowUserError('comment_invalid_isprivate', { id => $comment_id })
        if !$comment;

    $isprivate = $isprivate ? 1 : 0;
    if ($isprivate != $comment->is_private) {
        ThrowUserError('user_not_insider') if !Bugzilla->user->is_insider;
        $self->{comment_isprivate} ||= [];
        $comment->set_is_private($isprivate);
        push @{$self->{comment_is_private}}, $comment;
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
sub set_component  {
    my ($self, $name) = @_;
    my $old_comp  = $self->component_obj;
    my $component = $self->_check_component($name);
    if ($component && $old_comp->id != $component->id) {
        $self->{component_id}  = $component->id;
        $self->{component}     = $component->name;
        $self->{component_obj} = $component;
        # For update()
        $self->{_old_component_name} = $old_comp->name;
        # Add in the Default CC of the new Component;
        foreach my $cc (@{$component->initial_cc}) {
            $self->add_cc($cc);
        }
    }
}
sub set_custom_field {
    my ($self, $field, $value) = @_;

    if (ref $value eq 'ARRAY' && $field->type != FIELD_TYPE_MULTI_SELECT) {
        $value = $value->[0];
    }
    ThrowCodeError('field_not_custom', { field => $field }) if !$field->custom;
    $self->set($field->name, $value);
}
sub set_deadline { $_[0]->set('deadline', $_[1]); }
sub set_dependencies {
    my ($self, $dependson, $blocked) = @_;
    my %extra = ( blocked => $blocked );
    $dependson = $self->_check_dependencies($dependson, 'dependson', \%extra);
    $blocked = $extra{blocked};
    # These may already be detainted, but all setters are supposed to
    # detaint their input if they've run a validator (just as though
    # we had used Bugzilla::Object::set), so we do that here.
    detaint_natural($_) foreach (@$dependson, @$blocked);
    $self->{'dependson'} = $dependson;
    $self->{'blocked'}   = $blocked;
    delete $self->{depends_on_obj};
    delete $self->{blocks_obj};
}
sub _clear_dup_id { $_[0]->{dup_id} = undef; }
sub set_dup_id {
    my ($self, $dup_id) = @_;
    my $old = $self->dup_id || 0;
    $self->set('dup_id', $dup_id);
    my $new = $self->dup_id;
    return if $old == $new;

    # Make sure that we have the DUPLICATE resolution. This is needed
    # if somebody calls set_dup_id without calling set_bug_status or
    # set_resolution.
    if ($self->resolution ne 'DUPLICATE') {
        # Even if the current status is VERIFIED, we change it back to
        # RESOLVED (or whatever the duplicate_or_move_bug_status is) here,
        # because that's the same thing the UI does when you click on the
        # "Mark as Duplicate" link. If people really want to retain their
        # current status, they can use set_bug_status and set the DUPLICATE
        # resolution before getting here.
        $self->set_bug_status(
            Bugzilla->params->{'duplicate_or_move_bug_status'},
            { resolution => 'DUPLICATE' });
    }
    
    # Update the other bug.
    my $dupe_of = new Bugzilla::Bug($self->dup_id);
    if (delete $self->{_add_dup_cc}) {
        $dupe_of->add_cc($self->reporter);
    }
    $dupe_of->add_comment("", { type       => CMT_HAS_DUPE,
                                extra_data => $self->id });
    $self->{_dup_for_update} = $dupe_of;

    # Now make sure that we add a duplicate comment on *this* bug.
    # (Change an existing comment into a dup comment, if there is one,
    # or add an empty dup comment.)
    my @normal = grep { !defined $_->{type} || $_->{type} == CMT_NORMAL }
        @{ $self->{added_comments} || [] };
    if (@normal) {
        # Turn the last one into a dup comment.
        $normal[-1]->{type} = CMT_DUPE_OF;
        $normal[-1]->{extra_data} = $self->dup_id;
    }
    else {
        $self->add_comment('', { type       => CMT_DUPE_OF,
                                 extra_data => $self->dup_id });
    }
}
sub set_estimated_time { $_[0]->set('estimated_time', $_[1]); }
sub _set_everconfirmed { $_[0]->set('everconfirmed', $_[1]); }
sub set_flags {
    my ($self, $flags, $new_flags) = @_;

    Bugzilla::Flag->set_flag($self, $_) foreach (@$flags, @$new_flags);
}
sub set_op_sys         { $_[0]->set('op_sys',        $_[1]); }
sub set_platform       { $_[0]->set('rep_platform',  $_[1]); }
sub set_priority       { $_[0]->set('priority',      $_[1]); }
# For security reasons, you have to use set_all to change the product.
# See the strict_isolation check in set_all for an explanation.
sub _set_product {
    my ($self, $name, $params) = @_;
    my $old_product = $self->product_obj;
    my $product = $self->_check_product($name);

    if ($old_product->id != $product->id)
    {
        $self->{product_id}  = $product->id;
        $self->{product}     = $product->name;
        $self->{product_obj} = $product;
        # For update()
        $self->{_old_product_name} = $old_product->name;
        # Delete fields that depend upon the old Product value.
        delete $self->{choices};
        $self->{product_changed} = 1;
    }

    $params ||= {};
    # We delete these so that they're not set again later in set_all.
    my $comp_name = delete $params->{component} || $self->component;
    my $vers_name = delete $params->{version}   || $self->version;
    my $tm_name   = delete $params->{target_milestone};
    # This way, if usetargetmilestone is off and we've changed products,
    # set_target_milestone will reset our target_milestone to
    # $product->default_milestone. But if we haven't changed products,
    # we don't reset anything.
    if (!defined $tm_name
        && (Bugzilla->params->{'usetargetmilestone'} || !$product_changed))
    {
        $tm_name = $self->target_milestone;
    }

    if ($product_changed && Bugzilla->usage_mode == USAGE_MODE_BROWSER) {
        # Try to set each value with the new product.
        # Have to set error_mode because Throw*Error calls exit() otherwise.
        my $old_error_mode = Bugzilla->error_mode;
        Bugzilla->error_mode(ERROR_MODE_DIE);
        my $component_ok = eval { $self->set_component($comp_name);      1; };
        my $version_ok   = eval { $self->set_version($vers_name);        1; };
        my $milestone_ok = 1;
        # Reporters can move bugs between products but not set the TM.
        if ($self->check_can_change_field('target_milestone', 0, 1)) {
            $milestone_ok = eval { $self->set_target_milestone($tm_name); 1; };
        }
        else {
            # Have to set this directly to bypass the validators.
            $self->{target_milestone} = $product->default_milestone;
        }
        # If there were any errors thrown, make sure we don't mess up any
        # other part of Bugzilla that checks $@.
        undef $@;
        Bugzilla->error_mode($old_error_mode);
        
        my $verified = $params->{product_change_confirmed};
        my %vars;
        if (!$verified || !$component_ok || !$version_ok || !$milestone_ok) {
            $vars{defaults} = {
                # Note that because of the eval { set } above, these are
                # already set correctly if they're valid, otherwise they're
                # set to some invalid value which the template will ignore.
                component => $self->component,
                version   => $self->version,
                milestone => $milestone_ok ? $self->target_milestone
                                           : $product->default_milestone
            };
            $vars{components} = [map { $_->name } @{$product->components}];
            $vars{milestones} = [map { $_->name } @{$product->milestones}];
            $vars{versions}   = [map { $_->name } @{$product->versions}];
        }

        if (!$verified) {
            $vars{verify_bug_groups} = 1;
            my $dbh = Bugzilla->dbh;
            my @idlist = ($self->id);
            push(@idlist, map {$_->id} @{ $params->{other_bugs} })
                if $params->{other_bugs};
            # Get the ID of groups which are no longer valid in the new product.
            my $gids = $dbh->selectcol_arrayref(
                'SELECT bgm.group_id
                   FROM bug_group_map AS bgm
                  WHERE bgm.bug_id IN (' . join(',', ('?') x @idlist) . ')
                    AND bgm.group_id NOT IN
                        (SELECT gcm.group_id
                           FROM group_control_map AS gcm
                           WHERE gcm.product_id = ?
                                 AND ( (gcm.membercontrol != ?
                                        AND gcm.group_id IN ('
                                        . Bugzilla->user->groups_as_string . '))
                                       OR gcm.othercontrol != ?) )',
                undef, (@idlist, $product->id, CONTROLMAPNA, CONTROLMAPNA));
            $vars{'old_groups'} = Bugzilla::Group->new_from_list($gids);            
        }
        
        if (%vars) {
            $vars{product} = $product;
            $vars{bug} = $self;
            my $template = Bugzilla->template;
            $template->process("bug/process/verify-new-product.html.tmpl",
                \%vars) || ThrowTemplateError($template->error());
            exit;
        }
    }
    else {
        # When we're not in the browser (or we didn't change the product), we
        # just die if any of these are invalid.
        $self->set_component($comp_name);
        $self->set_version($vers_name);
        if ($product_changed 
            and !$self->check_can_change_field('target_milestone', 0, 1)) 
        {
            # Have to set this directly to bypass the validators.
            $self->{target_milestone} = $product->default_milestone;
        }
        else {
            $self->set_target_milestone($tm_name);
        }
    }

    if ($product_changed) {
        # Remove groups that can't be set in the new product.
        # We copy this array because the original array is modified while we're
        # working, and that confuses "foreach".
        my @current_groups = @{$self->groups_in};
        foreach my $group (@current_groups) {
            if (!$product->group_is_valid($group)) {
                $self->remove_group($group);
            }
        }

        # Make sure the bug is in all the mandatory groups for the new product.
        foreach my $group (@{$product->groups_mandatory}) {
            $self->add_group($group);
        }
    }
    
    return $product_changed;
}

sub set_qa_contact {
    my ($self, $value) = @_;
    $self->set('qa_contact', $value);
    # Store the old QA contact. check_can_change_field() needs it.
    if ($self->{'qa_contact_obj'}) {
        $self->{'_old_qa_contact'} = $self->{'qa_contact_obj'}->id;
    }
    delete $self->{'qa_contact_obj'};
}
sub reset_qa_contact {
    my $self = shift;
    my $comp = $self->component_obj;
    $self->set_qa_contact($comp->default_qa_contact);
}
sub set_remaining_time { $_[0]->set('remaining_time', $_[1]); }
# Used only when closing a bug or moving between closed states.
# sub _zero_remaining_time { $_[0]->{'remaining_time'} = 0; }
sub _zero_remaining_time { }
sub set_reporter_accessible { $_[0]->set('reporter_accessible', $_[1]); }
sub set_resolution {
    my ($self, $value, $params) = @_;

    my $old_res = $self->resolution;
    $self->set('resolution', $value);
    delete $self->{choices};
    my $new_res = $self->resolution;

    if ($new_res ne $old_res) {
        # Clear the dup_id if we're leaving the dup resolution.
        if ($old_res eq 'DUPLICATE') {
            $self->_clear_dup_id();
        }
        # Duplicates should have no remaining time left.
        elsif ($new_res eq 'DUPLICATE' && $self->remaining_time != 0) {
            $self->_zero_remaining_time();
        }
    }

    # We don't check if we're entering or leaving the dup resolution here,
    # because we could be moving from being a dup of one bug to being a dup
    # of another, theoretically. Note that this code block will also run
    # when going between different closed states.
    if ($self->resolution eq 'DUPLICATE') {
        if (my $dup_id = $params->{dup_id}) {
            $self->set_dup_id($dup_id);
        }
        elsif (!$self->dup_id) {
            ThrowUserError('dupe_id_required');
        }
    }

    # This method has handled dup_id, so set_all doesn't have to worry
    # about it now.
    delete $params->{dup_id};
}
sub clear_resolution {
    my $self = shift;
    if (!$self->status->is_open) {
        ThrowUserError('resolution_cant_clear', { bug_id => $self->id });
    }
    $self->{'resolution'} = '';
    $self->_clear_dup_id;
}
sub set_severity       { $_[0]->set('bug_severity',  $_[1]); }
sub set_bug_status {
    my ($self, $status, $params) = @_;
    my $old_status = $self->status;
    $self->{'bug_status'} = $status;
    delete $self->{'status'};
    delete $self->{'statuses_available'};
    delete $self->{'choices'};
    my $new_status = $self->status;

    if ($new_status->is_open) {
        # Check for the everconfirmed transition
        $self->_set_everconfirmed($new_status->name eq 'UNCONFIRMED' ? 0 : 1);
        $self->clear_resolution();
        # Calling clear_resolution handled the "resolution" and "dup_id"
        # setting, so set_all doesn't have to worry about them.
        delete $params->{resolution};
        delete $params->{dup_id};
    }
    else {
        # We do this here so that we can make sure closed statuses have
        # resolutions.
        my $resolution = $self->resolution;
        # We need to check "defined" to prevent people from passing
        # a blank resolution in the WebService, which would otherwise fail
        # silently.
        if (defined $params->{resolution}) {
            $resolution = delete $params->{resolution};
        }
        $self->set_resolution($resolution, $params);

        # Changing between closed statuses zeros the remaining time.
        if ($new_status->id != $old_status->id && $self->remaining_time != 0) {
            $self->_zero_remaining_time();
        }
    }
}
sub set_status_whiteboard { $_[0]->set('status_whiteboard', $_[1]); }
sub set_summary           { $_[0]->set('short_desc',        $_[1]); }
sub set_target_milestone  { $_[0]->set('target_milestone',  $_[1]); }
sub set_url               { $_[0]->set('bug_file_loc',      $_[1]); }
sub set_version           { $_[0]->set('version',           $_[1]); }
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

########################
# "Add/Remove" Methods #
########################

# These are in alphabetical order by field name.

# Accepts a User object or a username. Adds the user only if they
# don't already exist as a CC on the bug.
sub add_cc {
    my ($self, $user_or_name) = @_;
    return if !$user_or_name;
    my $user = ref $user_or_name ? $user_or_name
                                 : Bugzilla::User->check($user_or_name);
    $self->_check_strict_isolation_for_user($user);
    my $cc_users = $self->cc_users;
    push(@$cc_users, $user) if !grep($_->id == $user->id, @$cc_users);
}

# Accepts a User object or a username. Removes the User if they exist
# in the list, but doesn't throw an error if they don't exist.
sub remove_cc {
    my ($self, $user_or_name) = @_;
    my $user = ref $user_or_name ? $user_or_name
                                 : Bugzilla::User->check($user_or_name);
    my $currentUser = Bugzilla->user;
    if (!$self->user->{'canedit'} && $user->id != $currentUser->id) {
        ThrowUserError('cc_remove_denied');
    }
    my $cc_users = $self->cc_users;
    @$cc_users = grep { $_->id != $user->id } @$cc_users;
}

# $bug->add_comment("comment", {isprivate => 1, work_time => 10.5,
#                               type => CMT_NORMAL, extra_data => $data});
sub add_comment {
    my ($self, $comment, $params) = @_;

    $params ||= {};
    if (exists $params->{work_time}) {
        $params->{work_time} = $self->_check_work_time($params->{work_time});
        if ($comment eq '' && $params->{work_time} != 0 &&
            (!exists $params->{type} ||
            $params->{type} != CMT_WORKTIME &&
            $params->{type} != CMT_BACKDATED_WORKTIME))
        {
            ThrowUserError('comment_required');
        }
    }
    if (exists $params->{type}) {
        $params->{type} = $self->_check_comment_type($params->{type});
    }
    # XXX We really should check extra_data, too.

    # Fill out info that doesn't change and callers may not pass in
    $params->{'bug_id'}  = $self;
    $params->{'thetext'} = defined($comment) ? $comment : '';

    # Validate all the entered data
    Bugzilla::Comment->check_required_create_fields($params);
    $params = Bugzilla::Comment->run_create_validators($params);

    # This makes it so we won't create new comments when there is nothing
    # to add 
    if ($params->{'thetext'} eq ''
        && !($params->{type} || abs($params->{work_time} || 0)))
    {
        return;
    }

    # If the user has explicitly set remaining_time, this will be overridden
    # later in set_all. But if they haven't, this keeps remaining_time
    # up-to-date.
    if ($params->{work_time}) {
        $self->set_remaining_time(max($self->remaining_time - $params->{work_time}, 0));
    }

    $self->{added_comments} ||= [];

    push(@{$self->{added_comments}}, $params);
}

# Edit comment checker
sub edit_comment {
    my ($self, $comment_id, $comment) = @_;

    my $db_comment = Bugzilla::Comment->new($comment_id);
    my $old_comment = $self->_check_comment($db_comment->body);
    $comment = $self->_check_comment($comment);
    $self->{edited_comments} ||= [];

    if ($old_comment ne $comment) {
        push(@{$self->{edited_comments}}, {
            comment_id => $comment_id,
            oldthetext => $old_comment->{thetext},
            thetext => $comment->{thetext}
        });
    }
}

# There was a lot of duplicate code when I wrote this as three separate
# functions, so I just combined them all into one. This is also easier for
# process_bug to use.
sub modify_keywords {
    my ($self, $keywords, $keywords_description, $action) = @_;

    $action ||= 'set';
    if (!grep($action eq $_, qw(add remove set))) {
        $action = 'set';
    }

    $keywords = $self->_check_keywords($keywords, $keywords_description);

    my (@result, $any_changes);
    if ($action eq 'set') {
        @result = @$keywords;
        # Check if anything was added or removed.
        my @old_ids = map { $_->id } @{$self->keyword_objects};
        my @new_ids = map { $_->id } @result;
        my ($removed, $added) = diff_arrays(\@old_ids, \@new_ids);
        $any_changes = scalar @$removed || scalar @$added;
    }
    else {
        # We're adding or deleting specific keywords.
        my %keys = map {$_->id => $_} @{$self->keyword_objects};
        if ($action eq 'add') {
            $keys{$_->id} = $_ foreach @$keywords;
        }
        else {
            delete $keys{$_->id} foreach @$keywords;
        }
        @result = values %keys;
        $any_changes = scalar @$keywords;
    }
    # Make sure we retain the sort order.
    @result = sort {lc($a->name) cmp lc($b->name)} @result;

    if ($any_changes) {
        my $privs;
        my $new = join(', ', (map {$_->name} @result));
        my $check = $self->check_can_change_field('keywords', 0, 1, \$privs)
            || ThrowUserError('illegal_change', { field    => 'keywords',
                                                  oldvalue => $self->keywords,
                                                  newvalue => $new,
                                                  privs    => $privs });
    }

    $self->{'keyword_objects'} = \@result;
}

sub add_group {
    my ($self, $group) = @_;

    # If the user enters "FoO" but the DB has "Foo", $group->name would
    # return "Foo" and thus revealing the existence of the group name.
    # So we have to store and pass the name as entered by the user to
    # the error message, if we have it.
    my $group_name = blessed($group) ? $group->name : $group;
    my $args = { name => $group_name, product => $self->product,
                 bug_id => $self->id, action => 'add' };

    $group = Bugzilla::Group->check_no_disclose($args) if !blessed $group;

    # If the bug is already in this group, then there is nothing to do.
    return if $self->in_group($group);


    # Make sure that bugs in this product can actually be restricted
    # to this group by the current user.
    $self->product_obj->group_is_settable($group)
         || ThrowUserError('group_restriction_not_allowed', $args);

    # OtherControl people can add groups only during a product change,
    # and only when the group is not NA for them.
    if (!Bugzilla->user->in_group($group->name)) {
        my $controls = $self->product_obj->group_controls->{$group->id};
        if (!$self->{_old_product_name}
            || $controls->{othercontrol} == CONTROLMAPNA)
        {
            ThrowUserError('group_restriction_not_allowed', $args);
        }
    }

    my $current_groups = $self->groups_in;
    push(@$current_groups, $group);
}

sub remove_group {
    my ($self, $group) = @_;

    # See add_group() for the reason why we store the user input.
    my $group_name = blessed($group) ? $group->name : $group;
    my $args = { name => $group_name, product => $self->product,
                 bug_id => $self->id, action => 'remove' };

    $group = Bugzilla::Group->check_no_disclose($args) if !blessed $group;

    # If the bug isn't in this group, then either the name is misspelled,
    # or the group really doesn't exist. Let the user know about this problem.
    $self->in_group($group) || ThrowUserError('group_invalid_removal', $args);

    # Check if this is a valid group for this product. You can *always*
    # remove a group that is not valid for this product (set_product does this).
    # This particularly happens when we're moving a bug to a new product.
    # You still have to be a member of an inactive group to remove it.
    if ($self->product_obj->group_is_valid($group)) {
        my $controls = $self->product_obj->group_controls->{$group->id};

        # Nobody can ever remove a Mandatory group, unless it became inactive.
        if ($controls->{membercontrol} == CONTROLMAPMANDATORY && $group->is_active) {
            ThrowUserError('group_invalid_removal', $args);
        }

        # OtherControl people can remove groups only during a product change,
        # and only when they are non-Mandatory and non-NA.
        if (!Bugzilla->user->in_group($group->name)) {
            if (!$self->{_old_product_name}
                || $controls->{othercontrol} == CONTROLMAPMANDATORY
                || $controls->{othercontrol} == CONTROLMAPNA)
            {
                ThrowUserError('group_invalid_removal', $args);
            }
        }
    }

    my $current_groups = $self->groups_in;
    @$current_groups = grep { $_->id != $group->id } @$current_groups;
}

sub add_see_also {
    my ($self, $input, $skip_recursion) = @_;

    # This is needed by xt/search.t.
    $input = $input->name if blessed($input);

    $input = trim($input);
    return if !$input;

    my ($class, $uri) = Bugzilla::BugUrl->class_for($input);

    my $params = { value => $uri, bug_id => $self, class => $class };
    $class->check_required_create_fields($params);

    my $field_values = $class->run_create_validators($params);
    $uri = $field_values->{value};
    $field_values->{value} = $uri->as_string;

    # We only add the new URI if it hasn't been added yet. URIs are
    # case-sensitive, but most of our DBs are case-insensitive, so we do
    # this check case-insensitively.
    my $value = $uri->as_string;

    if (!grep { lc($_->name) eq lc($value) } @{ $self->see_also }) {
        my $privs;
        my $can = $self->check_can_change_field('see_also', '', $value, \$privs);
        if (!$can) {
            ThrowUserError('illegal_change', { field    => 'see_also',
                                               newvalue => $value,
                                               privs    => $privs });
        }
        # If this is a link to a local bug then save the
        # ref bug id for sending changes email.
        my $ref_bug = delete $field_values->{ref_bug};
        if ($class->isa('Bugzilla::BugUrl::Bugzilla::Local')
            and !$skip_recursion)
        {
            $ref_bug->add_see_also($self->id, 'skip_recursion');
            push @{ $self->{_update_ref_bugs} }, $ref_bug;
            push @{ $self->{see_also_changes} }, $ref_bug->id;
        }
        push @{ $self->{see_also} }, bless ($field_values, $class);
    }
}

sub remove_see_also {
    my ($self, $url, $skip_recursion) = @_;
    my $see_also = $self->see_also;

    # This is needed by xt/search.t.
    $url = $url->name if blessed($url);

    my ($removed_bug_url, $new_see_also) =
        part { lc($_->name) ne lc($url) } @$see_also;

    my $privs;
    my $can = $self->check_can_change_field('see_also', $see_also, $new_see_also, \$privs);
    if (!$can) {
        ThrowUserError('illegal_change', { field    => 'see_also',
                                           oldvalue => $url,
                                           privs    => $privs });
    }

    # Since we remove also the url from the referenced bug,
    # we need to notify changes for that bug too.
    $removed_bug_url = $removed_bug_url->[0];
    if (!$skip_recursion and $removed_bug_url
        and $removed_bug_url->isa('Bugzilla::BugUrl::Bugzilla::Local'))
    {
        my $ref_bug
            = Bugzilla::Bug->check($removed_bug_url->ref_bug_url->bug_id);

        if (Bugzilla->user->can_edit_product($ref_bug->product_id)) {
            my $self_url = $removed_bug_url->local_uri($self->id);
            $ref_bug->remove_see_also($self_url, 'skip_recursion');
            push @{ $self->{_update_ref_bugs} }, $ref_bug;
            push @{ $self->{see_also_changes} }, $ref_bug->id;
        }
    }

    $self->{see_also} = $new_see_also || [];
}

sub add_tag {
    my ($self, $tag) = @_;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    $tag = $self->_check_tag_name($tag);

    my $tag_id = $user->tags->{$tag}->{id};
    # If this tag doesn't exist for this user yet, create it.
    if (!$tag_id) {
        $dbh->do('INSERT INTO tag (user_id, name) VALUES (?, ?)',
                  undef, ($user->id, $tag));

        $tag_id = $dbh->selectrow_array('SELECT id FROM tag
                                         WHERE name = ? AND user_id = ?',
                                         undef, ($tag, $user->id));
        # The list has changed.
        delete $user->{tags};
    }
    # Do nothing if this tag is already set for this bug.
    return if grep { $_ eq $tag } @{$self->tags};

    # Increment the counter. Do it before the SQL call below,
    # to not count the tag twice.
    $user->tags->{$tag}->{bug_count}++;

    $dbh->do('INSERT INTO bug_tag (bug_id, tag_id) VALUES (?, ?)',
              undef, ($self->id, $tag_id));

    push(@{$self->{tags}}, $tag);
}

sub remove_tag {
    my ($self, $tag) = @_;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    $tag = $self->_check_tag_name($tag);

    my $tag_id = exists $user->tags->{$tag} ? $user->tags->{$tag}->{id} : undef;
    # Do nothing if the user doesn't use this tag, or didn't set it for this bug.
    return unless ($tag_id && grep { $_ eq $tag } @{$self->tags});

    $dbh->do('DELETE FROM bug_tag WHERE bug_id = ? AND tag_id = ?',
              undef, ($self->id, $tag_id));

    $self->{tags} = [grep { $_ ne $tag } @{$self->tags}];

    # Decrement the counter, and delete the tag if no bugs are using it anymore.
    if (!--$user->tags->{$tag}->{bug_count}) {
        $dbh->do('DELETE FROM tag WHERE name = ? AND user_id = ?',
                  undef, ($tag, $user->id));

        # The list has changed.
        delete $user->{tags};
    }
}

sub tags {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # This method doesn't support several users using the same bug object.
    if (!exists $self->{tags}) {
        $self->{tags} = $dbh->selectcol_arrayref(
            'SELECT name FROM bug_tag
             INNER JOIN tag ON tag.id = bug_tag.tag_id
             WHERE bug_id = ? AND user_id = ?',
             undef, ($self->id, $user->id));
    }
    return $self->{tags};
}

#####################################################################
# Simple Accessors
#####################################################################

# These are accessors that don't need to access the database.
# Keep them in alphabetical order.

sub alias               { return $_[0]->{alias}               }
sub bug_file_loc        { return $_[0]->{bug_file_loc}        }
sub bug_id              { return $_[0]->{bug_id}              }
sub bug_severity        { return $_[0]->{bug_severity}        }
sub bug_status          { return $_[0]->{bug_status}          }
sub cclist_accessible   { return $_[0]->{cclist_accessible}   }
sub component_id        { return $_[0]->{component_id}        }
sub creation_ts         { return $_[0]->{creation_ts}         }
sub estimated_time      { return $_[0]->{estimated_time}      }
sub deadline            { return $_[0]->{deadline}            }
sub delta_ts            { return $_[0]->{delta_ts}            }
sub error               { return $_[0]->{error}               }
sub everconfirmed       { return $_[0]->{everconfirmed}       }
sub lastdiffed          { return $_[0]->{lastdiffed}          }
sub op_sys              { return $_[0]->{op_sys}              }
sub priority            { return $_[0]->{priority}            }
sub product_id          { return $_[0]->{product_id}          }
sub remaining_time      { return $_[0]->{remaining_time}      }
sub reporter_accessible { return $_[0]->{reporter_accessible} }
sub rep_platform        { return $_[0]->{rep_platform}        }
sub resolution          { return $_[0]->{resolution}          }
sub short_desc          { return $_[0]->{short_desc}          }
sub status_whiteboard   { return $_[0]->{status_whiteboard}   }
sub target_milestone    { return $_[0]->{target_milestone}    }
sub version             { return $_[0]->{version}             }

#####################################################################
# Complex Accessors
#####################################################################

# These are accessors that have to access the database for additional
# information about a bug.

# These subs are in alphabetical order, as much as possible.
# If you add a new sub, please try to keep it in alphabetical order
# with the other ones.

# Note: If you add a new method, remember that you must check the error
# state of the bug before returning any data. If $self->{error} is
# defined, then return something empty. Otherwise you risk potential
# security holes.

sub dup_id {
    my ($self) = @_;
    return $self->{'dup_id'} if exists $self->{'dup_id'};

    $self->{'dup_id'} = undef;
    return if $self->{'error'};

    if ($self->{'resolution'} eq 'DUPLICATE') {
        my $dbh = Bugzilla->dbh;
        $self->{'dup_id'} =
          $dbh->selectrow_array(q{SELECT dupe_of
                                  FROM duplicates
                                  WHERE dupe = ?},
                                undef,
                                $self->{'bug_id'});
    }
    return $self->{'dup_id'};
}

sub _resolve_ultimate_dup_id {
    my ($bug_id, $dupe_of, $loops_are_an_error) = @_;
    my $dbh = Bugzilla->dbh;
    my $sth = $dbh->prepare('SELECT dupe_of FROM duplicates WHERE dupe = ?');

    my $this_dup = $dupe_of || $dbh->selectrow_array($sth, undef, $bug_id);
    my $last_dup = $bug_id;

    my %dupes;
    while ($this_dup) {
        if ($this_dup == $bug_id) {
            if ($loops_are_an_error) {
                ThrowUserError('dupe_loop_detected', { bug_id  => $bug_id,
                                                       dupe_of => $dupe_of });
            }
            else {
                return $last_dup;
            }
        }
        # If $dupes{$this_dup} is already set to 1, then a loop
        # already exists which does not involve this bug.
        # As the user is not responsible for this loop, do not
        # prevent him from marking this bug as a duplicate.
        return $last_dup if exists $dupes{$this_dup};
        $dupes{$this_dup} = 1;
        $last_dup = $this_dup;
        $this_dup = $dbh->selectrow_array($sth, undef, $this_dup);
    }

    return $last_dup;
}

sub actual_time {
    my ($self) = @_;
    return $self->{'actual_time'} if exists $self->{'actual_time'};

    if ( $self->{'error'} || !Bugzilla->user->is_timetracker ) {
        $self->{'actual_time'} = undef;
        return $self->{'actual_time'};
    }

    my $sth = Bugzilla->dbh->prepare("SELECT SUM(work_time)
                                      FROM longdescs
                                      WHERE longdescs.bug_id=?");
    $sth->execute($self->{bug_id});
    $self->{'actual_time'} = $sth->fetchrow_array();
    return $self->{'actual_time'};
}

sub any_flags_requesteeble {
    my ($self) = @_;
    return $self->{'any_flags_requesteeble'}
        if exists $self->{'any_flags_requesteeble'};
    return 0 if $self->{'error'};

    my $any_flags_requesteeble =
      grep { $_->is_requestable && $_->is_requesteeble } @{$self->flag_types};
    # Useful in case a flagtype is no longer requestable but a requestee
    # has been set before we turned off that bit.
    $any_flags_requesteeble ||= grep { $_->requestee_id } @{$self->flags};
    $self->{'any_flags_requesteeble'} = $any_flags_requesteeble;

    return $self->{'any_flags_requesteeble'};
}

sub attachments {
    my ($self) = @_;
    return $self->{'attachments'} if exists $self->{'attachments'};
    return [] if $self->{'error'};

    $self->{'attachments'} =
        Bugzilla::Attachment->get_attachments_by_bug($self->bug_id, {preload => 1});
    return $self->{'attachments'};
}

sub assigned_to {
    my ($self) = @_;
    return $self->{'assigned_to_obj'} if exists $self->{'assigned_to_obj'};
    $self->{'assigned_to'} = 0 if $self->{'error'};
    $self->{'assigned_to_obj'} ||= new Bugzilla::User($self->{'assigned_to'});
    return $self->{'assigned_to_obj'};
}

sub blocked {
    my ($self) = @_;
    return $self->{'blocked'} if exists $self->{'blocked'};
    return [] if $self->{'error'};
    $self->{'blocked'} = EmitDependList("dependson", "blocked", $self->bug_id);
    return $self->{'blocked'};
}

sub blocks_obj {
    my ($self) = @_;
    $self->{blocks_obj} ||= $self->_bugs_in_order($self->blocked);
    return $self->{blocks_obj};
}

sub bug_group {
    my ($self) = @_;
    return join(', ', (map { $_->name } @{$self->groups_in}));
}

sub related_bugs {
    my ($self, $relationship) = @_;
    return [] if $self->{'error'};

    my $field_name = $relationship->name;
    $self->{'related_bugs'}->{$field_name} ||= $self->match({$field_name => $self->id});
    return $self->{'related_bugs'}->{$field_name}; 
}

sub cc {
    my ($self) = @_;
    return $self->{'cc'} if exists $self->{'cc'};
    return [] if $self->{'error'};

    my $dbh = Bugzilla->dbh;
    $self->{'cc'} = $dbh->selectcol_arrayref(
        q{SELECT profiles.login_name FROM cc, profiles
           WHERE bug_id = ?
             AND cc.who = profiles.userid
        ORDER BY profiles.login_name},
      undef, $self->bug_id);

    $self->{'cc'} = undef if !scalar(@{$self->{'cc'}});

    return $self->{'cc'};
}

# XXX Eventually this will become the standard "cc" method used everywhere.
sub cc_users {
    my $self = shift;
    return $self->{'cc_users'} if exists $self->{'cc_users'};
    return [] if $self->{'error'};

    my $dbh = Bugzilla->dbh;
    my $cc_ids = $dbh->selectcol_arrayref(
        'SELECT who FROM cc WHERE bug_id = ?', undef, $self->id);
    $self->{'cc_users'} = Bugzilla::User->new_from_list($cc_ids);
    return $self->{'cc_users'};
}

sub component {
    my ($self) = @_;
    return $self->{component} if exists $self->{component};
    return '' if $self->{error};
    ($self->{component}) = Bugzilla->dbh->selectrow_array(
        'SELECT name FROM components WHERE id = ?',
        undef, $self->{component_id});
    return $self->{component};
}

# XXX Eventually this will replace component()
sub component_obj {
    my ($self) = @_;
    return $self->{component_obj} if defined $self->{component_obj};
    return {} if $self->{error};
    $self->{component_obj} = new Bugzilla::Component($self->{component_id});
    return $self->{component_obj};
}

sub classification_id {
    my ($self) = @_;
    return $self->{classification_id} if exists $self->{classification_id};
    return 0 if $self->{error};
    ($self->{classification_id}) = Bugzilla->dbh->selectrow_array(
        'SELECT classification_id FROM products WHERE id = ?',
        undef, $self->{product_id});
    return $self->{classification_id};
}

sub classification {
    my ($self) = @_;
    return $self->{classification} if exists $self->{classification};
    return '' if $self->{error};
    ($self->{classification}) = Bugzilla->dbh->selectrow_array(
        'SELECT name FROM classifications WHERE id = ?',
        undef, $self->classification_id);
    return $self->{classification};
}

sub default_bug_status {
    my $class = shift;
    # XXX This should just call new_bug_statuses when the UI accepts closed
    # bug statuses instead of accepting them as a parameter.
    my @statuses = @_;

    my $status;
    if (scalar(@statuses) == 1) {
        $status = $statuses[0]->name;
    }
    else {
        $status = ($statuses[0]->name ne 'UNCONFIRMED')
                  ? $statuses[0]->name : $statuses[1]->name;
    }

    return $status;
}

sub dependson {
    my ($self) = @_;
    return $self->{'dependson'} if exists $self->{'dependson'};
    return [] if $self->{'error'};
    $self->{'dependson'} =
        EmitDependList("blocked", "dependson", $self->bug_id);
    return $self->{'dependson'};
}

sub depends_on_obj {
    my ($self) = @_;
    $self->{depends_on_obj} ||= $self->_bugs_in_order($self->dependson);
    return $self->{depends_on_obj};
}

sub duplicates {
    my $self = shift;
    return $self->{duplicates} if exists $self->{duplicates};
    return [] if $self->{error};
    $self->{duplicates} = Bugzilla::Bug->new_from_list($self->duplicate_ids);
    return $self->{duplicates};
}

sub duplicate_ids {
    my $self = shift;
    return $self->{duplicate_ids} if exists $self->{duplicate_ids};
    return [] if $self->{error};

    my $dbh = Bugzilla->dbh;
    $self->{duplicate_ids} =
      $dbh->selectcol_arrayref('SELECT dupe FROM duplicates WHERE dupe_of = ?',
                               undef, $self->id);
    return $self->{duplicate_ids};
}

sub flag_types {
    my ($self) = @_;
    return $self->{'flag_types'} if exists $self->{'flag_types'};
    return [] if $self->{'error'};

    my $vars = { target_type  => 'bug',
                 product_id   => $self->{product_id},
                 component_id => $self->{component_id},
                 bug_id       => $self->bug_id,
                 bug_obj      => $self,
               };

    $self->{'flag_types'} = Bugzilla::Flag->_flag_types($vars);

    return $self->{'flag_types'};
}

sub flags {
    my $self = shift;

    # Don't cache it as it must be in sync with ->flag_types.
    $self->{flags} = [map { @{$_->{flags}} } @{$self->flag_types}];
    return $self->{flags};
}

sub isopened {
    my $self = shift;
    return is_open_state($self->{bug_status}) ? 1 : 0;
}

sub keywords {
    my ($self) = @_;
    return join(', ', (map { $_->name } @{$self->keyword_objects}));
}

# XXX At some point, this should probably replace the normal "keywords" sub.
sub keyword_objects {
    my $self = shift;
    return $self->{'keyword_objects'} if defined $self->{'keyword_objects'};
    return [] if $self->{'error'};

    my $dbh = Bugzilla->dbh;
    my $ids = $dbh->selectcol_arrayref(
         "SELECT keywordid FROM keywords WHERE bug_id = ?", undef, $self->id);
    $self->{'keyword_objects'} = Bugzilla::Keyword->new_from_list($ids);
    return $self->{'keyword_objects'};
}

sub comments {
    my ($self, $params) = @_;
    return [] if $self->{'error'};
    $params ||= {};

    if (!defined $self->{'comments'}) {
        $self->{'comments'} = Bugzilla::Comment->match({ bug_id => $self->id });
        my $count = 0;
        foreach my $comment (@{ $self->{'comments'} }) {
            $comment->{count} = $count++ if $comment->type != CMT_BACKDATED_WORKTIME;
            $comment->{bug} = $self;
        }
        Bugzilla::Comment->preload($self->{'comments'});
    }
    my @comments = @{ $self->{'comments'} };

    my $order = $params->{order} 
        || Bugzilla->user->setting('comment_sort_order');
    if ($order ne 'oldest_to_newest') {
        @comments = reverse @comments;
        if ($order eq 'newest_to_oldest_desc_first') {
            unshift(@comments, pop @comments);
        }
    }

    if ($params->{after}) {
        my $from = datetime_from($params->{after});
        @comments = grep { datetime_from($_->creation_ts) > $from } @comments;
    }
    elsif ($params->{start_at}) {
        splice(@comments, 0, $params->{start_at});
    }
    if ($params->{to}) {
        my $to = datetime_from($params->{to});
        @comments = grep { datetime_from($_->creation_ts) <= $to } @comments;
    }
    return \@comments;
}

sub new_bug_statuses {
    my ($class, $product) = @_;
    my $user = Bugzilla->user;

    # Construct the list of allowable statuses.
    my @statuses = @{ Bugzilla::Bug->statuses_available($product) };

    # If the user has no privs...
    unless ($user->in_group('editbugs', $product->id)
            || $user->in_group('canconfirm', $product->id))
    {
        # ... use UNCONFIRMED if available, else use the first status of the list.
        my ($unconfirmed) = grep { $_->name eq 'UNCONFIRMED' } @statuses;
    
        # Because of an apparent Perl bug, "$unconfirmed || $statuses[0]" doesn't
        # work, so we're using an "?:" operator. See bug 603314 for details.
        @statuses = ($unconfirmed ? $unconfirmed : $statuses[0]);
    }

    return \@statuses;
}

# This is needed by xt/search.t.
sub percentage_complete {
    my $self = shift;
    return undef if $self->{'error'} || !Bugzilla->user->is_timetracker;
    my $remaining = $self->remaining_time;
    my $actual    = $self->actual_time;
    my $total = $remaining + $actual;
    return undef if $total == 0;
    # Search.pm truncates this value to an integer, so we want to as well,
    # since this is mostly used in a test where its value needs to be
    # identical to what the database will return.
    return int(100 * ($actual / $total));
}

sub product {
    my ($self) = @_;
    return $self->{product} if exists $self->{product};
    return '' if $self->{error};
    ($self->{product}) = Bugzilla->dbh->selectrow_array(
        'SELECT name FROM products WHERE id = ?',
        undef, $self->{product_id});
    return $self->{product};
}

# XXX This should eventually replace the "product" subroutine.
sub product_obj {
    my $self = shift;
    return {} if $self->{error};
    $self->{product_obj} ||= new Bugzilla::Product($self->{product_id});
    return $self->{product_obj};
}

sub qa_contact {
    my ($self) = @_;
    return $self->{'qa_contact_obj'} if exists $self->{'qa_contact_obj'};
    return undef if $self->{'error'};

    if (Bugzilla->params->{'useqacontact'} && $self->{'qa_contact'}) {
        $self->{'qa_contact_obj'} = new Bugzilla::User($self->{'qa_contact'});
    } else {
        # XXX - This is somewhat inconsistent with the assignee/reporter
        # methods, which will return an empty User if they get a 0.
        # However, we're keeping it this way now, for backwards-compatibility.
        $self->{'qa_contact_obj'} = undef;
    }
    return $self->{'qa_contact_obj'};
}

sub reporter {
    my ($self) = @_;
    return $self->{'reporter'} if exists $self->{'reporter'};
    $self->{'reporter_id'} = 0 if $self->{'error'};
    $self->{'reporter'} = new Bugzilla::User($self->{'reporter_id'});
    return $self->{'reporter'};
}

sub see_also {
    my ($self) = @_;
    return [] if $self->{'error'};
    if (!exists $self->{see_also}) {
        my $ids = Bugzilla->dbh->selectcol_arrayref(
            'SELECT id FROM bug_see_also WHERE bug_id = ?',
            undef, $self->id);

        my $bug_urls = Bugzilla::BugUrl->new_from_list($ids);

        $self->{see_also} = $bug_urls;
    }
    return $self->{see_also};
}

sub status {
    my $self = shift;
    return undef if $self->{'error'};

    $self->{'status'} ||= new Bugzilla::Status({name => $self->{'bug_status'}});
    return $self->{'status'};
}

sub statuses_available {
    my ($invocant, $product) = @_;

    my @statuses;

    if (ref $invocant) {
      return [] if $invocant->{'error'};

      return $invocant->{'statuses_available'}
          if defined $invocant->{'statuses_available'};

        @statuses = @{ $invocant->status->can_change_to };
        $product = $invocant->product_obj;
    } else {
        @statuses = @{ Bugzilla::Status->can_change_to };
    }

    # UNCONFIRMED is only a valid status if it is enabled in this product.
    if (!$product->allows_unconfirmed) {
        @statuses = grep { $_->name ne 'UNCONFIRMED' } @statuses;
    }

    if (ref $invocant) {
        my $available = $invocant->_refine_available_statuses(@statuses);
        $invocant->{'statuses_available'} = $available;
        return $available;
    }

    return \@statuses;
}

sub _refine_available_statuses {
    my $self = shift;
    my @statuses = @_;

    my @available;
    foreach my $status (@statuses) {
        # Make sure this is a legal status transition
        next if !$self->check_can_change_field(
                     'bug_status', $self->status->name, $status->name);
        push(@available, $status);
    }

    # If this bug has an inactive status set, it should still be in the list.
    if (!grep($_->name eq $self->status->name, @available)) {
        unshift(@available, $self->status);
    }
    
    return \@available;
}

sub show_attachment_flags {
    my ($self) = @_;
    return $self->{'show_attachment_flags'}
        if exists $self->{'show_attachment_flags'};
    return 0 if $self->{'error'};

    # The number of types of flags that can be set on attachments to this bug
    # and the number of flags on those attachments.  One of these counts must be
    # greater than zero in order for the "flags" column to appear in the table
    # of attachments.
    my $num_attachment_flag_types = Bugzilla::FlagType::count(
        { 'target_type'  => 'attachment',
          'product_id'   => $self->{'product_id'},
          'component_id' => $self->{'component_id'} });
    my $num_attachment_flags = Bugzilla::Flag->count(
        { 'target_type'  => 'attachment',
          'bug_id'       => $self->bug_id });

    $self->{'show_attachment_flags'} =
        ($num_attachment_flag_types || $num_attachment_flags);

    return $self->{'show_attachment_flags'};
}

sub groups {
    my $self = shift;
    return $self->{'groups'} if exists $self->{'groups'};
    return [] if $self->{'error'};

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
             " ORDER BY description");
    $sth->execute($self->{'bug_id'},
                  $self->{'product_id'});

    while (my ($groupid, $name, $description, $ison, $ingroup, $isactive,
            $membercontrol, $othercontrol) = $sth->fetchrow_array()) {

        $membercontrol ||= 0;

        # For product groups, we only want to use the group if either
        # (1) The bit is set and not required, or
        # (2) The group is Shown or Default for members and
        #     the user is a member of the group.
        if ($ison ||
            ($isactive && $ingroup
                       && (($membercontrol == CONTROLMAPDEFAULT)
                           || ($membercontrol == CONTROLMAPSHOWN))
            ))
        {
            my $ismandatory = $isactive
              && ($membercontrol == CONTROLMAPMANDATORY);

            push (@groups, { "bit" => $groupid,
                             "name" => $name,
                             "ison" => $ison,
                             "ingroup" => $ingroup,
                             "mandatory" => $ismandatory,
                             "description" => $description });
        }
    }

    $self->{'groups'} = \@groups;

    return $self->{'groups'};
}

sub groups_in {
    my $self = shift;
    return $self->{'groups_in'} if exists $self->{'groups_in'};
    return [] if $self->{'error'};
    my $group_ids = Bugzilla->dbh->selectcol_arrayref(
        'SELECT group_id FROM bug_group_map WHERE bug_id = ?',
        undef, $self->id);
    $self->{'groups_in'} = Bugzilla::Group->new_from_list($group_ids);
    return $self->{'groups_in'};
}

sub in_group {
    my ($self, $group) = @_;
    return grep($_->id == $group->id, @{$self->groups_in}) ? 1 : 0;
}

sub user {
    my $self = shift;
    return $self->{'user'} if exists $self->{'user'};
    return {} if $self->{'error'};

    my $user = Bugzilla->user;

    my $prod_id = $self->{'product_id'};

    my $unknown_privileges = $user->in_group('editbugs', $prod_id);
    my $canedit = $unknown_privileges
                  || $user->id == $self->{'assigned_to'}
                  || (Bugzilla->params->{'useqacontact'}
                      && $self->{'qa_contact'}
                      && $user->id == $self->{'qa_contact'});
    my $canconfirm = $unknown_privileges
                     || $user->in_group('canconfirm', $prod_id);
    my $isreporter = $user->id
                     && $user->id == $self->{reporter_id};

    $self->{'user'} = {canconfirm => $canconfirm,
                       canedit    => $canedit,
                       isreporter => $isreporter};
    return $self->{'user'};
}

# This is intended to get values that can be selected by the user in the
# UI. It should not be used for security or validation purposes.
sub choices {
    my $self = shift;
    return $self->{choices} if exists $self->{'choices'};
    return {} if $self->{'error'};
    my $user = Bugzilla->user;

    my @products = @{ $user->get_enterable_products };
    # The current product is part of the popup, even if new bugs are no longer
    # allowed for that product
    if (!grep($_->name eq $self->product_obj->name, @products)) {
        unshift(@products, $self->product_obj);
    }
    my %class_ids = map { $_->classification_id => 1 } @products;
    my $classifications = 
        Bugzilla::Classification->new_from_list([keys %class_ids]);

    my %choices = (
        bug_status => $self->statuses_available,
        classification => $classifications,
        product    => \@products,
        component  => $self->product_obj->active_components,
        version    => $self->product_obj->versions,
        target_milestone => $self->product_obj->milestones,
    );

    my $resolution_field = Bugzilla->get_field('resolution');
    # Don't include the empty resolution in drop-downs.
    my @resolutions = grep($_->name, @{ $resolution_field->legal_values });
    $choices{'resolution'} = \@resolutions;

    $self->{'choices'} = \%choices;
    return $self->{'choices'};
}

# Convenience Function. If you need speed, use this. If you need
# other Bug fields in addition to this, just create a new Bug with
# the alias.
# Queries the database for the bug with a given alias, and returns
# the ID of the bug if it exists or the undefined value if it doesn't.
sub bug_alias_to_id {
    my ($alias) = @_;
    my $dbh = Bugzilla->dbh;
    trick_taint($alias);
    return $dbh->selectrow_array(
        "SELECT bug_id FROM bugs WHERE alias = ?", undef, $alias);
}

sub get_test_case_count {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $row_count = $dbh->selectall_arrayref(
        "SELECT DISTINCT case_id FROM test_case_bugs WHERE bug_id = ?",
        undef, $self->bug_id);
    return scalar @$row_count;
}

sub getAccessUserList {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my @user_ids;
    push (@user_ids, $self->assigned_to->id);
    push (@user_ids, $self->qa_contact->id);
    if ($self->reporter_accessible) {
        push (@user_ids, $self->reporter->id);
    }
    if ($self->cclist_accessible) {
        my $cc_list = $dbh->selectall_arrayref("SELECT cc.who FROM cc cc WHERE cc.bug_id = ?", undef, $self->bug_id);
        foreach my $cc_item (@$cc_list) {
            push (@user_ids, $cc_item->[0]);
        }
    }

    my $user_ids_group = {};
    foreach my $group (@{$self->groups}) {
        my @childgroups = @{Bugzilla::Group->flatten_group_membership($group->{'bit'})};
        my $group_users = $dbh->selectall_arrayref("SELECT DISTINCT user_id FROM user_group_map WHERE isbless = 0 AND group_id IN (".join(",", @childgroups).")");
        foreach my $users (@$group_users) {
            $user_ids_group->{$users->[0]}++;
        }
    }

    my $count_groups = scalar @{$self->groups};
    push (@user_ids, grep { $user_ids_group->{$_} == $count_groups } keys %$user_ids_group);

    return $dbh->selectall_arrayref("
        SELECT p.userid, p.login_name, p.realname
        FROM profiles p
        WHERE p.disabledtext = '' AND p.disable_mail = 0 AND p.userid in (".join(",", @user_ids).")
        ORDER BY p.realname");
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

# XXX - When Bug::update() will be implemented, we should make this routine
#       a private method.
# Join with bug_status and bugs tables to show bugs with open statuses first,
# and then the others
sub EmitDependList {
    my ($myfield, $targetfield, $bug_id) = (@_);
    my $dbh = Bugzilla->dbh;
    my $list_ref = $dbh->selectcol_arrayref(
        "SELECT $targetfield
           FROM dependencies
     INNER JOIN bugs ON dependencies.$targetfield = bugs.bug_id
     INNER JOIN bug_status ON bugs.bug_status = bug_status.value
          WHERE $myfield = ?
       ORDER BY is_open DESC, $targetfield",
        undef, $bug_id);
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
    if ($time !~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/so) {
        ThrowUserError("number_not_numeric",
                       {field => "$field", num => "$time"});
    }

    # Only the "work_time" field is allowed to contain a negative value.
    if ($time < 0 && $field ne "work_time") {
        ThrowUserError("number_too_small",
                       {field => "$field", num => "$time", min_num => "0"});
    }

    if ($time > 99999.99) {
        ThrowUserError("number_too_large",
                       {field => "$field", num => "$time", max_num => "99999.99"});
    }

    return $time;
}

# Creates a lot of bug objects in the same order as the input array.
sub _bugs_in_order {
    my ($self, $bug_ids) = @_;
    my $bugs = $self->new_from_list($bug_ids);
    my %bug_map = map { $_->id => $_ } @$bugs;
    my @result = map { $bug_map{$_} } @$bug_ids;
    return \@result;
}

# Get the activity of a bug, starting from $starttime (if given).
# This routine assumes Bugzilla::Bug->check has been previously called.
sub get_activity {
    my ($self, $attach_id, $starttime) = @_;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # Arguments passed to the SQL query.
    my @args = ($self->id);

    # Only consider changes since $starttime, if given.
    my $datepart = "";
    if (defined $starttime) {
        trick_taint($starttime);
        push (@args, $starttime);
        $datepart = "AND bugs_activity.bug_when > ?";
    }

    my $attachpart = "";
    if ($attach_id) {
        push(@args, $attach_id);
        $attachpart = "AND bugs_activity.attach_id = ?";
    }

    # Only includes attachments the user is allowed to see.
    my $suppjoins = "";
    my $suppwhere = "";
    if (!$user->is_insider) {
        $suppjoins = "LEFT JOIN attachments 
                   ON attachments.attach_id = bugs_activity.attach_id";
        $suppwhere = "AND COALESCE(attachments.isprivate, 0) = 0";
    }
    # For UNION longdescs_history
    push (@args, $bug_id);

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

    foreach my $entry (@$list) {
        my ($fieldname, $attachid, $when, $removed, $added, $who, $comment_id, $comment_count) = @$entry;
        my %change;
        my $activity_visible = 1;

        # check if the user should see this field's activity
        if (grep { $fieldname eq $_ } TIMETRACKING_FIELDS) {
            $activity_visible = $user->is_timetracker;
        }
        elsif ($fieldname eq 'longdescs.isprivate'
               && !$user->is_insider && $added)
        { 
            $activity_visible = 0;
        } 
        else {
            $activity_visible = 1;
        }

        if ($activity_visible) {
            # Check for the results of an old Bugzilla data corruption bug
            if (($added eq '?' && $removed eq '?')
                || ($added =~ /^\? / || $removed =~ /^\? /)) {
                $incomplete_data = 1;
            }

            # An operation, done by 'who' at time 'when', has a number of
            # 'changes' associated with it.
            # If this is the start of a new operation, store the data from the
            # previous one, and set up the new one.
            if ($operation->{'who'}
                && ($who ne $operation->{'who'}
                    || $when ne $operation->{'when'}))
            {
                $operation->{'changes'} = $changes;
                push (@operations, $operation);

                # Create new empty anonymous data structures.
                $operation = {};
                $changes = [];
            }

            # If this is the same field as the previous item, then concatenate
            # the data into the same change.
            if ($operation->{'who'} && $who eq $operation->{'who'}
                && $when eq $operation->{'when'}
                && $fieldname eq $operation->{'fieldname'}
                && ($attachid || 0) == ($operation->{'attachid'} || 0))
            {
                my $old_change = pop @$changes;
                $removed = $old_change->{'removed'} . $removed;
                $added = $old_change->{'added'} . $added;
            }
            $operation->{'who'} = $who;
            $operation->{'when'} = $when;
            $operation->{'fieldname'} = $change{'fieldname'} = $fieldname;
            $operation->{'attachid'} = $change{'attachid'} = $attachid;
            $change{'removed'} = $removed;
            $change{'added'} = $added;

            if ($comment_id) {
                $change{'comment'} = Bugzilla::Comment->new($comment_id);
            }

            push (@$changes, \%change);
        }
    }

    if ($operation->{'who'}) {
        $operation->{'changes'} = $changes;
        push (@operations, $operation);
    }

    return(\@operations, $incomplete_data);
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
sub LogActivityEntry {
    my ($i, $col, $removed, $added, $whoid, $timestamp, $comment_id) = @_;
    my $fieldid = Bugzilla->get_field($col);
    my $dbh = Bugzilla->dbh;
    # in the case of CCs, deps, and keywords, there's a possibility that someone
    # might try to add or remove a lot of them at once, which might take more
    # space than the activity table allows.  We'll solve this by splitting it
    # into multiple entries if it's too long.
    while ($removed || $added)
    {
        my ($removestr, $addstr) = ($removed, $added);
        if (length($removestr) > MAX_LINE_LENGTH) {
            my $commaposition = find_wrap_point($removed, MAX_LINE_LENGTH);
            $removestr = substr($removed, 0, $commaposition);
            $removed = substr($removed, $commaposition);
            $removed =~ s/^[,\s]+//; # remove any comma or space
        } else {
            $removed = ""; # no more entries
        }
        if (length($addstr) > MAX_LINE_LENGTH) {
            my $commaposition = find_wrap_point($added, MAX_LINE_LENGTH);
            $addstr = substr($added, 0, $commaposition);
            $added = substr($added, $commaposition);
            $added =~ s/^[,\s]+//; # remove any comma or space
        } else {
            $added = ""; # no more entries
        }
        trick_taint($addstr);
        trick_taint($removestr);
        $dbh->do("INSERT INTO bugs_activity
                  (bug_id, who, bug_when, fieldid, removed, added, comment_id)
                  VALUES (?, ?, ?, ?, ?, ?, ?)",
                  undef, ($i, $whoid, $timestamp, $fieldid->{'id'}, $removestr, $addstr, $comment_id));
    }
}

# Convert WebService API and email_in.pl field names to internal DB field
# names.
sub map_fields {
    my ($params, $except) = @_; 

    my %field_values;
    foreach my $field (keys %$params) {
        # Don't allow setting private fields via email_in or the WebService.
        next if $field =~ /^_/;
        my $field_name;
        if ($except->{$field}) {
           $field_name = $field;
        }
        else {
            $field_name = FIELD_MAP->{$field} || $field;
        }
        $field_values{$field_name} = $params->{$field};
    }
    return \%field_values;
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
sub check_can_change_field {
    my $self = shift;
    my ($field, $oldvalue, $newvalue, $PrivilegesRequired) = (@_);
    my $user = Bugzilla->user;

    $oldvalue = defined($oldvalue) ? $oldvalue : '';
    $newvalue = defined($newvalue) ? $newvalue : '';

    # Return true if they haven't changed this field at all.
    if ($oldvalue eq $newvalue) {
        return 1;
    } elsif (ref($newvalue) eq 'ARRAY' && ref($oldvalue) eq 'ARRAY') {
        my ($removed, $added) = diff_arrays($oldvalue, $newvalue);
        return 1 if !scalar(@$removed) && !scalar(@$added);
    } elsif (trim($oldvalue) eq trim($newvalue)) {
        return 1;
    # numeric fields need to be compared using ==
    } elsif (($field eq 'estimated_time' || $field eq 'remaining_time' 
              || $field eq 'work_time')
             && $oldvalue == $newvalue)
    {
        return 1;
    }

    my @priv_results;
    Bugzilla::Hook::process('bug_check_can_change_field',
        { bug => $self, field => $field, 
          new_value => $newvalue, old_value => $oldvalue, 
          priv_results => \@priv_results });
    if (my $priv_required = first { $_ > 0 } @priv_results) {
        $$PrivilegesRequired = $priv_required;
        return 0;
    }
    my $allow_found = first { $_ == 0 } @priv_results;
    if (defined $allow_found) {
        return 1;
    }

    # Allow anyone to change comments.
    if ($field =~ /^longdesc/) {
        return 1;
    }

    # If the user isn't allowed to change a field, we must tell him who can.
    # We store the required permission set into the $PrivilegesRequired
    # variable which gets passed to the error template.
    #
    # $PrivilegesRequired = PRIVILEGES_REQUIRED_NONE : no privileges required;
    # $PrivilegesRequired = PRIVILEGES_REQUIRED_REPORTER : the reporter, assignee or an empowered user;
    # $PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE : the assignee or an empowered user;
    # $PrivilegesRequired = PRIVILEGES_REQUIRED_EMPOWERED : an empowered user.
    
    # Only users in the time-tracking group can change time-tracking fields.
    if ( grep($_ eq $field, TIMETRACKING_FIELDS) ) {
        if (!$user->is_timetracker) {
            $$PrivilegesRequired = PRIVILEGES_REQUIRED_EMPOWERED;
            return 0;
        }
    }

    # Allow anyone with (product-specific) "editbugs" privs to change anything.
    if ($user->in_group('editbugs', $self->{'product_id'})) {
        return 1;
    }

    # *Only* users with (product-specific) "canconfirm" privs can confirm bugs.
    if ($self->_changes_everconfirmed($field, $oldvalue, $newvalue)) {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_EMPOWERED;
        return $user->in_group('canconfirm', $self->{'product_id'});
    }

    # Make sure that a valid bug ID has been given.
    if (!$self->{'error'}) {
        # Allow the assignee to change anything else.
        if ($self->{'assigned_to'} == $user->id
            || $self->{'_old_assigned_to'} && $self->{'_old_assigned_to'} == $user->id)
        {
            return 1;
        }

        # Allow the QA contact to change anything else.
        if (Bugzilla->params->{'useqacontact'}
            && (($self->{'qa_contact'} && $self->{'qa_contact'} == $user->id)
                || ($self->{'_old_qa_contact'} && $self->{'_old_qa_contact'} == $user->id)))
        {
            return 1;
        }
    }

    # At this point, the user is either the reporter or an
    # unprivileged user. We first check for fields the reporter
    # is not allowed to change.

    # The reporter may not:
    # - reassign bugs, unless the bugs are assigned to him;
    #   in that case we will have already returned 1 above
    #   when checking for the assignee of the bug.
    if ($field eq 'assigned_to') {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
        return 0;
    }
    # - change the QA contact
    if ($field eq 'qa_contact') {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
        return 0;
    }
    # - change the target milestone
    if ($field eq 'target_milestone') {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
        return 0;
    }
    # - change the priority (unless he could have set it originally)
    if ($field eq 'priority'
        && !Bugzilla->params->{'letsubmitterchoosepriority'})
    {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
        return 0;
    }
    # - unconfirm bugs (confirming them is handled above)
    if ($field eq 'everconfirmed') {
        $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
        return 0;
    }
    # - change the status from one open state to another
    if ($field eq 'bug_status'
        && is_open_state($oldvalue) && is_open_state($newvalue))
    {
       $$PrivilegesRequired = PRIVILEGES_REQUIRED_ASSIGNEE;
       return 0;
    }

    # The reporter is allowed to change anything else.
    if (!$self->{'error'} && $self->{'reporter_id'} == $user->id) {
        return 1;
    }

    # If we haven't returned by this point, then the user doesn't
    # have the necessary permissions to change this field.
    $$PrivilegesRequired = PRIVILEGES_REQUIRED_REPORTER;
    return 0;
}

# A helper for check_can_change_field
sub _changes_everconfirmed {
    my ($self, $field, $old, $new) = @_;
    return 1 if $field eq 'everconfirmed';
    if ($field eq 'bug_status') {
        if ($self->everconfirmed) {
            # Moving a confirmed bug to UNCONFIRMED will change everconfirmed.
            return 1 if $new eq 'UNCONFIRMED';
        }
        else {
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
# 2) Save recursively loaded dependencies in $invocant->dependent_validators
sub ValidateDependencies
{
    my ($invocant, $dependson, $blocked) = @_;
    my $id = ref($invocant) ? $invocant->id : 0;
    return unless defined $dependson || defined $blocked;

    # These can be arrayrefs or they can be strings.
    my $fields = { dependson => $dependson, blocked => $blocked };
    for (qw(blocked dependson))
    {
        $fields->{$_} = [split /[\s,]+/, $fields->{$_}] if !ref $fields->{$_};
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
        my $query = join(' OR ', map {
            "$_ IN (".join(',', map { int($_) } keys %{$stack->{$_}}).")"
        } grep { %{$stack->{$_}} } keys %$stack);
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
        ThrowUserError("dependency_loop_multi", { deps => \@intersect });
    }

    # Remember closure, will be used to check BUG_ID add_to_deps custom fields
    $invocant->dependent_validators->{dependencies} = $closure;
}

#####################################################################
# Custom Field Accessors
#####################################################################

sub _create_cf_accessors {
    my ($invocant) = @_;
    my $class = ref($invocant) || $invocant;
    return if Bugzilla->request_cache->{"${class}_cf_accessors_created"};

    my $fields = Bugzilla->fields({ custom => 1 });
    foreach my $field (@$fields) {
        my $accessor = $class->_accessor_for($field);
        my $name = "${class}::" . $field->name;
        {
            no strict 'refs';
            next if defined *{$name};
            *{$name} = $accessor;
        }
    }

    Bugzilla->request_cache->{"${class}_cf_accessors_created"} = 1;
}

sub _accessor_for {
    my ($class, $field) = @_;
    if ($field->type == FIELD_TYPE_MULTI_SELECT) {
        return $class->_multi_select_accessor($field->name);
    }
    return $class->_cf_accessor($field->name);
}

sub _cf_accessor {
    my ($class, $field) = @_;
    my $accessor = sub {
        my ($self) = @_;
        return $self->{$field};
    };
    return $accessor;
}

sub _multi_select_accessor {
    my ($class, $field) = @_;
    my $accessor = sub {
        my ($self) = @_;
        $self->{$field} ||= Bugzilla->dbh->selectcol_arrayref(
            "SELECT value FROM bug_$field WHERE bug_id = ? ORDER BY value",
            undef, $self->id);
        return $self->{$field};
    };
    return $accessor;
}

1;
