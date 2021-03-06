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
# The Initial Developer of the Original Code is Everything Solved.
# Portions created by Everything Solved are Copyright (C) 2006 
# Everything Solved. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;

package Bugzilla::Search::Saved;

use base qw(Bugzilla::Object);

use Bugzilla::CGI;
use Bugzilla::Hook;
use Bugzilla::Constants;
use Bugzilla::Group;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Search;
use Bugzilla::CheckerUtils;
use Bugzilla::Views;

use Scalar::Util qw(blessed);

#############
# Constants #
#############

use constant DB_TABLE => 'namedqueries';

use constant DB_COLUMNS => qw(
    id
    userid
    name
    query
);

use constant REQUIRED_CREATE_FIELDS => qw(name query);

use constant VALIDATORS => {
    name => \&_check_name,
    query => \&_check_query,
    link_in_footer => \&_check_link_in_footer,
};

use constant UPDATE_COLUMNS => qw(name query);

###############
# Constructor #
###############

sub new
{
    my $class = shift;
    my $param = shift;
    my $dbh = Bugzilla->dbh;

    my $user;
    if (ref $param && !$param->{id})
    {
        $user = $param->{user} || Bugzilla->user;
        my $name = $param->{name};
        if (!defined $name)
        {
            ThrowCodeError('bad_arg', { argument => 'name', function => "${class}::new" });
        }
        my $condition = 'userid = ? AND '.$dbh->sql_istrcmp('name', '?');
        my $user_id = blessed $user ? $user->id : $user;
        detaint_natural($user_id) || ThrowCodeError('param_must_be_numeric',
            { function => $class . '::_init', param => 'user' });
        my @values = ($user_id, $name);
        $param = { condition => $condition, values => \@values };
    }

    unshift @_, $param;
    my $self = $class->SUPER::new(@_);
    if ($self)
    {
        $self->{user} = $user if blessed $user;
        # Some DBs (read: Oracle) incorrectly mark the query string as UTF-8
        # when it's coming out of the database, even though it has no UTF-8
        # characters in it, which prevents Bugzilla::CGI from later reading
        # it correctly.
        utf8::downgrade($self->{query}) if utf8::is_utf8($self->{query});
    }
    return $self;
}

sub check
{
    my $class = shift;
    my ($param) = @_;
    my $search = $class->SUPER::check($param);
    my $user = $param->{runner} || Bugzilla->user;
    return $search if $search->user->id == $user->id;
    if (!$user->in_group('admin') &&
        (!$search->shared_with_group || !$user->in_group($search->shared_with_group)))
    {
        ThrowUserError('missing_query', {
            queryname => $search->name,
            sharer_id => $search->user->id,
        });
    }
    return $search;
}

##############
# Validators #
##############

sub _check_link_in_footer { return $_[1] ? 1 : 0; }

sub _check_name
{
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("query_name_missing");
    $name !~ /[<>&]/ || ThrowUserError("illegal_query_name");
    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError("query_name_too_long");
    }
    return $name;
}

sub _check_query
{
    my ($invocant, $query) = @_;
    $query || ThrowUserError("buglist_parameters_required");
    my $params = http_decode_query($query);
    # Don't store the query name as a parameter.
    delete $params->{known_name};
    delete $params->{sharer_id};
    return http_build_query(Bugzilla::Search->clean_search_params($params));
}

#########################
# Database Manipulation #
#########################

sub create
{
    my $class = shift;
    Bugzilla->login(LOGIN_REQUIRED);
    my $dbh = Bugzilla->dbh;
    $class->check_required_create_fields(@_);
    $dbh->bz_start_transaction();
    my $params = $class->run_create_validators(@_);

    # Right now you can only create a Saved Search for the current user.
    $params->{userid} = Bugzilla->user->id;

    my $lif = delete $params->{link_in_footer};
    my $obj = $class->insert_create_data($params);
    if ($lif)
    {
        $dbh->do(
            'INSERT INTO namedqueries_link_in_footer (user_id, namedquery_id) VALUES (?,?)',
            undef, $params->{userid}, $obj->id
        );
    }
    $dbh->bz_commit_transaction();

    return $obj;
}

sub preload
{
    my ($searches) = @_;
    my $dbh = Bugzilla->dbh;

    return unless scalar @$searches;

    my @query_ids = map { $_->id } @$searches;
    my $queries_in_footer = $dbh->selectcol_arrayref(
        'SELECT namedquery_id FROM namedqueries_link_in_footer' .
        ' WHERE ' . $dbh->sql_in('namedquery_id', \@query_ids) . ' AND user_id = ?',
        undef, Bugzilla->user->id
    );

    my %links_in_footer = map { $_ => 1 } @$queries_in_footer;
    foreach my $query (@$searches)
    {
        $query->{link_in_footer} = ($links_in_footer{$query->id}) ? 1 : 0;
    }
}

sub update
{
    my $self = shift;
    my @r;
    if (wantarray)
    {
        @r = $self->SUPER::update(@_);
    }
    else
    {
        @r = scalar $self->SUPER::update(@_);
    }
    Bugzilla::Hook::process('savedsearch-post-update', { search => $self });
    Bugzilla::CheckerUtils::savedsearch_post_update({ search => $self });
    Bugzilla::Views::refresh_some_views([ $self->user->login ]);
    return @r;
}

sub remove_from_db
{
    my $self = shift;

    # Do not forget the saved search if it is being used in a whine or a checker
    if (my $whines_in_use = $self->used_in_whine)
    {
        ThrowUserError('saved_search_used_by_whines', {
            subjects    => join(', ', @$whines_in_use),
            search_name => $self->name,
        });
    }
    if (my $checkers = $self->used_in_checkers)
    {
        ThrowUserError('saved_search_used_by_checkers', {
            search_name => $self->name,
        });
    }

    my $dbh = Bugzilla->dbh;
    $dbh->do('DELETE FROM namedqueries WHERE id = ?', undef, $self->id);

    if (Bugzilla->user->id == $self->userid)
    {
        # Reset the cached queries
        $self->user->flush_queries_cache;
    }
}

#####################
# Complex Accessors #
#####################

sub used_in_whine
{
    my ($self) = @_;
    return $self->{used_in_whine} if exists $self->{used_in_whine};
    my $r = Bugzilla->dbh->selectcol_arrayref(
        'SELECT DISTINCT whine_events.subject FROM whine_events'.
        ' INNER JOIN whine_queries ON whine_events.id = whine_queries.eventid'.
        ' WHERE whine_events.owner_userid = ? AND query_name = ?',
        undef, $self->{userid}, $self->name
    );
    $self->{used_in_whine} = $r && @$r ? $r : undef;
    return $self->{used_in_whine};
}

sub used_in_checkers
{
    my $self = shift;
    if (!exists $self->{used_in_checkers})
    {
        ($self->{used_in_checkers}) = Bugzilla->dbh->selectrow_array('SELECT 1 FROM checkers WHERE query_id=?', undef, $self->id);
    }
    return $self->{used_in_checkers};
}

sub link_in_footer
{
    my ($self, $user) = @_;
    # We only cache link_in_footer for the current Bugzilla->user.
    return $self->{link_in_footer} if exists $self->{link_in_footer} && !$user;
    my $user_id = $user ? $user->id : Bugzilla->user->id;
    my $link_in_footer = Bugzilla->dbh->selectrow_array(
        'SELECT 1 FROM namedqueries_link_in_footer WHERE namedquery_id = ? AND user_id = ?',
        undef, $self->id, $user_id
    ) || 0;
    $self->{link_in_footer} = $link_in_footer if !$user;
    return $link_in_footer;
}

sub shared_with_group
{
    my ($self) = @_;
    return $self->{shared_with_group} if exists $self->{shared_with_group};
    # Bugzilla only currently supports sharing with one group, even
    # though the database backend allows for an infinite number.
    my ($group_id) = Bugzilla->dbh->selectrow_array(
        'SELECT group_id FROM namedquery_group_map WHERE namedquery_id = ?',
        undef, $self->id
    );
    $self->{shared_with_group} = $group_id ? new Bugzilla::Group($group_id) : undef;
    return $self->{shared_with_group};
}

sub shared_with_users
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!exists $self->{shared_with_users})
    {
        $self->{shared_with_users} = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM namedqueries_link_in_footer'.
            ' INNER JOIN namedqueries ON namedquery_id = id'.
            ' WHERE namedquery_id = ? AND user_id != userid',
            undef, $self->id
        );
    }
    return $self->{shared_with_users};
}

####################
# Simple Accessors #
####################

sub query { $_[0]->{query} }
sub userid { $_[0]->{userid} }

sub user
{
    my ($self) = @_;
    return $self->{user} if defined $self->{user};
    return Bugzilla->user if Bugzilla->user->id == $self->{userid};
    $self->{user} = new Bugzilla::User($self->{userid});
    return $self->{user};
}

############
# Mutators #
############

sub set_name  { $_[0]->set('name',  $_[1]); }
sub set_query { $_[0]->set('query', $_[1]); }

sub set_link_in_footer
{
    my $self = shift;
    my ($link) = @_;
    if ($link && !$self->link_in_footer)
    {
        Bugzilla->dbh->do(
            'INSERT INTO namedqueries_link_in_footer (namedquery_id, user_id) VALUES (?, ?)',
            undef, $self->id, Bugzilla->user->id
        );
    }
    elsif (!$link && $self->link_in_footer)
    {
        Bugzilla->dbh->do(
            'DELETE FROM namedqueries_link_in_footer WHERE namedquery_id=? AND user_id=?',
            undef, $self->id, Bugzilla->user->id
        );
    }
    delete $self->{link_in_footer};
}

sub set_shared_with_group
{
    my $self = shift;
    my ($group, $force_link_in_footer) = @_;
    my $user = Bugzilla->user;
    # Don't allow the user to share queries with groups he's not allowed to.
    $group = undef if $group && !grep { $_ eq $group->id } @{$user->queryshare_groups};
    # Don't remove namedqueries_link_in_footer entries for users
    # subscribing to the shared query. The idea is that they will
    # probably want to be subscribers again should the sharing
    # user choose to share the query again.
    my $dbh = Bugzilla->dbh;
    $dbh->do('DELETE FROM namedquery_group_map WHERE namedquery_id=?', undef, $self->id);
    if ($group)
    {
        # Share the query to $group
        $dbh->do('INSERT INTO namedquery_group_map (namedquery_id, group_id) VALUES (?, ?)', undef, $self->id, $group->id);

        # If we're sharing our query with a group we can bless, we
        # have the ability to add link to our search to the footer of
        # direct group members automatically.
        my $force;
        if ($force_link_in_footer && $user->can_bless($group->id) &&
            ($force = $group->members_non_inherited) &&
            (@$force = grep { $_->id != $user->id } @$force))
        {
            $dbh->do(
                'DELETE FROM namedqueries_link_in_footer WHERE namedquery_id='.$self->id.
                ' AND user_id IN ('.join(',', map { $_->id } @$force).')'
            );
            $dbh->do(
                'INSERT INTO namedqueries_link_in_footer (namedquery_id, user_id) VALUES '.
                join(',', map { '('.$self->id.','.$_->id.')' } @$force)
            );
        }
    }
    $self->{shared_with_group} = $group;
}

1;

__END__

=head1 NAME

Bugzilla::Search::Saved - A saved search

=head1 SYNOPSIS

 use Bugzilla::Search::Saved;

 my $query = new Bugzilla::Search::Saved($query_id);

 my $edit_link  = $query->edit_link;
 my $search_url = $query->query;
 my $owner      = $query->user;
 my $num_subscribers = $query->shared_with_users;

=head1 DESCRIPTION

This module exists to represent a L<Bugzilla::Search> that has been
saved to the database.

This is an implementation of L<Bugzilla::Object>, and so has all the
same methods available as L<Bugzilla::Object>, in addition to what is
documented below.

=head1 METHODS

=head2 Constructors and Database Manipulation

=over

=item C<new>

Takes either an id, or the named parameters C<user> and C<name>.
C<user> can be either a L<Bugzilla::User> object or a numeric user id.

See also: L<Bugzilla::Object/new>.

=item C<preload>

Sets C<link_in_footer> for all given saved searches at once, for the
currently logged in user. This is much faster than calling this method
for each saved search individually.

=back


=head2 Accessors

These return data about the object, without modifying the object.

=over

=item C<edit_link>

A url with which you can edit the search.

=item C<url>

The CGI parameters for the search, as a string.

=item C<link_in_footer>

Whether or not this search should be displayed in the footer for the
I<current user> (not the owner of the search, but the person actually
using Bugzilla right now).

=item C<type>

The numeric id of the type of search this is (from L<Bugzilla::Constants>).

=item C<shared_with_group>

The L<Bugzilla::Group> that this search is shared with. C<undef> if
this search isn't shared.

=item C<shared_with_users>

Returns how many users (besides the author of the saved search) are
using the saved search, i.e. have it displayed in their footer.

=back
