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
# Contributor(s): Terry Weissman <terry@mozilla.org>,
#                 Bryce Nesbitt <bryce-mozilla@nextbus.com>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Alan Raetz <al_raetz@yahoo.com>
#                 Jacob Steenhagen <jake@actex.net>
#                 Matthew Tuck <matty@chariot.net.au>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 J. Paul Reed <preed@sigkill.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Byron Jones <bugzilla@glob.com.au>

use strict;

package Bugzilla::BugMail;

use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Hook;
use Bugzilla::Bug;
use Bugzilla::Classification;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Status;
use Bugzilla::Mailer;
use Bugzilla::Diff;

use Date::Parse;
use Date::Format;
use POSIX;

use constant FORMAT_TRIPLE => "%19s|%-28s|%-28s";
use constant FORMAT_3_SIZE => [19,28,28];
use constant FORMAT_DOUBLE => "%19s %-55s";
use constant FORMAT_2_SIZE => [19,55];

use constant BIT_DIRECT    => 1;
use constant BIT_WATCHING  => 2;

# We need these strings for the X-Bugzilla-Reasons header
# Note: this hash uses "," rather than "=>" to avoid auto-quoting of the LHS.
use constant REL_NAMES => {
    REL_ASSIGNEE      , "AssignedTo",
    REL_REPORTER      , "Reporter",
    REL_QA            , "QAcontact",
    REL_CC            , "CC",
    REL_VOTER         , "Voter",
    REL_GLOBAL_WATCHER, "GlobalWatcher"
};

# Used to send email when an update is done.
sub send_results
{
    shift if $_[0] eq __PACKAGE__;
    my ($vars) = @_;
    next if $vars->{message} eq 'bugmail' && $vars->{sent_bugmail};
    $vars->{commentsilent} = Bugzilla->input_params->{commentsilent}
        && Bugzilla->params->{allow_commentsilent};
    if ($vars->{message} eq 'flagmail')
    {
        $vars->{message} = 'bugmail';
        $vars->{type} = 'flag';
        $vars->{commentsilent} &&= Bugzilla->user->settings->{silent_affects_flags}->{value} eq 'do_not_send';
        if (!$vars->{commentsilent})
        {
            $vars->{sent_bugmail} = SendFlag($vars->{notify_data});
        }
        $vars->{new_flag} = {
            name => $vars->{notify_data}->{flag} ? $vars->{notify_data}->{flag}->name : $vars->{notify_data}->{old_flag}->name,
            status => $vars->{notify_data}->{flag} ? $vars->{notify_data}->{flag}->status : 'X',
        };
        delete $vars->{notify_data}; # erase data, don't store it in session
    }
    elsif ($vars->{message} eq 'votes-removed')
    {
        $vars->{message} = 'bugmail';
        $vars->{sent_bugmail} = SendVotesRemoved($vars);
        $vars->{commentsilent} = 0;
        delete $vars->{notify_data}; # erase data, don't store it in session
    }
    elsif ($vars->{message} eq 'bugmail')
    {
        $vars->{sent_bugmail} = Send($vars->{bug_id}, $vars->{mailrecipients}, $vars->{commentsilent});
    }
    return $vars;
}

# We use this instead of format because format doesn't deal well with
# multi-byte languages.
sub multiline_sprintf
{
    my ($format, $args, $sizes) = @_;
    my @parts;
    my @my_sizes = @$sizes; # Copy this so we don't modify the input array.
    foreach my $string (@$args)
    {
        my $size = shift @my_sizes;
        my @pieces = split("\n", wrap_hard($string, $size));
        push(@parts, \@pieces);
    }

    my $formatted;
    while (1)
    {
        # Get the first item of each part.
        my @line = map { shift @$_ } @parts;
        # If they're all undef, we're done.
        last if !grep { defined $_ } @line;
        # Make any single undef item into ''
        @line = map { defined $_ ? $_ : '' } @line;
        # And append a formatted line
        $formatted .= sprintf($format, @line);
        # Remove trailing spaces, or they become lots of =20's in
        # quoted-printable emails.
        $formatted =~ s/\s+$//;
        $formatted .= "\n";
    }
    return $formatted;
}

sub three_columns
{
    return multiline_sprintf(FORMAT_TRIPLE, \@_, FORMAT_3_SIZE);
}

sub SendFlag
{
    my ($flag_data) = (@_);

    my @sent;
    my @excluded;

    foreach my $email (@{$flag_data->{mail}})
    {
        $email = { %$email, %$flag_data };
        Bugzilla::Hook::process('flag-notify-pre-template', { vars => $email });

        my $template = Bugzilla->template_inner($email->{lang});
        my $message;
        $template->process("request/email.txt.tmpl", $email, \$message)
           || ThrowTemplateError($template->error());

        Bugzilla->template_inner("");
        MessageToMTA($message);

        Bugzilla::Hook::process('flag-notify-post-send', { vars => $email });

        push @sent, $email->{to};
    }

    return { sent => \@sent, excluded => \@excluded };
}

sub SendVotesRemoved
{
    my ($vars) = @_;

    my @to;
    for (@{$vars->{notify_data}})
    {
        $_->{bugid} = $vars->{bug_id};
        my $voter = new Bugzilla::User($_->{userid});
        my $template = Bugzilla->template_inner($voter->settings->{lang}->{value});
        my $msg;
        $template->process("email/votes-removed.txt.tmpl", $_, \$msg);
        MessageToMTA($msg);
        push @to, $voter->login;
    }
    Bugzilla->template_inner('');

    return { sent => \@to, excluded => [] };
}

# This is a bit of a hack, basically keeping the old system()
# cmd line interface. Should clean this up at some point.
#
# args: bug_id, and an optional hash ref which may have keys for:
# changer, owner, qa, reporter, cc
# Optional hash contains values of people which will be forced to those
# roles when the email is sent.
# All the names are email addresses, not userids
# values are scalars, except for cc, which is a list
sub Send
{
    my ($id, $forced, $silent) = (@_);

    if ($silent)
    {
        Bugzilla->dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id = ?', undef, $id);
        return { commentsilent => 1 };
    }

    my @headerlist;
    my %fielddescription;

    my $msg = "";

    my $dbh = Bugzilla->dbh;
    my $bug = new Bugzilla::Bug($id);

    foreach my $field (Bugzilla->get_fields({ obsolete => 0, sort => 'sortkey' }))
    {
        push @headerlist, $field if $field->in_new_bugmail;
        $fielddescription{$field->name} = $field->description;
    }

    my ($start, $creation_ts, $end) = $dbh->selectrow_array("SELECT lastdiffed, creation_ts, LOCALTIMESTAMP(0) FROM bugs WHERE bug_id=$id");

    # User IDs of people in various roles. More than one person can 'have' a
    # role, if the person in that role has changed, or people are watching.
    my $reporter = $bug->reporter_id;
    my @assignees = ($bug->assigned_to_id);
    my @qa_contacts = ($bug->qa_contact_id);
    my @ccs = map { $_->id } @{$bug->cc_users};
    my @cc_login_names = map { $_->login } @{$bug->cc_users};

    # Include the people passed in as being in particular roles.
    # This can include people who used to hold those roles.
    # At this point, we don't care if there are duplicates in these arrays.
    my $changer = $forced->{changer};
    if ($forced->{owner})
    {
        push @assignees, Bugzilla::User::login_to_id($forced->{owner}, THROW_ERROR);
    }

    if ($forced->{qacontact})
    {
        push @qa_contacts, Bugzilla::User::login_to_id($forced->{qacontact}, THROW_ERROR);
    }

    if ($forced->{cc})
    {
        foreach my $cc (@{$forced->{cc}})
        {
            push @ccs, Bugzilla::User::login_to_id($cc, THROW_ERROR);
        }
    }

    my %values;

    # Convert to names, for later display
    # If no changer is specified, then it has no name.
    if ($changer)
    {
        $changer = Bugzilla::User->new({ name => $changer }) if !ref $changer;
        $values{changername} = $changer->name if $changer;
        $values{changer} = $changer;
    }

    my @args = ($id, $start || $creation_ts, $end);
    my @dep_args = ($id, $start || $creation_ts, $end);
    my $when_restriction = ' AND bug_when > ? AND bug_when <= ?';
    # FIXME Use Bug::get_history
    my $diffs = $dbh->selectall_arrayref(
          "(SELECT profiles.login_name, profiles.realname, fielddefs.description fielddesc,
                   fielddefs.sortkey fieldsortkey,
                   bugs_activity.bug_when, bugs_activity.removed,
                   bugs_activity.added, bugs_activity.attach_id, fielddefs.name fieldname, null as comment_id, null as comment_count
              FROM bugs_activity
        INNER JOIN fielddefs
                ON fielddefs.id = bugs_activity.fieldid
        INNER JOIN profiles
                ON profiles.userid = bugs_activity.who
             WHERE bugs_activity.bug_id = ?
                   $when_restriction)
 UNION ALL (SELECT profile1.login_name, profile1.realname, fielddefs1.description fielddesc,
                   fielddefs1.sortkey fieldsortkey,
                   a.change_ts, a.removed, a.added, null, fielddefs1.name fieldname, a.object_id, COUNT(*)+1 comment_count
              FROM objects_activity a
        INNER JOIN longdescs ld ON ld.bug_id=? AND a.object_id=ld.comment_id
        INNER JOIN longdescs ld2 ON ld2.bug_id=? AND a.object_id=ld2.comment_id AND ld2.bug_when < ld.bug_when
        INNER JOIN profiles profile1 ON profile1.userid = a.who
        INNER JOIN fielddefs fielddefs1 ON fielddefs1.name = 'longdesc'
             WHERE $when_restriction
          GROUP BY a.id)
          ORDER BY bug_when, fieldsortkey", {Slice=>{}}, @args, @args);

    my @new_depbugs;
    foreach my $diff (@$diffs)
    {
        $diff->{attach_id} and $diff->{fielddesc} =~ s/^(Attachment )?/Attachment #$diff->{attach_id} /;
        if ($diff->{fieldname} eq 'estimated_time' ||
            $diff->{fieldname} eq 'remaining_time')
        {
            $diff->{removed} = format_time_decimal($diff->{removed});
            $diff->{added} = format_time_decimal($diff->{added});
        }
        if ($diff->{fieldname} eq 'dependson')
        {
            push(@new_depbugs, grep {$_ =~ /^\d+$/} split(/[\s,]+/, $diff->{added}));
        }
        if ($diff->{attach_id})
        {
            ($diff->{isprivate}) = $dbh->selectrow_array(
                'SELECT isprivate FROM attachments WHERE attach_id = ?',
                undef, ($diff->{attach_id}));
        }
    }

    my @depbugs;
    my $deptext = "";
    # Do not include data about dependent bugs when they have just been added.
    # Completely skip checking for dependent bugs on bug creation as all
    # dependencies bugs will just have been added.
    if ($start)
    {
        my $dep_restriction = "";
        if (scalar @new_depbugs)
        {
            $dep_restriction = "AND bugs_activity.bug_id NOT IN (" . join(", ", @new_depbugs) . ")";
        }

        my $dependency_diffs = $dbh->selectall_arrayref(
           "SELECT bugs_activity.bug_id dep, bugs.short_desc, fielddefs.name fieldname,
                   fielddefs.description fielddesc, bugs_activity.removed, bugs_activity.added,
                   profiles.login_name, profiles.realname
              FROM bugs_activity
        INNER JOIN bugs
                ON bugs.bug_id = bugs_activity.bug_id
        INNER JOIN dependencies
                ON bugs_activity.bug_id = dependencies.dependson
        INNER JOIN fielddefs
                ON fielddefs.id = bugs_activity.fieldid
        INNER JOIN profiles
                ON profiles.userid = bugs_activity.who
             WHERE dependencies.blocked = ?
               AND (fielddefs.name = 'bug_status'
                    OR fielddefs.name = 'resolution')
                   $when_restriction
                   $dep_restriction
          ORDER BY bugs_activity.bug_when, bugs.bug_id, fielddefs.sortkey", {Slice=>{}}, @dep_args);

        my $thisdiff = "";
        my $lastbug = "";
        my $interestingchange = 0;
        my @diff_tmp = ();
        foreach my $dep_diff (@$dependency_diffs)
        {
            $dep_diff->{bug_id} = $id;
            $dep_diff->{type} = 'dep';
            if ($dep_diff->{dep} ne $lastbug)
            {
                if ($interestingchange)
                {
                    push @$diffs, @diff_tmp;
                }
                @diff_tmp = ();
                $lastbug = $dep_diff->{dep};
                $interestingchange = 0;
            }
            if ($dep_diff->{fieldname} eq 'bug_status' &&
                scalar(grep { $_->is_open && $_->name eq $dep_diff->{removed} } Bugzilla::Status->get_all) !=
                scalar(grep { $_->is_open && $_->name eq $dep_diff->{added} } Bugzilla::Status->get_all))
            {
                $interestingchange = 1;
            }
            push @depbugs, $dep_diff->{dep};
            push @diff_tmp, $dep_diff;
        }

        if ($interestingchange)
        {
            push @$diffs, @diff_tmp;
        }
    }

    my $comments = $bug->comments({ after => $start, to => $end });

    ###########################################################################
    # Start of email filtering code
    ###########################################################################

    # A user_id => roles hash to keep track of people.
    my %recipients;
    my %watching;

    # Now we work out all the people involved with this bug, and note all of
    # the relationships in a hash. The keys are userids, the values are an
    # array of role constants.

    # Voters
    my $voters = $dbh->selectcol_arrayref("SELECT who FROM votes WHERE bug_id = ?", undef, ($id));

    $recipients{$_}->{+REL_VOTER} = BIT_DIRECT foreach (@$voters);

    # CCs
    $recipients{$_}->{+REL_CC} = BIT_DIRECT foreach (@ccs);

    # Reporter (there's only ever one)
    $recipients{$reporter}->{+REL_REPORTER} = BIT_DIRECT;

    # QA Contact
    if (Bugzilla->get_field('qa_contact')->enabled)
    {
        foreach (@qa_contacts)
        {
            # QA Contact can be blank; ignore it if so.
            $recipients{$_}->{+REL_QA} = BIT_DIRECT if $_;
        }
    }

    # Assignee
    $recipients{$_}->{+REL_ASSIGNEE} = BIT_DIRECT foreach (@assignees);

    # The last relevant set of people are those who are being removed from
    # their roles in this change. We get their names out of the diffs.
    foreach my $diff (@$diffs)
    {
        if ($diff->{removed})
        {
            # You can't stop being the reporter, and mail isn't sent if you
            # remove your vote.
            # Ignore people whose user account has been deleted or renamed.
            if ($diff->{fielddesc} eq "CC")
            {
                foreach my $cc_user (split(/[\s,]+/, $diff->{removed}))
                {
                    my $uid = Bugzilla::User::login_to_id($cc_user);
                    $recipients{$uid}->{+REL_CC} = BIT_DIRECT if $uid;
                }
            }
            elsif ($diff->{fielddesc} eq "QAContact")
            {
                my $uid = Bugzilla::User::login_to_id($diff->{removed});
                $recipients{$uid}->{+REL_QA} = BIT_DIRECT if $uid;
            }
            elsif ($diff->{fielddesc} eq "AssignedTo")
            {
                my $uid = Bugzilla::User::login_to_id($diff->{removed});
                $recipients{$uid}->{+REL_ASSIGNEE} = BIT_DIRECT if $uid;
            }
        }
    }

    Bugzilla::Hook::process('bugmail_recipients', { bug => $bug, recipients => \%recipients });

    # Find all those user-watching anyone on the current list, who is not
    # on it already themselves.
    my $involved = join(",", keys %recipients);

    my $userwatchers = $dbh->selectall_arrayref(
        "SELECT watcher, watched FROM watch WHERE watched IN ($involved)"
    );

    # Mark these people as having the role of the person they are watching
    foreach my $watch (@$userwatchers)
    {
        while (my ($role, $bits) = each %{$recipients{$watch->[1]}})
        {
            $recipients{$watch->[0]}->{$role} |= BIT_WATCHING if $bits & BIT_DIRECT;
        }
        push(@{$watching{$watch->[0]}}, $watch->[1]);
    }

    # Global watcher
    my @watchers = split(/[,\s]+/, Bugzilla->params->{globalwatchers});
    foreach (@watchers)
    {
        my $watcher_id = Bugzilla::User::login_to_id($_);
        next unless $watcher_id;
        $recipients{$watcher_id}->{+REL_GLOBAL_WATCHER} = BIT_DIRECT;
    }

    # We now have a complete set of all the users, and their relationships to
    # the bug in question. However, we are not necessarily going to mail them
    # all - there are preferences, permissions checks and all sorts to do yet.
    my @sent;
    my @excluded;

    foreach my $user_id (keys %recipients)
    {
        my %rels_which_want;
        my $sent_mail = 0;

        my $user = new Bugzilla::User($user_id);
        # Deleted users must be excluded.
        next unless $user;

        if ($user->can_see_bug($id))
        {
            # Go through each role the user has and see if they want mail in
            # that role.
            foreach my $relationship (keys %{$recipients{$user_id}})
            {
                if ($user->wants_bug_mail($id, $relationship, $diffs, $comments, $deptext, $changer, !$start))
                {
                    $rels_which_want{$relationship} = $recipients{$user_id}->{$relationship};
                }
            }
        }

        if (scalar(%rels_which_want))
        {
            # So the user exists, can see the bug, and wants mail in at least
            # one role. But do we want to send it to them?

            # Make sure the user isn't in the nomail list.
            if ($user->email_enabled)
            {
                # OK, OK, if we must. Email the user.
                $sent_mail = sendMail({
                    bug     => $bug,
                    user    => $user,
                    headers => \@headerlist,
                    rels    => \%rels_which_want,
                    changer => $values{changer},
                    changername => $values{changername},
                    fields  => \%fielddescription,
                    diffs   => $diffs,
                    new_comments => $comments,
                    isnew   => !$start,
                    watch   => exists $watching{$user_id} ? $watching{$user_id} : undef,
                });
            }
        }

        if ($sent_mail)
        {
            push(@sent, $user->login);
        }
        else
        {
            push(@excluded, $user->login);
        }
    }

    $dbh->do('UPDATE bugs SET lastdiffed = ? WHERE bug_id = ?', undef, ($end, $id));

    return { sent => \@sent, excluded => \@excluded };
}

sub sendMail
{
    my ($args) = @_;

    my $user = $args->{user};
    my $bug = $args->{bug};
    my $new_comments = $args->{new_comments};

    # Filter changes by verifying the user should see them
    my $new_diffs = [];
    foreach my $diff (@{$args->{diffs}})
    {
        # Exclude diffs with timetracking information for non-timetrackers
        # Exclude diffs with private attachments for non-insiders
        # Exclude dependency diffs with if dependencies are not visible to the user
        if (exists($diff->{fieldname}) &&
            (!TIMETRACKING_FIELDS->{$diff->{fieldname}} || $user->is_timetracker) &&
            (!$diff->{isprivate} || $user->is_insider) &&
            (!$diff->{dep} || $user->can_see_bug($diff->{dep})))
        {
            push @$new_diffs, $diff;
        }
    }

    if (!$user->is_insider)
    {
        # Exclude private comments for non-insiders
        $new_comments = [ grep { !$_->is_private } @$new_comments ];
    }

    if (!@$new_diffs && !scalar(@$new_comments) && !$args->{isnew})
    {
        # Whoops, no differences!
        return 0;
    }

    my $showfieldvalues = []; # for HTML emails
    if ($args->{isnew})
    {
        my ($value, $f);
        foreach my $field (@{$args->{headers}})
        {
            $f = $field->name;
            $value = $bug->get_string($field);
            # If there isn't anything to show, don't include this header.
            next unless $value;
            # Only send time tracking information if it is enabled and the user is in the group.
            if (!TIMETRACKING_FIELDS->{$f} || $user->is_timetracker)
            {
                push @$showfieldvalues, { desc => $args->{fields}->{$f}, value => $value };
            }
        }
    }

    my (@reasons, @reasons_watch);
    while (my ($relationship, $bits) = each %{$args->{rels}})
    {
        push(@reasons, $relationship) if ($bits & BIT_DIRECT);
        push(@reasons_watch, $relationship) if ($bits & BIT_WATCHING);
    }

    my @headerrel   = map { REL_NAMES->{$_} } @reasons;
    my @watchingrel = map { REL_NAMES->{$_} } @reasons_watch;
    push @headerrel,   'None' unless @headerrel;
    push @watchingrel, 'None' unless @watchingrel;
    push @watchingrel, map { $_->login } @{ Bugzilla::User->new_from_list($args->{watch}) };

    for my $change (@$new_diffs)
    {
        my $field = Bugzilla->get_field($change->{fieldname});
        if (($change->{fieldname} eq 'longdesc' || $field->{type} eq FIELD_TYPE_TEXTAREA) && !$change->{lines})
        {
            my $diff = new Bugzilla::Diff($change->{removed}, $change->{added});
            $change->{lines} = $diff->get_table;
            $change->{diff_removed} = $diff->get_removed;
            $change->{diff_added} = $diff->get_added;
        }
    }

    my $vars = {
        isnew              => $args->{isnew},
        showfieldvalues    => $showfieldvalues,
        to                 => $user->email,
        to_user            => $user,
        bug                => $bug,
        bugid              => $bug->id,
        reasons            => \@reasons,
        reasons_watch      => \@reasons_watch,
        reasonsheader      => join(" ", @headerrel),
        reasonswatchheader => join(" ", @watchingrel),
        changer            => $args->{changer},
        changername        => $args->{changername},
        diffs              => $new_diffs,
        new_comments       => $new_comments,
        threadingmarker    => build_thread_marker($bug->id, $user->id, $args->{isnew}),
        three_columns      => \&three_columns,
    };

    my $msg;
    my $tmpl = '';

    my $template = Bugzilla->template_inner($user->settings->{lang}->{value});
    Bugzilla::Hook::process('bugmail-pre_template', { tmpl => \$tmpl, vars => $vars });
    $tmpl = "email/newchangedmail.txt.tmpl" unless $template->template_exists($tmpl);
    $template->process($tmpl, $vars, \$msg) || ThrowTemplateError($template->error());
    Bugzilla->template_inner("");

    logMail($vars);
    MessageToMTA($msg);

    Bugzilla::Hook::process('bugmail-post_send', { tmpl => \$tmpl, vars => $vars });

    return 1;
}

# Log all messages with comment and diff count to data/maillog
sub logMail
{
    my ($vars) = @_;
    my $datadir = bz_locations()->{datadir};
    my $fd;
    if (-w "$datadir/maillog" && open $fd, ">>$datadir/maillog")
    {
        my $s = [ POSIX::strftime("%Y-%m-%d %H:%M:%S: ", localtime) . ($vars->{isnew} ? "" : "Re: ") . "Bug #$vars->{bugid} mail to $vars->{to}" ];
        if ($vars->{new_comments} && @{$vars->{new_comments}})
        {
            push @$s, scalar(@{$vars->{new_comments}}) . ' comment(s) (#' . (join ',', map { $_->{count} } @{$vars->{new_comments}}) . ')';
        }
        if ($vars->{diffarray} && @{$vars->{diffarray}})
        {
            push @$s, scalar(grep { $_->{type} eq 'change' } @{$vars->{diffarray}}) . ' diffs';
        }
        $s = join "; ", @$s;
        print $fd $s, "\n";
        close $fd;
    }
}

1;
