#!/usr/bin/perl -wT
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
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Stephan Niemz  <st.n@gmx.net>
#                 Andreas Franke <afranke@mathweb.org>
#                 Myk Melez <myk@mozilla.org>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

################################################################################
# Script Initialization
################################################################################

# Make it harder for us to do dangerous things in Perl.
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Hook;
use Bugzilla::Search;
use Bugzilla::Search::Quicksearch;
use Bugzilla::Search::Saved;
use Bugzilla::User;
use Bugzilla::Bug;
use Bugzilla::Product;
use Bugzilla::Keyword;
use Bugzilla::Field;
use Bugzilla::Status;
use Bugzilla::Token;

use Time::HiRes qw(gettimeofday);
use Date::Parse;
use POSIX;

# FIXME TRASHCODE!!! MUST BE REFACTORED!!!
# For example: buglist.cgi?dotweak=1&format=superworktime => $vars->{token} will be incorrect

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $buffer = $cgi->query_string;
my $query_format = $cgi->param('query_format') || 'advanced';

# We have to check the login here to get the correct footer if an error is
# thrown and to prevent a logged out user to use QuickSearch if 'requirelogin'
# is turned 'on'.
Bugzilla->login();

# CustIS Bug 68921 - "Супер-TodayWorktime", или массовая фиксация трудозатрат
# по нескольким багам, за нескольких сотрудников, за различные периоды.
# Для фиксации времени задним числом / другим юзером требует группу worktimeadmin.

# FIXME сейчас оно встроено сюда, ибо большАя часть логики, отвечающей за
#   создание и выполнение запроса поиска, находится не в Bugzilla::Search, а именно здесь :-(
#   кусочки логики находятся здесь по слову superworktime.
my $superworktime;
if (($cgi->param('format')||'') eq 'superworktime')
{
    require BugWorkTime;
    $superworktime = 1;
    Bugzilla->login(LOGIN_REQUIRED);
    BugWorkTime::HandleSuperWorktime($vars);
}

# If a parameter starts with cmd-, this means the And or Or button has been
# pressed in the advanced search page with JS turned off.
if (grep { $_ =~ /^cmd\-/ } $cgi->param()) {
    my $url = "query.cgi?$buffer#chart";
    print $cgi->redirect(-location => $url);
    # Generate and return the UI (HTML page) from the appropriate template.
    $vars->{'message'} = "buglist_adding_field";
    $vars->{'url'} = $url;
    $template->process("global/message.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
    exit;
}

# If query was POSTed, clean the URL from empty parameters and redirect back to
# itself. This will make advanced search URLs more tolerable.
#
if ($cgi->request_method() eq 'POST') {
    $cgi->clean_search_url();
    my $uri_length = length($cgi->self_url());
    if ($uri_length < CGI_URI_LIMIT) {
        print $cgi->redirect(-url => $cgi->self_url());
        exit;
    }
}

if ($superworktime)
{
    $cgi->delete('format', 'ctype');
}

# Determine whether this is a quicksearch query.
my $searchstring = $cgi->param('quicksearch');
if (defined($searchstring)) {
    $vars->{quicksearch} = $searchstring;
    $buffer = quicksearch($searchstring);
    # Quicksearch may do a redirect, in which case it does not return.
    # If it does return, it has modified $cgi->params so we can use them here
    # as if this had been a normal query from the beginning.
}

# If configured to not allow empty words, reject empty searches from the
# Find a Specific Bug search form, including words being a single or
# several consecutive whitespaces only.
if (!Bugzilla->params->{specific_search_allow_empty_words}
    && $query_format eq 'specific'
    && ($cgi->param('content')||'') =~ /^\s*$/)
{
    ThrowUserError("buglist_parameters_required");
}

################################################################################
# Data and Security Validation
################################################################################

# Whether or not the user wants to change multiple bugs.
my $dotweak = $cgi->param('tweak') ? 1 : 0;

# Log the user in
if ($dotweak)
{
    Bugzilla->login(LOGIN_REQUIRED);
}

# Hack to support legacy applications that think the RDF ctype is at format=rdf.
if (defined $cgi->param('format') && $cgi->param('format') eq "rdf"
    && !defined $cgi->param('ctype')) {
    $cgi->param('ctype', "rdf");
    $cgi->delete('format');
}

# Treat requests for ctype=rss as requests for ctype=atom
if (defined $cgi->param('ctype') && $cgi->param('ctype') eq "rss") {
    $cgi->param('ctype', "atom");
}

# The js ctype presents a security risk; a malicious site could use it
# to gather information about secure bugs. So, we only allow public bugs to be
# retrieved with this format.
#
# Note that if and when this call clears cookies or has other persistent
# effects, we'll need to do this another way instead.
if ((defined $cgi->param('ctype')) && ($cgi->param('ctype') eq "js")) {
    Bugzilla->logout_request();
}

# An agent is a program that automatically downloads and extracts data
# on its user's behalf.  If this request comes from an agent, we turn off
# various aspects of bug list functionality so agent requests succeed
# and coexist nicely with regular user requests.  Currently the only agent
# we know about is Firefox's microsummary feature.
my $agent = ($cgi->http('X-Moz') && $cgi->http('X-Moz') =~ /\bmicrosummary\b/);

# Determine the format in which the user would like to receive the output.
# Uses the default format if the user did not specify an output format;
# otherwise validates the user's choice against the list of available formats.
my $format = $superworktime ? "worktime/supertime" : "list/list";
$format = $template->get_format($format, scalar $cgi->param('format'), scalar $cgi->param('ctype'));

# Use server push to display a "Please wait..." message for the user while
# executing their query if their browser supports it and they are viewing
# the bug list as HTML and they have not disabled it by adding &serverpush=0
# to the URL.
#
# Server push is a Netscape 3+ hack incompatible with MSIE, Lynx, and others.
# Even Communicator 4.51 has bugs with it, especially during page reload.
# http://www.browsercaps.org used as source of compatible browsers.
# Safari (WebKit) does not support it, despite a UA that says otherwise (bug 188712)
# MSIE 5+ supports it on Mac (but not on Windows) (bug 190370)
#
my $serverpush =
  $format->{'extension'} eq "html"
    && exists $ENV{'HTTP_USER_AGENT'}
      && $ENV{'HTTP_USER_AGENT'} =~ /Mozilla.[3-9]/
        && (($ENV{'HTTP_USER_AGENT'} !~ /[Cc]ompatible/) || ($ENV{'HTTP_USER_AGENT'} =~ /MSIE 5.*Mac_PowerPC/))
          && $ENV{'HTTP_USER_AGENT'} !~ /WebKit/
            && !$agent
              && !defined($cgi->param('serverpush'))
                || $cgi->param('serverpush');

my $order = $cgi->param('order') || "";

# The params object to use for the actual query itself
my $params;

# If the user is retrieving the last bug list they looked at, hack the buffer
# storing the query string so that it looks like a query retrieving those bugs.
if (defined $cgi->param('regetlastlist')) {
    $cgi->cookie('BUGLIST') || ThrowUserError("missing_cookie");

    $order = "reuse last sort" unless $order;
    my $bug_id = $cgi->cookie('BUGLIST');
    $bug_id =~ s/:/,/g;
    # set up the params for this new query
    $params = new Bugzilla::CGI({
                                 bug_id => $bug_id,
                                 bug_id_type => 'anyexact',
                                 order => $order,
                                 columnlist => scalar($cgi->param('columnlist')),
                                });
}

# Figure out whether or not the user is doing a fulltext search.  If not,
# we'll remove the relevance column from the lists of columns to display
# and order by, since relevance only exists when doing a fulltext search.
my $fulltext = 0;
if ($cgi->param('content')) { $fulltext = 1 }
my @charts = map(/^field(\d-\d-\d)$/ ? $1 : (), $cgi->param());
foreach my $chart (@charts) {
    if ($cgi->param("field$chart") eq 'content' && $cgi->param("value$chart")) {
        $fulltext = 1;
        last;
    }
}

################################################################################
# Utilities
################################################################################

sub DiffDate {
    my ($datestr) = @_;
    my $date = str2time($datestr);
    my $age = time() - $date;

    if( $age < 18*60*60 ) {
        $date = format_time($datestr, '%H:%M:%S');
    } elsif( $age < 6*24*60*60 ) {
        $date = format_time($datestr, '%a %H:%M');
    } else {
        $date = format_time($datestr, '%Y-%m-%d');
    }
    return $date;
}

# Inserts a Named Query (a "Saved Search") into the database, or
# updates a Named Query that already exists..
# Takes four arguments:
# userid - The userid who the Named Query will belong to.
# query_name - A string that names the new Named Query, or the name
#              of an old Named Query to update. If this is blank, we
#              will throw a UserError. Leading and trailing whitespace
#              will be stripped from this value before it is inserted
#              into the DB.
# query - The query part of the buglist.cgi URL, unencoded. Must not be
#         empty, or we will throw a UserError.
# link_in_footer (optional) - 1 if the Named Query should be
# displayed in the user's footer, 0 otherwise.
# query_type (optional) - 1 if the Named Query contains a list of
# bug IDs only, 0 otherwise (default).
#
# All parameters are validated before passing them into the database.
#
# Returns: A boolean true value if the query existed in the database
# before, and we updated it. A boolean false value otherwise.
sub InsertNamedQuery {
    my ($query_name, $query, $link_in_footer, $query_type) = @_;
    my $dbh = Bugzilla->dbh;

    $query_name = trim($query_name);
    my ($query_obj) = grep {lc($_->name) eq lc($query_name)} @{Bugzilla->user->queries};

    if ($query_obj) {
        $query_obj->set_name($query_name);
        $query_obj->set_url($query);
        $query_obj->set_query_type($query_type);
        $query_obj->update();
    } else {
        Bugzilla::Search::Saved->create({
            name           => $query_name,
            query          => $query,
            query_type     => $query_type,
            link_in_footer => $link_in_footer
        });
    }

    return $query_obj ? 1 : 0;
}

sub LookupSeries {
    my ($series_id) = @_;
    detaint_natural($series_id) || ThrowCodeError("invalid_series_id");

    my $dbh = Bugzilla->dbh;
    my $result = $dbh->selectrow_array("SELECT query FROM series " .
                                       "WHERE series_id = ?"
                                       , undef, ($series_id));
    $result
           || ThrowCodeError("invalid_series_id", {'series_id' => $series_id});
    return $result;
}

sub GetQuip {
    my $dbh = Bugzilla->dbh;
    # COUNT is quick because it is cached for MySQL. We may want to revisit
    # this when we support other databases.
    my $count = $dbh->selectrow_array("SELECT COUNT(quip)"
                                    . " FROM quips WHERE approved = 1");
    my $random = int(rand($count));
    my $quip =
        $dbh->selectrow_array("SELECT quip FROM quips WHERE approved = 1 " .
                              $dbh->sql_limit(1, $random));
    return $quip;
}

# Return groups available for at least one product of the buglist.
sub GetGroups {
    my $product_names = shift;
    my $user = Bugzilla->user;
    my %legal_groups;

    foreach my $product_name (@$product_names) {
        my $product = new Bugzilla::Product({name => $product_name});

        foreach my $gid (keys %{$product->group_controls}) {
            # The user can only edit groups he belongs to.
            next unless $user->in_group_id($gid);

            # The user has no control on groups marked as NA or MANDATORY.
            my $group = $product->group_controls->{$gid};
            next if ($group->{membercontrol} == CONTROLMAPMANDATORY
                     || $group->{membercontrol} == CONTROLMAPNA);

            # It's fine to include inactive groups. Those will be marked
            # as "remove only" when editing several bugs at once.
            $legal_groups{$gid} ||= $group->{group};
        }
    }
    # Return a list of group objects.
    return [values %legal_groups];
}

sub _close_standby_message {
    my ($contenttype, $disposition, $serverpush) = @_;
    my $cgi = Bugzilla->cgi;

    # Close the "please wait" page, then open the buglist page
    if ($serverpush) {
        $cgi->send_multipart_end();
        $cgi->send_multipart_start(-type                => $contenttype,
                                   -content_disposition => $disposition);
    }
    else {
        $cgi->send_header(-type                => $contenttype,
                          -content_disposition => $disposition);
    }
}


################################################################################
# Command Execution
################################################################################

my $cmdtype   = $cgi->param('cmdtype')   || '';
my $remaction = $cgi->param('remaction') || '';

# Backwards-compatibility - the old interface had cmdtype="runnamed" to run
# a named command, and we can't break this because it's in bookmarks.
if ($cmdtype eq "runnamed") {
    $cmdtype = "dorem";
    $remaction = "run";
}

# Now we're going to be running, so ensure that the params object is set up,
# using ||= so that we only do so if someone hasn't overridden this
# earlier, for example by setting up a named query search.

# This will be modified, so make a copy.
$params ||= new Bugzilla::CGI($cgi);

# Generate a reasonable filename for the user agent to suggest to the user
# when the user saves the bug list.  Uses the name of the remembered query
# if available.  We have to do this now, even though we return HTTP headers
# at the end, because the fact that there is a remembered query gets
# forgotten in the process of retrieving it.
my @time = localtime(time());
my $date = sprintf "%04d-%02d-%02d", 1900+$time[5],$time[4]+1,$time[3];
my $filename = "bugs-$date.$format->{extension}";
if ($cmdtype eq "dorem" && $remaction =~ /^run/) {
    $filename = $cgi->param('namedcmd') . "-$date.$format->{extension}";
    # Remove white-space from the filename so the user cannot tamper
    # with the HTTP headers.
    $filename =~ s/\s/_/g;
}
$filename =~ s/\\/\\\\/g; # escape backslashes
$filename =~ s/"/\\"/g; # escape quotes

# Take appropriate action based on user's request.
if ($cmdtype eq "dorem") {
    if ($remaction eq "run") {
        my $query_id;
        ($buffer, $query_id) = Bugzilla::Search::LookupNamedQuery(
            scalar $cgi->param("namedcmd"), scalar $cgi->param('sharer_id')
        );
        # If this is the user's own query, remember information about it
        # so that it can be modified easily.
        $vars->{'searchname'} = $cgi->param('namedcmd');
        if (!$cgi->param('sharer_id') ||
            $cgi->param('sharer_id') == Bugzilla->user->id) {
            $vars->{'searchtype'} = "saved";
            $vars->{'search_id'} = $query_id;
        }
        if ($buffer =~ m!^[a-z][a-z0-9]*://!so)
        {
            # CustIS Bug 53697: Custom links in saved searches and footer/header
            print $cgi->redirect(-location => $buffer);
            exit;
        }
        $params = new Bugzilla::CGI($buffer);
        $order = $params->param('order') || $order;

    }
    elsif ($remaction eq "runseries") {
        $buffer = LookupSeries(scalar $cgi->param("series_id"));
        $vars->{'searchname'} = $cgi->param('namedcmd');
        $vars->{'searchtype'} = "series";
        $params = new Bugzilla::CGI($buffer);
        $order = $params->param('order') || $order;
    }
    elsif ($remaction eq "forget") {
        my $user = Bugzilla->login(LOGIN_REQUIRED);
        # Copy the name into a variable, so that we can trick_taint it for
        # the DB. We know it's safe, because we're using placeholders in
        # the SQL, and the SQL is only a DELETE.
        my $qname = $cgi->param('namedcmd');
        trick_taint($qname);

        # Do not forget the saved search if it is being used in a whine
        my $whines_in_use =
            $dbh->selectcol_arrayref('SELECT DISTINCT whine_events.subject
                                                 FROM whine_events
                                           INNER JOIN whine_queries
                                                   ON whine_queries.eventid
                                                      = whine_events.id
                                                WHERE whine_events.owner_userid
                                                      = ?
                                                  AND whine_queries.query_name
                                                      = ?
                                      ', undef, $user->id, $qname);
        if (scalar(@$whines_in_use)) {
            ThrowUserError('saved_search_used_by_whines',
                           { subjects    => join(',', @$whines_in_use),
                             search_name => $qname                      }
            );
        }

        # If we are here, then we can safely remove the saved search
        my ($query_id) = $dbh->selectrow_array('SELECT id FROM namedqueries
                                                    WHERE userid = ?
                                                      AND name   = ?',
                                                  undef, ($user->id, $qname));
        if (!$query_id) {
            # The user has no query of this name. Play along.
        }
        else {
            # Make sure the user really wants to delete his saved search.
            my $token = $cgi->param('token');
            check_hash_token($token, [$query_id, $qname]);

            $dbh->do('DELETE FROM namedqueries
                            WHERE id = ?',
                     undef, $query_id);
            $dbh->do('DELETE FROM namedqueries_link_in_footer
                            WHERE namedquery_id = ?',
                     undef, $query_id);
            $dbh->do('DELETE FROM namedquery_group_map
                            WHERE namedquery_id = ?',
                     undef, $query_id);
        }

        # Now reset the cached queries
        $user->flush_queries_cache();

        # Generate and return the UI (HTML page) from the appropriate template.
        $vars->{'message'} = "buglist_query_gone";
        $vars->{'namedcmd'} = $qname;
        $vars->{'url'} = "query.cgi";
        $template->process("global/message.html.tmpl", $vars)
          || ThrowTemplateError($template->error());
        exit;
    }
}
elsif (($cmdtype eq "doit") && defined $cgi->param('remtype')) {
    if ($cgi->param('remtype') eq "asdefault") {
        my $user = Bugzilla->login(LOGIN_REQUIRED);
        InsertNamedQuery(DEFAULT_QUERY_NAME, $buffer);
        $vars->{'message'} = "buglist_new_default_query";
    }
    elsif ($cgi->param('remtype') eq "asnamed") {
        my $user = Bugzilla->login(LOGIN_REQUIRED);
        my $query_name = $cgi->param('newqueryname');
        my $new_query = $cgi->param('newquery');
        my $query_type = QUERY_LIST;
        # If list_of_bugs is true, we are adding/removing individual bugs
        # to a saved search. We get the existing list of bug IDs (if any)
        # and add/remove the passed ones.
        if ($cgi->param('list_of_bugs')) {
            # We add or remove bugs based on the action choosen.
            my $action = trim($cgi->param('action') || '');
            $action =~ /^(add|remove)$/
              || ThrowCodeError('unknown_action', {'action' => $action});

            # If we are removing bugs, then we must have an existing
            # saved search selected.
            if ($action eq 'remove') {
                $query_name && ThrowUserError('no_bugs_to_remove');
            }

            my %bug_ids;
            my $is_new_name = 0;
            if ($query_name) {
                # Make sure this name is not already in use by a normal saved search.
                my ($query, $query_id) =
                    Bugzilla::Search::LookupNamedQuery($query_name, undef, QUERY_LIST, !THROW_ERROR);
                if ($query)
                {
                    ThrowUserError('query_name_exists', { name     => $query_name,
                                                          query_id => $query_id });
                }
                $is_new_name = 1;
            }
            # If no new tag name has been given, use the selected one.
            $query_name ||= $cgi->param('oldqueryname');

            # Don't throw an error if it's a new tag name: if the tag already
            # exists, add/remove bugs to it, else create it. But if we are
            # considering an existing tag, then it has to exist and we throw
            # an error if it doesn't (hence the usage of !$is_new_name).
            my ($old_query, $query_id) =
                Bugzilla::Search::LookupNamedQuery($query_name, undef, LIST_OF_BUGS, !$is_new_name);

            if ($old_query)
            {
                # We get the encoded query. We need to decode it.
                my $old_cgi = new Bugzilla::CGI($old_query);
                foreach my $bug_id (split /[\s,]+/, scalar $old_cgi->param('bug_id'))
                {
                    $bug_ids{$bug_id} = 1 if detaint_natural($bug_id);
                }
            }

            my $keep_bug = ($action eq 'add') ? 1 : 0;
            my $changes = 0;
            foreach my $bug_id (split(/[\s,]+/, $cgi->param('bug_ids'))) {
                next unless $bug_id;
                my $bug = Bugzilla::Bug->check($bug_id);
                $bug_ids{$bug->id} = $keep_bug;
                $changes = 1;
            }
            ThrowUserError('no_bug_ids',
                           {'action' => $action,
                            'tag' => $query_name})
              unless $changes;

            # Only keep bug IDs we want to add/keep. Disregard deleted ones.
            my @bug_ids = grep { $bug_ids{$_} == 1 } keys %bug_ids;
            # If the list is now empty, we could as well delete it completely.
            if (!scalar @bug_ids) {
                ThrowUserError('no_bugs_in_list', {name     => $query_name,
                                                   query_id => $query_id});
            }
            $new_query = "bug_id_type=anyexact&bug_id=" . join(',', sort {$a <=> $b} @bug_ids);
            $query_type = LIST_OF_BUGS;
        }
        my $tofooter = 1;
        my $existed_before = InsertNamedQuery($query_name, $new_query,
                                              $tofooter, $query_type);
        if ($existed_before) {
            $vars->{'message'} = "buglist_updated_named_query";
        }
        else {
            $vars->{'message'} = "buglist_new_named_query";
        }

        # Make sure to invalidate any cached query data, so that the footer is
        # correctly displayed
        $user->flush_queries_cache();

        $vars->{'queryname'} = $query_name;

        $template->process("global/message.html.tmpl", $vars)
          || ThrowTemplateError($template->error());
        exit;
    }
}

################################################################################
# Column Definition
################################################################################

my $columns = Bugzilla::Search::COLUMNS;

################################################################################
# Display Column Determination
################################################################################

# Determine the columns that will be displayed in the bug list via the
# columnlist CGI parameter, the user's preferences, or the default.
my @displaycolumns = ();
if (defined $params->param('columnlist')) {
    if ($params->param('columnlist') eq "all") {
        # If the value of the CGI parameter is "all", display all columns,
        # but remove the redundant "short_desc" column.
        @displaycolumns = grep($_ ne 'short_desc', keys(%$columns));
    }
    else {
        @displaycolumns = split(/[ ,]+/, $params->param('columnlist'));
    }
}
elsif (defined $cgi->cookie('COLUMNLIST')) {
    # 2002-10-31 Rename column names (see bug 176461)
    my $columnlist = $cgi->cookie('COLUMNLIST');
    $columnlist =~ s/\bowner\b/assigned_to/;
    $columnlist =~ s/\bowner_realname\b/assigned_to_realname/;
    $columnlist =~ s/\bplatform\b/rep_platform/;
    $columnlist =~ s/\bseverity\b/bug_severity/;
    $columnlist =~ s/\bstatus\b/bug_status/;
    $columnlist =~ s/\bsummaryfull\b/short_desc/;
    $columnlist =~ s/\bsummary\b/short_short_desc/;

    # Use the columns listed in the user's preferences.
    @displaycolumns = split(/ /, $columnlist);
}
else {
    # Use the default list of columns.
    @displaycolumns = DEFAULT_COLUMN_LIST;
}

$_ = Bugzilla::Search->COLUMN_ALIASES->{$_} || $_ for @displaycolumns;

# Weed out columns that don't actually exist to prevent the user
# from hacking their column list cookie to grab data to which they
# should not have access.  Detaint the data along the way.
@displaycolumns = grep($columns->{$_} && trick_taint($_), @displaycolumns);

# Remove the "ID" column from the list because bug IDs are always displayed
# and are hard-coded into the display templates.
@displaycolumns = grep($_ ne 'bug_id', @displaycolumns);

# Add the votes column to the list of columns to be displayed
# in the bug list if the user is searching for bugs with a certain
# number of votes and the votes column is not already on the list.

# Some versions of perl will taint 'votes' if this is done as a single
# statement, because the votes param is tainted at this point
my $votes = $params->param('votes');
$votes ||= "";
if (trim($votes) && !grep($_ eq 'votes', @displaycolumns)) {
    push(@displaycolumns, 'votes');
}

if ($superworktime && !grep($_ eq 'interval_time', @displaycolumns)) {
    push @displaycolumns, 'interval_time';
}

# Remove the timetracking columns if they are not a part of the group
# (happens if a user had access to time tracking and it was revoked/disabled)
if (!Bugzilla->user->is_timetracker)
{
    my %tt_fields = map { $_ => 1 } TIMETRACKING_FIELDS;
    @displaycolumns = grep { !$tt_fields{$_} } @displaycolumns;
}

# Remove the relevance column if the user is not doing a fulltext search.
if (grep('relevance', @displaycolumns) && !$fulltext) {
    @displaycolumns = grep($_ ne 'relevance', @displaycolumns);
}

################################################################################
# Select Column Determination
################################################################################

# Generate the list of columns that will be selected in the SQL query.

# The bug ID is always selected because bug IDs are always displayed.
# Severity, priority, resolution and status are required for buglist
# CSS classes.
my @selectcolumns = ("bug_id", "bug_severity", "priority", "bug_status",
                     "resolution", "product");

# remaining and work_time are required for percentage_complete calculation:
if (grep { $_ eq 'percentage_complete' } @displaycolumns) {
    push (@selectcolumns, "remaining_time");
    push (@selectcolumns, "work_time");
}

# Make sure that the login_name version of a field is always also
# requested if the realname version is requested, so that we can
# display the login name when the realname is empty.
my @realname_fields = grep(/_realname$/, @displaycolumns);
foreach my $item (@realname_fields) {
    my $login_field = $item;
    $login_field =~ s/_realname$//;
    if (!grep($_ eq $login_field, @selectcolumns)) {
        push(@selectcolumns, $login_field);
    }
}

# Display columns are selected because otherwise we could not display them.
foreach my $col (@displaycolumns) {
    push (@selectcolumns, $col) if !grep($_ eq $col, @selectcolumns);
}

# If the user is editing multiple bugs, we also make sure to select the
# status, because the values of that field determines what options the user
# has for modifying the bugs.
if ($dotweak) {
    push(@selectcolumns, "bug_status") if !grep($_ eq 'bug_status', @selectcolumns);
}

if ($format->{'extension'} eq 'ics') {
    push(@selectcolumns, "creation_ts") if !grep($_ eq 'creation_ts', @selectcolumns);
}

if ($format->{'extension'} eq 'atom') {
    # The title of the Atom feed will be the same one as for the bug list.
    $vars->{'title'} = $cgi->param('title');

    # This is the list of fields that are needed by the Atom filter.
    my @required_atom_columns = (
        'short_desc',
        'creation_ts',
        'delta_ts',
        'reporter',
        'reporter_realname',
        'priority',
        'bug_severity',
        'assigned_to',
        'assigned_to_realname',
        'bug_status',
        'product',
        'component',
        'resolution'
    );
    push(@required_atom_columns, 'target_milestone') if Bugzilla->params->{'usetargetmilestone'};

    foreach my $required (@required_atom_columns) {
        push(@selectcolumns, $required) if !grep($_ eq $required,@selectcolumns);
    }
}

if ($superworktime && !grep($_ eq 'product_notimetracking', @displaycolumns)) {
    push @selectcolumns, 'product_notimetracking';
}

################################################################################
# Sort Order Determination
################################################################################

# Add to the query some instructions for sorting the bug list.

# First check if we'll want to reuse the last sorting order; that happens if
# the order is not defined or its value is "reuse last sort"
if (!$order || $order =~ /^reuse/i) {
    if ($cgi->cookie('LASTORDER')) {
        $order = $cgi->cookie('LASTORDER');

        # Cookies from early versions of Specific Search included this text,
        # which is now invalid.
        $order =~ s/ LIMIT 200//;
    }
    else {
        $order = '';  # Remove possible "reuse" identifier as unnecessary
    }
}

# FIXME переместить в Bugzilla::Search
my $old_orders = {
    '' => 'bug_status,priority,assigned_to,bug_id', # Default
    'bug number' => 'bug_id',
    'importance' => 'priority,bug_severity,bug_id',
    'assignee' => 'assigned_to,bug_status,priority,bug_id',
    'last changed' => 'delta_ts,bug_status,priority,assigned_to,bug_id',
};
if ($order)
{
    # Convert the value of the "order" form field into a list of columns
    # by which to sort the results.
    if ($old_orders->{lc $order})
    {
        $order = $old_orders->{lc $order};
    }
    else
    {
        my (@order, @invalid_fragments);

        # A custom list of columns.  Make sure each column is valid.
        foreach my $fragment (split(/,/, $order))
        {
            $fragment = trim($fragment);
            next unless $fragment;
            my ($column_name, $direction) = split_order_term($fragment);
            $column_name = translate_old_column($column_name);

            # Special handlings for certain columns
            next if $column_name eq 'relevance' && !$fulltext;

            # If we are sorting by votes, sort in descending order if
            # no explicit sort order was given.
            if ($column_name eq 'votes' && !$direction)
            {
                $direction = "DESC";
            }

            if (exists $columns->{$column_name})
            {
                $direction = " $direction" if $direction;
                push @order, "$column_name$direction";
            }
            else
            {
                push @invalid_fragments, $fragment;
            }
        }
        if (scalar @invalid_fragments)
        {
            $vars->{message} = 'invalid_column_name';
            $vars->{invalid_fragments} = \@invalid_fragments;
        }

        $order = join(",", @order);
        # Now that we have checked that all columns in the order are valid,
        # detaint the order string.
        trick_taint($order) if $order;
    }
}

$order = $old_orders->{''} if !$order;

my @orderstrings = split(/,\s*/, $order);

# The bug status defined by a specific search is of type __foo__, but
# Search.pm converts it into a list of real bug statuses, which cannot
# be used when editing the specific search again. So we restore this
# parameter manually.
my $input_bug_status;
if ($query_format eq 'specific') {
    $input_bug_status = $params->param('bug_status');
}

# Generate the basic SQL query that will be used to generate the bug list.
my $search = new Bugzilla::Search('fields' => \@selectcolumns,
                                  'params' => $params,
                                  'order' => \@orderstrings);
my $query = $search->getSQL();
$vars->{search_description} = $search->search_description_html;
my $H = { %{ $params->Vars } };
$vars->{list_params} = $H;

# Generate equality operators for the "Create bug from querystring" link
# FIXME: check if there are some differently named fields
my $eq_query = {};
for my $eq (@{$search->get_equalities})
{
    if (!ref $eq->[2])
    {
        $eq_query->{$eq->[0]} = $eq->[2];
    }
}
$vars->{equality_querystring} = http_build_query($eq_query);

if (defined $cgi->param('limit')) {
    my $limit = $cgi->param('limit');
    if (detaint_natural($limit)) {
        $query .= " " . $dbh->sql_limit($limit);
    }
}
elsif ($fulltext) {
    if ($cgi->param('order') && $cgi->param('order') =~ /^relevance/) {
        $vars->{'message'} = 'buglist_sorted_by_relevance';
    }
}

if ($superworktime)
{
    # Must come after Bugzilla::Search::getSQL
    if (Bugzilla->user->in_group('worktimeadmin'))
    {
        my $d = $Bugzilla::Search::interval_to;
        if ($d)
        {
            # Use DateTime instead of SQL functions to be more DBMS-independent
            $d =~ s/(\d)( .*)?$/$1 00:00:00/;
            $d = datetime_from($d);
            $d->subtract(days => 1);
            $d = $d->ymd;
        }
        else
        {
            $d = POSIX::strftime("%Y-%m-%d", localtime);
        }
        $vars->{worktime_user} = $cgi->param('worktime_user') || ($Bugzilla::Search::interval_who ? $Bugzilla::Search::interval_who->login : undef);
        $vars->{worktime_date} = $cgi->param('worktime_date') || $d;
    }
    else
    {
        $vars->{worktime_date} = POSIX::strftime("%Y-%m-%d", localtime);
        $vars->{worktime_user} = Bugzilla->user->login;
    }
    $vars->{token} = issue_session_token('superworktime');
}

################################################################################
# Query Execution
################################################################################

if ($cgi->param('debug')) {
    $vars->{'debug'} = 1;
    $vars->{'query'} = $query;
    # Explains are limited to admins because you could use them to figure
    # out how many hidden bugs are in a particular product (by doing
    # searches and looking at the number of rows the explain says it's
    # examining).
    if (Bugzilla->user->in_group('admin')) {
        $vars->{'query_explain'} = $dbh->bz_explain($query);
    }
}

# Time to use server push to display an interim message to the user until
# the query completes and we can display the bug list.
if ($serverpush) {
    $cgi->send_multipart_init();
    $cgi->send_multipart_start(-type => 'text/html');

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("list/server-push.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    # Under mod_perl, flush stdout so that the page actually shows up.
    if ($ENV{MOD_PERL}) {
        require Apache2::RequestUtil;
        Apache2::RequestUtil->request->rflush();
    }

    # Don't do multipart_end() until we're ready to display the replacement
    # page, otherwise any errors that happen before then (like SQL errors)
    # will result in a blank page being shown to the user instead of the error.
}

# Connect to the shadow database if this installation is using one to improve
# query performance.
$dbh = Bugzilla->switch_to_shadow_db();

# Normally, we ignore SIGTERM and SIGPIPE, but we need to
# respond to them here to prevent someone DOSing us by reloading a query
# a large number of times.
$::SIG{TERM} = 'DEFAULT';
$::SIG{PIPE} = 'DEFAULT';

# Query start time
my $query_sql_time = gettimeofday();

# Execute the query.
my $buglist_sth = $dbh->prepare($query);
$buglist_sth->execute();

################################################################################
# Results Retrieval
################################################################################

# Retrieve the query results one row at a time and write the data into a list
# of Perl records.

# TODO перенести на общий механизм и чтобы в него вкручивалось interval_time
# If we're doing time tracking, then keep totals for all bugs.
my $percentage_complete = 1 && grep { $_ eq 'percentage_complete' } @displaycolumns;
my $estimated_time      = 1 && grep { $_ eq 'estimated_time' } @displaycolumns;
my $remaining_time      = $percentage_complete || grep { $_ eq 'remaining_time' } @displaycolumns;
my $work_time           = $percentage_complete || grep { $_ eq 'work_time' } @displaycolumns;
my $interval_time       = $percentage_complete || grep { $_ eq 'interval_time' } @displaycolumns;

my $time_info = { 'estimated_time' => 0,
                  'remaining_time' => 0,
                  'work_time' => 0,
                  'percentage_complete' => 0,
                  'interval_time' => 0, # CustIS Bug 68921
                  'time_present' => ($estimated_time || $remaining_time ||
                                     $work_time || $percentage_complete || $interval_time),
                };

my $bugowners = {};
my $bugproducts = {};
my $bugstatuses = {};
my @bugidlist;

my @bugs; # the list of records

while (my @row = $buglist_sth->fetchrow_array()) {
    my $bug = {}; # a record

    # Slurp the row of data into the record.
    # The second from last column in the record is the number of groups
    # to which the bug is restricted.
    foreach my $column (@selectcolumns) {
        $bug->{$column} = shift @row;
    }

    # Process certain values further (i.e. date format conversion).
    if ($bug->{'delta_ts'}) {
        $bug->{'delta_ts'} =~
            s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/$1-$2-$3 $4:$5:$6/;
        $bug->{'delta_ts_diff'} = DiffDate($bug->{'delta_ts'});
    }

    if ($bug->{'creation_ts'}) {
        $bug->{'creation_ts_diff'} = DiffDate($bug->{'creation_ts'});
    }

    # Record the assignee, product, and status in the big hashes of those things.
    $bugowners->{$bug->{'assigned_to'}} = 1 if $bug->{'assigned_to'};
    $bugproducts->{$bug->{'product'}} = 1 if $bug->{'product'};
    $bugstatuses->{$bug->{'bug_status'}} = 1 if $bug->{'bug_status'};

    $bug->{'secure_mode'} = undef;

    # Add the record to the list.
    push(@bugs, $bug);

    # Add id to list for checking for bug privacy later
    push(@bugidlist, $bug->{'bug_id'});

    # Compute time tracking info.
    $time_info->{'estimated_time'} += $bug->{'estimated_time'} if $estimated_time;
    $time_info->{'remaining_time'} += $bug->{'remaining_time'} if $remaining_time;
    $time_info->{'work_time'}      += $bug->{'work_time'}      if $work_time;
    $time_info->{'interval_time'}  += $bug->{'interval_time'}  if $interval_time;
}

my $query_template_time = gettimeofday();
$query_sql_time = $query_template_time-$query_sql_time;

# Check for bug privacy and set $bug->{'secure_mode'} to 'implied' or 'manual'
# based on whether the privacy is simply product implied (by mandatory groups)
# or because of human choice
my %min_membercontrol;
if (@bugidlist) {
    my $sth = $dbh->prepare(
        "SELECT DISTINCT bugs.bug_id, MIN(group_control_map.membercontrol) " .
          "FROM bugs " .
    "INNER JOIN bug_group_map " .
            "ON bugs.bug_id = bug_group_map.bug_id " .
     "LEFT JOIN group_control_map " .
            "ON group_control_map.product_id = bugs.product_id " .
           "AND group_control_map.group_id = bug_group_map.group_id " .
         "WHERE " . $dbh->sql_in('bugs.bug_id', \@bugidlist) .
            $dbh->sql_group_by('bugs.bug_id'));
    $sth->execute();
    while (my ($bug_id, $min_membercontrol) = $sth->fetchrow_array()) {
        $min_membercontrol{$bug_id} = $min_membercontrol || CONTROLMAPNA;
    }
    foreach my $bug (@bugs) {
        next unless defined($min_membercontrol{$bug->{'bug_id'}});
        if ($min_membercontrol{$bug->{'bug_id'}} == CONTROLMAPMANDATORY) {
            $bug->{'secure_mode'} = 'implied';
        }
        else {
            $bug->{'secure_mode'} = 'manual';
        }
    }
}

# Compute percentage complete without rounding.
my $sum = $time_info->{'work_time'} + $time_info->{'remaining_time'};
if ($sum > 0) {
    $time_info->{'percentage_complete'} = 100*$time_info->{'work_time'}/$sum;
}
else { # remaining_time <= 0
    $time_info->{'percentage_complete'} = 0
}

################################################################################
# Template Variable Definition
################################################################################

# Define the variables and functions that will be passed to the UI template.

$vars->{'bugs'} = \@bugs;
$vars->{'buglist'} = \@bugidlist;
$vars->{'buglist_joined'} = join(',', @bugidlist);
$vars->{'columns'} = $columns;
$vars->{'displaycolumns'} = \@displaycolumns;

$vars->{'openstates'} = [BUG_STATE_OPEN];
$vars->{'closedstates'} = [map {$_->name} closed_bug_statuses()];

# The iCal file needs priorities ordered from 1 to 9 (highest to lowest)
# If there are more than 9 values, just make all the lower ones 9
if ($format->{'extension'} eq 'ics') {
    my $n = 1;
    $vars->{'ics_priorities'} = {};
    my $priorities = Bugzilla->get_field('priority')->legal_value_names;
    foreach my $p (@$priorities) {
        $vars->{'ics_priorities'}->{$p} = ($n > 9) ? 9 : $n++;
    }
}

# Restore the bug status used by the specific search.
$params->param('bug_status', $input_bug_status) if $input_bug_status;

# The list of query fields in URL query string format, used when creating
# URLs to the same query results page with different parameters (such as
# a different sort order or when taking some action on the set of query
# results).  To get this string, we call the Bugzilla::CGI::canoncalise_query
# function with a list of elements to be removed from the URL.
$vars->{'urlquerypart'} = $params->canonicalise_query('order', 'cmdtype', 'query_based_on');
$vars->{'order'} = $order;
$vars->{'order_columns'} = [ @orderstrings ];
$vars->{'order_dir'} = [ map { s/ DESC$// ? 1 : 0 } @{$vars->{'order_columns'}} ];

$vars->{'caneditbugs'} = 1;
$vars->{'time_info'} = $time_info;

$vars->{query_params} = { %{ $params->Vars } }; # now used only in superworktime
$vars->{query_params}->{chfieldfrom} = $Bugzilla::Search::interval_from;
$vars->{query_params}->{chfieldto} = $Bugzilla::Search::interval_to;

if (!Bugzilla->user->in_group('editbugs')) {
    foreach my $product (keys %$bugproducts) {
        my $prod = new Bugzilla::Product({name => $product});
        if (!Bugzilla->user->in_group('editbugs', $prod->id)) {
            $vars->{'caneditbugs'} = 0;
            last;
        }
    }
}

my @bugowners = keys %$bugowners;
if (scalar(@bugowners) > 1 && Bugzilla->user->in_group('editbugs')) {
    my $suffix = Bugzilla->params->{'emailsuffix'};
    map(s/$/$suffix/, @bugowners) if $suffix;
    my $bugowners = join(",", @bugowners);
    $vars->{'bugowners'} = $bugowners;
}

# Whether or not to split the column titles across two rows to make
# the list more compact.
$vars->{'splitheader'} = $cgi->cookie('SPLITHEADER') ? 1 : 0;

$vars->{'quip'} = GetQuip();
$vars->{'currenttime'} = localtime(time());

# See if there's only one product in all the results (or only one product
# that we searched for), which allows us to provide more helpful links.
my @products = keys %$bugproducts;
my $one_product;
if (scalar(@products) == 1) {
    $one_product = new Bugzilla::Product({ name => $products[0] });
}
# This is used in the "Zarroo Boogs" case.
elsif (my @product_input = $cgi->param('product')) {
    if (scalar(@product_input) == 1 and $product_input[0] ne '') {
        $one_product = new Bugzilla::Product({ name => $cgi->param('product') });
    }
}
# We only want the template to use it if the user can actually
# enter bugs against it.
if ($one_product && Bugzilla->user->can_enter_product($one_product)) {
    $vars->{'one_product'} = $one_product;
}

# The following variables are used when the user is making changes to multiple bugs.
if ($dotweak && scalar @bugs) {
    if (!$vars->{'caneditbugs'}) {
        _close_standby_message('text/html', 'inline', $serverpush);
        ThrowUserError('auth_failure', {group  => 'editbugs',
                                        action => 'modify',
                                        object => 'multiple_bugs'});
    }
    $vars->{'dotweak'} = 1;

    # issue_session_token needs to write to the master DB.
    Bugzilla->switch_to_main_db();
    $vars->{'token'} = issue_session_token('buglist_mass_change');
    Bugzilla->switch_to_shadow_db();

    $vars->{'products'} = Bugzilla->user->get_enterable_products;
    $vars->{'platforms'} = Bugzilla->get_field('platform')->legal_value_names if Bugzilla->params->{useplatform};
    $vars->{'op_sys'} = Bugzilla->get_field('op_sys')->legal_value_names if Bugzilla->params->{useopsys};
    $vars->{'priorities'} = Bugzilla->get_field('priority')->legal_value_names;
    $vars->{'severities'} = Bugzilla->get_field('bug_severity')->legal_value_names;
    $vars->{'resolutions'} = Bugzilla->get_field('resolution')->legal_value_names;

    # Convert bug statuses to their ID.
    my @bug_statuses = map { $dbh->quote($_) } keys %$bugstatuses;
    my $bug_status_ids = $dbh->selectcol_arrayref('SELECT id FROM bug_status WHERE ' . $dbh->sql_in('value', \@bug_statuses));

    # The groups the user belongs to and which are editable for the given buglist.
    $vars->{'groups'} = GetGroups(\@products);

    # Select new statuses which are settable for ANY of current bug statuses,
    # plus transitions where the bug status doesn't change.
    $bug_status_ids = [ keys %{ { map { $_ => 1 } (@$bug_status_ids, @{ $dbh->selectcol_arrayref(
        'SELECT DISTINCT new_status FROM status_workflow'.
        ' INNER JOIN bug_status ON bug_status.id = new_status'.
        ' WHERE bug_status.isactive = 1 AND '.$dbh->sql_in('old_status', $bug_status_ids)
    ) }) } } ];

    $vars->{'current_bug_statuses'} = [keys %$bugstatuses];
    $vars->{'new_bug_statuses'} = Bugzilla::Status->new_from_list($bug_status_ids);

    # Generate unions of possible components, versions and milestones for all selected products
    @products = @{ Bugzilla::Product->match({ name => \@products }) };
    $vars->{components} = union(map { [ map { $_->name } @{ $_->components } ] } @products);
    $vars->{versions} = union(map { [ map { $_->name } @{ $_->versions } ] } @products);
    if (Bugzilla->params->{usetargetmilestone})
    {
        $vars->{targetmilestones} = union(map { [ map { $_->name } @{ $_->milestones } ] } @products);
    }

    # Generate unions of possible custom field values for all current controller values
    # This requires bug objects, at last!
    my $custom = [];
    my $bug_objects = Bugzilla::Bug->new_from_list(\@bugidlist);
    my $bug_vals = {};
    for my $field (Bugzilla->active_custom_fields)
    {
        my $vis_field = $field->visibility_field;
        if ($vis_field)
        {
            my $visible;
            for my $cv (@{ get_bug_vals($vis_field, $bug_objects, $bug_vals) })
            {
                if ($field->has_visibility_value($cv))
                {
                    $visible = 1;
                    last;
                }
            }
            next if !$visible;
        }
        my $value_field = $field->value_field;
        if (!$value_field || $field->type != FIELD_TYPE_MULTI_SELECT && $field->type != FIELD_TYPE_SINGLE_SELECT)
        {
            push @$custom, { field => $field, values => $field->legal_value_names };
            next;
        }
        my $union = [];
        for my $cv (@{ get_bug_vals($value_field, $bug_objects, $bug_vals) })
        {
            push @$union, $field->restricted_legal_values($cv);
        }
        push @$custom, { field => $field, values => union(@$union) };
    }
    $vars->{tweak_custom_fields} = $custom;
}

sub get_bug_vals
{
    my ($field, $bugs, $bug_vals) = @_;
    return $bug_vals->{$field} if $bug_vals->{$field};
    my $field_name = $field->name;
    my $name_field = $field->NAME_FIELD;
    my $vals = {};
    my $v;
    for my $bug (@$bugs)
    {
        $v = $bug->$field_name;
        $vals->{ref($v) ? $v->$name_field : $v} = 1;
    }
    my $class = Bugzilla::Field::Choice->type($field);
    return $bug_vals->{$field} = $class->match({ $name_field => [ keys %$vals ] });
}

# If we're editing a stored query, use the existing query name as default for
# the "Remember search as" field.
$vars->{defaultsavename} = $cgi->param('query_based_on');
$vars->{query_sql_time} = sprintf("%.2f", $query_sql_time);

Bugzilla::Hook::process('after-buglist', { vars => $vars });

$vars->{abbrev} = {
    bug_severity         => { maxlength => 3, title => "Sev" },
    priority             => { maxlength => 3, title => "Pri" },
    rep_platform         => { maxlength => 3, title => "Plt" },
    bug_status           => { maxlength => 4 },
    assigned_to          => { maxlength => 30, ellipsis => "..." },
    reporter             => { maxlength => 30, ellipsis => "..." },
    qa_contact           => { maxlength => 30, ellipsis => "..." },
    resolution           => { maxlength => 4 },
    short_short_desc     => { maxlength => 60, ellipsis => "..." },
    status_whiteboard    => { title => "Whiteboard" },
    component            => { maxlength => 8, title => "Comp" },
    product              => { maxlength => 8 },
    op_sys               => { maxlength => 4 },
    target_milestone     => { title => "Milestone" },
    percentage_complete  => { format_value => "%d %%" },
    comment0             => { maxlength => 40, ellipsis => "..." },
    lastcomment          => { maxlength => 40, ellipsis => "..." },
};

################################################################################
# HTTP Header Generation
################################################################################

# Generate HTTP headers

my $contenttype;
my $disposition = "inline";

if ($format->{extension} eq "html" && !$agent) {
    if ($order && !$cgi->param('sharer_id') && $query_format ne 'specific') {
        $cgi->send_cookie(-name => 'LASTORDER',
                          -value => $order,
                          -expires => 'Fri, 01-Jan-2038 00:00:00 GMT');
    }
    my $bugids = join(":", @bugidlist);
    # See also Bug 111999
    if (length($bugids) == 0) {
        $cgi->remove_cookie('BUGLIST');
    }
    elsif (length($bugids) < 4000) {
        $cgi->send_cookie(-name => 'BUGLIST',
                          -value => $bugids,
                          -expires => 'Fri, 01-Jan-2038 00:00:00 GMT');
    }
    else {
        $cgi->remove_cookie('BUGLIST');
        $vars->{'toolong'} = 1;
    }

    $contenttype = "text/html";
}
else {
    $contenttype = $format->{'ctype'};
}

if ($format->{'extension'} eq "csv") {
    # We set CSV files to be downloaded, as they are designed for importing
    # into other programs.
    $disposition = "attachment";
}

# Suggest a name for the bug list if the user wants to save it as a file.
$disposition .= "; filename=\"$filename\"";

_close_standby_message($contenttype, $disposition, $serverpush);

################################################################################
# Content Generation
################################################################################

$vars->{'template_format'} = $cgi->param('format');

# Generate and return the UI (HTML page) from the appropriate template.
my $output;
$template->process($format->{'template'}, $vars, \$output)
  || ThrowTemplateError($template->error());

$query_template_time = gettimeofday()-$query_template_time;
# CustIS Bug 69766 - Default CSV charset for M1cr0$0ft Excel
if (($cgi->param('ctype')||'') eq 'csv' &&
    Bugzilla->user->settings->{csv_charset} &&
    Bugzilla->user->settings->{csv_charset}->{value} ne 'utf-8')
{
    # Пара хаков:
    # во-первых, _utf8_off не работает на бывшем когда-то tainted скаляре,
    #   а from_to не работает на скаляре с включённым utf8 флагом, поэтому мы
    #   его копируем и работаем с копией.
    # во-вторых, заголовки выводятся с включённым utf8 флагом, а мы не хотим,
    #   чтобы perl сам что-то перекодировал - поэтому в конце идёт _utf8_on.
    trick_taint($output);
    my $untaint = $output;
    Encode::_utf8_off($untaint);
    Encode::from_to($untaint, 'utf-8', Bugzilla->user->settings->{csv_charset}->{value});
    $output = $untaint;
    Encode::_utf8_on($output);
}
elsif ($format->{extension} eq 'html')
{
    $output =~ s/\$_query_template_time/sprintf("%.2f", $query_template_time)/e;
}
print $output;

################################################################################
# Script Conclusion
################################################################################

$cgi->send_multipart_final() if $serverpush;

1;
