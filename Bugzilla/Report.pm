# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;

package Bugzilla::Report;

use base qw(Bugzilla::Object);

use Bugzilla::CGI;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Search;

use constant DB_TABLE => 'reports';

use constant DB_COLUMNS => qw(
    id
    user_id
    name
    query
);

use constant UPDATE_COLUMNS => qw(
    name
    query
);

use constant REQUIRED_CREATE_FIELDS => qw(
    user_id
    name
    query
);

use constant VALIDATORS => {
    name    => \&_check_name,
    query   => \&_check_query,
};

##############
# Validators #
##############

sub _check_name
{
    my ($invocant, $name) = @_;
    $name = clean_text($name);
    $name || ThrowUserError("report_name_missing");
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
    $query || ThrowUserError('buglist_parameters_required');
    return http_build_query(Bugzilla::Search->clean_search_params(http_decode_query($query)));
}

#############
# Accessors #
#############

sub query { $_[0]->{query} }
sub user_id { $_[0]->{user_id} }

sub set_name { $_[0]->set('name', $_[1]); }
sub set_query { $_[0]->set('query', $_[1]); }

###########
# Methods #
###########

sub create
{
    my $class = shift;
    my $param = shift;

    Bugzilla->login(LOGIN_REQUIRED);
    $param->{user_id} = Bugzilla->user->id;

    unshift @_, $param;
    my $self = $class->SUPER::create(@_);
}

sub check
{
    my $class = shift;
    my $report = $class->SUPER::check(@_);
    my $user = Bugzilla->user;
    if ($report->user_id != Bugzilla->user->id)
    {
        ThrowUserError('report_access_denied');
    }
    return $report;
}

1;

__END__

=head1 NAME

Bugzilla::Report - Bugzilla report class.

=head1 SYNOPSIS

    use Bugzilla::Report;

    my $report = new Bugzilla::Report(1);

    my $report = Bugzilla::Report->check({id => $id});

    my $name = $report->name;
    my $query = $report->query;

    my $report = Bugzilla::Report->create({ name => $name, query => $query });

    $report->set_name($new_name);
    $report->set_query($new_query);
    $report->update();

    $report->remove_from_db;

=head1 DESCRIPTION

Report.pm represents a Report object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

=cut
