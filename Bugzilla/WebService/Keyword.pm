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
# Contributor(s): Marc Schumann <wurblzap@gmail.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Mads Bondo Dydensborg <mbd@dbc.dk>
#                 Noura Elhawary <nelhawar@redhat.com>

package Bugzilla::WebService::Keyword;

use strict;
use base qw(Bugzilla::WebService);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::WebService::Util qw(filter validate);

# Function to return keywords by passing either keyword ids or
# keyword names or both together:
# $call = $rpc->call( 'Keyword.get', { ids => [1,2,3],
#         names => ['demo', 'meeting'] });
#
# Can be also used to match keywords based on their name:
# $call = $rpc->call( 'Keyword.get', { match => [ 'testkeyworda', 'testkeywordb' ]});
#
sub get
{
    my ($self, $params) = validate(@_, 'names', 'ids');

    # Make them arrays if they aren't
    if ($params->{names} && !ref $params->{names})
    {
        $params->{names} = [ $params->{names} ];
    }
    if ($params->{ids} && !ref $params->{ids})
    {
        $params->{ids} = [ $params->{ids} ];
    }
    if ($params->{match} && !ref $params->{match})
    {
        $params->{match} = [ $params->{match} ];
    }

    my @keyword_list;
    if ($params->{names})
    {
        my $keyword_objects = Bugzilla::Keyword->match({ value => @{$params->{names}} });
        @keyword_list = map { { name => $_->name } } @$keyword_objects;
    }

    if ($params->{ids})
    {
        my $keyword_objects = Bugzilla::Keyword->match({ id => @{$params->{ids}} });
        @keyword_list = map { { name => $_->name } } @$keyword_objects;
    }

    if ($params->{match})
    {
        my $keyword_objects = Bugzilla::Keyword->get_by_match(@{$params->{match}});
        @keyword_list = map { { name => $_->name } } @$keyword_objects;
    }

    return { keywords => \@keyword_list };
}

1;

__END__
