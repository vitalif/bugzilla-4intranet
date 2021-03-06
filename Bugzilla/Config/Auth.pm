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

package Bugzilla::Config::Auth;

use strict;

use Bugzilla::Util;
use Bugzilla::Config::Common;

our $sortkey = 300;

sub check_user_verify_class
{
    # doeditparams traverses the list of params, and for each one it checks,
    # then updates. This means that if one param checker wants to look at
    # other params, it must be below that other one. So you can't have two
    # params mutually dependent on each other.
    # This means that if someone clears the LDAP config params after setting
    # the login method as LDAP, we won't notice, but all logins will fail.
    # So don't do that.

    my $params = Bugzilla->params;
    my ($list, $entry) = @_;
    $list || return 'You need to specify at least one authentication mechanism';
    for my $class (split /,\s*/, $list)
    {
        my $res = check_multi($class, $entry);
        return $res if $res;
        if ($class eq 'RADIUS')
        {
            if (!Bugzilla->feature('auth_radius'))
            {
                return "RADIUS support is not available. Run checksetup.pl for more details";
            }
            return "RADIUS servername (RADIUS_server) is missing" if !$params->{RADIUS_server};
            return "RADIUS_secret is empty" if !$params->{RADIUS_secret};
        }
        elsif ($class eq 'LDAP')
        {
            if (!Bugzilla->feature('auth_ldap'))
            {
                return "LDAP support is not available. Run checksetup.pl for more details";
            }
            return "LDAP servername (LDAPserver) is missing" if !$params->{LDAPserver};
            return "LDAPBaseDN is empty" if !$params->{LDAPBaseDN};
        }
    }
    return "";
}

sub get_param_list
{
    my $class = shift;
    my @param_list = (
    {
        name => 'auth_env_id',
        type => 't',
        default => '',
    },

    {
        name => 'auth_env_email',
        type => 't',
        default => '',
    },

    {
        name => 'auth_env_realname',
        type => 't',
        default => '',
    },

    {
        name => 'user_info_class',
        type => 'o',
        choices => get_subclasses('Bugzilla::Auth::Login'),
        default => 'CGI',
        checker => \&check_multi
    },

    {
        name => 'user_verify_class',
        type => 'o',
        choices => get_subclasses('Bugzilla::Auth::Verify'),
        default => 'DB',
        checker => \&check_user_verify_class
    },

    {
        name => 'rememberlogin',
        type => 's',
        choices => ['on', 'defaulton', 'defaultoff', 'off'],
        default => 'on',
        checker => \&check_multi
    },

    {
        name => 'requirelogin',
        type => 'b',
        default => '0'
    },

    {
        name => 'emailregexp',
        type => 't',
        default => q:^[\\w\\.\\+\\-=]+@[\\w\\.\\-]+\\.[\\w\\-]+$:,
        checker => \&check_regexp
    },

    {
        name => 'emailregexpdesc',
        type => 'l',
        default => 'A legal address must contain exactly one \'@\', and at least one \'.\' after the @.'
    },

    {
        name => 'emailsuffix',
        type => 't',
        default => ''
    },

    {
        name => 'createemailregexp',
        type => 't',
        default => q:.*:,
        checker => \&check_regexp
    },

    {
        name => 'max_login_attempts',
        type => 't',
        default => 5,
        checker => sub { $_[0] =~ /^\d+$/so ? "" : "must be a positive integer value or 0 (means no limit)" },
    },

    {
        name => 'login_lockout_interval',
        type => 't',
        default => 30,
        checker => sub { $_[0] =~ /^[1-9]\d*$/so ? "" : "must be a positive integer value" },
    },
    );
    return @param_list;
}

1;
