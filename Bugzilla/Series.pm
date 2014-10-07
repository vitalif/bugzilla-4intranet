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

use strict;

# This module implements a series - a set of data to be plotted on a chart.
#
# This Series is in the database if and only if self->{'series_id'} is defined.
# Note that the series being in the database does not mean that the fields of
# this object are the same as the DB entries, as the object may have been
# altered.

package Bugzilla::Series;

use Bugzilla::Error;
use Bugzilla::Util;

sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my ($param) = @_;

    my $self = bless {}, $class;

    if ($param =~ /^(\d+)$/so)
    {
        # We've been given a series_id, which should represent an existing Series.
        $self = $self->initFromDatabase($1);
    }
    else
    {
        $self->set_all($param);
    }

    return $self;
}

sub initFromDatabase
{
    my ($self, $series_id) = @_;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    detaint_natural($series_id) || ThrowCodeError("invalid_series_id", { series_id => $series_id });

    my $grouplist = $user->groups_as_string;

    my $rows = $dbh->selectall_arrayref(
        "SELECT s.series_id, cc1.name category, cc2.name subcategory, s.name," .
        " s.creator creator_id, s.frequency, s.query, s.is_public public," .
        " s.category category_id, s.subcategory subcategory_id" .
        " FROM series s" .
        " INNER JOIN series_categories cc1 ON s.category = cc1.id" .
        " INNER JOIN series_categories cc2 ON s.subcategory = cc2.id" .
        " LEFT JOIN category_group_map cgm ON s.category = cgm.category_id" .
        " AND cgm.group_id NOT IN ($grouplist) " .
        " WHERE s.series_id = ? AND (s.creator = ? OR (s.is_public = 1 AND cgm.category_id IS NULL))",
        {Slice=>{}}, $series_id, $user->id
    );

    if (@$rows)
    {
        %$self = %{$rows->[0]};
        return $self;
    }

    return undef;
}

sub set_all
{
    my $self = shift;
    my ($params) = @_;

    $self->{category} = $params->{category} || ThrowUserError("missing_category");
    $self->{subcategory} = $params->{subcategory} || ThrowUserError("missing_subcategory");
    $self->{name} = $params->{name} || ThrowUserError("missing_name");
    $self->{creator_id} = Bugzilla->user->id || undef;
    $self->{frequency} = $params->{frequency};
    detaint_natural($self->{frequency}) || ThrowUserError("missing_frequency");
    if (exists $params->{query})
    {
        $self->{query} = $params->{query};
        trick_taint($self->{query});
    }
    $self->{public} = 1 && $params->{public};

    $self->{series_id} ||= $self->existsInDatabase();
}

sub writeToDatabase {
    my $self = shift;

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    my $category_id = getCategoryID($self->{'category'});
    my $subcategory_id = getCategoryID($self->{'subcategory'});

    my $exists;
    if ($self->{'series_id'}) {
        $exists =
            $dbh->selectrow_array("SELECT series_id FROM series
                                   WHERE series_id = $self->{'series_id'}");
    }

    # Is this already in the database?
    if ($exists) {
        # Update existing series
        my $dbh = Bugzilla->dbh;
        $dbh->do("UPDATE series SET " .
                 "category = ?, subcategory = ?," .
                 "name = ?, frequency = ?, is_public = ?  " .
                 "WHERE series_id = ?", undef,
                 $category_id, $subcategory_id, $self->{'name'},
                 $self->{'frequency'}, $self->{'public'},
                 $self->{'series_id'});
    }
    else {
        # Insert the new series into the series table
        $dbh->do("INSERT INTO series (creator, category, subcategory, " .
                 "name, frequency, query, is_public) VALUES " .
                 "(?, ?, ?, ?, ?, ?, ?)", undef,
                 $self->{'creator_id'}, $category_id, $subcategory_id, $self->{'name'},
                 $self->{'frequency'}, $self->{'query'}, $self->{'public'});

        # Retrieve series_id
        $self->{'series_id'} = $dbh->selectrow_array("SELECT MAX(series_id) " .
                                                     "FROM series");
        $self->{'series_id'}
          || ThrowCodeError("missing_series_id", { 'series' => $self });
    }

    $dbh->bz_commit_transaction();
}

# Check whether a series with this name, category and subcategory exists in
# the DB and, if so, returns its series_id.
sub existsInDatabase {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $category_id = getCategoryID($self->{'category'});
    my $subcategory_id = getCategoryID($self->{'subcategory'});

    trick_taint($self->{'name'});
    my $series_id = $dbh->selectrow_array("SELECT series_id " .
                              "FROM series WHERE category = $category_id " .
                              "AND subcategory = $subcategory_id AND name = " .
                              $dbh->quote($self->{'name'}));

    return($series_id);
}

# Get a category or subcategory IDs, creating the category if it doesn't exist.
sub getCategoryID {
    my ($category) = @_;
    my $category_id;
    my $dbh = Bugzilla->dbh;

    # This seems for the best idiom for "Do A. Then maybe do B and A again."
    while (1) {
        # We are quoting this to put it in the DB, so we can remove taint
        trick_taint($category);

        $category_id = $dbh->selectrow_array("SELECT id " .
                                      "from series_categories " .
                                      "WHERE name =" . $dbh->quote($category));

        last if defined($category_id);

        $dbh->do("INSERT INTO series_categories (name) " .
                 "VALUES (" . $dbh->quote($category) . ")");
    }

    return $category_id;
}

##########
# Methods
##########
sub id   { return $_[0]->{'series_id'}; }
sub name { return $_[0]->{'name'}; }

sub creator {
    my $self = shift;

    if (!$self->{creator} && $self->{creator_id}) {
        require Bugzilla::User;
        $self->{creator} = new Bugzilla::User($self->{creator_id});
    }
    return $self->{creator};
}

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->do('DELETE FROM series WHERE series_id = ?', undef, $self->id);
}

1;
