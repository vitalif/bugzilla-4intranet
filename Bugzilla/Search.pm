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
#                 Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Stephan Niemz <st.n@gmx.net>
#                 Andreas Franke <afranke@mathweb.org>
#                 Myk Melez <myk@mozilla.org>
#                 Michael Schindler <michael@compressconsult.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Joel Peshkin <bugreport@peshkin.net>
#                 Lance Larsh <lance.larsh@oracle.com>
#                 Jesse Clark <jjclark1982@gmail.com>
#                 Rémi Zara <remi_zara@mac.com>

use strict;

package Bugzilla::Search;
use base qw(Exporter);
@Bugzilla::Search::EXPORT = qw(
    EMPTY_COLUMN

    split_order_term
    translate_old_column
);

use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::Field;
use Bugzilla::Status;
use Bugzilla::Keyword;
use Bugzilla::Search::Saved;

use Date::Format;
use Date::Parse;

# A SELECTed expression that we use as a placeholder if somebody selects
# <none> for the X, Y, or Z axis in report.cgi.
use constant EMPTY_COLUMN => '-1';

# Some fields are not sorted on themselves, but on other fields.
# We need to have a list of these fields and what they map to.
# Each field points to an array that contains the fields mapped
# to, in order.
# Also when we add certain fields to the ORDER BY, we need to then add a
# table join to the FROM statement. This hash maps input fields to
# the join statements that need to be added.
sub SPECIAL_ORDER
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{special_order} if $cache->{special_order};
    my $special_order = {
        'target_milestone' => {
            fields => [ 'ms_order.sortkey', 'ms_order.value' ],
            joins  => [ 'LEFT JOIN milestones AS ms_order ON ms_order.value = bugs.target_milestone AND ms_order.product_id = bugs.product_id' ],
        },
    };
    my @select_fields = Bugzilla->get_fields({ type => FIELD_TYPE_SINGLE_SELECT });
    foreach my $field (@select_fields)
    {
        next if $field->name eq 'product' ||
            $field->name eq 'component' ||
            $field->name eq 'classification';
        my $type = Bugzilla::Field::Choice->type($field);
        my $name = $type->DB_TABLE;
        $special_order->{$field->name} = {
            fields => [ map { "$name.$_" } split /\s*,\s*/, $type->LIST_ORDER ],
            joins  => [ "LEFT JOIN $name ON $name.".$type->NAME_FIELD." = bugs.".$field->name ],
        };
    }
    Bugzilla::Hook::process('search_special_order', { columns => $special_order });
    return $cache->{special_order} = $special_order;
}

# Backward-compatibility for old field names. Goes old_name => new_name.
sub COLUMN_ALIASES
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{column_aliases} if $cache->{column_aliases};
    my $COLUMN_ALIASES = {
        opendate => 'creation_ts',
        changeddate => 'delta_ts',
        actual_time => 'work_time',
        '[Bug creation]' => 'creation_ts',
    };
    Bugzilla::Hook::process('search_column_aliases', { aliases => $COLUMN_ALIASES });
    return $cache->{column_aliases} = $COLUMN_ALIASES;
}

# STATIC_COLUMNS and COLUMNS define the columns that can be selected in a query
# and/or displayed in a bug list. These are hashes of hashes. The key is field
# name, and the value is a hash with following data:
#
# FIXME change hash key names (id -> name, name -> sql, subid -> subname)
# 1. id: equals to the key of outer hash (field name).
# 2. name: SQL code for field value.
# 3. joins: arrayref of table join SQL code needed to use this value.
# 4. title: The title of the column as displayed to users.
# 5. nobuglist: 1 for fields that cannot be displayed in bug list.
# 6. nocharts: 1 for fields that cannot be used in Boolean Charts.
#
# STATIC_COLUMNS is a constant and is freely cached between requests.
# COLUMNS is a subroutine that takes STATIC_COLUMNS, copies the hash,
# modifies it for the needs of current request and caches once per request.
# I.e. it removes time-tracking fields for non-timetrackers etc.

sub STATIC_COLUMNS
{
    my $dbh = Bugzilla->dbh;
    my $cache = Bugzilla->cache_fields;
    return $cache->{columns} if $cache->{columns};

    # ---- vfilippov@custis.ru 2010-02-02
    # The previous sql code:
    # "(SUM(ldtime.work_time) * COUNT(DISTINCT ldtime.bug_when)/COUNT(bugs.bug_id))"
    # was probably written by Australopithecus.
    my $actual_time = '(SELECT SUM(ldtime.work_time) FROM longdescs ldtime WHERE ldtime.bug_id=bugs.bug_id)';

    my %columns = (
        relevance            => { title => 'Relevance' },
        assigned_to_realname => { title => 'Assignee', nocharts => 1 },
        reporter_realname    => { title => 'Reporter', nocharts => 1 },
        qa_contact_realname  => { title => 'QA Contact', nocharts => 1 },
        deadline => { name => $dbh->sql_date_format('bugs.deadline', '%Y-%m-%d') },
        work_time => { name => $actual_time },
        percentage_complete => {
            name => "(CASE WHEN $actual_time + bugs.remaining_time = 0.0 THEN 0.0" .
                " ELSE 100 * ($actual_time / ($actual_time + bugs.remaining_time)) END)",
        },
        'flagtypes.name' => {
            name => $dbh->sql_group_concat('DISTINCT ' . $dbh->sql_string_concat('flagtypes.name', 'flags.status'), "', '"),
            joins => [
                "LEFT JOIN flags ON flags.bug_id = bugs.bug_id AND attach_id IS NULL",
                "LEFT JOIN flagtypes ON flagtypes.id = flags.type_id"
            ],
        },
    );

    # Fields that are email addresses
    my @email_fields = qw(assigned_to reporter qa_contact);

    foreach my $col (@email_fields)
    {
        my $sql = "map_${col}.login_name";
        if (!Bugzilla->user->id)
        {
            $sql = $dbh->sql_string_until($sql, $dbh->quote('@'));
        }
        $columns{$col.'_realname'}{name} = "map_${col}.realname";
        $columns{$col}{name} = $sql;
        $columns{$col}{joins} = $columns{"${col}_realname"}{joins} =
            [ "LEFT JOIN profiles AS map_$col ON bugs.$col = map_$col.userid" ];
    }

    # Other fields that are stored in the bugs table as an id, but
    # should be displayed using their name.
    my @id_fields = qw(product component classification);

    foreach my $col (@id_fields)
    {
        $columns{$col}{name} = "map_${col}s.name";
        $columns{$col}{joins} = [
            "INNER JOIN ${col}s AS map_${col}s ON ".
            ($col eq 'classification' ? "map_products" : "bugs").
            ".${col}_id = map_${col}s.id"
        ];
        if ($col eq 'classification')
        {
            unshift @{$columns{$col}{joins}}, @{$columns{product}{joins}};
        }
    }

    # Do the actual column-getting from fielddefs, now.
    my @bugsjoin;
    foreach my $field (Bugzilla->get_fields)
    {
        my $id = $field->name;
        $columns{$id}{name} ||= 'bugs.' . $field->name;
        $columns{$id}{title} = $field->description;
        $columns{$id}{nobuglist} = !$field->buglist;
        if ($field->type == FIELD_TYPE_BUG_ID)
        {
            push @bugsjoin, $field;
        }
    }

    # Fields of bugs related to selected
    foreach my $field (@bugsjoin)
    {
        my $id = $field->name;
        my $join = [ "LEFT JOIN bugs bugs_$id ON bugs_$id.bug_id=bugs.$id" ];
        foreach my $subfield (Bugzilla->get_fields({ obsolete => 0, buglist => 1 }))
        {
            my $subid = $subfield->name;
            if ($columns{$subid}{name} eq "bugs.$subid")
            {
                $columns{$id.'_'.$subid} = {
                    name  => "bugs_$id.".$subfield->name,
                    title => $field->description . ' ' . $subfield->description,
                    joins => $join,
                    subid => $subid,
                };
            }
        }
    }

    # short_short_desc is short_desc truncated to 60 characters
    # see template list/table.html.tmpl
    $columns{short_short_desc} = $columns{short_desc};

    Bugzilla::Hook::process('buglist_static_columns', { columns => \%columns });

    $columns{$_}{id} = $_ for keys %columns;

    $cache->{columns} = \%columns;
    return $cache->{columns};
}

# Copy and modify STATIC_COLUMNS for current user / request
sub COLUMNS
{
    my $cache = Bugzilla->rc_cache_fields;
    return $cache->{columns} if $cache->{columns};
    my %columns = %{ STATIC_COLUMNS() };
    if (!Bugzilla->user->is_timetracker)
    {
        delete $columns{$_} for TIMETRACKING_FIELDS;
    }
    Bugzilla::Hook::process('buglist_columns', { columns => \%columns });
    return $cache->{columns} = \%columns;
}

# This is now used only by query.cgi
sub CHANGEDFROMTO_FIELDS
{
    # creation_ts, longdesc, longdescs.isprivate, commenter
    # are treated specially and always have has_activity
    # (see install_update_fielddefs CustIS hook)
    my @fields = grep { $_->{name} } Bugzilla->get_fields({ has_activity => 1 });
    if (!Bugzilla->user->is_timetracker)
    {
        my %tt_fields = map { $_ => 1 } TIMETRACKING_FIELDS;
        @fields = grep { !$tt_fields{$_->name} } @fields;
    }
    return \@fields;
}

# Create a new Bugzilla::Search object
# Note that the param argument may be modified by Bugzilla::Search
sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $self = { @_ };
    bless($self, $class);

    $self->init();

    return $self;
}

sub init
{
    my $self = shift;
    my @fields = @{ $self->{'fields'} || [] };
    my $params = $self->{'params'};
    $params->convert_old_params();
    $self->{'user'} ||= Bugzilla->user;
    my $user = $self->{'user'};

    my @inputorder = @{ $self->{'order'} || [] };
    my @orderby;

    my @supptables;
    my @wherepart;
    my @having;
    my @groupby;
    my @specialchart;
    my @andlist;

    my $special_order = SPECIAL_ORDER();

    my @multi_select_fields = Bugzilla->get_fields({
        type     => [FIELD_TYPE_MULTI_SELECT, FIELD_TYPE_BUG_URLS],
        obsolete => 0 });

    my $dbh = Bugzilla->dbh;

    for (@fields)
    {
        $_ = COLUMN_ALIASES->{$_} if COLUMN_ALIASES->{$_};
    }

    # All items that are in the ORDER BY must be in the SELECT.
    foreach my $orderitem (@inputorder)
    {
        my $column_name = split_order_term($orderitem);
        $column_name = COLUMN_ALIASES->{$_} if COLUMN_ALIASES->{$_};
        if (!grep($_ eq $column_name, @fields))
        {
            push @fields, $column_name;
        }
    }

    # Add table joins
    for my $field (@fields)
    {
        for (@{ COLUMNS->{$field}->{joins} || [] })
        {
            push @supptables, $_ if lsearch(\@supptables, $_) < 0;
        }
    }

    # First, deal with all the old hard-coded non-chart-based poop.
    my $minvotes;
    if (defined $params->param('votes')) {
        my $c = trim($params->param('votes'));
        if ($c ne "") {
            if ($c !~ /^[0-9]*$/) {
                ThrowUserError("illegal_at_least_x_votes",
                                  { value => $c });
            }
            push(@specialchart, ["votes", "greaterthan", $c - 1]);
        }
    }

    # If the user has selected all of either status or resolution, change to
    # selecting none. This is functionally equivalent, but quite a lot faster.
    # Also, if the status is __open__ or __closed__, translate those
    # into their equivalent lists of open and closed statuses.
    if ($params->param('bug_status')) {
        my @bug_statuses = $params->param('bug_status');
        # Also include inactive bug statuses, as you can query them.
        my @legal_statuses =
            map {$_->name} @{Bugzilla->get_field('bug_status')->legal_values};

        # Filter out any statuses that have been removed completely that are still
        # being used by the client
        my @valid_statuses;
        foreach my $status (@bug_statuses) {
            push(@valid_statuses, $status) if grep($_ eq $status, @legal_statuses);
        }

        if (scalar(@valid_statuses) == scalar(@legal_statuses)
            || $bug_statuses[0] eq "__all__")
        {
            $params->delete('bug_status');
        }
        elsif ($bug_statuses[0] eq '__open__') {
            $params->param('bug_status', grep(is_open_state($_),
                                              @legal_statuses));
        }
        elsif ($bug_statuses[0] eq "__closed__") {
            $params->param('bug_status', grep(!is_open_state($_),
                                              @legal_statuses));
        }
        else {
            $params->param('bug_status', @valid_statuses);
        }
    }

    if ($params->param('resolution')) {
        my @resolutions = $params->param('resolution');
        # Also include inactive resolutions, as you can query them.
        my $legal_resolutions = Bugzilla->get_field('resolution')->legal_values;
        if (scalar(@resolutions) == scalar(@$legal_resolutions)) {
            $params->delete('resolution');
        }
    }

    # All fields that don't have a . in their name should be specifyable
    # in the URL directly.
    my @legal_fields = grep { $_->name !~ /\./ } Bugzilla->get_fields;
    if (!$user->is_timetracker) {
        foreach my $field (TIMETRACKING_FIELDS) {
            @legal_fields = grep { $_->name ne $field } @legal_fields;
        }
    }

    foreach my $field ($params->param())
    {
        # "votes" got special treatment, above.
        next if $field eq 'votes';
        if (grep { $_->name eq $field } @legal_fields)
        {
            my $type = $params->param("${field}_type");
            my $values = [ $params->param($field) ];
            next if !join '', @$values;
            $values = join ',', @$values;
            if (!$type || $field eq 'content')
            {
                if ($field eq 'keywords')
                {
                    $type = 'anywords';
                }
                elsif ($field eq 'content')
                {
                    $type = 'matches';
                }
                elsif ($field eq 'bug_id')
                {
                    $type = 'anyexact';
                    $values = [ map { /(\d+)/gso } $params->param($field) ];
                }
                else
                {
                    $type = 'anyexact';
                    $values = [ $params->param($field) ];
                }
            }
            push @specialchart, [$field, $type, $values];
        }
    }

    foreach my $id ("1", "2") {
        if (!defined ($params->param("email$id"))) {
            next;
        }
        my $email = trim($params->param("email$id"));
        if ($email eq "") {
            next;
        }
        my $type = $params->param("emailtype$id");
        $type = "anyexact" if ($type eq "exact");

        my @clist;
        foreach my $field ("assigned_to", "reporter", "cc", "qa_contact") {
            if ($params->param("email$field$id")) {
                push(@clist, $field, $type, $email);
            }
        }
        if ($params->param("emaillongdesc$id")) {
            push(@clist, "commenter", $type, $email);
        }
        if (@clist) {
            push(@specialchart, \@clist);
        }
        else {
            # No field is selected. Nothing to see here.
            next;
        }

        if ($type eq "anyexact") {
            foreach my $name (split(',', $email)) {
                $name = trim($name);
                login_to_id($name, THROW_ERROR) if $name && lc $name ne '%user%';
            }
        }
    }

    $Bugzilla::Search::interval_from = undef;
    $Bugzilla::Search::interval_to = undef;
    $Bugzilla::Search::interval_who = undef;

    my $chfieldfrom = trim(lc($params->param('chfieldfrom') || ''));
    my $chfieldto = trim(lc($params->param('chfieldto') || ''));
    $chfieldfrom = '' if ($chfieldfrom eq 'now');
    $chfieldto = '' if ($chfieldto eq 'now');
    my @chfield = $params->param('chfield');
    $_ = COLUMN_ALIASES->{$_} || $_ for @chfield;
    my $chvalue = trim($params->param('chfieldvalue')) || '';

    # 2003-05-20: The 'changedin' field is no longer in the UI, but we continue
    # to process it because it will appear in stored queries and bookmarks.
    my $changedin = trim($params->param('changedin')) || '';
    if ($changedin) {
        if ($changedin !~ /^[0-9]*$/) {
            ThrowUserError("illegal_changed_in_last_x_days",
                              { value => $changedin });
        }

        if (!$chfieldfrom
            && !$chfieldto
            && scalar(@chfield) == 1
            && $chfield[0] eq 'creation_ts')
        {
            # Deal with the special case where the query is using changedin
            # to get bugs created in the last n days by converting the value
            # into its equivalent for the chfieldfrom parameter.
            $chfieldfrom = "-" . ($changedin - 1) . "d";
        }
        else {
            # Oh boy, the general case.  Who knows why the user included
            # the changedin parameter, but do our best to comply.
            push(@specialchart, ["changedin", "lessthan", $changedin + 1]);
        }
    }

    if ($chfieldfrom ne '' || $chfieldto ne '')
    {
        my $sql_chfrom = $chfieldfrom ? $dbh->quote(SqlifyDate($chfieldfrom)):'';
        my $sql_chto   = $chfieldto   ? $dbh->quote(SqlifyDate($chfieldto))  :'';
        my $who_term;

        # do a match on user login or name
        my $chfieldwho = trim(lc($params->param('chfieldwho') || ''));
        if ($chfieldwho)
        {
            $chfieldwho = $chfieldwho eq '%user%' ? $user : Bugzilla::User::match($chfieldwho, 1)->[0];
            if ($chfieldwho)
            {
                $Bugzilla::Search::interval_who = $chfieldwho;
                $chfieldwho = $chfieldwho->id;
                $who_term = " AND actcheck.who=$chfieldwho";
            }
        }

        # CustIS Bug 68921 - a dirty hack: "interval worktime" column
        $Bugzilla::Search::interval_from = SqlifyDate($chfieldfrom);
        $Bugzilla::Search::interval_to = SqlifyDate($chfieldto);
        COLUMNS->{interval_time}->{name} =
            "(SELECT COALESCE(SUM(ldtime.work_time),0) FROM longdescs ldtime".
            " WHERE ldtime.bug_id=bugs.bug_id".
            ($sql_chfrom?" AND ldtime.bug_when>=$sql_chfrom":"").
            ($sql_chto  ?" AND ldtime.bug_when<=$sql_chto":"").
            ($chfieldwho?" AND ldtime.who=$chfieldwho":"").
            ")";

        my $sql_chvalue = $chvalue ne '' ? $dbh->quote($chvalue) : '';
        trick_taint($sql_chvalue);
        my $from_term  = " AND actcheck.bug_when >= $sql_chfrom";
        my $to_term    = " AND actcheck.bug_when <= $sql_chto";
        my $value_term = " AND actcheck.added = $sql_chvalue";
        # ---- vfilippov@custis.ru 2010-02-01
        # Search using bugs.delta_ts is not correct. It's "LAST changed in", not "Changed in".
        my $bug_creation_clause;
        my @list;
        my @actlist;
        my $seen_longdesc;
        my $need_commenter;
        foreach my $f (@chfield)
        {
            my $term;
            if ($f eq 'creation_ts')
            {
                # Treat creation_ts (and [Bug creation] through aliases)
                # differently because we need to look
                # at bugs.creation_ts rather than the bugs_activity table.
                my @l;
                if ($sql_chfrom) {
                    my $term = "bugs.creation_ts >= $sql_chfrom";
                    push(@l, $term);
                    $self->search_description({
                        field => 'creation_ts', type => 'greaterthaneq',
                        value => $chfieldfrom, term => $term,
                    });
                }
                if ($sql_chto) {
                    my $term = "bugs.creation_ts <= $sql_chto";
                    push(@l, $term);
                    $self->search_description({
                        field => 'creation_ts', type => 'lessthaneq',
                        value => $chfieldto, term => $term,
                    });
                }
                $bug_creation_clause = "(" . join(' AND ', @l) . ")";
            }
            elsif ($f eq 'longdesc' || $f eq 'longdescs.isprivate' || $f eq 'commenter')
            {
                # Treat comment properties differently because we need to look at longdescs table.
                if ($sql_chvalue)
                {
                    if ($f eq 'longdesc' && !$seen_longdesc)
                    {
                        # User is searching for a comment with specific text,
                        # but that has no sense if $chvalue was already used for comment privacy.
                        $seen_longdesc = [ $term = "INSTR(actcheck_comment.thetext, $sql_chvalue) > 0" ];
                    }
                    elsif ($f eq 'commenter')
                    {
                        # User is searching for a comment with specific author
                        $need_commenter = $term = "actcheck_commenter.login_name = $sql_chvalue";
                        $value_term = " AND actcheck.who = (SELECT actcheck_profiles.userid FROM profiles actcheck_profiles WHERE actcheck_profiles.login_name = $sql_chvalue)";
                        $seen_longdesc = [];
                    }
                    elsif (!$seen_longdesc)
                    {
                        # User is searching for a private / non-private comment for specific period,
                        # but that has no sense if $chvalue was already used for comment text.
                        $seen_longdesc = [ $term = "actcheck_comment.isprivate = ".($chvalue ? 1 : 0) ];
                    }
                    if ($term)
                    {
                        $self->search_description({
                            field => $f, type => 'changedto',
                            value => $chvalue, term => $term,
                        });
                    }
                }
                else
                {
                    $seen_longdesc = [];
                }
            }
            else
            {
                push @actlist, get_field_id($f);
                $term = 1;
                if ($sql_chvalue)
                {
                    $self->search_description({
                        field => $f, type => 'changedto',
                        value => $chvalue, term => $value_term,
                    });
                }
            }
            if ($term)
            {
                if ($sql_chfrom)
                {
                    $self->search_description({
                        field => $f, type => 'changedafter',
                        value => $chfieldfrom, term => $from_term,
                    });
                }
                if ($sql_chto)
                {
                    $self->search_description({
                        field => $f, type => 'changedbefore',
                        value => $chfieldto, term => $to_term,
                    });
                }
                if ($chfieldwho)
                {
                    $self->search_description({
                        field => $f, type => 'changedby',
                        value => user_id_to_login($chfieldwho), term => $who_term,
                    });
                }
            }
        }

        if (!@chfield)
        {
            # Add search description for the case when no field was selected
            if ($sql_chfrom)
            {
                $self->search_description({
                    field => '', type => 'changedafter',
                    value => $chfieldfrom, term => $from_term,
                });
            }
            if ($sql_chto)
            {
                $self->search_description({
                    field => '', type => 'changedbefore',
                    value => $chfieldto, term => $to_term,
                });
            }
            if ($chfieldwho)
            {
                $self->search_description({
                    field => '', type => 'changedby',
                    value => user_id_to_login($chfieldwho), term => $who_term,
                });
            }
        }

        my $extra;
        if (!@chfield || @actlist)
        {
            $extra = "1=1";
            $extra .= $from_term  if $sql_chfrom;
            $extra .= $to_term    if $sql_chto;
            $extra .= $value_term if $sql_chvalue;
            $extra .= $who_term   if $who_term;

            if (@actlist)
            {
                # Restrict bug activity to selected fields
                $extra .= " AND " . $dbh->sql_in('actcheck.fieldid', \@actlist);
            }

            push @list, "SELECT bug_id FROM bugs_activity AS actcheck WHERE $extra";
        }

        # http://wiki.office.custis.ru/Bugzilla_-_оптимизация_поиска_по_изменениям
        if (!@chfield || $seen_longdesc)
        {
            $extra = "1=1";
            $extra .= " AND actcheck_comment.bug_when >= $sql_chfrom" if $sql_chfrom;
            $extra .= " AND actcheck_comment.bug_when <= $sql_chto" if $sql_chto;
            $extra .= " AND actcheck_comment.who = $chfieldwho" if $chfieldwho;
            if ($seen_longdesc && @$seen_longdesc)
            {
                $extra .= " AND ".$seen_longdesc->[0];
            }
            push @list,
                "SELECT bug_id FROM longdescs AS actcheck_comment" .
                ($need_commenter ?
                    " INNER JOIN profiles AS actcheck_commenter" .
                    " ON actcheck_commenter.userid=actcheck_comment.who AND $need_commenter" : '') .
                " WHERE $extra";
        }

        if ($bug_creation_clause)
        {
            push @list, "SELECT bug_id FROM bugs WHERE $bug_creation_clause";
        }

        if (@list == 1)
        {
            $list[0] =~ s/^SELECT/SELECT DISTINCT/;
        }

        push @supptables, "INNER JOIN (" . join(' UNION ', @list) . ") actcheck_union ON bugs.bug_id=actcheck_union.bug_id";
    }

    my $sql_deadlinefrom;
    my $sql_deadlineto;
    if ($user->is_timetracker) {
        if ($params->param('deadlinefrom')) {
            my $deadlinefrom = $params->param('deadlinefrom');
            $sql_deadlinefrom = $dbh->quote(SqlifyDate($deadlinefrom));
            trick_taint($sql_deadlinefrom);
            my $term = "bugs.deadline >= $sql_deadlinefrom";
            push(@wherepart, $term);
            $self->search_description({
                field => 'deadline', type => 'greaterthaneq',
                value => $deadlinefrom, term => $term,
            });
        }

        if ($params->param('deadlineto')) {
            my $deadlineto = $params->param('deadlineto');
            $sql_deadlineto = $dbh->quote(SqlifyDate($deadlineto));
            trick_taint($sql_deadlineto);
            my $term = "bugs.deadline <= $sql_deadlineto";
            push(@wherepart, $term);
            $self->search_description({
                field => 'deadline', type => 'lessthaneq',
                value => $deadlineto, term => $term,
            });
        }
    }

    my @textfields = ("short_desc", "longdesc", "bug_file_loc", "status_whiteboard");
    # CustIS Bug 58300 - Add custom fields to search filters
    push @textfields,
        map { $_->name }
        grep { $_->type == FIELD_TYPE_FREETEXT || $_->type == FIELD_TYPE_TEXTAREA }
        Bugzilla->active_custom_fields;
    foreach my $f (@textfields) {
        if (defined $params->param($f)) {
            my $s = trim($params->param($f));
            if ($s ne "") {
                my $n = $f;
                my $q = $dbh->quote($s);
                trick_taint($q);
                my $type = $params->param($f . "_type");
                push(@specialchart, [$f, $type, $s]);
            }
        }
    }

    my $multi_fields = join('|', map($_->name, @multi_select_fields));

    my $chartid;
    my $sequence = 0;
    my $f;
    my $ff;
    my $t;
    my $q;
    my $v;
    my $term;
    my %funcsbykey;
    my %func_args = (
        'chartid' => \$chartid,
        'sequence' => \$sequence,
        'f' => \$f,
        'ff' => \$ff,
        't' => \$t,
        'v' => \$v,
        'q' => \$q,
        'term' => \$term,
        'funcsbykey' => \%funcsbykey,
        'supptables' => \@supptables,
        'wherepart' => \@wherepart,
        'having' => \@having,
        'groupby' => \@groupby,
        'fields' => \@fields,
    );
    my @funcdefs = (
        "^(?:assigned_to|reporter|qa_contact),(?:notequals|equals|anyexact),%group\\.([^%]+)%" => \&_contact_exact_group,
        "^(?:assigned_to|reporter|qa_contact),(?:equals|anyexact),(%\\w+%)" => \&_contact_exact,
        "^(?:assigned_to|reporter|qa_contact),(?:notequals),(%\\w+%)" => \&_contact_notequals,
        "^(assigned_to|reporter),(?!changed)" => \&_assigned_to_reporter_nonchanged,
        "^qa_contact,(?!changed)" => \&_qa_contact_nonchanged,
        "^(?:cc),(?:notequals|equals|anyexact),%group\\.([^%]+)%" => \&_cc_exact_group,
        "^cc,(?:equals|anyexact),(%\\w+%)" => \&_cc_exact,
        "^cc,(?:notequals),(%\\w+%)" => \&_cc_notequals,
        "^cc,(?!changed)" => \&_cc_nonchanged,
        "^long_?desc,changedby" => \&_long_desc_changedby,
        "^long_?desc,changedbefore" => \&_long_desc_changedbefore_after,
        "^long_?desc,changedafter" => \&_long_desc_changedbefore_after,
        "^long_?desc,changedfrom" => \&_changedfrom_changedto,
        "^long_?desc,changedto" => \&_changedfrom_changedto,
        "^content,(?:not)?matches" => \&_content_matches,
        "^content," => sub { ThrowUserError("search_content_without_matches"); },
        "^(?:deadline|creation_ts|delta_ts),(?:lessthan|greaterthan|equals|notequals),(?:-|\\+)?(?:\\d+)(?:[dDwWmMyY])\$" => \&_timestamp_compare,
        "^commenter,(?:equals|anyexact),(%\\w+%)" => \&_commenter_exact,
        "^commenter," => \&_commenter,
        # The _ is allowed for backwards-compatibility with 3.2 and lower.
        "^long_?desc," => \&_long_desc,
        "^longdescs\.isprivate," => \&_longdescs_isprivate,
        "^work_time,changedby" => \&_work_time_changedby,
        "^work_time,changedbefore" => \&_work_time_changedbefore_after,
        "^work_time,changedafter" => \&_work_time_changedbefore_after,
        "^work_time,changedfrom" => \&_changedfrom_changedto,
        "^work_time,changedto" => \&_changedfrom_changedto,
        "^work_time," => \&_work_time,
        "^percentage_complete," => \&_percentage_complete,
        "^bug_group,(?!changed)" => \&_bug_group_nonchanged,
        "^attach_data\.thedata,changed" => \&_attach_data_thedata_changed,
        "^attach_data\.thedata," => \&_attach_data_thedata,
        "^attachments\.submitter," => \&_attachments_submitter,
        "^attachments\..*," => \&_attachments,
        "^flagtypes.name," => \&_flagtypes_name,
        "^requestees.login_name," => \&_requestees_login_name,
        "^setters.login_name," => \&_setters_login_name,
        "^(changedin|days_elapsed)," => \&_changedin_days_elapsed,
        "^component,(?!changed)" => \&_component_nonchanged,
        "^product,(?!changed)" => \&_product_nonchanged,
        "^classification,(?!changed)" => \&_classification_nonchanged,
        "^keywords,(?:equals|anyexact|anyword|allwords)" => \&_keywords_exact,
        "^keywords,(?:notequals|notregexp|notsubstring|nowords|nowordssubstr)" => \&_multiselect_negative,
        "^keywords,(?!changed)" => \&_keywords_nonchanged,
        "^dependson,(?!changed)" => \&_dependson_nonchanged,
        "^blocked,(?!changed)" => \&_blocked_nonchanged,
        "^alias,(?!changed)" => \&_alias_nonchanged,
        "^owner_idle_time,(greaterthan|lessthan)" => \&_owner_idle_time_greater_less,
        "^($multi_fields),(?:notequals|notregexp|notsubstring|nowords|nowordssubstr)" => \&_multiselect_negative,
        "^($multi_fields),(?:allwords|allwordssubstr|anyexact)" => \&_multiselect_multiple,
        "^($multi_fields),(?!changed)" => \&_multiselect_nonchanged,
        ",equals" => \&_equals,
        ",notequals" => \&_notequals,
        ",casesubstring" => \&_casesubstring,
        ",substring" => \&_substring,
        ",substr" => \&_substring,
        ",notsubstring" => \&_notsubstring,
        ",regexp" => \&_regexp,
        ",notregexp" => \&_notregexp,
        ",lessthan" => \&_lessthan,
        ",matches" => sub { ThrowUserError("search_content_without_matches"); },
        ",notmatches" => sub { ThrowUserError("search_content_without_matches"); },
        ",greaterthan" => \&_greaterthan,
        ",anyexact" => \&_anyexact,
        ",anywordssubstr" => \&_anywordsubstr,
        ",allwordssubstr" => \&_allwordssubstr,
        ",nowordssubstr" => \&_nowordssubstr,
        ",anywords" => \&_anywords,
        ",allwords" => \&_allwords,
        ",nowords" => \&_nowords,
        ",(changedbefore|changedafter)" => \&_changedbefore_changedafter,
        ",(changedfrom|changedto)" => \&_changedfrom_changedto,
        ",changedby" => \&_changedby,
        ",insearch" => \&_in_search_results,
        ",notinsearch" => \&_not_in_search_results,
    );
    my @funcnames;
    while (@funcdefs) {
        my $key = shift(@funcdefs);
        my $value = shift(@funcdefs);
        if ($key =~ /^[^,]*$/) {
            die "All defs in %funcs must have a comma in their name: $key";
        }
        if (exists $funcsbykey{$key}) {
            die "Duplicate key in %funcs: $key";
        }
        $funcsbykey{$key} = $value;
        push(@funcnames, $key);
    }

    # first we delete any sign of "Chart #-1" from the HTML form hash
    # since we want to guarantee the user didn't hide something here
    my @badcharts = grep /^(field|type|value)-1-/, $params->param();
    foreach my $field (@badcharts) {
        $params->delete($field);
    }

    # now we take our special chart and stuff it into the form hash
    my $chart = -1;
    my $row = 0;
    foreach my $ref (@specialchart) {
        my $col = 0;
        while (@$ref) {
            $params->param("field$chart-$row-$col", shift(@$ref));
            $params->param("type$chart-$row-$col", shift(@$ref));
            $params->param("value$chart-$row-$col", shift(@$ref));
            $col++;
        }
        $row++;
    }

    my $specialchart_terms;

# A boolean chart is a way of representing the terms in a logical
# expression.  Bugzilla builds SQL queries depending on how you enter
# terms into the boolean chart. Boolean charts are represented in
# urls as tree-tuples of (chart id, row, column). The query form
# (query.cgi) may contain an arbitrary number of boolean charts where
# each chart represents a clause in a SQL query.
#
# The query form starts out with one boolean chart containing one
# row and one column.  Extra rows can be created by pressing the
# AND button at the bottom of the chart.  Extra columns are created
# by pressing the OR button at the right end of the chart. Extra
# charts are created by pressing "Add another boolean chart".
#
# Each chart consists of an arbitrary number of rows and columns.
# The terms within a row are ORed together. The expressions represented
# by each row are ANDed together. The expressions represented by each
# chart are ANDed together.
#
#        ----------------------
#        | col2 | col2 | col3 |
# --------------|------|------|
# | row1 |  a1  |  a2  |      |
# |------|------|------|------|  => ((a1 OR a2) AND (b1 OR b2 OR b3) AND (c1))
# | row2 |  b1  |  b2  |  b3  |
# |------|------|------|------|
# | row3 |  c1  |      |      |
# -----------------------------
#
#        --------
#        | col2 |
# --------------|
# | row1 |  d1  | => (d1)
# ---------------
#
# Together, these two charts represent a SQL expression like this
# SELECT blah FROM blah WHERE ( (a1 OR a2)AND(b1 OR b2 OR b3)AND(c1)) AND (d1)
#
# The terms within a single row of a boolean chart are all constraints
# on a single piece of data.  If you're looking for a bug that has two
# different people cc'd on it, then you need to use two boolean charts.
# This will find bugs with one CC matching 'foo@blah.org' and and another
# CC matching 'bar@blah.org'.
#
# --------------------------------------------------------------
# CC    | equal to
# foo@blah.org
# --------------------------------------------------------------
# CC    | equal to
# bar@blah.org
#
# If you try to do this query by pressing the AND button in the
# original boolean chart then what you'll get is an expression that
# looks for a single CC where the login name is both "foo@blah.org",
# and "bar@blah.org". This is impossible.
#
# --------------------------------------------------------------
# CC    | equal to
# foo@blah.org
# AND
# CC    | equal to
# bar@blah.org
# --------------------------------------------------------------

# $chartid is the number of the current chart whose SQL we're constructing
# $row is the current row of the current chart

# names for table aliases are constructed using $chartid and $row
#   SELECT blah  FROM $table "$table_$chartid_$row" WHERE ....

# $f  = field of table in bug db (e.g. bug_id, reporter, etc)
# $ff = qualified field name (field name prefixed by table)
#       e.g. bugs_activity.bug_id
# $t  = type of query. e.g. "equal to", "changed after", case sensitive substr"
# $v  = value - value the user typed in to the form
# $q  = sanitized version of user input trick_taint(($dbh->quote($v)))
# @supptables = Tables and/or table aliases used in query
# %suppseen   = A hash used to store all the tables in supptables to weed
#               out duplicates.
# @supplist   = A list used to accumulate all the JOIN clauses for each
#               chart to merge the ON sections of each.
# $suppstring = String which is pasted into query containing all table names

    $row = 0;
    for ($chart=-1 ;
         $chart < 0 || $params->param("field$chart-0-0") ;
         $chart++) {
        $chartid = $chart >= 0 ? $chart : "";
        my @chartandlist = ();
        for ($row = 0 ;
             $params->param("field$chart-$row-0") ;
             $row++) {
            my @orlist;
            for (my $col = 0 ;
                 $params->param("field$chart-$row-$col") ;
                 $col++) {
                $f = $params->param("field$chart-$row-$col") || "noop";
                my $original_f = $f; # Saved for search_description
                $t = $params->param("type$chart-$row-$col") || "noop";
                $v = $params->param("value$chart-$row-$col");
                $v = "" if !defined $v;
                $v = trim($v);
                if ($f eq "noop" || $t eq "noop" || $v eq "" &&
                    $t ne "equals" && $t ne "notequals" && $t ne "exact") {
                    next;
                }
                $f = COLUMN_ALIASES->{$f} if COLUMN_ALIASES->{$f};
                # chart -1 is generated by other code above, not from the user-
                # submitted form, so we'll blindly accept any values in chart -1
                if (!COLUMNS->{$f} && $chart != -1)
                {
                    ThrowCodeError("invalid_field_name", {field => $f});
                }
                if (COLUMNS->{$f})
                {
                    for (@{ COLUMNS->{$f}->{joins} || [] })
                    {
                        push @supptables, $_ if lsearch(\@supptables, $_) < 0;
                    }
                }
                # CustIS Bug 53836
                if ($t eq "equals" || $t eq "exact" || $t eq "anyexact") {
                    $v =~ s/\%user\%/$user->login/isge;
                }

                # This is either from the internal chart (in which case we
                # already know about it), or it was in %chartfields, so it is
                # a valid field name, which means that it's ok.
                trick_taint($f);
                $q = $dbh->quote($v);
                trick_taint($q);
                my $rhs = $v;
                $rhs =~ tr/,//;
                my $func;
                $term = undef;
                foreach my $key (@funcnames) {
                    if ("$f,$t,$rhs" =~ m/$key/) {
                        my $ref = $funcsbykey{$key};
                        $ff = $f;
                        if (COLUMNS->{$f}->{name}) {
                            $ff = COLUMNS->{$f}->{name};
                        } elsif ($f !~ /\./) {
                            $ff = "bugs.$f";
                        }
                        $self->$ref(%func_args);
                        if ($term) {
                            last;
                        }
                    }
                }
                if ($term) {
                    $self->search_description({
                        field => $original_f, type  => $t, value => $v,
                        term  => $term,
                    });
                    push(@orlist, $term);
                }
                else {
                    # This field and this type don't work together.
                    ThrowCodeError("field_type_mismatch",
                                   { field => $params->param("field$chart-$row-$col"),
                                     type => $params->param("type$chart-$row-$col"),
                                   });
                }
            }
            if (@orlist) {
                @orlist = map("($_)", @orlist) if (scalar(@orlist) > 1);
                push(@chartandlist, "(" . join(" OR ", @orlist) . ")");
            }
        }
        if (@chartandlist) {
            if ($params->param("negate$chart") ? 1 : 0) {
                push(@andlist, "NOT(" . join(" AND ", @chartandlist) . ")");
            } else {
                push(@andlist, "(" . join(" AND ", @chartandlist) . ")");
            }
            if ($chart < 0) {
                $specialchart_terms = pop @andlist;
            }
        }
    }

    # The ORDER BY clause goes last, but can require modifications
    # to other parts of the query, so we want to create it before we
    # write the FROM clause.
    foreach my $orderitem (@inputorder)
    {
        BuildOrderBy($special_order, $orderitem, \@orderby);
    }

    # Now JOIN the correct tables in the FROM clause.
    # This is done separately from the above because it's
    # cleaner to do it this way.
    foreach my $orderitem (@inputorder)
    {
        # Grab the part without ASC or DESC.
        my $column_name = split_order_term($orderitem);
        for (@{ $special_order->{$column_name}->{joins} || [] })
        {
            push @supptables, $_ if lsearch(\@supptables, $_) < 0;
        }
    }

    my %suppseen = ("bugs" => 1);
    my $suppstring = "bugs";
    my @supplist = (" ");
    foreach my $str (@supptables) {

        if ($str =~ /^(LEFT|INNER|RIGHT)\s+JOIN/iso) {
            $str =~ /^(.*?)\s+ON\s+(.*)$/iso;
            my ($leftside, $rightside) = ($1, $2);
            if (defined $suppseen{$leftside}) {
                $supplist[$suppseen{$leftside}] .= " AND ($rightside)";
            } else {
                $suppseen{$leftside} = scalar @supplist;
                push @supplist, " $leftside ON ($rightside)";
            }
        } else {
            # Do not accept implicit joins using comma operator
            # as they are not DB agnostic
            ThrowCodeError("comma_operator_deprecated");
        }
    }
    $suppstring .= join('', @supplist);

    # <vfilippov@custis.ru> AND(AND(OR)) is IMO pointless. Do OR(AND(OR)).
    @andlist = ("(" . join(" OR ", @andlist) . ")") if @andlist;
    unshift @andlist, $specialchart_terms if $specialchart_terms;

    # Make sure we create a legal SQL query.
    @andlist = ("1 = 1") if !@andlist;

    my @sql_fields;
    foreach my $field (@fields)
    {
        if (COLUMNS->{$field}->{name})
        {
            my $alias = $field;
            # Aliases cannot contain dots in them. We convert them to underscores.
            $alias =~ s/\./_/g;
            push @sql_fields, $field eq EMPTY_COLUMN
                ? EMPTY_COLUMN : COLUMNS->{$field}->{name} . " AS $alias";
        }
        else
        {
            push @sql_fields, $field;
        }
    }
    my $query = "SELECT " . join(', ', @sql_fields) . " FROM $suppstring";

    if (!$user->is_super_user)
    {
        $query .= " LEFT JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id";
        if ($user->id)
        {
            if (scalar @{ $user->groups })
            {
                $query .=
                    " AND bug_group_map.group_id NOT IN ("
                    . $user->groups_as_string . ") ";
            }
            $query .= " LEFT JOIN cc ON cc.bug_id = bugs.bug_id AND cc.who = " . $user->id;
        }
    }

    $query .= " WHERE (" . join(' AND ', (@wherepart, @andlist)) .
              " AND bugs.creation_ts IS NOT NULL ";

    if (!$user->is_super_user)
    {
        $query .= " AND ((bug_group_map.group_id IS NULL)";
        if ($user->id)
        {
            my $userid = $user->id;
            $query .=
                " OR (bugs.reporter_accessible = 1 AND bugs.reporter = $userid) " .
                " OR (bugs.cclist_accessible = 1 AND cc.who IS NOT NULL) " .
                " OR (bugs.assigned_to = $userid) ";
            if (Bugzilla->params->{'useqacontact'})
            {
                $query .= "OR (bugs.qa_contact = $userid) ";
            }
        }
        $query .= ") ";
    }
    $query .= ") ";

    # For some DBs, every field in the SELECT must be in the GROUP BY.
    foreach my $field (@fields) {
        # FIXME
        # These fields never go into the GROUP BY (bug_id goes in
        # explicitly, below).
        next if (grep($_ eq $field, EMPTY_COLUMN,
                      qw(bug_id actual_time percentage_complete flagtypes.name)));
        my $col = COLUMNS->{$field}->{name} || $field;
        push(@groupby, $col) if !grep($_ eq $col, @groupby);
    }

    # And all items from ORDER BY must be in the GROUP BY. The above loop
    # doesn't catch items that were put into the ORDER BY from SPECIAL_ORDER.
    foreach my $item (@inputorder)
    {
        my $column_name = split_order_term($item);
        if ($special_order->{$column_name}->{fields})
        {
            push @groupby, @{ $special_order->{$column_name}->{fields} };
        }
    }

    $query .= $dbh->sql_group_by("bugs.bug_id", join(', ', @groupby));

    if (@having) {
        $query .= " HAVING " . join(" AND ", @having);
    }

    if (@orderby) {
        $query .= " ORDER BY " . join(',', @orderby);
    }

    $self->{'sql'} = $query;
}

###############################################################################
# Helper functions for the init() method.
###############################################################################
sub SqlifyDate {
    my ($str) = @_;
    $str = "" if (!defined $str || lc($str) eq 'now');
    if ($str eq "") {
        my ($sec, $min, $hour, $mday, $month, $year, $wday) = localtime(time());
        return sprintf("%4d-%02d-%02d 00:00:00", $year+1900, $month+1, $mday);
    }

    if ($str =~ /^(-|\+)?(\d+)([hHdDwWmMyY])$/) {   # relative date
        my ($sign, $amount, $unit, $date) = ($1, $2, lc $3, time);
        my ($sec, $min, $hour, $mday, $month, $year, $wday)  = localtime($date);
        if ($sign && $sign eq '+') { $amount = -$amount; }
        if ($unit eq 'w') {                  # convert weeks to days
            $amount = 7*$amount + $wday;
            $unit = 'd';
        }
        if ($unit eq 'd') {
            $date -= $sec + 60*$min + 3600*$hour + 24*3600*$amount;
            return time2str("%Y-%m-%d %H:%M:%S", $date);
        }
        elsif ($unit eq 'y') {
            return sprintf("%4d-01-01 00:00:00", $year+1900-$amount);
        }
        elsif ($unit eq 'm') {
            $month -= $amount;
            while ($month<0) { $year--; $month += 12; }
            return sprintf("%4d-%02d-01 00:00:00", $year+1900, $month+1);
        }
        elsif ($unit eq 'h') {
            # Special case 0h for 'beginning of this hour'
            if ($amount == 0) {
                $date -= $sec + 60*$min;
            } else {
                $date -= 3600*$amount;
            }
            return time2str("%Y-%m-%d %H:%M:%S", $date);
        }
        return undef;                      # should not happen due to regexp at top
    }
    my $date = str2time($str);
    if (!defined($date)) {
        ThrowUserError("illegal_date", { date => $str });
    }
    return time2str("%Y-%m-%d %H:%M:%S", $date);
}

sub build_subselect {
    my ($outer, $inner, $table, $cond) = @_;
    my $q = "SELECT $inner FROM $table WHERE $cond";
    return "$outer IN ($q)";
    my $dbh = Bugzilla->dbh;
    my $list = $dbh->selectcol_arrayref($q);
    return "1=2" unless @$list; # Could use boolean type on dbs which support it
    return $dbh->sql_in($outer, $list);
}

sub GetByWordList {
    my ($field, $strs) = (@_);
    my @list;
    my $dbh = Bugzilla->dbh;
    return [] unless defined $strs;

    foreach my $w (split(/[\s,]+/, $strs)) {
        my $word = $w;
        if ($word ne "") {
            $word =~ tr/A-Z/a-z/;
            $word = $dbh->quote('(^|[^a-z0-9])' . quotemeta($word) . '($|[^a-z0-9])');
            trick_taint($word);
            push(@list, $dbh->sql_regexp($field, $word));
        }
    }

    return \@list;
}

# Support for "any/all/nowordssubstr" comparison type ("words as substrings")
sub GetByWordListSubstr {
    my ($field, $strs) = (@_);
    my @list;
    my $dbh = Bugzilla->dbh;
    my $sql_word;

    foreach my $word (split(/[\s,]+/, $strs)) {
        if ($word ne "") {
            $sql_word = $dbh->quote($word);
            trick_taint($sql_word);
            push(@list, $dbh->sql_iposition($sql_word, $field) . " > 0");
        }
    }

    return \@list;
}

sub getSQL {
    my $self = shift;
    return $self->{'sql'};
}

sub search_description {
    my ($self, $params) = @_;
    my $desc = $self->{'search_description'} ||= [];
    if ($params) {
        push(@$desc, $params);
    }
    return $self->{'search_description'};
}

sub pronoun {
    my ($noun, $user) = (@_);
    if ($noun eq "%user%") {
        if ($user->id) {
            return $user->id;
        } else {
            ThrowUserError('login_required_for_pronoun');
        }
    }
    if ($noun eq "%reporter%") {
        return "bugs.reporter";
    }
    if ($noun eq "%assignee%") {
        return "bugs.assigned_to";
    }
    if ($noun eq "%qacontact%") {
        return "bugs.qa_contact";
    }
    return 0;
}

# BuildOrderBy - Private Subroutine
# This function converts the input order to an "output" order,
# suitable for concatenation to form an ORDER BY clause. Basically,
# it just handles fields that have non-standard sort orders from
# %specialorder.
# Arguments:
#  $orderitem - A string. The next value to append to the ORDER BY clause,
#      in the format of an item in the 'order' parameter to
#      Bugzilla::Search.
#  $stringlist - A reference to the list of strings that will be join()'ed
#      to make ORDER BY. This is what the subroutine modifies.
#  $reverseorder - (Optional) A boolean. TRUE if we should reverse the order
#      of the field that we are given (from ASC to DESC or vice-versa).
#
# Explanation of $reverseorder
# ----------------------------
# The role of $reverseorder is to handle things like sorting by
# "target_milestone DESC".
# Let's say that we had a field "A" that normally translates to a sort
# order of "B ASC, C DESC". If we sort by "A DESC", what we really then
# mean is "B DESC, C ASC". So $reverseorder is only used if we call
# BuildOrderBy recursively, to let it know that we're "reversing" the
# order. That is, that we wanted "A DESC", not "A".
sub BuildOrderBy
{
    my ($special_order, $orderitem, $stringlist, $reverseorder) = (@_);

    my ($orderfield, $orderdirection) = split_order_term($orderitem);

    if ($reverseorder) {
        # If orderdirection is empty or ASC...
        if (!$orderdirection || $orderdirection =~ m/asc/i) {
            $orderdirection = "DESC";
        } else {
            # This has the minor side-effect of making any reversed invalid
            # direction into ASC.
            $orderdirection = "ASC";
        }
    }

    # Handle fields that have non-standard sort orders, from $specialorder.
    if ($special_order->{$orderfield}->{fields}) {
        foreach my $subitem (@{$special_order->{$orderfield}->{fields}}) {
            # DESC on a field with non-standard sort order means
            # "reverse the normal order for each field that we map to."
            BuildOrderBy($special_order, $subitem, $stringlist,
                         $orderdirection =~ m/desc/i);
        }
        return;
    }
    # Aliases cannot contain dots in them. We convert them to underscores.
    $orderfield =~ s/\./_/g if exists COLUMNS->{$orderfield};

    push @$stringlist, trim($orderfield . ' ' . $orderdirection);
}

# Splits out "asc|desc" from a sort order item.
sub split_order_term
{
    my $fragment = shift;
    $fragment =~ /^(.+?)(?:\s+(ASC|DESC))?$/i;
    my ($column_name, $direction) = (lc($1), uc($2 || ''));
    return wantarray ? ($column_name, $direction) : $column_name;
}

# Used to translate old SQL fragments from buglist.cgi's "order" argument
# into our modern field IDs.
sub translate_old_column
{
    my ($column) = @_;
    return COLUMN_ALIASES->{$column} if COLUMN_ALIASES->{$column};

    # All old SQL fragments have a period in them somewhere.
    return $column if $column !~ /\./;

    if ($column =~ /\bAS\s+(\w+)$/i) {
        return $1;
    }
    # product, component, classification, assigned_to, qa_contact, reporter
    elsif ($column =~ /map_(\w+?)s?\.(login_)?name/i) {
        return $1;
    }

    # If it doesn't match the regexps above, check to see if the old
    # SQL fragment matches the SQL of an existing column
    foreach my $key (%{ COLUMNS() }) {
        next unless exists COLUMNS->{$key}->{name};
        return $key if COLUMNS->{$key}->{name} eq $column;
    }

    return $column;
}

#####################################################################
# Search Functions
#####################################################################

sub _contact_exact_group {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f, $t, $v, $term) =
        @func_args{qw(chartid supptables f t v term)};
    my $user = $self->{'user'};

    $$v =~ m/%group\\.([^%]+)%/;
    my $group = $1;
    my $groupid = Bugzilla::Group::ValidateGroupName( $group, ($user));
    ($groupid && $user->in_group_id($groupid))
      || ThrowUserError('invalid_group_name',{name => $group});
    my @childgroups = @{Bugzilla::Group->flatten_group_membership($groupid)};
    my $table = "user_group_map_$$chartid";
    push (@$supptables, "LEFT JOIN user_group_map AS $table " .
                        "ON $table.user_id = bugs.$$f " .
                        "AND $table.group_id IN(" .
                        join(',', @childgroups) . ") " .
                        "AND $table.isbless = 0 " .
                        "AND $table.grant_type IN(" .
                        GRANT_DIRECT . "," . GRANT_REGEXP . ")"
         );
    if ($$t =~ /^not/) {
        $$term = "$table.group_id IS NULL";
    } else {
        $$term = "$table.group_id IS NOT NULL";
    }
}

sub _contact_exact {
    my $self = shift;
    my %func_args = @_;
    my ($term, $f, $v) = @func_args{qw(term f v)};
    my $user = $self->{'user'};

    $$v =~ m/(%\\w+%)/;
    $$term = "bugs.$$f = " . pronoun($1, $user);
}

sub _contact_notequals {
    my $self = shift;
    my %func_args = @_;
    my ($term, $f, $v) = @func_args{qw(term f v)};
    my $user = $self->{'user'};

    $$v =~ m/(%\\w+%)/;
    $$term = "bugs.$$f <> " . pronoun($1, $user);
}

sub _assigned_to_reporter_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $funcsbykey, $t, $term) =
        @func_args{qw(f ff funcsbykey t term)};

    my $real_f = $$f;
    $$f = "login_name";
    $$ff = "profiles.login_name";
    $$funcsbykey{",$$t"}($self, %func_args);
    $$term = "bugs.$real_f IN (SELECT userid FROM profiles WHERE $$term)";
}

sub _qa_contact_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($supptables, $f) =
        @func_args{qw(supptables f)};

    if (!grep { /map_qa_contact/ } @$supptables)
    {
        push(@$supptables, "LEFT JOIN profiles AS map_qa_contact " .
                           "ON bugs.qa_contact = map_qa_contact.userid");
    }
    $$f = "COALESCE(map_$$f.login_name,'')";
}

sub _cc_exact_group {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $supptables, $t, $v, $term) =
        @func_args{qw(chartid sequence supptables t v term)};
    my $user = $self->{'user'};

    $$v =~ m/%group\\.([^%]+)%/;
    my $group = $1;
    my $groupid = Bugzilla::Group::ValidateGroupName( $group, ($user));
    ($groupid && $user->in_group_id($groupid))
      || ThrowUserError('invalid_group_name',{name => $group});
    my @childgroups = @{Bugzilla::Group->flatten_group_membership($groupid)};
    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "CC$$sequence";
        $$sequence++;
    }
    my $table = "user_group_map_$chartseq";
    push(@$supptables, "LEFT JOIN cc AS cc_$chartseq " .
                       "ON bugs.bug_id = cc_$chartseq.bug_id");
    push(@$supptables, "LEFT JOIN user_group_map AS $table " .
                        "ON $table.user_id = cc_$chartseq.who " .
                        "AND $table.group_id IN(" .
                        join(',', @childgroups) . ") " .
                        "AND $table.isbless = 0 " .
                        "AND $table.grant_type IN(" .
                        GRANT_DIRECT . "," . GRANT_REGEXP . ")"
         );
    if ($$t =~ /^not/) {
        $$term = "$table.group_id IS NULL";
    } else {
        $$term = "$table.group_id IS NOT NULL";
    }
}

sub _cc_exact {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $supptables, $term, $v) =
        @func_args{qw(chartid sequence supptables term v)};
    my $user = $self->{'user'};

    $$v =~ m/(%\\w+%)/;
    my $match = pronoun($1, $user);
    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "CC$$sequence";
        $$sequence++;
    }
    push(@$supptables, "LEFT JOIN cc AS cc_$chartseq " .
                       "ON bugs.bug_id = cc_$chartseq.bug_id " .
                       "AND cc_$chartseq.who = $match");
    $$term = "cc_$chartseq.who IS NOT NULL";
}

sub _cc_notequals {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $supptables, $term, $v) =
        @func_args{qw(chartid sequence supptables term v)};
    my $user = $self->{'user'};

    $$v =~ m/(%\\w+%)/;
    my $match = pronoun($1, $user);
    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "CC$$sequence";
        $$sequence++;
    }
    push(@$supptables, "LEFT JOIN cc AS cc_$chartseq " .
                       "ON bugs.bug_id = cc_$chartseq.bug_id " .
                       "AND cc_$chartseq.who = $match");
    $$term = "cc_$chartseq.who IS NULL";
}

sub _cc_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $f, $ff, $t, $funcsbykey, $supptables, $term, $v) =
        @func_args{qw(chartid sequence f ff t funcsbykey supptables term v)};

    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "CC$$sequence";
        $$sequence++;
    }
    $$f = "login_name";
    $$ff = "profiles.login_name";
    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables, "LEFT JOIN cc AS cc_$chartseq " .
                       "ON bugs.bug_id = cc_$chartseq.bug_id " .
                       "AND cc_$chartseq.who IN" .
                       "(SELECT userid FROM profiles WHERE $$term)"
                       );
    $$term = "cc_$chartseq.who IS NOT NULL";
}

sub _long_desc_changedby {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $term, $v) =
        @func_args{qw(chartid supptables term v)};

    my $table = "longdescs_$$chartid";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                       "ON $table.bug_id = bugs.bug_id");
    my $id = login_to_id($$v, THROW_ERROR);
    $$term = "$table.who = $id";
}

sub _long_desc_changedbefore_after {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $t, $v, $supptables, $term) =
        @func_args{qw(chartid t v supptables term)};
    my $dbh = Bugzilla->dbh;

    my $operator = ($$t =~ /before/) ? '<' : '>';
    my $table = "longdescs_$$chartid";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                              "ON $table.bug_id = bugs.bug_id " .
                                 "AND $table.bug_when $operator " .
                                  $dbh->quote(SqlifyDate($$v)) );
    $$term = "($table.bug_when IS NOT NULL)";
}

sub _content_matches
{
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $term, $groupby, $fields, $t, $v) =
        @func_args{qw(chartid supptables term groupby fields t v)};
    my $dbh = Bugzilla->dbh;

    # "content" is an alias for columns containing text for which we
    # can search a full-text index and retrieve results by relevance,
    # currently just bug comments (and summaries to some degree).
    # There's only one way to search a full-text index, so we only
    # accept the "matches" operator, which is specific to full-text
    # index searches.

    # Add the fulltext table to the query so we can search on it.
    my $table = "bugs_fulltext_$$chartid";
    my $comments_col = "comments";
    $comments_col = "comments_noprivate" unless $self->{'user'}->is_insider;

    # Create search terms to add to the SELECT and WHERE clauses.
    my $text = stem_text($$v);
    my ($term1, $rterm1) = $dbh->sql_fulltext_search("bugs_fulltext.$comments_col", $text);
    my ($term2, $rterm2) = $dbh->sql_fulltext_search("bugs_fulltext.short_desc", $text);

    # In order to sort by relevance (in case the user requests it),
    # we SELECT the relevance value so we can add it to the ORDER BY
    # clause. Every time a new fulltext chart isadded, this adds more
    # terms to the relevance sql. (That doesn't make sense in
    # "NOT" charts, but Bugzilla never uses those with fulltext
    # by default.)
    #

    # Bug 46221 - Russian Stemming in Bugzilla fulltext search
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        # MATCH(...) OR MATCH(...) is very slow in MySQL - it does no
        # fulltext index merge optimization. So we use INNER JOIN to UNION.
        push @$supptables, "INNER JOIN (SELECT bug_id FROM bugs_fulltext WHERE $term1
            UNION SELECT bug_id FROM bugs_fulltext WHERE $term2) AS $table ON bugs.bug_id=$table.bug_id";

        # All work done by INNER JOIN
        $$term = "1=1";
    }
    else
    {
        push @$supptables, "INNER JOIN bugs_fulltext ON bugs_fulltext.bug_id=bugs.bug_id";
        $$term = "$term1 OR $term2";
    }

    # We build the relevance SQL by modifying the COLUMNS list directly,
    # which is kind of a hack but works.
    COLUMNS->{relevance}->{name} = "(SELECT $rterm1+$rterm2 FROM bugs_fulltext WHERE bugs_fulltext.bug_id=bugs.bug_id)";
}

sub _timestamp_compare {
    my $self = shift;
    my %func_args = @_;
    my ($v, $q) = @func_args{qw(v q)};
    my $dbh = Bugzilla->dbh;

    $$v = SqlifyDate($$v);
    $$q = $dbh->quote($$v);
}

sub _commenter_exact {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $supptables, $term, $v) =
        @func_args{qw(chartid sequence supptables term v)};
    my $user = $self->{'user'};

    $$v =~ m/(%\\w+%)/;
    my $match = pronoun($1, $user);
    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "LD$$sequence";
        $$sequence++;
    }
    my $table = "longdescs_$chartseq";
    my $extra = $user->is_insider ? "" : "AND $table.isprivate < 1";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                       "ON $table.bug_id = bugs.bug_id $extra " .
                       "AND $table.who IN ($match)");
    $$term = "$table.who IS NOT NULL";
}

sub _commenter {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $sequence, $supptables, $f, $ff, $t, $funcsbykey, $term) =
        @func_args{qw(chartid sequence supptables f ff t funcsbykey term)};

    my $chartseq = $$chartid;
    if ($$chartid eq "") {
        $chartseq = "LD$$sequence";
        $$sequence++;
    }
    my $table = "longdescs_$chartseq";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $table.isprivate < 1";
    $$f = "login_name";
    $$ff = "profiles.login_name";
    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                       "ON $table.bug_id = bugs.bug_id $extra " .
                       "AND $table.who IN" .
                       "(SELECT userid FROM profiles WHERE $$term)"
                       );
    $$term = "$table.who IS NOT NULL";
}

sub _long_desc {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f) =
        @func_args{qw(chartid supptables f)};

    my $table = "longdescs_$$chartid";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $table.isprivate < 1";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                       "ON $table.bug_id = bugs.bug_id $extra");
    $$f = "$table.thetext";
}

sub _longdescs_isprivate {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f) =
        @func_args{qw(chartid supptables f)};

    my $table = "longdescs_$$chartid";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $table.isprivate < 1";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                      "ON $table.bug_id = bugs.bug_id $extra");
    $$f = "$table.isprivate";
}

sub _work_time_changedby {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $v, $term) =
        @func_args{qw(chartid supptables v term)};

    my $table = "longdescs_$$chartid";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                       "ON $table.bug_id = bugs.bug_id");
    my $id = login_to_id($$v, THROW_ERROR);
    $$term = "(($table.who = $id";
    $$term .= ") AND ($table.work_time <> 0))";
}

sub _work_time_changedbefore_after {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $t, $v, $supptables, $term) =
        @func_args{qw(chartid t v supptables term)};
    my $dbh = Bugzilla->dbh;

    my $operator = ($$t =~ /before/) ? '<' : '>';
    my $table = "longdescs_$$chartid";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                              "ON $table.bug_id = bugs.bug_id " .
                                 "AND $table.work_time <> 0 " .
                                 "AND $table.bug_when $operator " .
                                  $dbh->quote(SqlifyDate($$v)) );
    $$term = "($table.bug_when IS NOT NULL)";
}

sub _work_time {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f) =
        @func_args{qw(chartid supptables f)};

    my $table = "longdescs_$$chartid";
    push(@$supptables, "LEFT JOIN longdescs AS $table " .
                      "ON $table.bug_id = bugs.bug_id");
    $$f = "$table.work_time";
}

sub _percentage_complete {
    my $self = shift;
    my %func_args = @_;
    my ($t, $chartid, $supptables, $fields, $q, $v, $having, $groupby, $term) =
        @func_args{qw(t chartid supptables fields q v having groupby term)};
    my $dbh = Bugzilla->dbh;

    my $oper;
    if ($$t eq "equals") {
        $oper = "=";
    } elsif ($$t eq "greaterthan") {
        $oper = ">";
    } elsif ($$t eq "lessthan") {
        $oper = "<";
    } elsif ($$t eq "notequal") {
        $oper = "<>";
    } elsif ($$t eq "regexp") {
        # This is just a dummy to help catch bugs- $oper won't be used
        # since "regexp" is treated as a special case below.  But
        # leaving $oper uninitialized seems risky...
        $oper = "sql_regexp";
    } elsif ($$t eq "notregexp") {
        # This is just a dummy to help catch bugs- $oper won't be used
        # since "notregexp" is treated as a special case below.  But
        # leaving $oper uninitialized seems risky...
        $oper = "sql_not_regexp";
    } else {
        $oper = "noop";
    }
    if ($oper ne "noop") {
        my $table = "longdescs_$$chartid";
        if (!grep($_ eq 'remaining_time', @$fields)) {
            push(@$fields, "remaining_time");
        }
        push(@$supptables, "LEFT JOIN longdescs AS $table " .
                           "ON $table.bug_id = bugs.bug_id");
        my $expression = "(100 * ((SUM($table.work_time) *
                                    COUNT(DISTINCT $table.bug_when) /
                                    COUNT(bugs.bug_id)) /
                                   ((SUM($table.work_time) *
                                     COUNT(DISTINCT $table.bug_when) /
                                     COUNT(bugs.bug_id)) +
                                    bugs.remaining_time)))";
        $$q = $dbh->quote($$v);
        trick_taint($$q);
        if ($$t eq "regexp") {
            push(@$having, $dbh->sql_regexp($expression, $$q));
        } elsif ($$t eq "notregexp") {
            push(@$having, $dbh->sql_not_regexp($expression, $$q));
        } else {
            push(@$having, "$expression $oper " . $$q);
        }
        push(@$groupby, "bugs.remaining_time");
    }
    $$term = "0=0";
}

sub _bug_group_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($supptables, $chartid, $ff, $f, $t, $funcsbykey, $term) =
        @func_args{qw(supptables chartid ff f t funcsbykey term)};

    push(@$supptables,
            "LEFT JOIN bug_group_map AS bug_group_map_$$chartid " .
            "ON bugs.bug_id = bug_group_map_$$chartid.bug_id");
    $$ff = $$f = "groups_$$chartid.name";
    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables,
            "LEFT JOIN groups AS groups_$$chartid " .
            "ON groups_$$chartid.id = bug_group_map_$$chartid.group_id " .
            "AND $$term");
    $$term = "$$ff IS NOT NULL";
}

sub _attach_data_thedata_changed {
    my $self = shift;
    my %func_args = @_;
    my ($f) = @func_args{qw(f)};

    # Searches for attachment data's change must search
    # the creation timestamp of the attachment instead.
    $$f = "attachments.whocares";
}

sub _attach_data_thedata {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f) =
        @func_args{qw(chartid supptables f)};

    my $atable = "attachments_$$chartid";
    my $dtable = "attachdata_$$chartid";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $atable.isprivate = 0";
    push(@$supptables, "INNER JOIN attachments AS $atable " .
                       "ON bugs.bug_id = $atable.bug_id $extra");
    push(@$supptables, "INNER JOIN attach_data AS $dtable " .
                       "ON $dtable.id = $atable.attach_id");
    $$f = "$dtable.thedata";
}

sub _attachments_submitter {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f) =
        @func_args{qw(chartid supptables f)};

    my $atable = "map_attachment_submitter_$$chartid";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $atable.isprivate = 0";
    push(@$supptables, "INNER JOIN attachments AS $atable " .
                       "ON bugs.bug_id = $atable.bug_id $extra");
    push(@$supptables, "LEFT JOIN profiles AS attachers_$$chartid " .
                       "ON $atable.submitter_id = attachers_$$chartid.userid");
    $$f = "attachers_$$chartid.login_name";
}

sub _attachments {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $supptables, $f, $t, $v, $q) =
        @func_args{qw(chartid supptables f t v q)};
    my $dbh = Bugzilla->dbh;

    my $table = "attachments_$$chartid";
    my $extra = $self->{'user'}->is_insider ? "" : "AND $table.isprivate = 0";
    push(@$supptables, "INNER JOIN attachments AS $table " .
                       "ON bugs.bug_id = $table.bug_id $extra");
    $$f =~ m/^attachments\.(.*)$/;
    my $field = $1;
    if ($$t eq "changedby") {
        $$v = login_to_id($$v, THROW_ERROR);
        $$q = $dbh->quote($$v);
        $field = "submitter_id";
        $$t = "equals";
    } elsif ($$t eq "changedbefore") {
        $$v = SqlifyDate($$v);
        $$q = $dbh->quote($$v);
        $field = "creation_ts";
        $$t = "lessthan";
    } elsif ($$t eq "changedafter") {
        $$v = SqlifyDate($$v);
        $$q = $dbh->quote($$v);
        $field = "creation_ts";
        $$t = "greaterthan";
    }
    if ($field eq "ispatch" && $$v ne "0" && $$v ne "1") {
        ThrowUserError("illegal_attachment_is_patch");
    }
    if ($field eq "isobsolete" && $$v ne "0" && $$v ne "1") {
        ThrowUserError("illegal_is_obsolete");
    }
    $$f = "$table.$field";
}

sub _flagtypes_name {
    my $self = shift;
    my %func_args = @_;
    my ($t, $chartid, $supptables, $ff, $funcsbykey, $having, $term) =
        @func_args{qw(t chartid supptables ff funcsbykey having term)};
    my $dbh = Bugzilla->dbh;

    # Matches bugs by flag name/status.
    # Note that--for the purposes of querying--a flag comprises
    # its name plus its status (i.e. a flag named "review"
    # with a status of "+" can be found by searching for "review+").

    # Don't do anything if this condition is about changes to flags,
    # as the generic change condition processors can handle those.
    return if ($$t =~ m/^changed/);

    # Add the flags and flagtypes tables to the query.  We do
    # a left join here so bugs without any flags still match
    # negative conditions (f.e. "flag isn't review+").
    my $flags = "flags_$$chartid";
    push(@$supptables, "LEFT JOIN flags AS $flags " .
                       "ON bugs.bug_id = $flags.bug_id ");
    my $flagtypes = "flagtypes_$$chartid";
    push(@$supptables, "LEFT JOIN flagtypes AS $flagtypes " .
                       "ON $flags.type_id = $flagtypes.id");

    # Generate the condition by running the operator-specific
    # function. Afterwards the condition resides in the global $term
    # variable.
    $$ff = $dbh->sql_string_concat("${flagtypes}.name",
                                   "$flags.status");
    $$funcsbykey{",$$t"}($self, %func_args);

    # If this is a negative condition (f.e. flag isn't "review+"),
    # we only want bugs where all flags match the condition, not
    # those where any flag matches, which needs special magic.
    # Instead of adding the condition to the WHERE clause, we select
    # the number of flags matching the condition and the total number
    # of flags on each bug, then compare them in a HAVING clause.
    # If the numbers are the same, all flags match the condition,
    # so this bug should be included.
    if ($$t =~ m/not/) {
       push(@$having,
            "SUM(CASE WHEN $$ff IS NOT NULL THEN 1 ELSE 0 END) = " .
            "SUM(CASE WHEN $$term THEN 1 ELSE 0 END)");
       $$term = "0=0";
    }
}

sub _requestees_login_name {
    my $self = shift;
    my %func_args = @_;
    my ($f, $chartid, $supptables) = @func_args{qw(f chartid supptables)};

    my $flags = "flags_$$chartid";
    push(@$supptables, "LEFT JOIN flags AS $flags " .
                       "ON bugs.bug_id = $flags.bug_id ");
    push(@$supptables, "LEFT JOIN profiles AS requestees_$$chartid " .
                       "ON $flags.requestee_id = requestees_$$chartid.userid");
    $$f = "requestees_$$chartid.login_name";
}

sub _setters_login_name {
    my $self = shift;
    my %func_args = @_;
    my ($f, $chartid, $supptables) = @func_args{qw(f chartid supptables)};

    my $flags = "flags_$$chartid";
    push(@$supptables, "LEFT JOIN flags AS $flags " .
                       "ON bugs.bug_id = $flags.bug_id ");
    push(@$supptables, "LEFT JOIN profiles AS setters_$$chartid " .
                       "ON $flags.setter_id = setters_$$chartid.userid");
    $$f = "setters_$$chartid.login_name";
}

sub _changedin_days_elapsed {
    my $self = shift;
    my %func_args = @_;
    my ($f) = @func_args{qw(f)};
    my $dbh = Bugzilla->dbh;

    $$f = "(" . $dbh->sql_to_days('NOW()') . " - " .
                $dbh->sql_to_days('bugs.delta_ts') . ")";
}

sub _component_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $t, $funcsbykey, $term) =
        @func_args{qw(f ff t funcsbykey term)};

    $$f = $$ff = "components.name";
    $$funcsbykey{",$$t"}($self, %func_args);
    $$term = build_subselect("bugs.component_id",
                             "components.id",
                             "components",
                             $$term);
}
sub _product_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $t, $funcsbykey, $term) =
        @func_args{qw(f ff t funcsbykey term)};

    # Generate the restriction condition
    $$f = $$ff = "products.name";
    $$funcsbykey{",$$t"}($self, %func_args);
    $$term = build_subselect("bugs.product_id",
                             "products.id",
                             "products",
                             $$term);
}

sub _classification_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $v, $ff, $f, $funcsbykey, $t, $supptables, $term) =
        @func_args{qw(chartid v ff f funcsbykey t supptables term)};

    # Generate the restriction condition
    if (!grep { /map_product/ } @$supptables)
    {
        push @$supptables, "INNER JOIN products AS map_products " .
                           "ON bugs.product_id = map_products.id";
    }
    $$f = $$ff = "classifications.name";
    $$funcsbykey{",$$t"}($self, %func_args);
    $$term = build_subselect("map_products.classification_id",
                             "classifications.id",
                             "classifications",
                              $$term);
}

sub _keywords_exact {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $v, $ff, $f, $t, $term, $supptables) =
        @func_args{qw(chartid v ff f t term supptables)};

    my @list;
    my $table = "keywords_$$chartid";
    my @v = ref $$v ? @$$v : split /[\s,]+/, $$v;
    $$v = join ', ', @$$v if ref $$v;
    foreach my $value (@v) {
        if ($value eq '') {
            next;
        }
        my $keyword = new Bugzilla::Keyword({name => $value});
        if ($keyword) {
            push(@list, "$table.keywordid = " . $keyword->id);
        }
        else {
            ThrowUserError("unknown_keyword",
                           { keyword => $$v });
        }
    }
    my $haveawordterm;
    if (@list) {
        $haveawordterm = "(" . join(' OR ', @list) . ")";
        if ($$t eq "anywords") {
            $$term = $haveawordterm;
        } elsif ($$t eq "allwords") {
            $self->_allwords;
            if ($$term && $haveawordterm) {
                $$term = "(($$term) AND $haveawordterm)";
            }
        }
    }
    if ($$term) {
        push(@$supptables, "LEFT JOIN keywords AS $table " .
                           "ON $table.bug_id = bugs.bug_id");
    }
}

sub _keywords_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $v, $ff, $f, $t, $term, $supptables) =
        @func_args{qw(chartid v ff f t term supptables)};

    my $k_table = "keywords_$$chartid";
    my $kd_table = "keyworddefs_$$chartid";

    # CustIS Bug 65346 - keyword search is broken in 3.6

    $$f = "(SELECT COALESCE(".Bugzilla->dbh->sql_group_concat("$kd_table.name", "' '").", '') FROM keywords AS $k_table " .
        " LEFT JOIN keyworddefs AS $kd_table ON $kd_table.id=$k_table.keywordid" .
        " WHERE $k_table.bug_id = bugs.bug_id)";
}

sub _dependson_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $ff, $f, $funcsbykey, $t, $term, $supptables) =
        @func_args{qw(chartid ff f funcsbykey t term supptables)};

    my $table = "dependson_" . $$chartid;
    $$ff = "$table.$$f";
    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables, "LEFT JOIN dependencies AS $table " .
                       "ON $table.blocked = bugs.bug_id " .
                       "AND ($$term)");
    $$term = "$$ff IS NOT NULL";
}

sub _blocked_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $ff, $f, $funcsbykey, $t, $term, $supptables) =
        @func_args{qw(chartid ff f funcsbykey t term supptables)};

    my $table = "blocked_" . $$chartid;
    $$ff = "$table.$$f";
    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables, "LEFT JOIN dependencies AS $table " .
                       "ON $table.dependson = bugs.bug_id " .
                       "AND ($$term)");
    $$term = "$$ff IS NOT NULL";
}

sub _alias_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $funcsbykey, $t, $term) =
        @func_args{qw(ff funcsbykey t term)};

    $$ff = "COALESCE(bugs.alias, '')";

    $$funcsbykey{",$$t"}($self, %func_args);
}

sub _owner_idle_time_greater_less {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $v, $supptables, $t, $wherepart, $term) =
        @func_args{qw(chartid v supptables t wherepart term)};
    my $dbh = Bugzilla->dbh;

    my $table = "idle_" . $$chartid;
    $$v =~ /^(\d+)\s*([hHdDwWmMyY])?$/;
    my $quantity = $1;
    my $unit = lc $2;
    my $unitinterval = 'DAY';
    if ($unit eq 'h') {
        $unitinterval = 'HOUR';
    } elsif ($unit eq 'w') {
        $unitinterval = ' * 7 DAY';
    } elsif ($unit eq 'm') {
        $unitinterval = 'MONTH';
    } elsif ($unit eq 'y') {
        $unitinterval = 'YEAR';
    }
    my $cutoff = "NOW() - " .
                 $dbh->sql_interval($quantity, $unitinterval);
    my $assigned_fieldid = get_field_id('assigned_to');
    push(@$supptables, "LEFT JOIN longdescs AS comment_$table " .
                       "ON comment_$table.who = bugs.assigned_to " .
                       "AND comment_$table.bug_id = bugs.bug_id " .
                       "AND comment_$table.bug_when > $cutoff");
    push(@$supptables, "LEFT JOIN bugs_activity AS activity_$table " .
                       "ON (activity_$table.who = bugs.assigned_to " .
                       "OR activity_$table.fieldid = $assigned_fieldid) " .
                       "AND activity_$table.bug_id = bugs.bug_id " .
                       "AND activity_$table.bug_when > $cutoff");
    if ($$t =~ /greater/) {
        push(@$wherepart, "(comment_$table.who IS NULL " .
                          "AND activity_$table.who IS NULL)");
    } else {
        push(@$wherepart, "(comment_$table.who IS NOT NULL " .
                          "OR activity_$table.who IS NOT NULL)");
    }
    $$term = "0=0";
}

sub _multiselect_negative {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $t, $funcsbykey, $term) = @func_args{qw(f ff t funcsbykey term)};

    my %map = (
        notequals => 'equals',
        notregexp => 'regexp',
        notsubstring => 'substring',
        nowords => 'anywords',
        nowordssubstr => 'anywordssubstr',
    );

    my $table;
    if ($$f eq 'keywords') {
        $table = "keywords LEFT JOIN keyworddefs"
                 . " ON keywords.keywordid = keyworddefs.id";
        $$ff = "keyworddefs.name";
    }
    else {
        $table = "bug_$$f";
        $$ff = "$table.value";
    }

    $$funcsbykey{",".$map{$$t}}($self, %func_args);
    $$term = "bugs.bug_id NOT IN (SELECT bug_id FROM $table WHERE $$term)";
}

sub _multiselect_multiple {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $t, $v, $funcsbykey, $term) = @func_args{qw(f ff t v funcsbykey term)};

    my @terms;
    my $table = "bug_$$f";
    $$ff = "$table.value";

    my @v = ref $$v ? @$$v : split /[\s,]+/, $$v;
    $$v = join ', ', @$$v if ref $$v;
    foreach my $word (@v) {
        $$v = $word;
        $$funcsbykey{",".$$t}($self, %func_args);
        push(@terms, "bugs.bug_id IN
                      (SELECT bug_id FROM $table WHERE $$term)");
    }

    if ($$t eq 'anyexact') {
        $$term = "(" . join(" OR ", @terms) . ")";
    }
    else {
        $$term = "(" . join(" AND ", @terms) . ")";
    }
}

sub _multiselect_nonchanged {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $f, $ff, $t, $funcsbykey, $supptables) =
        @func_args{qw(chartid f ff t funcsbykey supptables)};

    my $table = $$f."_".$$chartid;
    $$ff = "$table.value";

    $$funcsbykey{",$$t"}($self, %func_args);
    push(@$supptables, "LEFT JOIN bug_$$f AS $table " .
                       "ON $table.bug_id = bugs.bug_id ");
}

sub _equals
{
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $v, $term) = @func_args{qw(ff q v term)};

    if ($v eq '')
    {
        $$term = "IFNULL($$ff,'') = $$q";
    }
    else
    {
        $$term = "$$ff = $$q";
    }
}

sub _notequals
{
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $v, $term) = @func_args{qw(ff q v term)};

    if ($v eq '')
    {
        $$term = "IFNULL($$ff,'') != $$q";
    }
    else
    {
        $$term = "$$ff != $$q";
    }
}

sub _casesubstring {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};
    my $dbh = Bugzilla->dbh;

    $$term = $dbh->sql_position($$q, $$ff) . " > 0";
}

sub _substring {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};
    my $dbh = Bugzilla->dbh;

    $$term = $dbh->sql_iposition($$q, $$ff) . " > 0";
}

sub _notsubstring {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};
    my $dbh = Bugzilla->dbh;

    $$term = $dbh->sql_iposition($$q, $$ff) . " = 0";
}

sub _regexp {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};
    my $dbh = Bugzilla->dbh;

    $$term = $dbh->sql_regexp($$ff, $$q);
}

sub _notregexp {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};
    my $dbh = Bugzilla->dbh;

    $$term = $dbh->sql_not_regexp($$ff, $$q);
}

sub _lessthan {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};

    $$term = "$$ff < $$q";
}

sub _greaterthan {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $q, $term) = @func_args{qw(ff q term)};

    $$term = "$$ff > $$q";
}

sub _anyexact {
    my $self = shift;
    my %func_args = @_;
    my ($f, $ff, $v, $q, $term) = @func_args{qw(f ff v q term)};
    my $dbh = Bugzilla->dbh;

    my @list;
    my @v = ref $$v ? @$$v : split /[\s,]+/, $$v;
    $$v = join ', ', @$$v if ref $$v;
    foreach my $w (@v) {
        if ($w eq "---" && $$f =~ /resolution/) {
            $w = "";
        }
        $$q = $dbh->quote($w);
        trick_taint($$q);
        push(@list, $$q);
    }
    if (@list) {
        $$term = $dbh->sql_in($$ff, \@list);
    }
}

sub _anywordsubstr {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    $$term = join(" OR ", @{GetByWordListSubstr($$ff, $$v)});
}

sub _allwordssubstr {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    $$term = join(" AND ", @{GetByWordListSubstr($$ff, $$v)});
}

sub _nowordssubstr {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    my @list = @{GetByWordListSubstr($$ff, $$v)};
    if (@list) {
        $$term = "NOT (" . join(" OR ", @list) . ")";
    }
}

sub _anywords {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    $$term = join(" OR ", @{GetByWordList($$ff, $$v)});
}

sub _allwords {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    $$term = join(" AND ", @{GetByWordList($$ff, $$v)});
}

sub _nowords {
    my $self = shift;
    my %func_args = @_;
    my ($ff, $v, $term) = @func_args{qw(ff v term)};

    my @list = @{GetByWordList($$ff, $$v)};
    if (@list) {
        $$term = "NOT (" . join(" OR ", @list) . ")";
    }
}

sub _changedbefore_changedafter {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $f, $ff, $t, $v, $supptables, $term) =
        @func_args{qw(chartid f ff t v supptables term)};
    my $dbh = Bugzilla->dbh;

    my $operator = ($$t =~ /before/) ? '<' : '>';
    my $table = "act_$$chartid";
    my $fieldid = Bugzilla->get_field($$f);
    if (!$fieldid) {
        ThrowCodeError("invalid_field_name", {field => $$f});
    }
    $fieldid = $fieldid->id;
    push(@$supptables, "LEFT JOIN bugs_activity AS $table " .
                      "ON $table.bug_id = bugs.bug_id " .
                      "AND $table.fieldid = $fieldid " .
                      "AND $table.bug_when $operator " .
                      $dbh->quote(SqlifyDate($$v)) );
    $$term = "($table.bug_when IS NOT NULL)";
}

sub _changedfrom_changedto {
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $f, $t, $v, $q, $supptables, $term) =
        @func_args{qw(chartid f t v q supptables term)};

    my $operator = ($$t =~ /from/) ? 'removed' : 'added';
    my $table = "act_$$chartid";
    my $fieldid = Bugzilla->get_field($$f);
    if (!$fieldid) {
        ThrowCodeError("invalid_field_name", {field => $$f});
    }
    $fieldid = $fieldid->id;
    push(@$supptables, "LEFT JOIN bugs_activity AS $table " .
                      "ON $table.bug_id = bugs.bug_id " .
                      "AND $table.fieldid = $fieldid " .
                      "AND $table.$operator = $$q");
    $$term = "($table.bug_when IS NOT NULL)";
}

sub _changedby
{
    my $self = shift;
    my %func_args = @_;
    my ($chartid, $f, $v, $supptables, $term) =
        @func_args{qw(chartid f v supptables term)};

    my $table = "act_$$chartid";
    my $fieldid = Bugzilla->get_field($$f);
    if (!$fieldid) {
        ThrowCodeError("invalid_field_name", {field => $$f});
    }
    $fieldid = $fieldid->id;
    my $id = login_to_id($$v, THROW_ERROR);
    push @$supptables, "LEFT JOIN bugs_activity AS $table " .
                      "ON $table.bug_id = bugs.bug_id " .
                      "AND $table.fieldid = $fieldid " .
                       "AND $table.who = $id";
    $$term = "($table.bug_when IS NOT NULL)";
}

sub _in_search_results
{
    my $self = shift;
    my %func_args = @_;
    my ($not_in, $f, $v, $term) =
        @func_args{qw(__not_in f v term)};
    my $query = LookupNamedQuery(trim($$v));
    my $queryparams = new Bugzilla::CGI($query);
    my $search = new Bugzilla::Search(
        params => $queryparams,
        fields => ["bugs.bug_id"],
        user   => Bugzilla->user,
    );
    my $sqlquery = $search->getSQL();
    unless ($not_in)
    {
        $$term = "($$f IN ($sqlquery))";
    }
    else
    {
        $$term = "($$f NOT IN ($sqlquery))";
    }
}

sub _not_in_search_results
{
    return _in_search_results(@_, __not_in => 1);
}

sub LookupNamedQuery
{
    my ($name, $sharer_id, $query_type, $throw_error) = @_;
    $throw_error = THROW_ERROR unless defined $throw_error;

    Bugzilla->login(LOGIN_REQUIRED);

    my $constructor = $throw_error ? 'check' : 'new';
    my $query = Bugzilla::Search::Saved->$constructor(
        { user => $sharer_id, name => $name });

    if (!$query ||
        defined $query_type && $query->type != $query_type)
    {
        if ($throw_error)
        {
            ThrowUserError("missing_query", { queryname => $name,
                                              sharer_id => $sharer_id });
        }
        else
        {
            return undef;
        }
    }

    $query->url
       || ThrowUserError("buglist_parameters_required", { queryname  => $name });

    return wantarray ? ($query->url, $query->id) : $query->url;
}

1;
