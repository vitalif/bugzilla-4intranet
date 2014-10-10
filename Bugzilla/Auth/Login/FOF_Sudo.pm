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
# Contributor(s): Erik Stambaugh <erik@dasbistro.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Auth::Login::FOF_Sudo;
use strict;
use base qw(Bugzilla::Auth::Login);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;

use Net::IP::Match::XS;
use JSON;
use LWP::Simple ();

use constant can_logout => 0;
use constant can_login  => 0;
use constant requires_persistence  => 0;
use constant requires_verification => 0;

sub get_login_info {
    my ($self) = @_;

    my $cookie = Bugzilla->cookies->{fof_sudo_id};
    my $server = Bugzilla->params->{fof_sudo_server};
    return { failure => AUTH_NODATA } unless $cookie && $server;

    my @mynetworks = map { trim($_) } split /,+/, Bugzilla->params->{fof_sudo_mynetworks};
    return { failure => AUTH_NODATA } if @mynetworks && !match_ip(remote_ip(), @mynetworks);

    my $url = $server;
    $url .= ($url =~ tr/?/?/ ? '&' : '?');
    $url .= 'id=' . url_quote($cookie);
    my $authdata = LWP::Simple::get($url);
    if ($authdata)
    {
        trick_taint($authdata);
        eval { $authdata = decode_json($authdata); };
        if ($@)
        {
            die "Error decoding JSON: $@\nJSON:\n$authdata";
        }
    }
    return { failure => AUTH_NODATA } unless $authdata && $authdata->{user_name};

    my ($userid) = Bugzilla->dbh->selectrow_array("SELECT userid FROM emailin_aliases WHERE address=?", undef, $authdata->{user_name});

    return { failure => AUTH_NODATA } unless $userid;

    return { user_id => $userid };
}

sub fail_nodata {
    ThrowCodeError('env_no_email');
}

1;
