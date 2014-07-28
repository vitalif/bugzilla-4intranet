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
# Contributor(s): Gervase Markham <gerv@gerv.net>
#                 <rdean@cambianetworks.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Field;
use Bugzilla::Search;

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};
my $buffer = $cgi->query_string();

# Go straight back to query.cgi if we are adding a boolean chart.
if (grep(/^cmd-/, $cgi->param())) {
    my $params = $cgi->canonicalise_query("format", "ctype");
    my $location = "query.cgi?format=" . $cgi->param('query_format') .
        ($params ? "&$params" : "");

    print $cgi->redirect($location);
    exit;
}

Bugzilla->login();

my $dbh = Bugzilla->switch_to_shadow_db();

my $action = $cgi->param('action') || 'menu';

if ($action eq "menu") {
    # No need to do any searching in this case, so bail out early.
    $template->process("reports/menu.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
    exit;
}

my $valid_columns = Bugzilla::Search::REPORT_COLUMNS();

my $field = {};
for (qw(x y z))
{
    my $f = $cgi->param($_.'_axis_field') || '';
    trick_taint($f);
    if ($f)
    {
        if ($valid_columns->{$f})
        {
            $field->{$_} = $f;
        }
        else
        {
            ThrowCodeError("report_axis_invalid", {fld => $_, val => $f});
        }
    }
}

if (!keys %$field) {
    ThrowUserError("no_axes_defined");
}

my $width = $cgi->param('width');
my $height = $cgi->param('height');

if (defined($width)) {
    (detaint_natural($width) && $width > 0)
      || ThrowCodeError("invalid_dimensions");
    $width <= 2000 || ThrowUserError("chart_too_large");
}

if (defined($height)) {
    (detaint_natural($height) && $height > 0)
      || ThrowCodeError("invalid_dimensions");
    $height <= 2000 || ThrowUserError("chart_too_large");
}

# These shenanigans are necessary to make sure that both vertical and
# horizontal 1D tables convert to the correct dimension when you ask to
# display them as some sort of chart.
if (defined $cgi->param('format') && $cgi->param('format') =~ /^(table|simple)$/) {
    if ($field->{x} && !$field->{y}) {
        # 1D *tables* should be displayed vertically (with a row_field only)
        $field->{y} = $field->{x};
        delete $field->{x};
    }
}
else {
    if (!Bugzilla->feature('graphical_reports')) {
        ThrowCodeError('feature_disabled', { feature => 'graphical_reports' });
    }

    if ($field->{y} && !$field->{x}) {
        # 1D *charts* should be displayed horizontally (with an col_field only)
        $field->{x} = $field->{y};
        delete $field->{y};
    }
}

my $measures = {
    etime => 'estimated_time',
    rtime => 'remaining_time',
    wtime => 'interval_time',
    count => '_count',
};
# Trick Bugzilla::Search by adding '_count' column
Bugzilla::Search->COLUMNS->{_count}->{name} = '1';

my $measure = $cgi->param('measure');
$measure = 'count' unless $measures->{$measure};
$vars->{measure} = $measure;

# Validate the values in the axis fields or throw an error.
my %a;
my @group_by = grep { !($a{$_}++) } values %$field;
my @axis_fields = @group_by;
push @axis_fields, $measures->{$measure} unless $a{$measures->{$measure}};

# Clone the params, so that Bugzilla::Search can modify them
my $params = new Bugzilla::CGI($cgi);
my $search = new Bugzilla::Search(
    'fields' => \@axis_fields,
    'params' => $params,
);
my $query = $search->getSQL();
$query =
    "SELECT ".
    ($field->{x} || "''")." x, ".
    ($field->{y} || "''")." y, ".
    ($field->{z} || "''")." z, ".
    "SUM(".$measures->{$measure}.") r FROM ($query) _report_table GROUP BY ".join(", ", @group_by);

$::SIG{TERM} = 'DEFAULT';
$::SIG{PIPE} = 'DEFAULT';

my $results = $dbh->selectall_arrayref($query, {Slice=>{}});

# We have a hash of hashes for the data itself, and a hash to hold the
# row/col/table names.
my %data;
my %names;

# Read the bug data and count the bugs for each possible value of row, column
# and table.
#
# We detect a numerical field, and sort appropriately, if all the values are
# numeric.
my %isnumeric;

foreach my $group (@$results)
{
    for (qw(x y z))
    {
        $isnumeric{$_} &&= ($group->{$_} =~ /^-?\d+(\.\d+)?$/o);
        $names{$_}{$group->{$_}} = 1;
    }
    $data{$group->{z}}{$group->{x}}{$group->{y}} = $group->{r};
}

my @tbl_names = @{get_names($names{z}, $isnumeric{z}, $field->{z})};
my @col_names = @{get_names($names{x}, $isnumeric{x}, $field->{x})};
my @row_names = @{get_names($names{y}, $isnumeric{y}, $field->{y})};

# The GD::Graph package requires a particular format of data, so once we've
# gathered everything into the hashes and made sure we know the size of the
# data, we reformat it into an array of arrays of arrays of data.
push(@tbl_names, "-total-") if (scalar(@tbl_names) > 1);

my @image_data;
foreach my $tbl (@tbl_names) {
    my @tbl_data;
    push(@tbl_data, \@col_names);
    foreach my $row (@row_names) {
        my @col_data;
        foreach my $col (@col_names) {
            $data{$tbl}{$col}{$row} = $data{$tbl}{$col}{$row} || 0;
            push(@col_data, $data{$tbl}{$col}{$row});
            if ($tbl ne "-total-") {
                # This is a bit sneaky. We spend every loop except the last
                # building up the -total- data, and then last time round,
                # we process it as another tbl, and push() the total values
                # into the image_data array.
                $data{"-total-"}{$col}{$row} += $data{$tbl}{$col}{$row};
            }
        }

        push(@tbl_data, \@col_data);
    }

    unshift(@image_data, \@tbl_data);
}

$vars->{'tbl_field'} = $field->{z};
$vars->{'col_field'} = $field->{x};
$vars->{'row_field'} = $field->{y};
$vars->{'time'} = localtime(time());

$vars->{'col_names'} = \@col_names;
$vars->{'row_names'} = \@row_names;
$vars->{'tbl_names'} = \@tbl_names;

# Below a certain width, we don't see any bars, so there needs to be a minimum.
if ($width && $cgi->param('format') eq "bar") {
    my $min_width = (scalar(@col_names) || 1) * 20;

    if (!$cgi->param('cumulate')) {
        $min_width *= (scalar(@row_names) || 1);
    }

    $vars->{'min_width'} = $min_width;
}

$vars->{'width'} = $width if $width;
$vars->{'height'} = $height if $height;

$vars->{'query'} = $query;
$vars->{'debug'} = $cgi->param('debug');

my $formatparam = $cgi->param('format');

if ($action eq "wrap") {
    # So which template are we using? If action is "wrap", we will be using
    # no format (it gets passed through to be the format of the actual data),
    # and either report.csv.tmpl (CSV), or report.html.tmpl (everything else).
    # report.html.tmpl produces an HTML framework for either tables of HTML
    # data, or images generated by calling report.cgi again with action as
    # "plot".
    $formatparam =~ s/[^a-zA-Z\-]//g;
    trick_taint($formatparam);
    $vars->{'format'} = $formatparam;
    $formatparam = '' if $formatparam ne 'simple';

    # We need to keep track of the defined restrictions on each of the
    # axes, because buglistbase, below, throws them away. Without this, we
    # get buglistlinks wrong if there is a restriction on an axis field.
    $vars->{'col_vals'} = join("&", $buffer =~ /[&?]($field->{x}=[^&]+)/g);
    $vars->{'row_vals'} = join("&", $buffer =~ /[&?]($field->{y}=[^&]+)/g);
    $vars->{'tbl_vals'} = join("&", $buffer =~ /[&?]($field->{z}=[^&]+)/g);

    # We need a number of different variants of the base URL for different
    # URLs in the HTML.
    $vars->{buglistbase} = $cgi->canonicalise_query(
        qw(x_axis_field y_axis_field z_axis_field ctype format query_format
        measure), @axis_fields
    );
    $vars->{imagebase} = $cgi->canonicalise_query(
        $field->{z}, qw(action ctype format width height),
    );
    $vars->{switchbase} = $cgi->canonicalise_query(
        qw(query_format action ctype format width height measure)
    );
    $vars->{data} = \%data;
}
elsif ($action eq "plot") {
    # If action is "plot", we will be using a format as normal (pie, bar etc.)
    # and a ctype as normal (currently only png.)
    $vars->{'cumulate'} = $cgi->param('cumulate') ? 1 : 0;
    $vars->{'x_labels_vertical'} = $cgi->param('x_labels_vertical') ? 1 : 0;
    $vars->{'data'} = \@image_data;
}
else {
    ThrowCodeError("unknown_action", {action => $cgi->param('action')});
}

my $format = $template->get_format("reports/report", $formatparam,
                                   scalar($cgi->param('ctype')));

# If we get a template or CGI error, it comes out as HTML, which isn't valid
# PNG data, and the browser just displays a "corrupt PNG" message. So, you can
# set debug=1 to always get an HTML content-type, and view the error.
$format->{'ctype'} = "text/html" if $cgi->param('debug');

my @time = localtime(time());
my $date = sprintf "%04d-%02d-%02d", 1900+$time[5],$time[4]+1,$time[3];
my $filename = "report-$date.$format->{extension}";
$cgi->send_header(-type => $format->{'ctype'},
                  -content_disposition => "inline; filename=$filename");

# Problems with this CGI are often due to malformed data. Setting debug=1
# prints out both data structures.
if ($cgi->param('debug')) {
    require Data::Dumper;
    print "<pre>data hash:\n";
    print html_quote(Data::Dumper::Dumper(%data)) . "\n\n";
    print "data array:\n";
    print html_quote(Data::Dumper::Dumper(@image_data)) . "\n\n</pre>";
}

# All formats point to the same section of the documentation.
$vars->{'doc_section'} = 'reporting.html#reports';

disable_utf8() if ($format->{'ctype'} =~ /^image\//);

$template->process("$format->{'template'}", $vars)
  || ThrowTemplateError($template->error());

exit;

sub get_names
{
    my ($names, $isnumeric, $field) = @_;

    # These are all the fields we want to preserve the order of in reports.
    my $f = Bugzilla->get_field($field);
    if ($f && $f->is_select)
    {
        my $values = [ '', map { $_->name } @{ $f->legal_values(1) } ];
        my %dup;
        @$values = grep { exists($names->{$_}) && !($dup{$_}++) } @$values;
        return $values;
    }
    elsif ($isnumeric)
    {
        # It's not a field we are preserving the order of, so sort it
        # numerically...
        sub numerically { $a <=> $b }
        return [ sort numerically keys %$names ];
    }
    else
    {
        # ...or alphabetically, as appropriate.
        return [ sort keys %$names ];
    }
}
