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
#                 David Gardiner <david.gardiner@unisa.edu.au>
#                 Matthias Radestock <matthias@sorted.org>
#                 Gervase Markham <gerv@gerv.net>
#                 Byron Jones <bugzilla@glob.com.au>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Search;
use Bugzilla::Search::Saved;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;
use Bugzilla::Keyword;
use Bugzilla::Field;
use Bugzilla::Install::Util qw(vers_cmp);

my $cgi = Bugzilla->cgi;
# Copy hash and throw away tied reference returned by Vars()
my $params = { %{ $cgi->Vars } };
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

my $user = Bugzilla->login();
my $userid = $user->id;

# Backwards compatibility hack -- if there are any of the old QUERY_*
# cookies around, and we are logged in, then move them into the database
# and nuke the cookie. This is required for Bugzilla 2.8 and earlier.
if ($userid)
{
    my @oldquerycookies;
    foreach my $i ($cgi->cookie()) {
        if ($i =~ /^QUERY_(.*)$/) {
            push @oldquerycookies, [$1, $i, $cgi->cookie($i)];
        }
    }
    if (defined $cgi->cookie('DEFAULTQUERY'))
    {
        push @oldquerycookies, [DEFAULT_QUERY_NAME, 'DEFAULTQUERY',
                                $cgi->cookie('DEFAULTQUERY')];
    }
    if (@oldquerycookies)
    {
        foreach my $ref (@oldquerycookies)
        {
            my ($name, $cookiename, $value) = (@$ref);
            if ($value)
            {
                # If the query name contains invalid characters, don't import.
                $name =~ /[<>&]/ && next;
                trick_taint($name);
                $dbh->bz_start_transaction();
                my $query = $dbh->selectrow_array(
                    "SELECT query FROM namedqueries " .
                     "WHERE userid = ? AND name = ?",
                     undef, $userid, $name
                );
                if (!$query)
                {
                    $dbh->do(
                        "INSERT INTO namedqueries " .
                        "(userid, name, query) VALUES (?, ?, ?)",
                        undef, $userid, $name, $value
                   );
                }
                $dbh->bz_commit_transaction();
            }
            $cgi->remove_cookie($cookiename);
        }
    }
}

if ($params->{nukedefaultquery} && $userid)
{
    $dbh->do(
        "DELETE FROM namedqueries WHERE userid = ? AND name = ?", 
        undef, $userid, DEFAULT_QUERY_NAME
    );
}

# We are done with changes committed to the DB.
$dbh = Bugzilla->switch_to_shadow_db;

my $userdefaultquery;
if ($userid)
{
    ($userdefaultquery) = $dbh->selectrow_array(
        "SELECT query FROM namedqueries WHERE userid = ? AND name = ?",
         undef, $userid, DEFAULT_QUERY_NAME
    );
}

my $default = {};

# Nothing must be undef, otherwise the template complains.
my @list = qw(
    bug_status resolution assigned_to
    rep_platform priority bug_severity
    classification product reporter op_sys
    component version target_milestone
    chfield chfieldfrom chfieldto chfieldwho chfieldvalue
    email emailtype emailreporter
    emailassigned_to emailcc emailqa_contact
    emaillongdesc content
    changedin votes short_desc short_desc_type
    longdesc longdesc_type bug_file_loc
    bug_file_loc_type status_whiteboard
    status_whiteboard_type bug_id
    bug_id_type keywords keywords_type
    deadlinefrom deadlineto
    x_axis_field y_axis_field z_axis_field
    chart_format cumulate x_labels_vertical
    category subcategory name newcategory
    newsubcategory public frequency
);

# These fields can also have default values (when used in reports).
# CustIS Bug 58300 - Add custom field to search filters
for my $field (Bugzilla->active_custom_fields)
{
    push @list, $field->name;
    push @list, $field->name . '_type';
}

foreach my $name (@list)
{
    $default->{$name} = [];
}

if ($params->{nukedefaultquery})
{
    # Don't prefill form
}
elsif (!PrefillForm($params, $default))
{
    # Ah-hah, there was no form stuff specified. Do it again with the
    # default query.
    my $buf = new Bugzilla::CGI($userdefaultquery || Bugzilla->params->{defaultquery});
    PrefillForm({ %{ $buf->Vars } }, $default);
}

if (!@{$default->{chfieldto}} || $default->{chfieldto}->[0] eq '')
{
    $default->{chfieldto} = [ 'Now' ];
}

# "where one or more of the following changed:"
$vars->{chfield} = [
    sort { $a->{name} cmp $b->{name} }
    map { { id => $_->{name}, name => $_->{description} } }
    @{ Bugzilla::Search->CHANGEDFROMTO_FIELDS }
];

# Fields for reports
$vars->{report_columns} = [
    sort { $a->{title} cmp $b->{title} }
    values %{Bugzilla::Search::REPORT_COLUMNS()}
];

# Boolean charts
my $opdescs = Bugzilla->messages->{operator_descs};
$vars->{chart_types} = Bugzilla::Search->CHART_OPERATORS_ORDER;
$vars->{text_types} = Bugzilla::Search->TEXT_OPERATORS_ORDER;

# Fields for boolean charts
$vars->{chart_fields} = [
    map { { id => $_->{id}, name => $_->{title} } }
    sort { (($a->{sortkey}||0) <=> ($b->{sortkey}||0)) || ($a->{title} cmp $b->{title}) }
    grep { !$_->{nocharts} }
    values %{ Bugzilla::Search->COLUMNS }
];

# Another hack...
unshift @{$vars->{chart_fields}}, { id => 'noop', name => '---' };
$vars->{'bug_status'} = Bugzilla::Field->new({name => 'bug_status'})->legal_values;
$vars->{'rep_platform'} = Bugzilla::Field->new({name => 'rep_platform'})->legal_values;
$vars->{'op_sys'} = Bugzilla::Field->new({name => 'op_sys'})->legal_values;
$vars->{'priority'} = Bugzilla::Field->new({name => 'priority'})->legal_values;
$vars->{'bug_severity'} = Bugzilla::Field->new({name => 'bug_severity'})->legal_values;
$vars->{'resolution'} = Bugzilla::Field->new({name => 'resolution'})->legal_values;

# Boolean charts
my @fields = @{ Bugzilla->fields({ obsolete => 0 }) };

# If we're not in the time-tracking group, exclude time-tracking fields.
if (!Bugzilla->user->is_timetracker) {
    foreach my $tt_field (TIMETRACKING_FIELDS) {
        @{$vars->{chart_fields}} = grep($_->{name} ne $tt_field, @{$vars->{chart_fields}});
    }
}

# Parse boolean charts from the form hash
# FIXME add support for "Attachment 2 submitter", ..., i.e., selecting
# the target of a search term that could be correlated
my @charts;
for (keys %$params)
{
    if (/^(field|type|value)(\d+)-(\d+)-(\d+)$/so)
    {
        $charts[$2]{rows}[$3][$4]{$1} = $params->{$_};
    }
    elsif (/^negate(\d+)$/so)
    {
        $charts[$2]{negate} = $params->{$_};
    }
}

# Remove empty charts
for (@charts)
{
    @$_ = grep { $_ && $_->{field} && $_->{field} ne 'noop' && $_->{field} ne '---' } @$_ for @{$_->{rows}};
    @{$_->{rows}} = grep { @$_ } @{$_->{rows}};
}
@charts = grep { @{$_->{rows}} } @charts;

# Add one chart, if we've removed all of them
@charts = ( { rows => [ [ { field => 'noop' } ] ] } ) unless @charts;

$default->{charts} = \@charts;

# Named queries
if ($userid)
{
    $vars->{namedqueries} = $dbh->selectcol_arrayref(
        "SELECT name FROM namedqueries " .
        "WHERE userid = ? AND name != ? " .
        "ORDER BY name",
        undef, $userid, DEFAULT_QUERY_NAME
    );
}

# Sort order
my $deforder;
my @orders = ('Bug Number', 'Importance', 'Assignee', 'Last Changed', 'relevance');

if ($cgi->cookie('LASTORDER'))
{
    $deforder = "Reuse same sort as last time";
    unshift(@orders, $deforder);
}

if ($params->{order} && !grep { $_ eq $params->{order} } @orders)
{
    unshift @orders, $params->{order};
}

$vars->{userdefaultquery} = $userdefaultquery;
$vars->{orders} = \@orders;
$default->{order} = [$deforder || 'Importance'];

# CustIS Bug 58300 - Add custom fields to search filters
# This logic is moved from search/form.html.tmpl
$vars->{freetext_fields} = [
    Bugzilla->get_field('longdesc'),
    Bugzilla->get_field('bug_file_loc')
];
if (Bugzilla->params->{usestatuswhiteboard})
{
    push @{$vars->{freetext_fields}}, Bugzilla->get_field('status_whiteboard');
}
push @{$vars->{freetext_fields}},
    Bugzilla->active_custom_fields({ type => [ FIELD_TYPE_TEXTAREA, FIELD_TYPE_FREETEXT, FIELD_TYPE_EXTURL ] });

($vars->{known_name}) = list $params->{known_name};
$vars->{columnlist} = $params->{columnlist};

# Add in the defaults.
$vars->{default} = $default;

$vars->{format} = $params->{format};

# Set default page to "advanced" if none provided
if (!$params->{query_format} && !$params->{format})
{
    if (defined $cgi->cookie('DEFAULTFORMAT'))
    {
        $params->{format} = $cgi->cookie('DEFAULTFORMAT');
    }
    else
    {
        $params->{format} = 'advanced';
    }
}

$vars->{query_format} = $params->{query_format} || $params->{format};
if ($vars->{query_format} eq "create-series")
{
    require Bugzilla::Chart;
    $vars->{category} = Bugzilla::Chart::getVisibleSeries();
}

# Custis Bug 66910
my @keyword_list = Bugzilla::Keyword->get_all();
my @keyword_list_out = map { { name => $_->{name} } } @keyword_list;
$vars->{keyword_list} = \@keyword_list_out;
# END Custis Bug 66910


# Set cookie to current format as default, but only if the format
# one that we should remember.
if (defined $vars->{format} && IsValidQueryType($vars->{format}))
{
    $cgi->send_cookie(
        -name => 'DEFAULTFORMAT',
        -value => $vars->{format},
        -expires => "Fri, 01-Jan-2038 00:00:00 GMT"
    );
}

# Generate and return the UI (HTML page) from the appropriate template.
# If we submit back to ourselves (for e.g. boolean charts), we need to
# preserve format information; hence query_format taking priority over
# format.
my $format = $template->get_format(
    "search/search",
    $params->{query_format} || $params->{format},
    $params->{ctype}
);

$cgi->send_header($format->{ctype});
$template->process($format->{template}, $vars)
    || ThrowTemplateError($template->error());
exit;

# We pass the defaults as a hash of references to arrays. For those
# Items which are single-valued, the template should only reference [0]
# and ignore any multiple values.
# This is used only for prefilling full queries, not parts of them,
# so we always prefill boolean charts.
sub PrefillForm
{
    my ($params, $default) = @_;
    my $foundone = 0;

    # Iterate over the URL parameters
    foreach (keys %$params)
    {
        # If the name begins with the string 'field', 'type', 'value', or
        # 'negate', then it is part of the boolean charts. Because
        # these are built different than the rest of the form, we need
        # to store these as parameters. We also need to indicate that
        # we found something so the default query isn't added in if
        # all we have are boolean chart items.
        if (m/^(?:field|type|value|negate)/)
        {
            $foundone = 1;
        }
        # If the name ends in a number (which it does for the fields which
        # are part of the email searching), we use the array
        # positions to show the defaults for that number field.
        elsif (m/^(.+)(\d)$/ && defined $default->{$1})
        {
            $foundone = 1;
            $default->{$1}->[$2] = [ list $params->{$_} ]->[0];
        }
        elsif (exists $default->{$_})
        {
            $foundone = 1;
            push @{$default->{$_}}, list $params->{$_};
        }
    }

    return $foundone;
}
