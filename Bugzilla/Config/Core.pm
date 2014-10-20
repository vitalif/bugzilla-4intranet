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
#                 Dawn Endico <endico@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Joe Robins <jmrobins@tgix.com>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 J. Paul Reed <preed@sigkill.com>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Joseph Heenan <joseph@heenan.me.uk>
#                 Erik Stambaugh <erik@dasbistro.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#

package Bugzilla::Config::Core;

use strict;

use Socket;
use Bugzilla::Config::Common;

our $sortkey = 100;

sub check_sslbase
{
    my $url = shift;
    if ($url ne '')
    {
        if ($url !~ m#^https://([^/]+).*/$#)
        {
            return "must be a legal URL, that starts with https and ends with a slash.";
        }
        my $host = $1;
        # Fall back to port 443 if for some reason getservbyname() fails.
        my $port = getservbyname('https', 'tcp') || 443;
        if ($host =~ /^(.+):(\d+)$/)
        {
            $host = $1;
            $port = $2;
        }
        local *SOCK;
        my $proto = getprotobyname('tcp');
        socket(SOCK, PF_INET, SOCK_STREAM, $proto);
        my $iaddr = inet_aton($host) || return "The host $host cannot be resolved";
        my $sin = sockaddr_in($port, $iaddr);
        if (!connect(SOCK, $sin))
        {
            return "Failed to connect to $host:$port; unable to enable SSL";
        }
        close(SOCK);
    }
    return "";
}

use constant get_param_list => (
    {
        name => 'error_log',
        type => 't',
        default => 'errorlog',
    },

    {
        name => 'report_code_errors_to_maintainer',
        type => 'b',
        default => 1,
    },

    {
        name => 'report_user_errors_to_maintainer',
        type => 'b',
        default => 0,
    },

    {
        name => 'urlbase',
        type => 't',
        default => '',
        checker => \&check_urlbase,
    },

    {
        name => 'ssl_redirect',
        type => 'b',
        default => 0,
    },

    {
        name => 'sslbase',
        type => 't',
        default => '',
        checker => \&check_sslbase,
    },

    {
        name => 'cookiepath',
        type => 't',
        default => '/',
    },
);

1;
