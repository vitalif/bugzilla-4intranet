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
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Config::General;

use strict;
use POSIX;

use Bugzilla::Config::Common;
use Bugzilla::Constants;

our $sortkey = 150;

sub check_notification
{
    my $option = shift;
    my @current_version = (BUGZILLA_VERSION =~ m/^(\d+)\.(\d+)(?:(rc|\.)(\d+))?\+?$/);
    if ($current_version[1] % 2 && $option eq 'stable_branch_release')
    {
        return "You are currently running a development snapshot, and so your " .
            "installation is not based on a branch. If you want to be notified " .
            "about the next stable release, you should select " .
            "'latest_stable_release' instead";
    }
    if ($option ne 'disabled' && !Bugzilla->feature('updates'))
    {
        return "Some Perl modules are missing to get notifications about " .
            "new releases. See the output of checksetup.pl for more information";
    }
    return "";
}

sub check_utf8
{
    my $utf8 = shift;
    # You cannot turn off the UTF-8 parameter if you've already converted your tables to utf-8.
    my $dbh = Bugzilla->dbh;
    if ($dbh->isa('Bugzilla::DB::Mysql') && $dbh->bz_db_is_utf8 && !$utf8)
    {
        return "You cannot disable UTF-8 support, because your MySQL database is encoded in UTF-8";
    }
    return "";
}

use constant get_param_list => (
    {
        name => 'maintainer',
        type => 't',
        no_reset => '1',
        default => '',
        checker => \&check_email
    },

    {
        name => 'docs_urlbase',
        type => 't',
        default => 'docs/%lang%/html/',
        checker => \&check_url
    },

    {
        name => 'utf8',
        type => 'b',
        default => '0',
        checker => \&check_utf8
    },

    {
        name => 'announcehtml',
        type => 'l',
        default => ''
    },

    {
        name => 'entryheaderhtml',
        type => 'l',
        default =>
'<p>Before reporting a bug, please read the <a href="page.cgi?id=bug-writing.html">
bug writing guidelines</a>, please look at the list of
<a href="duplicates.cgi">most frequently reported bugs</a>, and please
<a href="query.cgi">search</a> for the bug.</p><hr />'
    },

    {
        name => 'bannerhtml',
        type => 'l',
        default => ''
    },

    {
        name => 'upgrade_notification',
        type => 's',
        choices => ['development_snapshot', 'latest_stable_release', 'stable_branch_release', 'disabled'],
        default => 'latest_stable_release',
        checker => \&check_notification
    },

    {
        name => 'new_functionality_msg',
        type => 'l',
        default => ''
    },

    {
        name => 'new_functionality_tsp',
        type => 't',
        default => POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime)
    },

    {
        name => 'shutdownhtml',
        type => 'l',
        default => ''
    },
);

1;
