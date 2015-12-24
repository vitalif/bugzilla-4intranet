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
# Contributor(s): Erik Stambaugh <erik@dasbistro.com>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Search;
use Bugzilla::User;
use Bugzilla::Mailer;
use Bugzilla::Util;
use Bugzilla::Group;

# %seen_schedules is a list of all of the schedules that have already been
# touched by reset_timer. If reset_timer sees a schedule more than once, it
# sets it to NULL so it won't come up again until the next execution of
# whine.pl
my %seen_schedules;

################################################################################
# Main Body Execution
################################################################################

my $dbh = Bugzilla->dbh;

# This script needs to check through the database for schedules that have
# run_next set to NULL, which means that schedule is new or has been altered.
# It then sets it to run immediately if the schedule entry has it running at
# an interval like every hour, otherwise to the appropriate day and time.

# After that, it looks over each user to see if they have schedules that need
# running, then runs those and generates the email messages.

# Send whines from the address in the 'mailfrom' Parameter so that all
# Bugzilla-originated mail appears to come from a single address.
my $fromaddress = Bugzilla->params->{mailfrom};

# get the current date and time
my ($now_sec, $now_minute, $now_hour, $now_day, $now_month, $now_year, $now_weekday) = localtime;
# Convert year to two digits
$now_year = sprintf("%02d", $now_year % 100);
# Convert the month to January being "1" instead of January being "0".
$now_month++;

my @daysinmonth = qw(0 31 28 31 30 31 30 31 31 30 31 30 31);
# Alter February in case of a leap year.  This simple way to do it only
# applies if you won't be looking at February of next year, which whining
# doesn't need to do.
if (($now_year % 4 == 0) && (($now_year % 100 != 0) || ($now_year % 400 == 0)))
{
    $daysinmonth[2] = 29;
}

# run_day can contain either a calendar day (1, 2, 3...), a day of the week
# (Mon, Tue, Wed...), a range of days (All, MF), or 'last' for the last day of
# the month.
#
# run_time can contain either an hour (0, 1, 2...) or an interval
# (60min, 30min, 15min).
#
# We go over each uninitialized schedule record and use its settings to
# determine what the next time it runs should be
for my $row (@{$dbh->selectall_arrayref(
    "SELECT id, run_day, run_time FROM whine_schedules WHERE run_next IS NULL"
) || []})
{
    my ($schedule_id, $day, $time) = @$row;

    # fill in some defaults in case they're blank
    $day  ||= '0';
    $time ||= '0';

    # If this schedule is supposed to run today, we see if it's supposed to be
    # run at a particular hour.  If so, we set it for that hour, and if not,
    # it runs at an interval over the course of a day, which means we should
    # set it to run immediately.
    if (check_today($day))
    {
        # Values that are not entirely numeric are intervals, like "30min"
        if ($time !~ /^\d+$/)
        {
            # set it to now
            $dbh->do("UPDATE whine_schedules SET run_next=NOW() WHERE id=?", undef, $schedule_id);
        }
        # A time greater than now means it still has to run today
        elsif ($time >= $now_hour)
        {
            # set it to today + number of hours
            $dbh->do(
                "UPDATE whine_schedules SET run_next = " .
                $dbh->sql_date_math('CURRENT_DATE', '+', '?', 'HOUR') . " WHERE id = ?", undef, $time, $schedule_id
            );
        }
        # the target time is less than the current time
        else
        {
            # set it for the next applicable day
            $day = get_next_date($day);
            my $run_next = $dbh->sql_date_math(
                '(' . $dbh->sql_date_math('CURRENT_DATE', '+', '?', 'DAY') . ')',
                '+', '?', 'HOUR'
            );
            $dbh->do(
                "UPDATE whine_schedules SET run_next = $run_next WHERE id = ?",
                undef, $day, $time, $schedule_id
            );
        }
    }
    # If the schedule is not supposed to run today, we set it to run on the
    # appropriate date and time
    else
    {
        my $target_date = get_next_date($day);
        # If configured for a particular time, set it to that, otherwise midnight
        my $target_time = ($time =~ /^\d+$/) ? $time : 0;
        my $run_next = $dbh->sql_date_math(
            '(' . $dbh->sql_date_math('CURRENT_DATE', '+', '?', 'DAY') . ')',
            '+', '?', 'HOUR'
        );
        $dbh->do("UPDATE whine_schedules SET run_next=$run_next WHERE id=?", undef, $target_date, $target_time, $schedule_id);
    }
}

# Run the queries for each event
#
# $event:
#   eventid (the database ID for this event)
#   author  (user object for who created the event)
#   mailto  (array of user objects for mail targets)
#   subject (subject line for message)
#   body    (text blurb at top of message)
#   mailifnobugs (send message even if there are no query or query results)
while (my $event = get_next_event())
{
    my $eventid = $event->{eventid};

    # We loop for each target user because some of the queries will be using
    # subjective pronouns
    $dbh = Bugzilla->switch_to_shadow_db();
    for my $target (@{$event->{mailto}})
    {
        my $args = {
            subject     => $event->{subject},
            body        => $event->{body},
            eventid     => $event->{eventid},
            author      => $event->{author},
            recipient   => $target,
            from        => $fromaddress,
        };

        # run the queries for this schedule
        my $queries = run_queries($args);

        # If mailifnobugs is false, make sure there is something to output
        if (!$event->{mailifnobugs})
        {
            my $there_are_bugs = 0;
            for my $query (@{$queries})
            {
                $there_are_bugs = 1 if scalar @{$query->{bugs}};
            }
            next unless $there_are_bugs;
        }

        $args->{queries} = $queries;

        mail($args);
    }
    $dbh = Bugzilla->switch_to_main_db();
}

################################################################################
# Functions
################################################################################

# get_next_event
#
# This function will:
#   1. Grab the most overdue pending schedules on the same event that must run
#   2. Update those schedules' run_next value
#   3. Return an event hashref
#
# The event hashref consists of:
#   eventid - ID of the event
#   author  - user object for the event's creator
#   users   - array of user objects for recipients
#   subject - Subject line for the email
#   body    - the text inserted above the bug lists
#   mailifnobugs - send message even if there are no query or query results
sub get_next_event
{
    my $event = {};
    my $dbh = Bugzilla->dbh;

    # Loop until there's something to return
    until (scalar keys %$event)
    {
        $dbh->bz_start_transaction();

        # Get the event ID for the first pending schedule
        my ($eventid, $owner_id, $subject, $body, $mailifnobugs) = Bugzilla->dbh->selectrow_array(
            "SELECT e.id, e.owner_userid, e.subject, e.body, e.mailifnobugs" .
            " FROM whine_schedules s LEFT JOIN whine_events e ON e.id = s.eventid" .
            " WHERE run_next <= NOW() ORDER BY run_next " . $dbh->sql_limit(1)
        );
        return undef unless $eventid;

        my $owner = Bugzilla::User->new($owner_id);

        my $whineatothers = $owner->in_group('bz_canusewhineatothers');

        my %user_objects;   # Used for keeping track of who has been added

        # Get all schedules that match that event ID and are pending
        my $rows = Bugzilla->dbh->selectall_arrayref(
            "SELECT id, mailto_type, mailto FROM whine_schedules " .
            "WHERE eventid=? AND run_next <= NOW()", undef, $eventid
        ) || [];

        # Add the users from those schedules to the list
        for my $row (@$rows)
        {
            my ($sid, $mailto_type, $mailto) = @$row;

            # Only bother doing any work if this user has whine permission
            if ($owner->in_group('bz_canusewhines'))
            {
                if ($mailto_type == MAILTO_USER)
                {
                    if (not defined $user_objects{$mailto})
                    {
                        if ($mailto == $owner_id)
                        {
                            $user_objects{$mailto} = $owner;
                        }
                        elsif ($whineatothers)
                        {
                            $user_objects{$mailto} = Bugzilla::User->new($mailto);
                        }
                    }
                }
                elsif ($mailto_type == MAILTO_GROUP)
                {
                    my $group = Bugzilla::Group->new($mailto);
                    if ($group)
                    {
                        for my $u (@{$group->users_in_group})
                        {
                            if ($u->{member_indirect} || $u->{member_direct} || $u->{member_regexp})
                            {
                                $user_objects{$u->{user}->id} ||= $u->{user};
                            }
                        }
                    }
                }
            }
            reset_timer($sid);
        }

        $dbh->bz_commit_transaction();

        # Only set $event if the user is allowed to do whining
        if ($owner->in_group('bz_canusewhines'))
        {
            my @users = values %user_objects;
            $event = {
                eventid => $eventid,
                author  => $owner,
                mailto  => \@users,
                subject => $subject,
                body    => $body,
                mailifnobugs => $mailifnobugs,
            };
        }
    }
    return $event;
}

# The mail and run_queries functions use an anonymous hash ($args) for their
# arguments, which are then passed to the templates.
#
# When run_queries is run, $args contains the following fields:
#  - body           Message body defined in event
#  - from           Bugzilla system email address
#  - queries        array of hashes containing:
#          - bugs:  array of hashes mapping fieldnames to values for this bug
#          - title: text title given to this query in the whine event
#  - schedule_id    integer id of the schedule being run
#  - subject        Subject line for the message
#  - recipient      user object for the recipient
#  - author         user object of the person who created the whine event
#
# In addition, mail adds two more fields to $args:
#  - alternatives   array of hashes defining mime multipart types and contents
#  - boundary       a MIME boundary generated using the process id and time
#
sub mail
{
    my ($args) = @_;
    my $addressee = $args->{recipient};
    # Don't send mail to someone whose bugmail notification is disabled.
    return if $addressee->email_disabled;

    my $template = Bugzilla->template_inner($addressee->settings->{lang}->{value});
    my $msg = ''; # it's a temporary variable to hold the template output
    $args->{alternatives} ||= [];

    # put together the different multipart mime segments

    $template->process("whine/mail.txt.tmpl", $args, \$msg)
        or die($template->error());
    push @{$args->{alternatives}}, {
        content => $msg,
        type    => 'text/plain',
    };
    $msg = '';

    $template->process("whine/mail.html.tmpl", $args, \$msg)
        or die($template->error());
    push @{$args->{alternatives}}, {
        content => $msg,
        type    => 'text/html',
    };
    $msg = '';

    # now produce a ready-to-mail mime-encoded message

    $args->{boundary} = "----------" . $$ . "--" . time() . "-----";

    $template->process("whine/multipart-mime.txt.tmpl", $args, \$msg)
        or die($template->error());

    Bugzilla->template_inner("");
    MessageToMTA($msg);

    delete $args->{boundary};
    delete $args->{alternatives};
}

# run_queries runs all of the queries associated with a schedule ID, adding
# the results to $args or mailing off the template if a query wants individual
# messages for each bug
sub run_queries
{
    my ($args) = @_;
    my $return_queries = [];
    my $dbh = Bugzilla->dbh;

    my $queries = $dbh->selectall_arrayref(
        "SELECT query_name, title, onemailperbug FROM whine_queries".
        " WHERE eventid=? ORDER BY sortkey", {Slice=>{}}
    );
    foreach my $thisquery (@$queries)
    {
        $thisquery->{bugs} = [];
        next unless $thisquery->{name}; # named query is blank

        my $savedquery = Bugzilla::Search::Saved->new({ name => $thisquery->{name}, user => $args->{author} });
        next unless $savedquery; # silently ignore missing queries

        # Execute the saved query
        my @searchfields = qw(
            bug_id
            bug_severity
            priority
            rep_platform
            assigned_to
            bug_status
            resolution
            short_desc
        );
        my $search = new Bugzilla::Search(
            fields => \@searchfields,
            params => http_decode_query($savedquery->query),
            user   => $args->{recipient}, # the search runs as the recipient
        );
        my $sqlquery = $search->getSQL();
        my $sth = $dbh->prepare($sqlquery);
        $sth->execute;

        while (my @row = $sth->fetchrow_array)
        {
            my $bug = {};
            for my $field (@searchfields)
            {
                my $fieldname = $field;
                $fieldname =~ s/^bugs\.//; # No need for bugs.whatever
                $bug->{$fieldname} = shift @row;
            }
            if ($thisquery->{onemailperbug})
            {
                $args->{queries} = [ {
                    name  => $thisquery->{name},
                    title => $thisquery->{title},
                    bugs  => [ $bug ],
                } ];
                mail($args);
                delete $args->{queries};
            }
            else
            {
                # It belongs in one message with any other lists
                push @{$thisquery->{bugs}}, $bug;
            }
        }
        if (!$thisquery->{onemailperbug} && @{$thisquery->{bugs}})
        {
            push @{$return_queries}, $thisquery;
        }
    }

    return $return_queries;
}

# check_today gets a run day from the schedule and sees if it matches today
# a run day value can contain any of:
#   - a three-letter day of the week
#   - a number for a day of the month
#   - 'last' for the last day of the month
#   - 'All' for every day
#   - 'MF' for every weekday
sub check_today
{
    my ($run_day) = @_;
    if ($run_day eq 'MF' && $now_weekday > 0 && $now_weekday < 6)
    {
        return 1;
    }
    elsif (length($run_day) == 3 && index("SunMonTueWedThuFriSat", $run_day)/3 == $now_weekday)
    {
        return 1;
    }
    elsif ($run_day eq 'All' || $run_day eq 'last' && $now_day == $daysinmonth[$now_month] || $run_day eq $now_day)
    {
        return 1;
    }
    return 0;
}

# reset_timer sets the next time a whine is supposed to run, assuming it just
# ran moments ago.  Its only parameter is a schedule ID.
#
# reset_timer does not lock the whine_schedules table.  Anything that calls it
# should do that itself.
sub reset_timer
{
    my ($schedule_id) = @_;
    my $dbh = Bugzilla->dbh;

    # Schedules may not be executed more than once for each invocation of
    # whine.pl -- there are legitimate circumstances that can cause this, like
    # a set of whines that take a very long time to execute, so it's done
    # quietly.
    if ($seen_schedules{$schedule_id})
    {
        null_schedule($schedule_id);
        return;
    }
    $seen_schedules{$schedule_id} = 1;

    my ($run_day, $run_time) = $dbh->selectrow_array(
        "SELECT run_day, run_time FROM whine_schedules WHERE id=?", undef, $schedule_id
    );
    # It may happen that the run_time field is NULL or blank due to
    # a bug in editwhines.cgi when this field was initially 0.
    $run_time ||= 0;

    my $run_today = 0;
    my $minute_offset = 0;

    # If the schedule is to run today, and it runs many times per day,
    # it shall be set to run immediately.
    $run_today = check_today($run_day);
    if ($run_today && $run_time !~ /^\d+$/)
    {
        # The default of 60 catches any bad value
        my $minute_interval = 60;
        if ($run_time =~ /^(\d+)min$/i)
        {
            $minute_interval = $1;
        }
        # set the minute offset to the next interval point
        $minute_offset = $minute_interval - ($now_minute % $minute_interval);
    }
    elsif ($run_today && $run_time > $now_hour)
    {
        # timed event for later today
        # (This should only happen if, for example, an 11pm scheduled event
        #  didn't happen until after midnight)
        $minute_offset = (60 * ($run_time - $now_hour)) - $now_minute;
    }
    else
    {
        # it's not something that runs later today.
        $minute_offset = 0;

        # Set the target time if it's a specific hour
        my $target_time = ($run_time =~ /^\d+$/) ? $run_time : 0;

        my $nextdate = get_next_date($run_day);
        my $run_next = $dbh->sql_date_math(
            '(' . $dbh->sql_date_math('CURRENT_DATE', '+', '?', 'DAY') . ')',
            '+', '?', 'HOUR'
        );
        $dbh->do(
            "UPDATE whine_schedules SET run_next=$run_next WHERE id=?",
            undef, $nextdate, $target_time, $schedule_id
        );
        return;
    }

    if ($minute_offset > 0)
    {
        # Scheduling is done in terms of whole minutes.
        my $next_run = $dbh->selectrow_array(
            'SELECT ' . $dbh->sql_date_math('NOW()', '+', '?', 'MINUTE'),
            undef, $minute_offset
        );
        $next_run = format_time($next_run, "%Y-%m-%d %R");
        Bugzilla->dbh->do("UPDATE whine_schedules SET run_next=? WHERE id=?", undef, $next_run, $schedule_id);
    }
    else
    {
        # The minute offset is zero or less, which is not supposed to happen.
        # complain to STDERR
        null_schedule($schedule_id);
        print STDERR "Error: bad minute_offset for schedule ID $schedule_id\n";
    }
}

# null_schedule is used to safeguard against infinite loops.  Schedules with
# run_next set to NULL will not be available to get_next_event until they are
# rescheduled, which only happens when whine.pl starts.
sub null_schedule
{
    my ($schedule_id) = @_;
    Bugzilla->dbh->do("UPDATE whine_schedules SET run_next = NULL WHERE id=?", undef, $schedule_id);
}

# get_next_date determines the difference in days between now and the next
# time a schedule should run, excluding today
#
# It takes a run_day argument (see check_today, above, for an explanation),
# and returns an integer, representing a number of days.
sub get_next_date
{
    my ($day) = @_;
    my $add_days = 0;
    if ($day eq 'All')
    {
        $add_days = 1;
    }
    elsif ($day eq 'last')
    {
        # next_date should contain the last day of this month, or next month if it's today
        if ($daysinmonth[$now_month] == $now_day)
        {
            my $month = $now_month + 1;
            $month = 1 if $month > 12;
            $add_days = $daysinmonth[$month] + 1;
        }
        else
        {
            $add_days = $daysinmonth[$now_month] - $now_day;
        }
    }
    elsif ($day eq 'MF')
    {
        # any day Monday through Friday
        if ($now_weekday < 5)
        {
            # Sun-Thurs
            $add_days = 1;
        }
        elsif ($now_weekday == 5)
        {
            # Friday
            $add_days = 3;
        }
        else
        {
            # it's 6, Saturday
            $add_days = 2;
        }
    }
    elsif ($day !~ /^\d+$/)
    {
        # A specific day of the week
        # The default is used if there is a bad value in the database, in
        # which case we mark it to a less-popular day (Sunday)
        my $day_num = 0;
        if (length($day) == 3)
        {
            $day_num = (index("SunMonTueWedThuFriSat", $day)/3) or 0;
        }
        $add_days = $day_num - $now_weekday;
        if ($add_days <= 0)
        {
            # it's next week
            $add_days += 7;
        }
    }
    else
    {
        # it's a number, so we set it for that calendar day
        $add_days = $day - $now_day;
        # If it's already beyond that day this month, set it to the next one
        if ($add_days <= 0)
        {
            $add_days += $daysinmonth[$now_month];
        }
    }
    return $add_days;
}
