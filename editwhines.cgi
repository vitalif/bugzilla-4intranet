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
#

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Group;
use Bugzilla::Token;
use Bugzilla::Whine::Schedule;
use Bugzilla::Whine::Query;

# require the user to have logged in
my $user = Bugzilla->login(LOGIN_REQUIRED);

my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};
my $dbh = Bugzilla->dbh;

my $userid = $user->id;
my $token = $ARGS->{token};

# $events is a hash ref, keyed by event id, that stores the active user's
# events.  It starts off with:
#  'subject' - the subject line for the email message
#  'body'    - the text to be sent at the top of the message
#
# Eventually, it winds up with:
#  'queries'  - array ref containing hashes of:
#       'name'          - the name of the saved query
#       'title'         - The title line for the search results table
#       'sort'          - Numeric sort ID
#       'id'            - row ID for the query entry
#       'onemailperbug' - whether a single message must be sent for each
#                         result.
#  'schedule' - array ref containing hashes of:
#       'day' - Day or range of days this schedule will be run
#       'time' - time or interval to run
#       'mailto_type' - MAILTO_USER or MAILTO_GROUP
#       'mailto' - person/group who will receive the results
#       'id' - row ID for the schedule
my $events = get_events($userid);

# First see if this user may use whines
$user->in_group('bz_canusewhines') || ThrowUserError("auth_failure", {
    group  => "bz_canusewhines",
    action => "schedule",
    object => "reports",
});

# May this user send mail to other users?
my $can_mail_others = Bugzilla->user->in_group('bz_canusewhineatothers');

# If the form was submitted, we need to look for what needs to be added or
# removed, then what was altered.
if ($ARGS->{update})
{
    check_token_data($token, 'edit_whine');

    if ($ARGS->{add_event})
    {
        # we create a new event
        $dbh->do("INSERT INTO whine_events (owner_userid) VALUES (?)", undef, $userid);
    }
    else
    {
        for my $eventid (keys %{$events})
        {
            # delete an entire event
            if ($ARGS->{"remove_event_$eventid"})
            {
                # We need to make sure these belong to the same user,
                # otherwise we could simply delete whatever matched that ID.
                $dbh->do("DELETE FROM whine_events WHERE id=? AND owner_userid=?", undef, $eventid, $userid);
            }
            else
            {
                # check the subject, body and mailifnobugs for changes
                my $subject = $ARGS->{"event_${eventid}_subject"} || '';
                my $body    = $ARGS->{"event_${eventid}_body"} || '';
                my $mailifnobugs = $ARGS->{"event_${eventid}_mailifnobugs"} ? 1 : 0;

                trick_taint($subject) if $subject;
                trick_taint($body)    if $body;

                if ($subject ne $events->{$eventid}->{subject} ||
                    $mailifnobugs != $events->{$eventid}->{mailifnobugs} ||
                    $body ne $events->{$eventid}->{body})
                {
                    $dbh->do(
                        "UPDATE whine_events SET subject=?, body=?, mailifnobugs=? WHERE id=?",
                        undef, $subject, $body, $mailifnobugs, $eventid
                    );
                }

                # add a schedule
                if ($ARGS->{"add_schedule_$eventid"})
                {
                    # the schedule table must be locked before altering
                    $dbh->do(
                        "INSERT INTO whine_schedules (eventid, mailto_type, mailto, " .
                        "run_day, run_time) VALUES (?, ?, ?, 'Sun', 2)",
                        undef, $eventid, MAILTO_USER, $userid
                    );
                }
                # add a query
                elsif ($ARGS->{"add_query_$eventid"})
                {
                    $dbh->do("INSERT INTO whine_queries (eventid) VALUES (?)", undef, $eventid);
                }
            }

            # now check all of the schedules and queries to see if they need
            # to be altered or deleted

            # Check schedules for changes
            my $schedules = Bugzilla::Whine::Schedule->match({ eventid => $eventid });
            my @scheduleids = ();
            foreach my $schedule (@$schedules)
            {
                push @scheduleids, $schedule->id;
            }

            # we need to double-check all of the user IDs in mailto to make
            # sure they exist
            my $arglist = {};   # args for match_field
            for my $sid (@scheduleids)
            {
                if ($ARGS->{"mailto_type_$sid"} == MAILTO_USER)
                {
                    $arglist->{"mailto_$sid"} = { type => 'single' };
                }
            }
            if (scalar %{$arglist})
            {
                Bugzilla::User::match_field($arglist);
            }

            for my $sid (@scheduleids)
            {
                if ($ARGS->{"remove_schedule_$sid"})
                {
                    # having the assignee id in here is a security failsafe
                    $dbh->do(
                        "DELETE FROM whine_schedules WHERE id=?".
                        " AND (SELECT owner_userid FROM whine_events WHERE whine_events.id=eventid)=?",
                        undef, $sid, $userid
                    );
                }
                else
                {
                    my $o_day         = $ARGS->{"orig_day_$sid"} || '';
                    my $day           = $ARGS->{"day_$sid"} || '';
                    my $o_time        = $ARGS->{"orig_time_$sid"} || 0;
                    my $time          = $ARGS->{"time_$sid"} || 0;
                    my $o_mailto      = $ARGS->{"orig_mailto_$sid"} || '';
                    my $mailto        = $ARGS->{"mailto_$sid"} || '';
                    my $o_mailto_type = $ARGS->{"orig_mailto_type_$sid"} || 0;
                    my $mailto_type   = $ARGS->{"mailto_type_$sid"} || 0;

                    my $mailto_id = $userid;

                    # get an id for the mailto address
                    if ($can_mail_others && $mailto)
                    {
                        if ($mailto_type == MAILTO_USER)
                        {
                            $mailto_id = Bugzilla::User::login_to_id($mailto);
                        }
                        elsif ($mailto_type == MAILTO_GROUP)
                        {
                            # The group name is used in a placeholder.
                            trick_taint($mailto);
                            $mailto_id = Bugzilla::Group::ValidateGroupName($mailto, ($user))
                                || ThrowUserError('invalid_group_name', { name => $mailto });
                        }
                        else
                        {
                            # bad value, so it will just mail to the whine
                            # owner.  $mailto_id was already set above.
                            $mailto_type = MAILTO_USER;
                        }
                    }

                    detaint_natural($mailto_type);

                    if ($o_day ne $day || $o_time ne $time ||
                        $o_mailto ne $mailto || $o_mailto_type != $mailto_type)
                    {
                        trick_taint($day);
                        trick_taint($time);

                        # the schedule table must be locked
                        $dbh->do(
                            "UPDATE whine_schedules SET run_day=?, run_time=?,".
                            " mailto_type=?, mailto=?, run_next=NULL WHERE id=?",
                            undef, $day, $time, $mailto_type, $mailto_id, $sid
                        );
                    }
                }
            }

            # Check queries for changes
            my $queries = Bugzilla::Whine::Query->match({ eventid => $eventid });
            for my $query (@$queries)
            {
                my $qid = $query->id;
                if ($ARGS->{"remove_query_$qid"})
                {
                    $dbh->do(
                        "DELETE FROM whine_queries WHERE id=?".
                        " AND (SELECT owner_userid FROM whine_events WHERE whine_events.id=eventid)=?",
                        undef, $qid, $userid
                    );
                }
                else
                {
                    my $o_sort      = $ARGS->{"orig_query_sort_$qid"} || 0;
                    my $sort        = $ARGS->{"query_sort_$qid"} || 0;
                    my $o_queryname = $ARGS->{"orig_query_name_$qid"} || '';
                    my $queryname   = $ARGS->{"query_name_$qid"} || '';
                    my $o_title     = $ARGS->{"orig_query_title_$qid"} || '';
                    my $title       = $ARGS->{"query_title_$qid"} || '';
                    my $o_onemailperbug = $ARGS->{"orig_query_onemailperbug_$qid"} || 0;
                    my $onemailperbug   = $ARGS->{"query_onemailperbug_$qid"} ? 1 : 0;
                    my $isreport    = 0;

                    if ($o_sort != $sort || $o_queryname ne $queryname ||
                        $o_onemailperbug != $onemailperbug || $o_title ne $title)
                    {
                        detaint_natural($sort);
                        trick_taint($queryname);
                        trick_taint($title);
                        if ($queryname =~ /^([01])-(.*)$/s)
                        {
                            ($isreport, $queryname) = ($1, $2);
                        }
                        $dbh->do(
                            "UPDATE whine_queries SET sortkey=?, query_name=?, title=?, onemailperbug=?, isreport=? WHERE id=?",
                            undef, $sort, $queryname, $title, $onemailperbug, $isreport, $qid
                        );
                    }
                }
            }
        }
    }
    delete_token($token);
}

$vars->{mail_others} = $can_mail_others;

# Get events again, to cover any updates that were made
$events = get_events($userid);

# Here is the data layout as sent to the template:
#
#   events
#       event_id #
#           schedule
#               day
#               time
#               mailto
#           queries
#               name
#               title
#               sort
#
# build the whine list by event id
for my $event_id (keys %{$events})
{
    $events->{$event_id}->{schedule} = [];
    $events->{$event_id}->{queries} = [];

    # schedules
    my $schedules = Bugzilla::Whine::Schedule->match({ eventid => $event_id });
    foreach my $schedule (@$schedules)
    {
        my $mailto_type = $schedule->mailto_is_group ? MAILTO_GROUP : MAILTO_USER;
        my $mailto = '';
        if ($mailto_type == MAILTO_USER)
        {
            $mailto = $schedule->mailto && $schedule->mailto->login;
        }
        elsif ($mailto_type == MAILTO_GROUP)
        {
            $mailto = $schedule->mailto && $schedule->mailto->name;
        }
        push @{$events->{$event_id}->{schedule}}, {
            day         => $schedule->run_day,
            time        => $schedule->run_time,
            mailto_type => $mailto_type,
            mailto      => $mailto,
            id          => $schedule->id,
        };
    }

    # queries
    my $queries = Bugzilla::Whine::Query->match({ eventid => $event_id });
    for my $query (@$queries)
    {
        push @{$events->{$event_id}->{queries}}, {
            name          => $query->name,
            title         => $query->title,
            sort          => $query->sortkey,
            id            => $query->id,
            onemailperbug => $query->one_email_per_bug,
            isreport      => $query->isreport,
        };
    }
}

$vars->{events} = $events;

# get the available queries
$vars->{available_queries} = $dbh->selectcol_arrayref("SELECT name FROM namedqueries WHERE userid=? ORDER BY name", undef, $userid) || [];
$vars->{available_reports} = $dbh->selectcol_arrayref("SELECT name FROM reports WHERE user_id=? ORDER BY name", undef, $userid) || [];
$vars->{token} = issue_session_token('edit_whine');
$vars->{local_timezone} = Bugzilla->local_timezone->short_name_for_datetime(DateTime->now());

$template->process("whine/schedule.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;

# get_events takes a userid and returns a hash, keyed by event ID, containing
# the subject and body of each event that user owns
sub get_events
{
    my $userid = shift;
    return Bugzilla->dbh->selectall_hashref(
        "SELECT DISTINCT id, subject, body, mailifnobugs FROM whine_events WHERE owner_userid=?",
        'id', undef, $userid
    );
}
