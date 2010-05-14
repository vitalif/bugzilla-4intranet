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
use Bugzilla::CustisLocalBugzillas;

use Date::Parse;
use Date::Format;

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

# We use this instead of format because format doesn't deal well with
# multi-byte languages.
sub multiline_sprintf {
    my ($format, $args, $sizes) = @_;
    my @parts;
    my @my_sizes = @$sizes; # Copy this so we don't modify the input array.
    foreach my $string (@$args) {
        my $size = shift @my_sizes;
        my @pieces = split("\n", wrap_hard($string, $size));
        push(@parts, \@pieces);
    }

    my $formatted;
    while (1) {
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

sub three_columns {
    return multiline_sprintf(FORMAT_TRIPLE, \@_, FORMAT_3_SIZE);
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
sub Send {
    my ($id, $forced) = (@_);

    my @headerlist;
    my %defmailhead;
    my %fielddescription;

    my $msg = "";

    my $dbh = Bugzilla->dbh;
    my $bug = new Bugzilla::Bug($id);

    # XXX - These variables below are useless. We could use field object
    # methods directly. But we first have to implement a cache in
    # Bugzilla->get_fields to avoid querying the DB all the time.
    foreach my $field (Bugzilla->get_fields({obsolete => 0})) {
        push(@headerlist, $field->name);
        $defmailhead{$field->name} = $field->in_new_bugmail;
        $fielddescription{$field->name} = $field->description;
    }

    my %values = %{$dbh->selectrow_hashref(
        'SELECT *, lastdiffed AS start_time, LOCALTIMESTAMP(0) AS end_time
           FROM bugs WHERE bug_id = ?',
        undef, $id)};

    my $product = new Bugzilla::Product($values{product_id});
    $values{product} = $product->name;
    if (Bugzilla->params->{'useclassification'}) {
        $values{classification} = Bugzilla::Classification->new($product->classification_id)->name;
    }
    my $component = new Bugzilla::Component($values{component_id});
    $values{component} = $component->name;

    my ($start, $end) = ($values{start_time}, $values{end_time});

    # User IDs of people in various roles. More than one person can 'have' a
    # role, if the person in that role has changed, or people are watching.
    my $reporter = $values{'reporter'};
    my @assignees = ($values{'assigned_to'});
    my @qa_contacts = ($values{'qa_contact'});

    my $cc_users = $dbh->selectall_arrayref(
           "SELECT cc.who, profiles.login_name
              FROM cc
        INNER JOIN profiles
                ON cc.who = profiles.userid
             WHERE bug_id = ?",
           undef, $id);

    my (@ccs, @cc_login_names);
    foreach my $cc_user (@$cc_users) {
        my ($user_id, $user_login) = @$cc_user;
        push (@ccs, $user_id);
        push (@cc_login_names, $user_login);
    }

    # Include the people passed in as being in particular roles.
    # This can include people who used to hold those roles.
    # At this point, we don't care if there are duplicates in these arrays.
    my $changer = $forced->{'changer'};
    if ($forced->{'owner'}) {
        push (@assignees, login_to_id($forced->{'owner'}, THROW_ERROR));
    }

    if ($forced->{'qacontact'}) {
        push (@qa_contacts, login_to_id($forced->{'qacontact'}, THROW_ERROR));
    }

    if ($forced->{'cc'}) {
        foreach my $cc (@{$forced->{'cc'}}) {
            push(@ccs, login_to_id($cc, THROW_ERROR));
        }
    }

    # Convert to names, for later display
    $values{'changer'} = $changer;
    # If no changer is specified, then it has no name.
    if ($changer) {
        $values{'changername'} = Bugzilla::User->new({name => $changer})->name;
    }
    $values{'assigned_to'} = user_id_to_login($values{'assigned_to'});
    $values{'reporter'} = user_id_to_login($values{'reporter'});
    if ($values{'qa_contact'}) {
        $values{'qa_contact'} = user_id_to_login($values{'qa_contact'});
    }
    $values{'cc'} = join(', ', @cc_login_names);
    $values{'estimated_time'} = format_time_decimal($values{'estimated_time'});

    if ($values{'deadline'}) {
        $values{'deadline'} = time2str("%Y-%m-%d", str2time($values{'deadline'}));
    }

    my $dependslist = $dbh->selectcol_arrayref(
        'SELECT dependson FROM dependencies
         WHERE blocked = ? ORDER BY dependson',
        undef, ($id));

    $values{'dependson'} = join(",", @$dependslist);

    my $blockedlist = $dbh->selectcol_arrayref(
        'SELECT blocked FROM dependencies
         WHERE dependson = ? ORDER BY blocked',
        undef, ($id));

    $values{'blocked'} = join(",", @$blockedlist);

    my $grouplist = $dbh->selectcol_arrayref(
        '    SELECT name FROM groups
         INNER JOIN bug_group_map
                 ON groups.id = bug_group_map.group_id
                    AND bug_group_map.bug_id = ?',
        undef, ($id));

    $values{'bug_group'} = join(', ', @$grouplist);

    my @args = ($id);

    # If lastdiffed is NULL, then we don't limit the search on time.
    my $when_restriction = '';
    if ($start) {
        $when_restriction = ' AND bug_when > ? AND bug_when <= ?';
        push @args, ($start, $end);
    }

    my $diffs = $dbh->selectall_arrayref(
           "SELECT profiles.login_name, profiles.realname, fielddefs.description fielddesc,
                   bugs_activity.bug_when, bugs_activity.removed,
                   bugs_activity.added, bugs_activity.attach_id, fielddefs.name fieldname
              FROM bugs_activity
        INNER JOIN fielddefs
                ON fielddefs.id = bugs_activity.fieldid
        INNER JOIN profiles
                ON profiles.userid = bugs_activity.who
             WHERE bugs_activity.bug_id = ?
                   $when_restriction
          ORDER BY bugs_activity.bug_when", {Slice=>{}}, @args);

    my @new_depbugs;
    foreach my $diff (@$diffs) {
        $diff->{attach_id} and $diff->{fielddesc} =~ s/^(Attachment )?/Attachment #$diff->{attach_id} /;
        if ($diff->{fieldname} eq 'estimated_time' ||
            $diff->{fieldname} eq 'remaining_time') {
            $diff->{removed} = format_time_decimal($diff->{removed});
            $diff->{added} = format_time_decimal($diff->{added});
        }
        if ($diff->{fieldname} eq 'dependson') {
            push(@new_depbugs, grep {$_ =~ /^\d+$/} split(/[\s,]+/, $diff->{added}));
        }
        if ($diff->{attach_id}) {
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
    if ($start) {
        my $dep_restriction = "";
        if (scalar @new_depbugs) {
            $dep_restriction = "AND bugs_activity.bug_id NOT IN (" .
                               join(", ", @new_depbugs) . ")";
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
          ORDER BY bugs_activity.bug_when, bugs.bug_id", {Slice=>{}}, @args);

        my $thisdiff = "";
        my $lastbug = "";
        my $interestingchange = 0;
        my @diff_tmp = ();
        foreach my $dep_diff (@$dependency_diffs) {
            $dep_diff->{bug_id} = $id;
            $dep_diff->{type} = 'dep';
            if ($dep_diff->{dep} ne $lastbug) {
                if ($interestingchange) {
                    push @$diffs, @diff_tmp;
                }
                @diff_tmp = ();
                $lastbug = $dep_diff->{dep};
                $interestingchange = 0;
            }
            if ($dep_diff->{fieldname} eq 'bug_status'
                && is_open_state($dep_diff->{removed}) ne is_open_state($dep_diff->{added}))
            {
                $interestingchange = 1;
            }
            push @depbugs, $dep_diff->{dep};
            push @diff_tmp, $dep_diff;
        }

        if ($interestingchange) {
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
    my $voters = $dbh->selectcol_arrayref(
        "SELECT who FROM votes WHERE bug_id = ?", undef, ($id));

    $recipients{$_}->{+REL_VOTER} = BIT_DIRECT foreach (@$voters);

    # CCs
    $recipients{$_}->{+REL_CC} = BIT_DIRECT foreach (@ccs);

    # Reporter (there's only ever one)
    $recipients{$reporter}->{+REL_REPORTER} = BIT_DIRECT;

    # QA Contact
    if (Bugzilla->params->{'useqacontact'}) {
        foreach (@qa_contacts) {
            # QA Contact can be blank; ignore it if so.
            $recipients{$_}->{+REL_QA} = BIT_DIRECT if $_;
        }
    }

    # Assignee
    $recipients{$_}->{+REL_ASSIGNEE} = BIT_DIRECT foreach (@assignees);

    # The last relevant set of people are those who are being removed from
    # their roles in this change. We get their names out of the diffs.
    foreach my $diff (@$diffs) {
        if ($diff->{removed}) {
            # You can't stop being the reporter, and mail isn't sent if you
            # remove your vote.
            # Ignore people whose user account has been deleted or renamed.
            if ($diff->{fielddesc} eq "CC") {
                foreach my $cc_user (split(/[\s,]+/, $diff->{removed})) {
                    my $uid = login_to_id($cc_user);
                    $recipients{$uid}->{+REL_CC} = BIT_DIRECT if $uid;
                }
            }
            elsif ($diff->{fielddesc} eq "QAContact") {
                my $uid = login_to_id($diff->{removed});
                $recipients{$uid}->{+REL_QA} = BIT_DIRECT if $uid;
            }
            elsif ($diff->{fielddesc} eq "AssignedTo") {
                my $uid = login_to_id($diff->{removed});
                $recipients{$uid}->{+REL_ASSIGNEE} = BIT_DIRECT if $uid;
            }
        }
    }

    Bugzilla::Hook::process('bugmail_recipients',
                            { bug => $bug, recipients => \%recipients });

    # Find all those user-watching anyone on the current list, who is not
    # on it already themselves.
    my $involved = join(",", keys %recipients);

    my $userwatchers =
        $dbh->selectall_arrayref("SELECT watcher, watched FROM watch
                                  WHERE watched IN ($involved)");

    # Mark these people as having the role of the person they are watching
    foreach my $watch (@$userwatchers) {
        while (my ($role, $bits) = each %{$recipients{$watch->[1]}}) {
            $recipients{$watch->[0]}->{$role} |= BIT_WATCHING
                if $bits & BIT_DIRECT;
        }
        push(@{$watching{$watch->[0]}}, $watch->[1]);
    }

    # Global watcher
    my @watchers = split(/[,\s]+/, Bugzilla->params->{'globalwatchers'});
    foreach (@watchers) {
        my $watcher_id = login_to_id($_);
        next unless $watcher_id;
        $recipients{$watcher_id}->{+REL_GLOBAL_WATCHER} = BIT_DIRECT;
    }

    # We now have a complete set of all the users, and their relationships to
    # the bug in question. However, we are not necessarily going to mail them
    # all - there are preferences, permissions checks and all sorts to do yet.
    my @sent;
    my @excluded;

    foreach my $user_id (keys %recipients) {
        my %rels_which_want;
        my $sent_mail = 0;

        my $user = new Bugzilla::User($user_id);
        # Deleted users must be excluded.
        next unless $user;

        if ($user->can_see_bug($id)) {
            # Go through each role the user has and see if they want mail in
            # that role.
            foreach my $relationship (keys %{$recipients{$user_id}}) {
                if ($user->wants_bug_mail($id,
                                          $relationship,
                                          $diffs,
                                          $comments,
                                          $deptext,
                                          $changer,
                                          !$start))
                {
                    $rels_which_want{$relationship} =
                        $recipients{$user_id}->{$relationship};
                }
            }
        }

        if (scalar(%rels_which_want)) {
            # So the user exists, can see the bug, and wants mail in at least
            # one role. But do we want to send it to them?

            # We shouldn't send mail if this is a dependency mail (i.e. there
            # is something in @depbugs), and any of the depending bugs are not
            # visible to the user. This is to avoid leaking the summaries of
            # confidential bugs.
            my $dep_ok = 1;
            foreach my $dep_id (@depbugs) {
                if (!$user->can_see_bug($dep_id)) {
                   $dep_ok = 0;
                   last;
                }
            }

            # Make sure the user isn't in the nomail list, and the insider and
            # dep checks passed.
            if ($user->email_enabled && $dep_ok) {
                # OK, OK, if we must. Email the user.
                $sent_mail = sendMail(
                    user    => $user,
                    headers => \@headerlist,
                    rels    => \%rels_which_want,
                    values  => \%values,
                    defhead => \%defmailhead,
                    fields  => \%fielddescription,
                    diffs   => $diffs,
                    newcomm => $comments,
                    isnew   => !$start,
                    id      => $id,
                    watch   => exists $watching{$user_id} ? $watching{$user_id} : undef,
                );
            }
        }

        if ($sent_mail) {
            push(@sent, $user->login);
        }
        else {
            push(@excluded, $user->login);
        }
    }

    $dbh->do('UPDATE bugs SET lastdiffed = ? WHERE bug_id = ?',
             undef, ($end, $id));

    return {'sent' => \@sent, 'excluded' => \@excluded};
}

sub sendMail
{
    my %arguments = @_;
    my ($user, $hlRef, $relRef, $valueRef, $dmhRef, $fdRef,
        $diffs, $comments_in, $isnew,
        $id, $watchingRef
    ) = @arguments{qw(
        user headers rels values defhead fields
        diffs newcomm isnew
        id watch
    )};

    my @send_comments = @$comments_in;
    my %values = %$valueRef;
    my @headerlist = @$hlRef;
    my %mailhead = %$dmhRef;
    my %fielddescription = %$fdRef;

    # Filter changes by verifying the user should see them
    my $new_diffs = [];
    foreach my $diff (@$diffs)
    {
        if (exists($diff->{'fieldname'}) &&
            ($diff->{'fieldname'} ne 'estimated_time' &&
             $diff->{'fieldname'} ne 'remaining_time' &&
             $diff->{'fieldname'} ne 'work_time' &&
             $diff->{'fieldname'} ne 'deadline' ||
             $user->is_timetracker) &&
            (!$diff->{'isprivate'} || $user->is_insider))
        {
            push @$new_diffs, $diff;
        }
    }

    $diffs = $new_diffs;

    if (!$user->is_insider) {
        @send_comments = grep { !$_->is_private } @send_comments;
    }

    if (!@$diffs && !scalar(@send_comments) && !$isnew) {
        # Whoops, no differences!
        return 0;
    }

    my @showfieldvalues = (); # for HTML emails
    if ($isnew) {
        my $head = "";
        foreach my $f (@headerlist) {
            next unless $mailhead{$f};
            my $value = $values{$f};
            # If there isn't anything to show, don't include this header.
            next unless $value;
            # Only send time tracking information if it is enabled and the user is in the group.
            if (($f ne 'work_time' && $f ne 'estimated_time' && $f ne 'deadline') || $user->is_timetracker) {
                push @showfieldvalues, { desc => $fielddescription{$f}, value => $value };
            }
        }
    }

    my (@reasons, @reasons_watch);
    while (my ($relationship, $bits) = each %{$relRef}) {
        push(@reasons, $relationship) if ($bits & BIT_DIRECT);
        push(@reasons_watch, $relationship) if ($bits & BIT_WATCHING);
    }

    my @headerrel   = map { REL_NAMES->{$_} } @reasons;
    my @watchingrel = map { REL_NAMES->{$_} } @reasons_watch;
    push @headerrel,   'None' unless @headerrel;
    push @watchingrel, 'None' unless @watchingrel;
    push @watchingrel, map { user_id_to_login($_) } @$watchingRef;

    my $vars = {
        isnew              => $isnew,
        showfieldvalues    => \@showfieldvalues,
        to                 => $user->email,
        to_user            => $user,
        bugid              => $id,
        alias              => Bugzilla->params->{'usebugaliases'} ? $values{'alias'} : "",
        classification     => $values{'classification'},
        product            => $values{'product'},
        comp               => $values{'component'},
        keywords           => $values{'keywords'},
        severity           => $values{'bug_severity'},
        status             => $values{'bug_status'},
        priority           => $values{'priority'},
        assignedto         => $values{'assigned_to'},
        assignedtoname     => Bugzilla::User->new({name => $values{'assigned_to'}})->name,
        targetmilestone    => $values{'target_milestone'},
        summary            => $values{'short_desc'},
        reasons            => \@reasons,
        reasons_watch      => \@reasons_watch,
        reasonsheader      => join(" ", @headerrel),
        reasonswatchheader => join(" ", @watchingrel),
        changer            => $values{'changer'},
        changername        => $values{'changername'},
        reporter           => $values{'reporter'},
        reportername       => Bugzilla::User->new({name => $values{'reporter'}})->name,
        diffs              => $diffs,
        new_comments       => \@send_comments,
        threadingmarker    => build_thread_marker($id, $user->id, $isnew),
        three_columns      => \&three_columns,
    };

    # Hack into urlbase and set it to be correct for current user
    Bugzilla::CustisLocalBugzillas::HackIntoUrlbase($user->email);

    my $msg;
    my $tmpl = '';

    my $template = Bugzilla->template_inner($user->settings->{lang}->{value});
    Bugzilla::Hook::process('bugmail-pre_template', { tmpl => \$tmpl, vars => $vars });
    $tmpl = "email/newchangedmail.txt.tmpl" unless $template->template_exists($tmpl);
    $template->process($tmpl, $vars, \$msg) || ThrowTemplateError($template->error());
    Bugzilla->template_inner("");

    MessageToMTA($msg);

    # Unhack urlbase :-)
    Bugzilla::CustisLocalBugzillas::HackIntoUrlbase(undef);

    return 1;
}

1;
