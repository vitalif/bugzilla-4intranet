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

package Bugzilla::Config::MTA;

use strict;

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Config::Common;

our $sortkey = 1200;

sub check_mail_delivery_method
{
    my $check = check_multi(@_);
    return $check if $check;
    my $mailer = shift;
    if ($mailer eq 'sendmail' && ON_WINDOWS)
    {
        # look for sendmail.exe
        return "Failed to locate " . SENDMAIL_EXE unless -e SENDMAIL_EXE;
    }
    return "";
}

sub check_smtp_auth
{
    my $username = shift;
    if ($username && !Bugzilla->feature('smtp_auth'))
    {
        return "SMTP Authentication is not available. Run checksetup.pl for more details";
    }
    return "";
}

sub check_theschwartz_available
{
    my $use_queue = shift;
    if ($use_queue && !Bugzilla->feature('jobqueue'))
    {
        return "Using the job queue requires that you have certain Perl" .
            " modules installed. See the output of checksetup.pl" .
            " for more information";
    }
    return "";
}

sub get_param_list
{
    my $class = shift;
    my @param_list = (
    {
        name => 'mail_delivery_method',
        type => 's',
        choices => ['Sendmail', 'SMTP', 'Test', 'None'],
        default => 'Sendmail',
        checker => \&check_mail_delivery_method
    },

    {
        name => 'mailfrom',
        type => 't',
        default => 'bugzilla-daemon'
    },

    {
        name => 'use_mailer_queue',
        type => 'b',
        default => 0,
        checker => \&check_theschwartz_available,
    },

    {
        name => 'sendmailnow',
        type => 'b',
        default => 1
    },

    {
        name => 'smtpserver',
        type => 't',
        default => 'localhost'
    },

    {
        name => 'smtp_username',
        type => 't',
        default => '',
        checker => \&check_smtp_auth
    },

    {
        name => 'smtp_password',
        type => 'p',
        default => '',
    },

    {
        name => 'smtp_debug',
        type => 'b',
        default => 0
    },

    {
        name => 'whinedays',
        type => 't',
        default => 7,
        checker => \&check_numeric
    },

    {
        name => 'globalwatchers',
        type => 't',
        default => ''
    },
    );
    return @param_list;
}

1;
