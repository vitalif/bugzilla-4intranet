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
# Contributor(s): Christian Reis <kiko@async.com.br>
#                 Shane H. W. Travis <travis@sedsystems.ca>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

use lib qw(. lib);
use DateTime;
use Date::Parse;         # strptime

use Bugzilla;
use Bugzilla::Constants; # LOGIN_*
use Bugzilla::Bug;       # EmitDependList
use Bugzilla::Util;      # trim
use Bugzilla::Error;

# Bug 17977 (restrict to developer activity)
sub restrict_my_activity
{
    my (undef, $values) = @_;
    my $user = Bugzilla->user;
    if ($user)
    {
        $_[0] = " AND longdescs.who=? $_[0]";
        unshift @$values, $user->id;
        return 1;
    }
    return 0;
}

# Date handling
sub date_adjust
{
    my ($year, $month, $day, $by) = @_;
    my $d = DateTime->new(year => $year, month => $month, day => $day);
    $d->add(days => $by);
    return ($d->year, $d->month, $d->day);
}

sub split_by_month
{
    # Takes start and end dates and splits them into a list of
    # monthly-spaced 2-lists of dates.
    my ($start_date, $end_date) = @_;

    # We assume at this point that the dates are provided and sane
    my (undef, undef, undef, $sd, $sm, $sy, undef) = strptime($start_date);
    my (undef, undef, undef, $ed, $em, $ey, undef) = strptime($end_date);

    my @months;

    # These +1 and +1900 are a result of strptime's bizarre semantics
    $end_date = sprintf("%04d-%02d-%02d", $ey+1900, $em+1, $ed);
    my $d = DateTime->new(year => $sy+1900, month => $sm+1, day => $sd);
    my ($prev, $cur);
    $prev = sprintf("%04d-%02d-%02d", $d->year, $d->month, $d->day);
    while (1)
    {
        $d->add(months => 1);
        $cur = sprintf("%04d-%02d-%02d", $d->year, $d->month, $d->day);
        if ($cur gt $end_date)
        {
            push @months, [ $prev, $end_date ];
            last;
        }
        push @months, [ $prev, $cur ];
        $prev = $cur;
    }

    return @months;
}

sub sqlize_dates
{
    my ($start_date, $end_date) = @_;
    my $date_bits = "";
    my @date_values;
    if ($start_date)
    {
        # we've checked, trick_taint is fine
        trick_taint($start_date);
        $date_bits = " AND longdescs.bug_when > ?";
        push @date_values, $start_date;
    }
    if ($end_date)
    {
        # we need to add one day to end_date to catch stuff done today
        # do not forget to adjust date if it was the last day of month
        my (undef, undef, undef, $ed, $em, $ey, undef) = strptime($end_date);
        ($ey, $em, $ed) = date_adjust($ey+1900, $em+1, $ed+1, 1);
        $end_date = sprintf("%04d-%02d-%02d", $ey, $em, $ed);
        $date_bits .= " AND longdescs.bug_when < ?";
        push @date_values, $end_date;
    }
    return ($date_bits, \@date_values);
}

# Return all blockers of the current bug, recursively.
sub get_blocker_ids
{
    my ($bug_id, $unique) = @_;
    $unique ||= {$bug_id => 1};
    my $deps = Bugzilla::Bug::EmitDependList("blocked", "dependson", $bug_id);
    my @unseen = grep { !$unique->{$_}++ } @$deps;
    foreach $bug_id (@unseen)
    {
        get_blocker_ids($bug_id, $unique);
    }
    return keys %$unique;
}

# Return a hashref whose key is chosen by the user (bug ID or commenter)
# and value is a hash of the form {bug ID, commenter, time spent}.
# So you can either view it as the time spent by commenters on each bug
# or the time spent in bugs by each commenter.
sub get_list
{
    my ($bugids, $start_date, $end_date, $keyname, $my_activity) = @_;
    my $dbh = Bugzilla->dbh;

    my ($date_bits, $date_values) = sqlize_dates($start_date, $end_date);
    my $buglist = join(", ", @$bugids);

    restrict_my_activity($date_bits, $date_values) if $my_activity;
    # Returns the total time worked on each bug *per developer*.
    my %list;
    if ($buglist)
    {
        my $data = $dbh->selectall_arrayref(
            "SELECT SUM(work_time) AS total_time, login_name, longdescs.bug_id FROM longdescs".
            " INNER JOIN profiles ON longdescs.who = profiles.userid".
            " INNER JOIN bugs ON bugs.bug_id = longdescs.bug_id".
            " WHERE longdescs.bug_id IN ($buglist) $date_bits".
            " GROUP BY longdescs.bug_id, login_name" .
            " HAVING SUM(work_time) != 0", {Slice => {}}, @$date_values
        );
        # What this loop does is to push data having the same key in an array.
        push @{$list{$_->{$keyname}}}, $_ foreach @$data;
    }
    return \%list;
}

# Return bugs which had no activity (a.k.a work_time = 0) during the given time range.
sub get_inactive_bugs
{
    my ($bugids, $start_date, $end_date, $my_activity) = @_;
    my $dbh = Bugzilla->dbh;
    my ($date_bits, $date_values) = sqlize_dates($start_date, $end_date);
    restrict_my_activity($date_bits, $date_values) if $my_activity;
    return [] unless @$bugids;
    my $buglist = join(", ", @$bugids);
    my $bugs = $dbh->selectcol_arrayref(
        "SELECT bug_id FROM bugs".
        " WHERE bugs.bug_id IN ($buglist) AND NOT EXISTS".
        " (SELECT 1 FROM longdescs WHERE bugs.bug_id = longdescs.bug_id".
        " AND work_time != 0 $date_bits)", undef, @$date_values
    );
    return $bugs;
}

# Return 1st day of the month of the earliest activity date for a given list of bugs.
sub get_earliest_activity_date
{
    my ($bugids) = @_;
    my $dbh = Bugzilla->dbh;
    my ($date) = $dbh->selectrow_array(
        'SELECT ' . $dbh->sql_date_format('MIN(bug_when)', '%Y-%m-01') .
        ' FROM longdescs WHERE ' . $dbh->sql_in('bug_id', $bugids) . ' AND work_time != 0'
    );
    return $date;
}

#
# Template code starts here
#

Bugzilla->login(LOGIN_REQUIRED);

my $ARGS = Bugzilla->input_params;
my $user = Bugzilla->user;
my $template = Bugzilla->template;
my $vars = {};

Bugzilla->switch_to_shadow_db();

$user->is_timetracker || ThrowUserError("auth_failure", {
    group  => "time-tracking",
    action => "access",
    object => "timetracking_summaries",
});

my @ids = split(",", $ARGS->{id});
@ids = map { Bugzilla::Bug->check($_)->id } @ids;

my $group_by = $ARGS->{group_by} || "number";
my $monthly = $ARGS->{monthly};
my $detailed = $ARGS->{detailed};
my $do_report = $ARGS->{do_report};
my $inactive = $ARGS->{inactive};
my $do_depends = $ARGS->{do_depends};
my $ctype = $ARGS->{ctype};
my $my_activity = $ARGS->{my_activity};

$my_activity || scalar(@ids) || ThrowUserError('no_bugs_chosen', { action => 'view'});

my ($start_date, $end_date);
if ($do_report)
{
    my @bugs = @ids;

    # Validate dates
    $start_date = trim $ARGS->{start_date};
    $end_date = trim $ARGS->{end_date};

    # Swap dates in case the user put an end_date before the start_date
    if ($start_date && $end_date &&
        str2time($start_date) > str2time($end_date))
    {
        $vars->{warn_swap_dates} = 1;
        ($start_date, $end_date) = ($end_date, $start_date);
    }
    foreach my $date ($start_date, $end_date)
    {
        next unless $date;
        validate_date($date) || ThrowUserError('illegal_date', {
            date => $date,
            format => 'YYYY-MM-DD',
        });
    }

    # Ignore @ids, select touched during selected period bugs (Bug 17977)
    if ($my_activity)
    {
        my $user   = Bugzilla->user;
        my $userid = $user->id;
        my ($sql, @bind);
        $sql = "SELECT bug_id FROM longdescs WHERE who=?";
        @bind = ($userid);
        if ($start_date)
        {
            $sql .= " AND bug_when>=?";
            trick_taint($start_date);
            push @bind, $start_date;
        }
        if ($end_date)
        {
            my (undef, undef, undef, $ed, $em, $ey, undef) = strptime($end_date);
            ($ey, $em, $ed) = date_adjust($ey+1900, $em+1, $ed+1, 1);
            my $end_date2 = sprintf("%04d-%02d-%02d", $ey, $em, $ed);
            $sql .= " AND bug_when<?";
            trick_taint($end_date2);
            push @bind, $end_date2;
        }
        @bugs = @{ Bugzilla->dbh->selectcol_arrayref($sql, undef, @bind) || [] };
    }

    # Dependency mode requires a single bug and grabs dependents
    elsif ($do_depends)
    {
        if (scalar(@bugs) != 1)
        {
            ThrowCodeError("bad_arg", {
                argument => "id",
                function => "summarize_time",
            });
        }
        @bugs = get_blocker_ids($bugs[0]);
        @bugs = grep { $user->can_see_bug($_) } @bugs;
    }

    # Store dates in a session cookie so re-visiting the page
    # for other bugs keeps them around.
    Bugzilla->cgi->send_cookie(
        -name => 'time-summary-dates',
        -value => join ";", ($start_date, $end_date)
    );

    my (@parts, $part_data, @part_list);

    # Break dates apart into months if necessary; if not, we use the
    # same @parts list to allow us to use a common codepath.
    if ($monthly)
    {
        # Calculate the earliest activity date if the user doesn't
        # specify a start date.
        if (!$start_date)
        {
            $start_date = get_earliest_activity_date(\@bugs);
        }
        # Provide a default end date. Note that this differs in semantics
        # from the open-ended queries we use when start/end_date aren't
        # provided -- and clock skews will make this evident!
        @parts = split_by_month($start_date, $end_date || format_time(scalar localtime(time()), '%Y-%m-%d'));
    }
    else
    {
        @parts = ([ $start_date, $end_date ]);
    }

    # For each of the separate divisions, grab the relevant data.
    my $keyname = ($group_by eq 'owner') ? 'login_name' : 'bug_id';
    foreach my $part (@parts)
    {
        my ($sub_start, $sub_end) = @$part;
        $part_data = get_list(\@bugs, $sub_start, $sub_end, $keyname, $my_activity);
        push @part_list, $part_data;
    }

    # Do we want to see inactive bugs?
    if ($inactive)
    {
        $vars->{null} = get_inactive_bugs(\@bugs, $start_date, $end_date, $my_activity);
    }
    else
    {
        $vars->{null} = {};
    }

    # Convert bug IDs to bug objects.
    @bugs = map { new Bugzilla::Bug($_) } @bugs;

    $vars->{part_list} = \@part_list;
    $vars->{parts} = \@parts;
    # We pass the list of bugs as a hashref.
    $vars->{bugs} = {map { $_->id => $_ } @bugs};
}
elsif (Bugzilla->cookies->{'time-summary-dates'})
{
    ($start_date, $end_date) = split ";", Bugzilla->cookies->{'time-summary-dates'};
}

$vars->{ids} = \@ids;
$vars->{start_date} = $start_date;
$vars->{end_date} = $end_date;
$vars->{group_by} = $group_by;
$vars->{monthly} = $monthly;
$vars->{detailed} = $detailed;
$vars->{inactive} = $inactive;
$vars->{do_report} = $do_report;
$vars->{do_depends} = $do_depends;
$vars->{my_activity} = $my_activity;

my $format = $template->get_format("bug/summarize-time", undef, $ctype);

# Get the proper content-type
Bugzilla->cgi->send_header(-type => $format->{ctype});
$template->process($format->{template}, $vars)
    || ThrowTemplateError($template->error());
exit;
