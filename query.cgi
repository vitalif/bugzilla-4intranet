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
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;
use Bugzilla::Keyword;
use Bugzilla::Field;
use Bugzilla::Install::Util qw(vers_cmp);

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $buffer = $cgi->query_string();

my $user = Bugzilla->login();
my $userid = $user->id;

# Backwards compatibility hack -- if there are any of the old QUERY_*
# cookies around, and we are logged in, then move them into the database
# and nuke the cookie. This is required for Bugzilla 2.8 and earlier.
if ($userid) {
    my @oldquerycookies;
    foreach my $i ($cgi->cookie()) {
        if ($i =~ /^QUERY_(.*)$/) {
            push(@oldquerycookies, [$1, $i, $cgi->cookie($i)]);
        }
    }
    if (defined $cgi->cookie('DEFAULTQUERY')) {
        push(@oldquerycookies, [DEFAULT_QUERY_NAME, 'DEFAULTQUERY',
                                $cgi->cookie('DEFAULTQUERY')]);
    }
    if (@oldquerycookies) {
        foreach my $ref (@oldquerycookies) {
            my ($name, $cookiename, $value) = (@$ref);
            if ($value) {
                # If the query name contains invalid characters, don't import.
                $name =~ /[<>&]/ && next;
                trick_taint($name);
                $dbh->bz_start_transaction();
                my $query = $dbh->selectrow_array(
                    "SELECT query FROM namedqueries " .
                     "WHERE userid = ? AND name = ?",
                     undef, ($userid, $name));
                if (!$query) {
                    $dbh->do("INSERT INTO namedqueries " .
                            "(userid, name, query) VALUES " .
                            "(?, ?, ?)", undef, ($userid, $name, $value));
                }
                $dbh->bz_commit_transaction();
            }
            $cgi->remove_cookie($cookiename);
        }
    }
}

if ($cgi->param('nukedefaultquery')) {
    if ($userid) {
        $dbh->do("DELETE FROM namedqueries" .
                 " WHERE userid = ? AND name = ?", 
                 undef, ($userid, DEFAULT_QUERY_NAME));
    }
    $buffer = "";
}

# We are done with changes committed to the DB.
$dbh = Bugzilla->switch_to_shadow_db;

my $userdefaultquery;
if ($userid) {
    $userdefaultquery = $dbh->selectrow_array(
        "SELECT query FROM namedqueries " .
         "WHERE userid = ? AND name = ?", 
         undef, ($userid, DEFAULT_QUERY_NAME));
}

local our %default;

# We pass the defaults as a hash of references to arrays. For those
# Items which are single-valued, the template should only reference [0]
# and ignore any multiple values.
sub PrefillForm {
    my ($buf) = (@_);
    my $cgi = Bugzilla->cgi;
    $buf = new Bugzilla::CGI($buf);
    my $foundone = 0;

    # Nothing must be undef, otherwise the template complains.
    my @list = ("bug_status", "resolution", "assigned_to",
                      "rep_platform", "priority", "bug_severity",
                      "classification", "product", "reporter", "op_sys",
                      "component", "version", "chfield", "chfieldfrom",
                      "chfieldto", "chfieldvalue", "target_milestone",
                      "email", "emailtype", "emailreporter",
                      "emailassigned_to", "emailcc", "emailqa_contact",
                      "emaillongdesc", "content",
                      "changedin", "votes", "short_desc", "short_desc_type",
                      "longdesc", "longdesc_type", "bug_file_loc",
                      "bug_file_loc_type", "status_whiteboard",
                      "status_whiteboard_type", "bug_id",
                      "bug_id_type", "keywords", "keywords_type",
                      "deadlinefrom", "deadlineto",
                      "x_axis_field", "y_axis_field", "z_axis_field",
                      "chart_format", "cumulate", "x_labels_vertical",
                      "category", "subcategory", "name", "newcategory",
                      "newsubcategory", "public", "frequency");
    # These fields can also have default values (when used in reports).
    # CustIS Bug 58300 - Add custom field to search filters
    for my $field (Bugzilla->active_custom_fields)
    {
        push @list, $field->name;
        if ($field->type == FIELD_TYPE_FREETEXT || $field->type == FIELD_TYPE_TEXTAREA)
        {
            push @list, $field->name . '_type';
        }
    }

    foreach my $name (@list) {
        $default{$name} = [];
    }
 
    # we won't prefill the boolean chart data from this query if
    # there are any being submitted via params
    my $prefillcharts = (grep(/^field-/, $cgi->param)) ? 0 : 1;
 
    # Iterate over the URL parameters
    foreach my $name ($buf->param()) {
        my @values = $buf->param($name);

        # If the name begins with the string 'field', 'type', 'value', or
        # 'negate', then it is part of the boolean charts. Because
        # these are built different than the rest of the form, we need
        # to store these as parameters. We also need to indicate that
        # we found something so the default query isn't added in if
        # all we have are boolean chart items.
        if ($name =~ m/^(?:field|type|value|negate)/) {
            $cgi->param(-name => $name, -value => $values[0]) if ($prefillcharts);
            $foundone = 1;
        }
        # If the name ends in a number (which it does for the fields which
        # are part of the email searching), we use the array
        # positions to show the defaults for that number field.
        elsif ($name =~ m/^(.+)(\d)$/ && defined($default{$1})) {
            $foundone = 1;
            $default{$1}->[$2] = $values[0];
        }
        elsif (exists $default{$name}) {
            $foundone = 1;
            push (@{$default{$name}}, @values);
        }
    }
    return $foundone;
}

if (!PrefillForm($buffer)) {
    # Ah-hah, there was no form stuff specified.  Do it again with the
    # default query.
    if ($userdefaultquery) {
        PrefillForm($userdefaultquery);
    } else {
        PrefillForm(Bugzilla->params->{"defaultquery"});
    }
}

if (!scalar(@{$default{'chfieldto'}}) || $default{'chfieldto'}->[0] eq "") {
    $default{'chfieldto'} = ["Now"];
}

# if using groups for entry, then we don't want people to see products they 
# don't have access to. Remove them from the list.
my @selectable_products = sort {lc($a->name) cmp lc($b->name)} 
                               @{$user->get_selectable_products};
Bugzilla::Product::preload(\@selectable_products);

# Create the component, version and milestone lists.
my %components;
my %versions;
my %milestones;

foreach my $product (@selectable_products) {
    $components{$_->name} = 1 foreach (@{$product->components});
    $versions{$_->name}   = 1 foreach (@{$product->versions});
    $milestones{$_->name} = 1 foreach (@{$product->milestones});
}

my @components = sort(keys %components);
my @versions = sort { vers_cmp (lc($a), lc($b)) } keys %versions;
my @milestones = sort(keys %milestones);

$vars->{'product'} = \@selectable_products;

# Create data structures representing each classification
if (Bugzilla->params->{'useclassification'}) {
    $vars->{'classification'} = $user->get_selectable_classifications;
}

# We use 'component_' because 'component' is a Template Toolkit reserved word.
$vars->{'component_'} = \@components;

$vars->{'version'} = \@versions;

if (Bugzilla->params->{'usetargetmilestone'}) {
    $vars->{'target_milestone'} = \@milestones;
}

# Fields for boolean charts
my @fields = Bugzilla->get_fields({ obsolete => 0 });
@fields = sort {lc($a->description) cmp lc($b->description)} @fields;
$vars->{'fields'} = \@fields;

# "where one or more of the following changed:"
# ---- vfilippov@custis.ru 2010-02-01
# This is much much more correct than Bugzilla::Bug::editable_bug_fields().
# We only need to exclude final and automatic fields.
# FIXME remove hardcode
my %exclude = map { $_ => 1 } qw(
    noop bug_id delta_ts creation_ts days_elapsed owner_idle_time
    everconfirmed percentage_complete
);
$vars->{'chfield'} = [ sort grep { !$exclude{$_} } map { $_->name } @fields ];

# Another hack...
unshift @{$vars->{fields}}, { name => "noop", description => "---" };

# Legal values for select fields
$vars->{'bug_status'} = Bugzilla::Field->new({name => 'bug_status'})->legal_values;
Bugzilla->params->{useplatform} and $vars->{'rep_platform'} = Bugzilla::Field->new({name => 'rep_platform'})->legal_values;
Bugzilla->params->{useopsys} and $vars->{'op_sys'} = Bugzilla::Field->new({name => 'op_sys'})->legal_values;
$vars->{'priority'} = Bugzilla::Field->new({name => 'priority'})->legal_values;
$vars->{'bug_severity'} = Bugzilla::Field->new({name => 'bug_severity'})->legal_values;
$vars->{'resolution'} = Bugzilla::Field->new({name => 'resolution'})->legal_values;

# If we're not in the time-tracking group, exclude time-tracking fields.
if (!Bugzilla->user->is_timetracker) {
    foreach my $tt_field (TIMETRACKING_FIELDS) {
        @{$vars->{fields}} = grep($_->name ne $tt_field, @{$vars->{fields}});
    }
}

# Boolean charts

# Creating new charts - if the cmd-add value is there, we define the field
# value so the code sees it and creates the chart. It will attempt to select
# "xyzzy" as the default, and fail. This is the correct behaviour.
foreach my $cmd (grep(/^cmd-/, $cgi->param)) {
    if ($cmd =~ /^cmd-add(\d+)-(\d+)-(\d+)$/) {
        $cgi->param(-name => "field$1-$2-$3", -value => "xyzzy");
    }
}

if (!$cgi->param('field0-0-0')) {
    $cgi->param(-name => 'field0-0-0', -value => "xyzzy");
}

# Create data structure of boolean chart info. It's an array of arrays of
# arrays - with the inner arrays having three members - field, type and
# value.
my @charts;
for (my $chart = 0; $cgi->param("field$chart-0-0"); $chart++) {
    my @rows;
    for (my $row = 0; $cgi->param("field$chart-$row-0"); $row++) {
        my @cols;
        for (my $col = 0; $cgi->param("field$chart-$row-$col"); $col++) {
            my $value = $cgi->param("value$chart-$row-$col");
            if (!defined($value)) {
                $value = '';
            }
            push(@cols, { field => $cgi->param("field$chart-$row-$col"),
                          type => $cgi->param("type$chart-$row-$col") || 'noop',
                          value => $value });
        }
        push(@rows, \@cols);
    }
    push(@charts, {'rows' => \@rows, 'negate' => scalar($cgi->param("negate$chart")) });
}

$default{'charts'} = \@charts;

# Named queries
if ($userid) {
     $vars->{'namedqueries'} = $dbh->selectcol_arrayref(
           "SELECT name FROM namedqueries " .
            "WHERE userid = ? AND name != ? " .
         "ORDER BY name",
         undef, ($userid, DEFAULT_QUERY_NAME));
}

# Sort order
my $deforder;
my @orders = ('Bug Number', 'Importance', 'Assignee', 'Last Changed');

if ($cgi->cookie('LASTORDER')) {
    $deforder = "Reuse same sort as last time";
    unshift(@orders, $deforder);
}

if ($cgi->param('order'))
{
    $deforder = $cgi->param('order');
    if (lsearch(\@orders, $deforder) < 0)
    {
        unshift @orders, $deforder;
    }
}

$vars->{'userdefaultquery'} = $userdefaultquery;
$vars->{'orders'} = \@orders;
$default{'order'} = [$deforder || 'Importance'];

if (($cgi->param('query_format') || $cgi->param('format') || "")
    eq "create-series") {
    require Bugzilla::Chart;
    $vars->{'category'} = Bugzilla::Chart::getVisibleSeries();
}

# CustIS Bug 58300 - Add custom fields to search filters
# This logic is moved from search/form.html.tmpl
$vars->{freetext_fields} = [
    Bugzilla::Field->new({ name => "longdesc" }),
    Bugzilla::Field->new({ name => "bug_file_loc" }),
];
if (Bugzilla->params->{usestatuswhiteboard})
{
    push @{$vars->{freetext_fields}}, Bugzilla::Field->new({ name => "status_whiteboard" });
}
push @{$vars->{freetext_fields}},
    grep { $_->type == FIELD_TYPE_TEXTAREA || $_->type == FIELD_TYPE_FREETEXT }
    Bugzilla->active_custom_fields;

if ($cgi->param('format') && $cgi->param('format') =~ /^report-(table|graph)$/) {
    # Get legal custom fields for tabular and graphical reports.
    my @custom_fields_for_reports =
      grep { $_->type == FIELD_TYPE_SINGLE_SELECT } Bugzilla->active_custom_fields;
    $vars->{'custom_fields'} = \@custom_fields_for_reports;
}

$vars->{'known_name'} = $cgi->param('known_name');
$vars->{'columnlist'} = $cgi->param('columnlist');


# Add in the defaults.
$vars->{'default'} = \%default;

$vars->{'format'} = $cgi->param('format');
$vars->{'query_format'} = $cgi->param('query_format');

# Set default page to "specific" if none provided
if (!($cgi->param('query_format') || $cgi->param('format'))) {
    if (defined $cgi->cookie('DEFAULTFORMAT')) {
        $vars->{'format'} = $cgi->cookie('DEFAULTFORMAT');
    } else {
        $vars->{'format'} = 'specific';
    }
}

# Set cookie to current format as default, but only if the format
# one that we should remember.
if (defined($vars->{'format'}) && IsValidQueryType($vars->{'format'})) {
    $cgi->send_cookie(-name => 'DEFAULTFORMAT',
                      -value => $vars->{'format'},
                      -expires => "Fri, 01-Jan-2038 00:00:00 GMT");
}

# Generate and return the UI (HTML page) from the appropriate template.
# If we submit back to ourselves (for e.g. boolean charts), we need to
# preserve format information; hence query_format taking priority over
# format.
my $format = $template->get_format("search/search", 
                                   $vars->{'query_format'} || $vars->{'format'}, 
                                   scalar $cgi->param('ctype'));

print $cgi->header($format->{'ctype'});

$template->process($format->{'template'}, $vars)
  || ThrowTemplateError($template->error());
