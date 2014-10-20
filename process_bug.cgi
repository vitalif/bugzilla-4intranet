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
use Bugzilla::CheckerUtils;

use Storable qw(dclone);

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->input_params;

######################################################################
# Begin Data/Security Validation
######################################################################

$dbh->bz_start_transaction();

# Create a list of objects for all bugs being modified in this request.
# <vitalif@mail.ru> Use SELECT ... FOR UPDATE to lock these bugs
my @bug_objects;
if ($ARGS->{id})
{
    ($ARGS->{id}) = @{$ARGS->{id}} if ref $ARGS->{id};
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
    'newcc'       => { type => 'multi'  },
    'masscc'      => { type => 'multi'  },
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

        ## Change only fields the user wanted to change (Originally CustIS Bug 56327)

        # Merge all changes into a single hash
        my $add_rm = {};
        for my $op (@{$vars->{operations}})
        {
            for my $chg (@{$op->{changes}})
            {
                if ($chg->{fieldname} eq 'dependson' || $chg->{fieldname} eq 'blocked' ||
                    Bugzilla->get_field($chg->{fieldname})->type == FIELD_TYPE_MULTI_SELECT)
                {
                    my @rm = split_escaped(',\s*', $chg->{removed});
                    my @add = split_escaped(',\s*', $chg->{added});
                    my $h = ($add_rm->{$chg->{fieldname}} ||= [ {}, {} ]);
                    for (@rm)
                    {
                        delete $h->[1]->{$_} or $h->[0]->{$_} = 1;
                    }
                    for (@add)
                    {
                        delete $h->[0]->{$_} or $h->[1]->{$_} = 1;
                    }
                }
                elsif (!defined $add_rm->{$chg->{fieldname}})
                {
                    $add_rm->{$chg->{fieldname}} = [ $chg->{removed}, $chg->{added} ];
                }
                else
                {
                    $add_rm->{$chg->{fieldname}}->[1] = $chg->{added};
                }
            }
        }

        for my $field (keys %$add_rm)
        {
            my ($removed, $added) = @{$add_rm->{$field}};
            # FIXME Also detect bug_group changes?
            if ($field eq 'dependson' || $field eq 'blocked' ||
                Bugzilla->get_field($field)->type == FIELD_TYPE_MULTI_SELECT)
            {
                # Restore old value by rolling back the activity
                my %new;
                if ($field eq 'dependson' || $field eq 'blocked')
                {
                    %new = (map { $_ => 1 } @{ $first_bug->$field() });
                }
                else
                {
                    %new = (map { $_->name => 1 } @{ $first_bug->get_object($field) });
                }
                my %old = %new;
                delete $old{$_} for keys %$added;
                $old{$_} = 1 for keys %$removed;
                # Compare old value with the submitted one
                my $equal = 1;
                $ARGS->{$field} = '' if !defined $ARGS->{$field};
                for (ref $ARGS->{$field} ? @{$ARGS->{$field}} : split /[\s,]*,[\s,]*/, $ARGS->{$field})
                {
                    if (!$old{$_})
                    {
                        $equal = 0;
                        last;
                    }
                    delete $old{$_};
                }
                $equal = 0 if %old;
                # If equal to old value -> change to the new value
                $ARGS->{$field} = [ keys %new ] if $equal;
            }
            elsif ($ARGS->{$field} eq $removed)
            {
                # If equal to old value -> change to the new value
                $ARGS->{$field} = $added;
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

my $next_bug_id;
my $action;
if ($ARGS->{id})
{
    $action = Bugzilla->user->settings->{post_bug_submit_action}->{value};
    if ($action eq 'next_bug')
    {
        my @bug_list;
        if (Bugzilla->cookies->{BUGLIST}) # FIXME
        {
            @bug_list = split /:/, Bugzilla->cookies->{BUGLIST};
        }
        my $cur = lsearch(\@bug_list, $ARGS->{id});
        if ($cur >= 0 && $cur < $#bug_list)
        {
            $next_bug_id = $bug_list[$cur + 1];
            detaint_natural($next_bug_id);
            if ($next_bug_id && !$user->can_see_bug($next_bug_id))
            {
                $next_bug_id = undef;
            }
        }
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

Bugzilla::Flag::show_flag_reminders(\@bug_objects);

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
    if (defined $ARGS->{remove_see_also})
    {
        $b->remove_see_also($_) foreach ref $ARGS->{remove_see_also} ? @{$ARGS->{remove_see_also}} : $ARGS->{remove_see_also};
    }

    # And set custom fields.
    foreach my $field (@custom_fields)
    {
        my $fname = $field->name;
        if (defined $ARGS->{$fname} || defined $ARGS->{"defined_$fname"})
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
    if (defined $ARGS->{alias})
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
        if (/^wtonly_(\d+)$/)
        {
            $first_bug->set_comment_worktimeonly($1, $ARGS->{$_});
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
        $cc_add = ref $ARGS->{newcc} ? join(', ', @{$ARGS->{newcc}}) : $ARGS->{newcc};
        # We came from bug_form which uses a select box to determine what cc's
        # need to be removed...
        if (defined $ARGS->{removecc} && $ARGS->{cc})
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
        Bugzilla->add_result_message({
            message        => 'bugmail',
            type           => 'move',
            bug_id         => $bug->id,
            mailrecipients => { 'changer' => $user->login },
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

    Bugzilla->send_mail;

    $template->process("global/header.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    $template->process("bug/navigate.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    $template->process("global/footer.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
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

# Set the status, resolution, and dupe_of (if needed).
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

Bugzilla->request_cache->{checkers_hide_error} = 1 if @bug_objects > 1;

##############################
# Do Actual Database Updates #
##############################
foreach my $bug (@bug_objects)
{
    $dbh->bz_start_transaction();

    my $msg_count = @{Bugzilla->result_messages};
    my $changes = $bug->update;

    if ($bug->{failed_checkers} && @{$bug->{failed_checkers}} &&
        !$bug->{passed_checkers})
    {
        # Update is blocked and rollback_to_savepoint is already done in Checkers.pm.
        # Rollback mail results and result messages.
        splice @{Bugzilla->result_messages}, $msg_count;
        next;
    }

    $dbh->bz_commit_transaction();
}

# CustIS Bug 68919 - Create multiple attachments to bug
if (@bug_objects == 1)
{
    Bugzilla::Attachment::add_multiple($first_bug);
}
else
{
    Bugzilla::CheckerUtils::show_checker_errors();
}

$dbh->bz_commit_transaction();

###############
# Send Emails #
###############

# Send bugmail
Bugzilla->send_mail;

if (scalar(@bug_objects) > 1)
{
    Bugzilla->session_data({ title => Bugzilla->messages->{terms}->{Bugs} . ' processed' });
}
elsif ($action eq 'next_bug')
{
    if ($next_bug_id)
    {
        # Do not override the title, but show a message
        Bugzilla->add_result_message({ message => 'next_bug_shown', bug_id => $next_bug_id });
    }
    else
    {
        $action = 'nothing';
    }
}
elsif ($action eq 'same_bug')
{
    # FIXME hard-coded template title, also in bug/show-header.html.tmpl
    Bugzilla->session_data({ title => Bugzilla->messages->{terms}->{Bug} . ' ' . $first_bug->id . ' processed &ndash; ' .
        $first_bug->short_desc . ' &ndash; ' . $first_bug->product . '/' . $first_bug->component . ' &ndash; ' .
        $first_bug->bug_status_obj->name . ($first_bug->resolution ? ' ' . $first_bug->resolution_obj->name : '') });
}

if (scalar(@bug_objects) == 1 && $action ne 'nothing' && Bugzilla->save_session_data)
{
    # Do redirect and exit
    print $cgi->redirect(-location => 'show_bug.cgi?id='.($next_bug_id || $first_bug->id));
}
else
{
    # End the response page.
    $vars->{last_bug_list} = [ split /:/, Bugzilla->cookies->{BUGLIST} ];
    $template->process("global/header.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    $template->process("bug/navigate.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    $template->process("global/footer.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

exit;
