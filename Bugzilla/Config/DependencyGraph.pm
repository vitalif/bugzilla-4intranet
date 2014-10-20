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

package Bugzilla::Config::DependencyGraph;

use strict;

use Bugzilla::Config::Common;

our $sortkey = 800;

sub check_webdotbase
{
    my ($value) = (@_);
    $value = trim($value);
    if ($value eq "")
    {
        return "";
    }
    if ($value !~ /^https?:/)
    {
        if (!-x $value)
        {
            return "The file path \"$value\" is not a valid executable. Please specify the complete file path to 'dot' if you intend to generate graphs locally.";
        }
        # Check .htaccess allows access to generated images
        my $webdotdir = bz_locations()->{webdotdir};
        if (-e "$webdotdir/.htaccess")
        {
            open HTACCESS, "$webdotdir/.htaccess";
            local $/ = undef;
            if (!grep /png/, <HTACCESS>)
            {
                return "Dependency graph images are not accessible.\nAssuming that you have not modified the file, delete $webdotdir/.htaccess and re-run checksetup.pl to rectify.\n";
            }
            close HTACCESS;
        }
    }
    return "";
}

sub get_param_list
{
    my $class = shift;
    my @param_list = (
    {
        name => 'webdotbase',
        type => 't',
        default => 'http://www.research.att.com/~north/cgi-bin/webdot.cgi/%urlbase%',
        checker => \&check_webdotbase
    },

    {
        name => 'webtwopibase',
        type => 't',
        default => '',
        checker => \&check_webdotbase
    },

    {
        name => 'graph_rankdir',
        type => 's',
        choices => ['LR', 'RL', 'TB', 'BT'],
        default => 'LR'
    },

    {
        name => 'localdottimeout',
        type => 't',
        default => '5'
    },

    {
        name => 'graph_font',
        type => 't',
        default => '',
    },

    {
        name => 'graph_font_size',
        type => 't',
        default => '8',
    },
    );
    return @param_list;
}

1;
