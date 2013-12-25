#!/usr/bin/perl -wT
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Implementation notes for this file:
#
# 1) the 'id' form parameter is validated early on, and if it is not a valid
# bugid an error will be reported, so it is OK for later code to simply check
# for a defined form 'id' value, and it can assume a valid bugid.
#
# 2) If the 'id' form parameter is not defined (after the initial validation),
# then we are processing multiple bugs, and @idlist will contain the ids.
#
# 3) If we are processing just the one id, then it is stored in @idlist for
# later processing.

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Bug;
use Bugzilla::BugMail;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Flag;
use Bugzilla::Status;
use Bugzilla::Token;

use Checkers;

use List::MoreUtils qw(firstidx);
use Storable qw(dclone);

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = { %{ $cgi->Vars } };

######################################################################
# Subroutines
######################################################################

# Tells us whether or not a field should be changed by process_bug.
sub should_set {
    # check_defined is used for fields where there's another field
    # whose name starts with "defined_" and then the field name--it's used
    # to know when we did things like empty a multi-select or deselect
    # a checkbox.
    my ($field, $check_defined) = @_;
    my $cgi = Bugzilla->cgi;
    if ((defined $cgi->param($field)
        || ($check_defined && defined $cgi->param("defined_$field")))
        && ($field ne 'comment' || $cgi->param('comment') !~ /^\s*$/so))
    {
        return 1;
    }
    return 0;
}

######################################################################
# Begin Data/Security Validation
######################################################################

$dbh->bz_start_transaction();

# Create a list of objects for all bugs being modified in this request.
# <vitalif@mail.ru> Use SELECT ... FOR UPDATE to lock these bugs
my @bug_objects;
if (defined $cgi->param('id')) {
  my $bug = Bugzilla::Bug->check_for_edit(scalar $cgi->param('id'));
  $cgi->param('id', $bug->id);
  push(@bug_objects, $bug);
} else {
    foreach my $i ($cgi->param()) {
        if ($i =~ /^id_([1-9][0-9]*)/) {
            my $id = $1;
            push(@bug_objects, Bugzilla::Bug->check_for_edit($id));
        }
    }
}

# Make sure there are bugs to process.
scalar(@bug_objects) || ThrowUserError("no_bugs_chosen", {action => 'modify'});

my $first_bug = $bug_objects[0]; # Used when we're only updating a single bug.

# Delete any parameter set to 'dontchange'.
if (defined $cgi->param('dontchange')) {
    foreach my $name ($cgi->param) {
        next if $name eq 'dontchange'; # But don't delete dontchange itself!
        # Skip ones we've already deleted (such as "defined_$name").
        next if !defined $cgi->param($name);
        if ($cgi->param($name) eq $cgi->param('dontchange')) {
            $cgi->delete($name);
            $cgi->delete("defined_$name");
            delete $ARGS->{$name};
            delete $ARGS->{"defined_$name"};
        }
    }
}

# do a match on the fields if applicable
Bugzilla::User::match_field({
    'qa_contact'                => { 'type' => 'single' },
    'newcc'                     => { 'type' => 'multi'  },
    'masscc'                    => { 'type' => 'multi'  },
    'assigned_to'               => { 'type' => 'single' },
});

# Check for a mid-air collision. Currently this only works when updating
# an individual bug.
if (defined $cgi->param('delta_ts'))
{
    my $delta_ts_z = datetime_from($cgi->param('delta_ts'));
    my $first_delta_tz_z =  datetime_from($first_bug->delta_ts);
    if ($first_delta_tz_z ne $delta_ts_z) {
        ($vars->{'operations'}) = $first_bug->get_activity(undef, $cgi->param('delta_ts'));

        # CustIS Bug 56327 - Change only fields the user wanted to change
        for my $op (@{$vars->{operations}})
        {
            for (@{$op->{changes}})
            {
                # FIXME similar detection is needed for other multi-selects
                if ($_->{fieldname} eq 'dependson' || $_->{fieldname} eq 'blocked')
                {
                    # Calculate old value from current value and activity log
                    my $cur = $_->{fieldname};
                    $cur = { map { $_ => 1 } @{ $first_bug->$cur() } };
                    my $new = join ', ', keys %$cur;
                    delete $cur->{$_} for split /[\s,]*,[\s,]*/, $_->{added};
                    $cur->{$_} = 1 for split /[\s,]*,[\s,]*/, $_->{removed};
                    # Compare the old value with submitted one
                    my $equal = 1;
                    for (split /[\s,]*,[\s,]*/, $cgi->param($_->{fieldname}))
                    {
                        if (!$cur->{$_})
                        {
                            $equal = 0;
                            last;
                        }
                        delete $cur->{$_};
                    }
                    $equal = 0 if %$cur;
                    # If equal to old value -> change to the new value
                    $cgi->param($_->{fieldname}, $new) if $equal;
                }
                elsif ($cgi->param($_->{fieldname}) eq $_->{removed})
                {
                    # If equal to old value -> change to the new value
                    $cgi->param($_->{fieldname}, $_->{added});
                }
            }
        }

        $vars->{'title_tag'} = "mid_air";

        ThrowCodeError('undefined_field', { field => 'longdesclength' })
            if !defined $cgi->param('longdesclength');

        $vars->{'start_at'} = $cgi->param('longdesclength');
        # Always sort midair collision comments oldest to newest,
        # regardless of the user's personal preference.
        $vars->{'comments'} = $first_bug->comments({ order => "oldest_to_newest" });
        $vars->{'bug'} = $first_bug;

        # The token contains the old delta_ts. We need a new one.
        $cgi->param('token', issue_hash_token([$first_bug->id, $first_bug->delta_ts]));
        # Warn the user about the mid-air collision and ask them what to do.
        $template->process("bug/process/midair.html.tmpl", $vars)
          || ThrowTemplateError($template->error());
        exit;
    }
}


my %edit_comment;
foreach my $arg_key (keys $ARGS) {
    if ($arg_key =~ /edit_comment/){
        my $comment_id = $arg_key;
        $comment_id =~ s/^edit_comment\[(.*)\]$/$1/;
        trick_taint($ARGS->{$arg_key});
        $edit_comment{$comment_id} = $ARGS->{$arg_key};
    }
}

# We couldn't do this check earlier as we first had to validate bug IDs
# and display the mid-air collision page if delta_ts changed.
# If we do a mass-change, we use session tokens.
my $token = $cgi->param('token');

if ($cgi->param('id')) {
    check_hash_token($token, [$first_bug->id, $first_bug->delta_ts]);
}
else {
    check_token_data($token, 'buglist_mass_change', 'query.cgi');
}

######################################################################
# End Data/Security Validation
######################################################################

$vars->{title_tag} = "bug_processed";
$vars->{commentsilent} = $cgi->param('commentsilent');

my $action;
if (defined $cgi->param('id')) {
    $action = $user->setting('post_bug_submit_action');

    if ($action eq 'next_bug') {
        my $bug_list_obj = $user->recent_search_for($first_bug);
        my @bug_list = $bug_list_obj ? @{$bug_list_obj->bug_list} : ();
        my $cur = firstidx { $_ eq $cgi->param('id') } @bug_list;
        if ($cur >= 0 && $cur < $#bug_list) {
            my $next_bug_id = $bug_list[$cur + 1];
            detaint_natural($next_bug_id);
            if ($next_bug_id and $user->can_see_bug($next_bug_id)) {
                # We create an object here so that $bug->send_changes can use it
                # when displaying the header.
                $vars->{'bug'} = new Bugzilla::Bug($next_bug_id);
            }
        }
    }
    # Include both action = 'same_bug' and 'nothing'.
    else {
        $vars->{'bug'} = $first_bug;
    }
}
else {
    # param('id') is not defined when changing multiple bugs at once.
    $action = 'nothing';
}

# For each bug, we have to check if the user can edit the bug the product
# is currently in, before we allow them to change anything.
foreach my $bug (@bug_objects) {
    Bugzilla->user->can_edit_bug($bug, THROW_ERROR);
}

# For security purposes, and because lots of other checks depend on it,
# we set the product first before anything else.
my $product_change; # Used only for strict_isolation checks, right now.
if (should_set('product')) {
    foreach my $b (@bug_objects) {
        $b->{_other_bugs} = \@bug_objects;
        my $changed = $b->_set_product(scalar $cgi->param('product'));
        $product_change ||= $changed;
    }
}

# strict_isolation checks mean that we should set the groups
# immediately after changing the product.
foreach my $b (@bug_objects) {
    foreach my $group (@{$b->product_obj->groups_valid}) {
        my $gid = $group->id;
        if (should_set("bit-$gid", 1)) {
            # Check ! first to avoid having to check defined below.
            if (!$cgi->param("bit-$gid")) {
                $b->remove_group($gid);
            }
            # "== 1" is important because mass-change uses -1 to mean
            # "don't change this restriction"
            elsif ($cgi->param("bit-$gid") == 1) {
                $b->add_group($gid);
            }
        }
    }
}

Bugzilla::Hook::process('process_bug-after_move', { bug_objects => \@bug_objects, vars => $vars });

# Flags should be set AFTER the bug has been moved into another product/component.
if ($cgi->param('id')) {
    my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi($first_bug, undef, $vars);
    $first_bug->set_flags($flags, $new_flags);
}

if ($cgi->param('id') && (defined $cgi->param('dependson')
                          || defined $cgi->param('blocked')))
{
    $first_bug->set_dependencies(scalar $cgi->param('dependson'),
                                 scalar $cgi->param('blocked'));
}
elsif (should_set('dependson') || should_set('blocked')) {
    foreach my $bug (@bug_objects) {
        my %temp_deps;
        foreach my $type (qw(dependson blocked)) {
            $temp_deps{$type} = { map { $_ => 1 } @{$bug->$type} };
            if (should_set($type) && $cgi->param($type . '_action') =~ /^(add|remove)$/) {
                foreach my $id (split(/[,\s]+/, $cgi->param($type))) {
                    if ($cgi->param($type . '_action') eq 'remove') {
                        delete $temp_deps{$type}{$id};
                    }
                    else {
                        $temp_deps{$type}{$id} = 1;
                    }
                }
            }
        }
        $bug->set_dependencies([ keys %{$temp_deps{'dependson'}} ], [ keys %{$temp_deps{'blocked'}} ]);
    }
}

my $any_keyword_changes;
if (defined $cgi->param('keywords')) {

    foreach my $b (@bug_objects) {
        my $return =
            $b->modify_keywords(scalar $cgi->param('keywords'),
                                scalar $cgi->param('keywords_description'),
                                scalar $cgi->param('keywordaction'));
        $any_keyword_changes ||= $return;
    }
}

# Component, target_milestone, and version are in here just in case
# the 'product' field wasn't defined in the CGI. It doesn't hurt to set
# them twice.
my @set_fields = qw(op_sys rep_platform priority bug_severity
                    component target_milestone version
                    bug_file_loc status_whiteboard short_desc
                    deadline remaining_time estimated_time
                    bug_status
                    );
push(@set_fields, 'assigned_to') if !$cgi->param('set_default_assignee');
push(@set_fields, 'qa_contact')  if !$cgi->param('set_default_qa_contact');
my %field_translation = (
    bug_severity => 'severity',
    rep_platform => 'platform',
    short_desc   => 'summary',
    bug_file_loc => 'url',
    set_default_assignee   => 'reset_assigned_to',
    set_default_qa_contact => 'reset_qa_contact',
    confirm_product_change => 'product_change_confirmed',
);

my %set_all_fields = ( other_bugs => \@bug_objects );
foreach my $field_name (@set_fields) {
    if (should_set($field_name, 1)) {
        my $param_name = $field_translation{$field_name} || $field_name;
        $set_all_fields{$param_name} = $cgi->param($field_name);
    }
}

if (should_set('keywords')) {
    my $action = $cgi->param('keywordaction') || '';
    # Backward-compatibility for Bugzilla 3.x and older.
    $action = 'remove' if $action eq 'delete';
    $action = 'set'    if $action eq 'makeexact';
    $set_all_fields{keywords}->{$action} = $cgi->param('keywords');
}
if (should_set('comment')) {
    $set_all_fields{comment} = {
        body       => scalar $cgi->param('comment'),
        is_private => scalar $cgi->param('comment_is_private'),
    };
}

my %methods = (
    bug_severity => 'set_severity',
    rep_platform => 'set_platform',
    short_desc   => 'set_summary',
    bug_file_loc => 'set_url',
);

foreach my $b (@bug_objects)
{
    if ($ARGS->{comment} !~ /^\s*$/ || $ARGS->{work_time})
    {
        # Add a comment as needed to each bug. This is done early because
        # there are lots of things that want to check if we added a comment.
        $b->add_comment($ARGS->{comment}, {
            isprivate => $ARGS->{commentprivacy},
            work_time => $ARGS->{work_time},
            type      => $ARGS->{cmt_worktime} ? CMT_WORKTIME : CMT_NORMAL,
        });
    }
    foreach my $field_name (@set_fields)
    {
        if (defined $ARGS->{$field_name} ||
            defined $ARGS->{product} && $field_name =~ /^(component|target_milestone|version)$/)
        {
            my $method = $methods{$field_name};
            $method ||= "set_" . $field_name;
            $b->$method($ARGS->{$field_name} || '', $ARGS);
        }
    }
    $b->reset_assigned_to if $cgi->param('set_default_assignee');
    $b->reset_qa_contact  if $cgi->param('set_default_qa_contact');

    if (should_set('see_also')) {
        my @see_also = split(',', $cgi->param('see_also'));
        $b->add_see_also($_) foreach @see_also;
    }
    if (should_set('remove_see_also')) {
        $b->remove_see_also($_) foreach $cgi->param('remove_see_also')
    }

    # CustIS Bug 134368 - Edit comment
    if (%edit_comment)
    {
        foreach my $comment_id (keys %edit_comment)
        {
            $b->edit_comment($comment_id, $edit_comment{$comment_id});
        }
    }
}

# Certain changes can only happen on individual bugs, never on mass-changes.
if (defined $cgi->param('id')) {
    # Since aliases are unique (like bug numbers), they can only be changed
    # for one bug at a time.
    if (Bugzilla->params->{"usebugaliases"} && defined $cgi->param('alias')) {
        $first_bug->set_alias($cgi->param('alias'));
    }

    # reporter_accessible and cclist_accessible--these are only set if
    # the user can change them and they appear on the page.
    if (should_set('cclist_accessible', 1)) {
        $first_bug->set_cclist_accessible($cgi->param('cclist_accessible'))
    }
    if (should_set('reporter_accessible', 1)) {
        $first_bug->set_reporter_accessible($cgi->param('reporter_accessible'))
    }

    # You can only mark/unmark comments as private on single bugs. If
    # you're not in the insider group, this code won't do anything.
    foreach my $field (grep(/^defined_isprivate/, $cgi->param())) {
        $field =~ /(\d+)$/;
        my $comment_id = $1;
        $first_bug->set_comment_is_private($comment_id,
            $cgi->param("isprivate_$comment_id"));
    }

    # Same with worktime-only
    foreach (keys %$ARGS)
    {
        if (/^cmt_(normal|worktime)_(\d+)$/ && $ARGS->{$_})
        {
            $first_bug->set_comment_worktimeonly($2, $1 eq 'worktime');
        }
    }
}
# Formulate the CC data into two arrays of users involved in this CC change.
if (defined $cgi->param('newcc')
    or defined $cgi->param('addselfcc')
    or defined $cgi->param('removecc')
    or defined $cgi->param('masscc')) 
{
    my (@cc_add, @cc_remove);
    # If masscc is defined, then we came from buglist and need to either add or
    # remove cc's... otherwise, we came from show_bug and may need to do both.
    if (defined $cgi->param('masscc')) {
        if ($cgi->param('ccaction') eq 'add') {
            @cc_add = $cgi->param('masscc');
        } elsif ($cgi->param('ccaction') eq 'remove') {
            @cc_remove = $cgi->param('masscc');
        }
    } else {
        @cc_add = $cgi->param('newcc');
        push(@cc_add, $user) if $cgi->param('addselfcc');

        # We came from show_bug which uses a select box to determine what cc's
        # need to be removed...
        if ($cgi->param('removecc') && $cgi->param('cc')) {
            @cc_remove = $cgi->param('cc');
        }
    }

    $set_all_fields{cc} = { add => \@cc_add, remove => \@cc_remove };
}

# Fields that can only be set on one bug at a time.
if (defined $cgi->param('id')) {
    # Since aliases are unique (like bug numbers), they can only be changed
    # for one bug at a time.
    if (defined $cgi->param('alias')) {
        $set_all_fields{alias} = $cgi->param('alias');
    }
}

my %is_private;
foreach my $field (grep(/^defined_isprivate/, $cgi->param())) {
    $field =~ /(\d+)$/;
    my $comment_id = $1;
    $is_private{$comment_id} = $cgi->param("isprivate_$comment_id");
}
$set_all_fields{comment_is_private} = \%is_private;

my @check_groups = $cgi->param('defined_groups');
my @set_groups = $cgi->param('groups');
my ($removed_groups) = diff_arrays(\@check_groups, \@set_groups);
$set_all_fields{groups} = { add => \@set_groups, remove => $removed_groups };

my @custom_fields = Bugzilla->active_custom_fields;
foreach my $field (@custom_fields) {
    my $fname = $field->name;
    if (should_set($fname, 1)) {
        $set_all_fields{$fname} = [$cgi->param($fname)];
    }
}

# We are going to alter the list of removed groups, so we keep a copy here.
my @unchecked_groups = @$removed_groups;
foreach my $b (@bug_objects) {
    # Don't blindly ask to remove unchecked groups available in the UI.
    # A group can be already unchecked, and the user didn't try to remove it.
    # In this case, we don't want remove_group() to complain.
    my @remove_groups;
    foreach my $g (@{$b->groups_in}) {
        push(@remove_groups, $g->name) if grep { $_ eq $g->name } @unchecked_groups;
    }
    local $set_all_fields{groups}->{remove} = \@remove_groups;
    $b->set_all(\%set_all_fields);
}

# TODO move saved state into a global object
my $send_results = [];
my $send_attrs = {};

Bugzilla::Hook::process('process_bug-pre_update', { bugs => \@bug_objects });

# @msgs will store emails which have to be sent to voters, if any.
my @msgs;

Bugzilla->request_cache->{checkers_hide_error} = 1 if @bug_objects > 1;

##############################
# Do Actual Database Updates #
##############################
foreach my $bug (@bug_objects) {
    Bugzilla->dbh->bz_start_transaction;

    my $mail_count = @{Bugzilla->get_mail_result()};
    my $timestamp = $dbh->selectrow_array(q{SELECT LOCALTIMESTAMP(0)});
    my $changes = $bug->update($timestamp);

    if ($bug->{failed_checkers} && @{$bug->{failed_checkers}} &&
        !$bug->{passed_checkers})
    {
        # This means update is blocked
        # and rollback_to_savepoint is already done in Checkers.pm
        # Roll back flag mail
        splice @{Bugzilla->get_mail_result()}, $mail_count;
        next;
    }

    my %notify_deps;
    if ($changes->{'bug_status'}) {
        my ($old_status, $new_status) = @{ $changes->{'bug_status'} };

        # If this bug has changed from opened to closed or vice-versa,
        # then all of the bugs we block need to be notified.
        if (is_open_state($old_status) ne is_open_state($new_status)) {
            $notify_deps{$_} = 1 foreach (@{$bug->blocked});
        }

        # We may have zeroed the remaining time, if we moved into a closed
        # status, so we should inform the user about that.
        if (!is_open_state($new_status) && $changes->{'remaining_time'}) {
            $vars->{'message'} = "remaining_time_zeroed"
              if $user->is_timetracker;
        }
    }

    # CustIS Bug 38616 - CC list restriction
    if ($bug->{restricted_cc})
    {
        $vars->{restricted_cc} = $bug->{restricted_cc};
        $vars->{cc_restrict_group} = $bug->product_obj->cc_restrict_group;
        $vars->{message} = 'cc_list_restricted';
    }

    # To get a list of all changed dependencies, convert the "changes" arrays
    # into a long string, then collapse that string into unique numbers in
    # a hash.
    my $all_changed_deps = join(', ', @{ $changes->{'dependson'} || [] });
    $all_changed_deps = join(', ', @{ $changes->{'blocked'} || [] },
                                   $all_changed_deps);
    my %changed_deps = map { $_ => 1 } split(', ', $all_changed_deps);
    # When clearning one field (say, blocks) and filling in the other
    # (say, dependson), an empty string can get into the hash and cause
    # an error later.
    delete $changed_deps{''};

    $dbh->bz_commit_transaction();

    ###############
    # Send Emails #
    ###############

    my $old_qa  = $changes->{'qa_contact'}  ? $changes->{'qa_contact'}->[0] : '';
    my $old_own = $changes->{'assigned_to'} ? $changes->{'assigned_to'}->[0] : '';
    my $old_cc  = $changes->{cc}            ? $changes->{cc}->[0] : '';
    # Let the user know the bug was changed and who did and didn't
    # receive email about the change.
    push @$send_results, {
        mailrecipients => {
            cc        => [split(/[\s,]+/, $old_cc)],
            owner     => $old_own,
            qacontact => $old_qa,
            changer   => Bugzilla->user->login,
        },
        bug_id => $bug->id,
        type => "bug",
    };

    # If the bug was marked as a duplicate, we need to notify users on the
    # other bug of any changes to that bug.
    my $new_dup_id = $changes->{'dup_id'} ? $changes->{'dup_id'}->[1] : undef;
    if ($new_dup_id) {
        # Let the user know a duplication notation was added to the 
        # original bug.
        push @$send_results, {
            mailrecipients => { changer => Bugzilla->user->login },
            bug_id => $new_dup_id,
            type => "dupe",
        };
    }

    my %all_dep_changes = (%notify_deps, %changed_deps);
    foreach my $id (sort { $a <=> $b } (keys %all_dep_changes)) {
        # Let the user (if he is able to see the bug) know we checked to
        # see if we should email notice of this change to users with a 
        # relationship to the dependent bug and who did and didn't 
        # receive email about it.
        push @$send_results, {
            mailrecipients => { changer => Bugzilla->user->login },
            bug_id => $id,
            type => "dep",
        };
    }
}

# CustIS Bug 68919 - Create multiple attachments to bug
if (@bug_objects == 1)
{
    Bugzilla::Attachment::add_multiple($first_bug, $cgi, $send_attrs);
}

$dbh->bz_commit_transaction();

###############
# Send Emails #
###############

# TODO move votes removed mail to BugMail
# Now is a good time to send email to voters.
foreach my $msg (@msgs) {
    MessageToMTA($msg);
}

# Send bugmail

# Add flag notifications to send_results
my $notify = Bugzilla->get_mail_result();
push @$send_results, @$notify;

send_results($_) for @$send_results;
$vars->{sentmail} = $send_results;
$vars->{failed_checkers} = Bugzilla->request_cache->{failed_checkers};

my $bug;
if (Bugzilla->usage_mode == USAGE_MODE_EMAIL) {
    # Do nothing.
}
elsif (($action eq 'next_bug' or $action eq 'same_bug') && ($bug = $vars->{bug}) && $user->can_see_bug($bug))
{
    if ($action eq 'same_bug')
    {
        # $bug->update() does not update the internal structure of
        # the bug sufficiently to display the bug with the new values.
        # (That is, if we just passed in the old Bug object, we'd get
        # a lot of old values displayed.)
        $bug = new Bugzilla::Bug($bug->id);
        $vars->{'bug'} = $bug;
    }
    # Do redirect and exit
    my $title;
    if (scalar(@bug_objects) == 1)
    {
        # FIXME hard-coded template title, also in bug/show-header.html.tmpl
        $title = Bugzilla->messages->{terms}->{Bug} . ' ' . $bug_objects[0]->id . ' processed &ndash; ' .
            $bug->short_desc . ' &ndash; ' . $bug->product . '/' . $bug->component . ' &ndash; ' .
            $bug->bug_status . ' ' . $bug->resolution;
    }
    else
    {
        $title = Bugzilla->messages->{terms}->{Bugs} . ' processed';
    }
    $send_attrs->{nextbug} = $action eq 'next_bug' ? 1 : 0;
    my $ses = {
        sent => $send_results,
        title => $title,
        sent_attrs => $send_attrs,
        # CustIS Bug 68921 - Correctness checkers
        failed_checkers => Checkers::freeze_failed_checkers(Bugzilla->request_cache->{failed_checkers}),
    };
    # CustIS Bug 38616 - CC list restriction
    if (scalar(@bug_objects) == 1 && $bug_objects[0]->{restricted_cc})
    {
        $ses->{message_vars} = {
            restricted_cc     => [ map { $_->login } @{ $bug_objects[0]->{restricted_cc} } ],
            cc_restrict_group => $bug_objects[0]->product_obj->cc_restrict_group,
        };
        $ses->{message} = 'cc_list_restricted';
    }
    if (Bugzilla->save_session_data($ses))
    {
        print $cgi->redirect(-location => 'show_bug.cgi?id='.$bug->id);
        exit;
    }
}

if ($action ne 'nothing' && $action ne 'next_bug' && $action ne 'same_bug') {
    ThrowCodeError("invalid_post_bug_submit_action");
}

# End the response page.
unless (Bugzilla->usage_mode == USAGE_MODE_EMAIL)
{
    foreach (@$send_results)
    {
        $template->process("bug/process/results.html.tmpl", { %$vars, %$_ })
            || ThrowTemplateError($template->error());
        $vars->{header_done} = 1;
    }
    if (!$vars->{header_done})
    {
        $template->process("global/header.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
    }
    $template->process("bug/navigate.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    $template->process("global/footer.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

$vars;
__END__
