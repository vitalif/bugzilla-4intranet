#!/usr/bin/perl -wT
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
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Dave Miller <justdave@syndicomm.com>
#                 Christopher Aillon <christopher@aillon.com>
#                 Myk Melez <myk@mozilla.org>
#                 Jeff Hedlund <jeff.hedlund@matrixsi.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Lance Larsh <lance.larsh@oracle.com>
#                 Akamai Technologies <bugzilla-dev@akamai.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

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
use Bugzilla::Mailer;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Field;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Keyword;
use Bugzilla::Flag;
use Bugzilla::Status;
use Bugzilla::Token;

use Checkers;

use Storable qw(dclone);

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = { %{ $cgi->Vars } };
#my $ARGS = $cgi->VarHash; # FIXME (see lines with "FIXME array[]")

######################################################################
# Begin Data/Security Validation
######################################################################

$dbh->bz_start_transaction();

# Create a list of objects for all bugs being modified in this request.
# <vitalif@mail.ru> Use SELECT ... FOR UPDATE to lock these bugs
my @bug_objects;
if ($ARGS->{id})
{
    ($ARGS->{id}) = @{$ARGS->{id}} if ref $ARGS->{id}; # FIXME array[]
    my $bug = Bugzilla::Bug->check({ id => $ARGS->{id}, for_update => 1 });
    $ARGS->{id} = $bug->id;
    push @bug_objects, $bug;
}
else
{
    foreach my $i (keys %$ARGS)
    {
        if ($i =~ /^id_([1-9][0-9]*)/)
        {
            my $id = $1;
            push @bug_objects, Bugzilla::Bug->check({ id => $id, for_update => 1 });
        }
    }
}

# Make sure there are bugs to process.
scalar(@bug_objects) || ThrowUserError("no_bugs_chosen", {action => 'modify'});

my $first_bug = $bug_objects[0]; # Used when we're only updating a single bug.

# Delete any parameter set to 'dontchange'.
if ($ARGS->{dontchange})
{
    foreach my $name (keys %$ARGS)
    {
        next if $name eq 'dontchange'; # But don't delete dontchange itself!
        # Skip ones we've already deleted (such as "defined_$name").
        next if !defined $ARGS->{$name};
        if ($ARGS->{$name} eq $ARGS->{dontchange} ||
            ref $ARGS->{$name} && @{$ARGS->{$name}} == 1 && $ARGS->{$name}->[0] eq $ARGS->{dontchange})
        {
            # FIXME remove these $cgi->delete when Bugzilla::User::match_field won't need CGI
            $cgi->delete($name);
            $cgi->delete("defined_$name");
            delete $ARGS->{$name};
            delete $ARGS->{"defined_$name"};
        }
    }
}

# do a match on the fields if applicable
Bugzilla::User::match_field({
    'qa_contact'  => { type => 'single' },
    'newcc'       => { type => 'multi'  }, # FIXME array[]
    'masscc'      => { type => 'multi'  }, # FIXME array[]
    'assigned_to' => { type => 'single' },
});

# Check for a mid-air collision. Currently this only works when updating
# an individual bug.
if ($ARGS->{delta_ts})
{
    my $delta_ts_z = datetime_from($ARGS->{delta_ts});
    my $first_delta_tz_z = datetime_from($first_bug->delta_ts);
    if ($first_delta_tz_z ne $delta_ts_z)
    {
        ($vars->{operations}) = Bugzilla::Bug::GetBugActivity($first_bug->id, undef, $ARGS->{delta_ts});

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
                    for (split /[\s,]*,[\s,]*/, $ARGS->{$_->{fieldname}})
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
                    $ARGS->{$_->{fieldname}} = $new if $equal;
                    $cgi->param($_->{fieldname}, $new) if $equal;
                }
                elsif ($ARGS->{$_->{fieldname}} eq $_->{removed})
                {
                    # If equal to old value -> change to the new value
                    $ARGS->{$_->{fieldname}} = $_->{added};
                    $cgi->param($_->{fieldname}, $_->{added});
                }
            }
        }

        $vars->{title_tag} = "mid_air";

        ThrowCodeError('undefined_field', { field => 'longdesclength' }) if !$ARGS->{longdesclength};

        $vars->{start_at} = $ARGS->{longdesclength};
        # Always sort midair collision comments oldest to newest,
        # regardless of the user's personal preference.
        $vars->{comments} = $first_bug->comments({ order => "oldest_to_newest", start_at => $vars->{start_at} });
        $vars->{bug} = $first_bug;
        $vars->{ARGS} = $ARGS;

        # The token contains the old delta_ts. We need a new one.
        $ARGS->{token} = issue_hash_token([ $first_bug->id, $first_bug->delta_ts ]);
        # Warn the user about the mid-air collision and ask them what to do.
        $template->process("bug/process/midair.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        exit;
    }
}

my %edit_comment;
foreach my $key (keys %$ARGS)
{
    if ($key =~ /edit_comment\[(.*)\]$/)
    {
        my $comment_id = $1;
        trick_taint($ARGS->{$key});
        $edit_comment{$comment_id} = $ARGS->{$key};
    }
}

# We couldn't do this check earlier as we first had to validate bug IDs
# and display the mid-air collision page if delta_ts changed.
# If we do a mass-change, we use session tokens.
my $token = $ARGS->{token};

if ($ARGS->{id})
{
    check_hash_token($token, [ $first_bug->id, $first_bug->delta_ts ]);
}
else
{
    check_token_data($token, 'buglist_mass_change', 'query.cgi');
}

######################################################################
# End Data/Security Validation
######################################################################

$vars->{title_tag} = "bug_processed";
$vars->{commentsilent} = $ARGS->{commentsilent};

my $action;
if ($ARGS->{id})
{
    $action = Bugzilla->user->settings->{post_bug_submit_action}->{value};
    if ($action eq 'next_bug')
    {
        my @bug_list;
        if ($cgi->cookie("BUGLIST")) # TODO
        {
            @bug_list = split /:/, $cgi->cookie("BUGLIST");
        }
        my $cur = lsearch(\@bug_list, $ARGS->{id});
        if ($cur >= 0 && $cur < $#bug_list)
        {
            my $next_bug_id = $bug_list[$cur + 1];
            detaint_natural($next_bug_id);
            if ($next_bug_id && $user->can_see_bug($next_bug_id))
            {
                # We create an object here so that send_results can use it
                # when displaying the header.
                $vars->{bug} = new Bugzilla::Bug($next_bug_id);
            }
        }
    }
    # Include both action = 'same_bug' and 'nothing'.
    else
    {
        $vars->{bug} = $first_bug;
    }
}
else
{
    # param('id') is not defined when changing multiple bugs at once.
    $action = 'nothing';
}

# For each bug, we have to check if the user can edit the bug the product
# is currently in, before we allow them to change anything.
foreach my $bug (@bug_objects)
{
    Bugzilla->user->can_edit_bug($bug, THROW_ERROR);
}

# For security purposes, and because lots of other checks depend on it,
# we set the product first before anything else.
if (defined $ARGS->{product})
{
    foreach my $b (@bug_objects)
    {
        $b->set(product => $ARGS->{product});
    }
}

# strict_isolation checks mean that we should set the groups
# immediately after changing the product.
foreach my $b (@bug_objects)
{
    my $g;
    foreach my $group (@{$b->product_obj->groups_valid})
    {
        my $gid = $group->id;
        if (defined $ARGS->{"bit-$gid"} || defined $ARGS->{"defined_bit-$gid"})
        {
            $g ||= { map { $_->{bit} => 1 } @{$b->groups} };
            # Check ! first to avoid having to check defined below.
            if (!$ARGS->{"bit-$gid"})
            {
                delete $g->{$gid};
            }
            # "== 1" is important because mass-change uses -1 to mean
            # "don't change this restriction"
            elsif ($ARGS->{"bit-$gid"} == 1)
            {
                $g->{$gid} = 1;
            }
        }
    }
    $b->set(groups => [ keys %$g ]) if $g;
}

if ($ARGS->{id})
{
    my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi($first_bug, undef, $vars);
    $first_bug->set_flags($flags, $new_flags);
}

if ($ARGS->{id} && (defined $ARGS->{dependson} || defined $ARGS->{blocked}))
{
    $first_bug->set_dependencies({ dependson => $ARGS->{dependson}, blocked => $ARGS->{blocked} });
}
elsif (defined $ARGS->{dependson} || defined $ARGS->{blocked})
{
    foreach my $bug (@bug_objects)
    {
        my %temp_deps;
        foreach my $type (qw(dependson blocked))
        {
            $temp_deps{$type} = { map { $_ => 1 } @{$bug->$type} };
            if (defined $ARGS->{$type} && $ARGS->{$type.'_action'} =~ /^(add|remove)$/)
            {
                foreach my $id (split /[,\s]+/, $ARGS->{$type})
                {
                    if ($ARGS->{$type.'_action'} eq 'remove')
                    {
                        delete $temp_deps{$type}{$id};
                    }
                    else
                    {
                        $temp_deps{$type}{$id} = 1;
                    }
                }
            }
        }
        $bug->set_dependencies({ dependson => [ keys %{$temp_deps{dependson}} ], blocked => [ keys %{$temp_deps{blocked}} ] });
    }
}

my $any_keyword_changes;
if (exists $ARGS->{keywords})
{
    foreach my $b (@bug_objects)
    {
        my $return = $b->modify_keywords(
            $ARGS->{keywords},
            $ARGS->{keywords_description},
            $ARGS->{keywordaction},
        );
        $any_keyword_changes ||= $return;
    }
}

# FIXME use a global set_fields list
my @custom_fields = Bugzilla->active_custom_fields;
my @set_fields = qw(
    component deadline remaining_time estimated_time alias op_sys rep_platform bug_severity
    priority status_whiteboard short_desc target_milestone bug_file_loc version
);
push @set_fields, 'assigned_to' if !$ARGS->{set_default_assignee};
push @set_fields, 'qa_contact' if !$ARGS->{set_default_qa_contact};

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
            $b->set($field_name, $ARGS->{$field_name} || '');
        }
    }
    $b->reset_assigned_to if $ARGS->{set_default_assignee};
    $b->reset_qa_contact  if $ARGS->{set_default_qa_contact};

    if (defined $ARGS->{see_also})
    {
        my @see_also = split ',', $ARGS->{see_also};
        $b->add_see_also($_) foreach @see_also;
    }
    if (defined $ARGS->{remove_see_also}) # FIXME array[]
    {
        $b->remove_see_also($_) foreach ref $ARGS->{remove_see_also} ? @{$ARGS->{remove_see_also}} : $ARGS->{remove_see_also};
    }

    # And set custom fields.
    foreach my $field (@custom_fields)
    {
        my $fname = $field->name;
        if (defined $ARGS->{$fname} || defined $ARGS->{"defined_$fname"}) # FIXME array[] for multiselects
        {
            $b->set($fname, $ARGS->{$fname});
        }
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
if ($ARGS->{id})
{
    # Since aliases are unique (like bug numbers), they can only be changed
    # for one bug at a time.
    if (Bugzilla->params->{usebugaliases} && defined $ARGS->{alias})
    {
        $first_bug->set(alias => $ARGS->{alias});
    }

    # reporter_accessible and cclist_accessible--these are only set if
    # the user can change them and they appear on the page.
    if (defined $ARGS->{cclist_accessible} || defined $ARGS->{defined_cclist_accessible})
    {
        $first_bug->set(cclist_accessible => $ARGS->{cclist_accessible});
    }
    if (defined $ARGS->{reporter_accessible} || defined $ARGS->{defined_reporter_accessible})
    {
        $first_bug->set(reporter_accessible => $ARGS->{reporter_accessible});
    }

    # You can only mark/unmark comments as private on single bugs. If
    # you're not in the insider group, this code won't do anything.
    foreach (keys %$ARGS)
    {
        if (/^defined_isprivate_(\d+)$/)
        {
            my $comment_id = $1;
            $first_bug->set_comment_is_private($comment_id, $ARGS->{"isprivate_$comment_id"});
        }
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

# We need to check the addresses involved in a CC change before we touch
# any bugs. What we'll do here is formulate the CC data into two arrays of
# users involved in this CC change.  Then those arrays can be used later
# on for the actual change.
my (@cc_add, @cc_remove);
if ($ARGS->{newcc} || $ARGS->{addselfcc} || $ARGS->{removecc} || $ARGS->{masscc})
{
    # If masscc is defined, then we came from buglist and need to either add or
    # remove cc's... otherwise, we came from bugform and may need to do both.
    my ($cc_add, $cc_remove) = "";
    if ($ARGS->{masscc})
    {
        if ($ARGS->{ccaction} eq 'add')
        {
            $cc_add = $ARGS->{masscc};
        }
        elsif ($ARGS->{ccaction} eq 'remove')
        {
            $cc_remove = $ARGS->{masscc};
        }
    }
    else
    {
        $cc_add = ref $ARGS->{newcc} ? join(', ', @{$ARGS->{newcc}}) : $ARGS->{newcc}; # FIXME array[]
        # We came from bug_form which uses a select box to determine what cc's
        # need to be removed...
        if (defined $ARGS->{removecc} && $ARGS->{cc}) # FIXME array[]
        {
            $cc_remove = ref $ARGS->{cc} ? join(', ', @{$ARGS->{cc}}) : $ARGS->{cc};
        }
    }

    push @cc_add, split /[\s,]+/, $cc_add if $cc_add;
    push @cc_add, Bugzilla->user if defined $ARGS->{addselfcc};
    push @cc_remove, split /[\s,]+/, $cc_remove if $cc_remove;
}

foreach my $b (@bug_objects)
{
    $b->remove_cc($_) foreach @cc_remove;
    $b->add_cc($_) foreach @cc_add;
}

# TODO move saved state into a global object
my $send_results = [];
my $send_attrs = {};

my $move_action = $ARGS->{action} || '';
if ($move_action eq Bugzilla->params->{'move-button-text'})
{
    Bugzilla->params->{'move-enabled'} || ThrowUserError("move_bugs_disabled");

    $user->is_mover || ThrowUserError("auth_failure", { action => 'move', object => 'bugs' });

    $dbh->bz_start_transaction();

    # First update all moved bugs.
    foreach my $bug (@bug_objects)
    {
        $bug->add_comment('', { type => CMT_MOVED_TO, extra_data => $user->login });
    }
    # Don't export the new status and resolution. We want the current ones.
    local $Storable::forgive_me = 1;
    my $bugs = dclone(\@bug_objects);

    my $new_status = Bugzilla->params->{duplicate_or_move_bug_status};
    foreach my $bug (@bug_objects)
    {
        $bug->{moving} = 1;
        $bug->set(bug_status => $new_status);
        $bug->set(resolution => 'MOVED');
    }
    $_->update() foreach @bug_objects;
    $dbh->bz_commit_transaction();

    # Now send emails.
    foreach my $bug (@bug_objects)
    {
        push @$send_results, send_results({
            mailrecipients => { 'changer' => $user->login },
            bug_id         => $bug->id,
            type           => 'move',
        });
    }
    # Prepare and send all data about these bugs to the new database
    my $to = Bugzilla->params->{'move-to-address'};
    $to =~ s/@/\@/;
    my $from = Bugzilla->params->{'moved-from-address'};
    $from =~ s/@/\@/;
    my $msg = "To: $to\n";
    $msg .= "From: Bugzilla <" . $from . ">\n";
    $msg .= "Subject: Moving bug(s) " . join(', ', map($_->id, @bug_objects)) . "\n\n";

    # FIXME Bug moving definitely does not work with all our changes.
    my @fieldlist = (Bugzilla::Bug->fields, 'group', 'long_desc', 'attachment', 'attachmentdata');
    my %displayfields;
    foreach (@fieldlist)
    {
        $displayfields{$_} = 1;
    }

    $template->process('bug/show.xml.tmpl', {
        bugs => $bugs,
        displayfields => \%displayfields,
    }, \$msg) || ThrowTemplateError($template->error());

    $msg .= "\n";
    MessageToMTA($msg);

    # End the response page.
    unless (Bugzilla->usage_mode == USAGE_MODE_EMAIL)
    {
        foreach (@$send_results)
        {
            $template->process("bug/process/results.html.tmpl", { %$vars, %$_ })
                || ThrowTemplateError($template->error());
        }
        $template->process("bug/navigate.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
        $template->process("global/footer.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
    }
    exit;
}

Bugzilla::Hook::process('process_bug-after_move', { bug_objects => \@bug_objects, vars => $vars });

# You cannot mark bugs as duplicates when changing several bugs at once
# (because currently there is no way to check for duplicate loops in that
# situation).
if (!$ARGS->{id} && $ARGS->{dup_id})
{
    ThrowUserError('dupe_not_allowed');
}

# Set the status, resolution, and dupe_of (if needed). This has to be done
# down here, because the validity of status changes depends on other fields,
# such as Target Milestone.
foreach my $b (@bug_objects)
{
    if (defined $ARGS->{bug_status})
    {
        $b->set(bug_status => $ARGS->{bug_status});
    }
    if (defined $ARGS->{resolution})
    {
        $b->set(resolution => $ARGS->{resolution});
    }
    if (defined $ARGS->{dup_id})
    {
        $b->set(dup_id => $ARGS->{dup_id});
    }
}

Bugzilla::Hook::process('process_bug-pre_update', { bugs => \@bug_objects });

# @msgs will store emails which have to be sent to voters, if any.
my @msgs;

Bugzilla->request_cache->{checkers_hide_error} = 1 if @bug_objects > 1;

##############################
# Do Actual Database Updates #
##############################
foreach my $bug (@bug_objects)
{
    $dbh->bz_start_transaction();

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
    if ($changes->{bug_status})
    {
        my ($old_status, $new_status) = @{ $changes->{bug_status} };

        # If this bug has changed from opened to closed or vice-versa,
        # then all of the bugs we block need to be notified.
        if (is_open_state($old_status) ne is_open_state($new_status))
        {
            $notify_deps{$_} = 1 foreach @{$bug->blocked};
        }

        # We may have zeroed the remaining time, if we moved into a closed
        # status, so we should inform the user about that.
        if (!is_open_state($new_status) && $changes->{remaining_time} &&
            !$changes->{remaining_time}->[1] &&
            Bugzilla->user->in_group(Bugzilla->params->{timetrackinggroup}))
        {
            $vars->{message} = "remaining_time_zeroed";
        }
    }

    # CustIS Bug 38616 - CC list restriction
    if ($bug->{restricted_cc})
    {
        $vars->{restricted_cc} = [ map { $_->login } @{$bug->{restricted_cc}} ];
        $vars->{cc_restrict_group} = $bug->product_obj->cc_group;
        $vars->{message} = 'cc_list_restricted';
    }

    # To get a list of all changed dependencies, convert the "changes" arrays
    # into a long string, then collapse that string into unique numbers in
    # a hash.
    my $all_changed_deps = join(', ', @{ $changes->{dependson} || [] });
    $all_changed_deps = join(', ', @{ $changes->{blocked} || [] }, $all_changed_deps);
    my %changed_deps = map { $_ => 1 } split(', ', $all_changed_deps);
    # When clearning one field (say, blocks) and filling in the other
    # (say, dependson), an empty string can get into the hash and cause
    # an error later.
    delete $changed_deps{''};

    if ($changes->{product})
    {
        # If some votes have been removed, RemoveVotes() returns
        # a list of messages to send to voters.
        # We delay the sending of these messages till changes are committed.
        push @msgs, RemoveVotes($bug->id, 0, 'votes_bug_moved');
        CheckIfVotedConfirmed($bug->id);
    }

    $dbh->bz_commit_transaction();

    my $old_qa  = $changes->{qa_contact}  ? $changes->{qa_contact}->[0] : '';
    my $old_own = $changes->{assigned_to} ? $changes->{assigned_to}->[0] : '';
    my $old_cc  = $changes->{cc}          ? $changes->{cc}->[0] : '';

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
    my $new_dup_id = $changes->{dup_id} ? $changes->{dup_id}->[1] : undef;
    if ($new_dup_id)
    {
        # Let the user know a duplication notation was added to the 
        # original bug.
        push @$send_results, {
            mailrecipients => { changer => Bugzilla->user->login },
            bug_id => $new_dup_id,
            type => "dupe",
        };
    }

    my %all_dep_changes = (%notify_deps, %changed_deps);
    foreach my $id (sort { $a <=> $b } (keys %all_dep_changes))
    {
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
foreach my $msg (@msgs)
{
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
if (Bugzilla->usage_mode == USAGE_MODE_EMAIL)
{
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
        $vars->{bug} = $bug;
    }
    # Do redirect and exit
    my $title;
    if (scalar(@bug_objects) == 1)
    {
        # FIXME hard-coded template title, also in bug/show-header.html.tmpl
        $title = Bugzilla->messages->{terms}->{Bug} . ' ' . $bug_objects[0]->id . ' processed &ndash; ' .
            $bug->short_desc . ' &ndash; ' . $bug->product . '/' . $bug->component . ' &ndash; ' .
            $bug->bug_status_obj->name . ($bug->resolution ? ' ' . $bug->resolution_obj->name : '');
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
            cc_restrict_group => $bug_objects[0]->product_obj->cc_group,
        };
        $ses->{message} = 'cc_list_restricted';
    }
    if (Bugzilla->save_session_data($ses))
    {
        print $cgi->redirect(-location => 'show_bug.cgi?id='.$bug->id);
        exit;
    }
}

if ($action ne 'nothing' && $action ne 'next_bug' && $action ne 'same_bug')
{
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
