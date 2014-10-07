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
#                 Lance Larsh <lance.larsh@oracle.com>
#                 Frédéric Buclin <LpSolit@gmail.com>

# Glossary:
# series:   An individual, defined set of data plotted over time.
# data set: What a series is called in the UI.
# line:     A set of one or more series, to be summed and drawn as a single
#           line when the series is plotted.
# chart:    A set of lines
#
# So when you select rows in the UI, you are selecting one or more lines, not
# series.

# Generic Charting TODO:
#
# JS-less chart creation - hard.
# Broken image on error or no data - need to do much better.
# Centralise permission checking, so Bugzilla->user->in_group('editbugs')
#   not scattered everywhere.
# User documentation :-)
#
# Bonus:
# Offer subscription when you get a "series already exists" error?

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Chart;
use Bugzilla::Series;
use Bugzilla::User;
use Bugzilla::Token;

local our $template = Bugzilla->template;
local our $vars = {};
my $ARGS = Bugzilla->input_params;
my $dbh = Bugzilla->dbh;

my $user = Bugzilla->login(LOGIN_REQUIRED);

if (!Bugzilla->feature('new_charts')) {
    ThrowCodeError('feature_disabled', { feature => 'new_charts' });
}

# Go back to query.cgi if we are adding a boolean chart parameter.
if (grep /^cmd-/, keys %$ARGS)
{
    delete $ARGS->{$_} for qw(format ctype action);
    $ARGS->{format} = $ARGS->{query_format};
    print Bugzilla->cgi->redirect('query.cgi?' . http_build_query($ARGS));
    exit;
}

my $action = $ARGS->{action};
my $series_id = $ARGS->{series_id};
$vars->{'doc_section'} = 'reporting.html#charts';

# Because some actions are chosen by buttons, we can't encode them as the value
# of the action param, because that value is localization-dependent. So, we
# encode it in the name, as "action-<action>". Some params even contain the
# series_id they apply to (e.g. subscribe, unsubscribe).
my @actions = grep /^action-/, keys %$ARGS;
if ($actions[0] && $actions[0] =~ /^action-([^\d]+)(\d*)$/) {
    $action = $1;
    $series_id = $2 if $2;
}

$action ||= "assemble";

# Go to buglist.cgi if we are doing a search.
if ($action eq "search") {
    delete $ARGS->{$_} for qw(format ctype action);
    my $params = http_build_query($ARGS);
    print Bugzilla->cgi->redirect("buglist.cgi" . ($params ? "?$params" : ""));
    exit;
}

$user->in_group(Bugzilla->params->{"chartgroup"})
  || ThrowUserError("auth_failure", {group  => Bugzilla->params->{"chartgroup"},
                                     action => "use",
                                     object => "charts"});

# Only admins may create public queries
$user->in_group('admin') || delete $ARGS->{public};

# All these actions relate to chart construction.
if ($action =~ /^(assemble|add|remove|sum|subscribe|unsubscribe)$/) {
    # These two need to be done before the creation of the Chart object, so
    # that the changes they make will be reflected in it.
    if ($action =~ /^subscribe|unsubscribe$/) {
        detaint_natural($series_id) || ThrowCodeError("invalid_series_id");
        my $series = new Bugzilla::Series($series_id);
        $series->$action($user->id);
    }

    my $chart = new Bugzilla::Chart($ARGS);

    if ($action =~ /^remove|sum$/) {
        $chart->$action(getSelectedLines());
    }
    elsif ($action eq "add") {
        my @series_ids = getAndValidateSeriesIDs();
        $chart->add(@series_ids);
    }

    view($chart);
}
elsif ($action eq "plot") {
    plot();
}
elsif ($action eq "wrap") {
    # For CSV "wrap", we go straight to "plot".
    if ($ARGS->{ctype} && $ARGS->{ctype} eq "csv") {
        plot();
    }
    else {
        wrap();
    }
}
elsif ($action eq "create") {
    assertCanCreate();
    check_hash_token($ARGS->{token}, ['create-series']);

    my $q = { %$ARGS };
    delete $q->{$_} for qw(series_id category newcategory subcategory newsubcategory name frequency public);
    my $series = new Bugzilla::Series({
        category => $ARGS->{category},
        subcategory => $ARGS->{subcategory},
        name => $ARGS->{name},
        frequency => $ARGS->{frequency},
        public => $ARGS->{public},
        query => http_build_query($q),
    });

    ThrowUserError("series_already_exists", {'series' => $series})
        if $series->existsInDatabase;

    $series->writeToDatabase();
    $vars->{'message'} = "series_created";
    $vars->{'series'} = $series;

    my $chart = new Bugzilla::Chart($ARGS);
    view($chart);
}
elsif ($action eq "edit") {
    my $series = assertCanEdit($series_id);
    edit($series);
}
elsif ($action eq "alter") {
    my $series = assertCanEdit($series_id);
    check_hash_token($ARGS->{token}, [ $series->id, $series->name ]);

    $series = new Bugzilla::Series($series_id);
    $series->set_all({
        category => $ARGS->{newcategory},
        subcategory => $ARGS->{newsubcategory},
        name => $ARGS->{name},
        frequency => $ARGS->{frequency},
        public => $ARGS->{public},
    });

    # We need to check if there is _another_ series in the database with
    # our (potentially new) name. So we call existsInDatabase() to see if
    # the return value is us or some other series we need to avoid stomping
    # on.
    my $id_of_series_in_db = $series->existsInDatabase();
    if (defined($id_of_series_in_db) && $id_of_series_in_db != $series->{'series_id'}) 
    {
        ThrowUserError("series_already_exists", {'series' => $series});
    }

    $series->writeToDatabase();
    $vars->{'changes_saved'} = 1;

    edit($series);
}
elsif ($action eq "confirm-delete") {
    $vars->{'series'} = assertCanEdit($series_id);
    $template->process("reports/delete-series.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
}
elsif ($action eq "delete") {
    my $series = assertCanEdit($series_id);
    check_hash_token($ARGS->{token}, [$series->id, $series->name]);

    $dbh->bz_start_transaction();

    $series->remove_from_db();
    # Remove (sub)categories which no longer have any series.
    foreach my $cat (qw(category subcategory)) {
        my $is_used = $dbh->selectrow_array("SELECT COUNT(*) FROM series WHERE $cat = ?",
                                             undef, $series->{"${cat}_id"});
        if (!$is_used) {
            $dbh->do('DELETE FROM series_categories WHERE id = ?',
                      undef, $series->{"${cat}_id"});
        }
    }
    $dbh->bz_commit_transaction();

    $vars->{'message'} = "series_deleted";
    $vars->{'series'} = $series;
    view();
}
elsif ($action eq "convert_search") {
    my $saved_search = $ARGS->{series_from_search} || '';
    my ($query) = grep { $_->name eq $saved_search } @{ $user->queries };
    my $url = '';
    if ($query) {
        my $params = http_decode_query($query->query);
        # These two parameters conflict with the one below.
        delete $params->{$_} for ('format', 'query_format');
        $url = '&amp;' . html_quote(http_build_query($params));
    }
    print Bugzilla->cgi->redirect(-location => correct_urlbase() . "query.cgi?format=create-series$url");
}
else {
    ThrowCodeError("unknown_action");
}

exit;

# Find any selected series and return either the first or all of them.
sub getAndValidateSeriesIDs {
    my @series_ids = grep(/^\d+$/, list Bugzilla->input_params->{name});

    return wantarray ? @series_ids : $series_ids[0];
}

# Return a list of IDs of all the lines selected in the UI.
sub getSelectedLines {
    my @ids = map { /^select(\d+)$/ ? $1 : () } keys %{ Bugzilla->input_params };

    return @ids;
}

# Check if the user is the owner of series_id or is an admin. 
sub assertCanEdit {
    my $series_id = shift;
    my $user = Bugzilla->user;

    my $series = new Bugzilla::Series($series_id)
      || ThrowCodeError('invalid_series_id');

    if (!$user->in_group('admin') && $series->{creator_id} != $user->id) {
        ThrowUserError('illegal_series_edit');
    }

    return $series;
}

# Check if the user is permitted to create this series with these parameters.
sub assertCanCreate {
    my $user = Bugzilla->user;

    $user->in_group("editbugs") || ThrowUserError("illegal_series_creation");

    # Check permission for frequency
    my $min_freq = 7;
    if (Bugzilla->input_params->{frequency} < $min_freq && !$user->in_group("admin")) {
        ThrowUserError("illegal_frequency", { 'minimum' => $min_freq });
    }
}

sub validateWidthAndHeight {
    $vars->{'width'} = Bugzilla->input_params->{width};
    $vars->{'height'} = Bugzilla->input_params->{height};

    if (defined($vars->{'width'})) {
       (detaint_natural($vars->{'width'}) && $vars->{'width'} > 0)
         || ThrowCodeError("invalid_dimensions");
    }

    if (defined($vars->{'height'})) {
       (detaint_natural($vars->{'height'}) && $vars->{'height'} > 0)
         || ThrowCodeError("invalid_dimensions");
    }

    # The equivalent of 2000 square seems like a very reasonable maximum size.
    # This is merely meant to prevent accidental or deliberate DOS, and should
    # have no effect in practice.
    if ($vars->{'width'} && $vars->{'height'}) {
       (($vars->{'width'} * $vars->{'height'}) <= 4000000)
         || ThrowUserError("chart_too_large");
    }
}

sub edit {
    my $series = shift;

    $vars->{'category'} = Bugzilla::Chart::getVisibleSeries();
    $vars->{'default'} = $series;

    $template->process("reports/edit-series.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
}

sub plot {
    validateWidthAndHeight();

    my $ARGS = Bugzilla->input_params;
    $vars->{'chart'} = new Bugzilla::Chart($ARGS);

    my $format = $template->get_format("reports/chart", "", $ARGS->{ctype});

    # Debugging PNGs is a pain; we need to be able to see the error messages
    if ($ARGS->{debug}) {
        Bugzilla->cgi->send_header();
        $vars->{chart}->dump();
    }

    Bugzilla->cgi->send_header($format->{'ctype'});
    disable_utf8() if ($format->{'ctype'} =~ /^image\//);

    $template->process($format->{'template'}, $vars)
      || ThrowTemplateError($template->error());
}

sub wrap {
    validateWidthAndHeight();
    
    my $chart = new Bugzilla::Chart(Bugzilla->input_params);
    
    $vars->{'time'} = localtime(time());

    my $q = { %{ Bugzilla->input_params } };
    delete $q->{$_} for qw(action action-wrap ctype format width height);
    $vars->{'imagebase'} = http_build_query($q);

    $template->process("reports/chart.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
}

sub view {
    my $chart = shift;

    my $ARGS = Bugzilla->input_params;
    # Set defaults
    foreach my $field ('category', 'subcategory', 'name', 'ctype') {
        $vars->{'default'}{$field} = $ARGS->{$field} || 0;
    }

    # Pass the state object to the display UI.
    $vars->{'chart'} = $chart;
    $vars->{'category'} = Bugzilla::Chart::getVisibleSeries();

    # If we have having problems with bad data, we can set debug=1 to dump
    # the data structure.
    $chart->dump() if $ARGS->{debug};

    $template->process("reports/create-chart.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
}
