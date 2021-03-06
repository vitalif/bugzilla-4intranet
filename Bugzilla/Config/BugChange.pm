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

package Bugzilla::Config::BugChange;

use strict;

use Bugzilla::Status;

our $sortkey = 500;

sub check_bug_status
{
    my $bug_status = shift;
    my @closed_bug_statuses = map { $_->name } grep { !$_->is_open } Bugzilla::Status->get_all;
    if (!grep { $_ eq $bug_status } @closed_bug_statuses)
    {
        return "Must be a valid closed status: one of " . join(', ', @closed_bug_statuses);
    }
    return "";
}

sub check_resolution
{
    my $resolution = shift;
    my $f;
    if (!$f->value_type->new({ name => $resolution }))
    {
        return "Must be a valid resolution: one of " . join(', ', $f->legal_value_names);
    }
    return "";
}

sub get_param_list
{
    my $class = shift;

    # Hardcoded bug statuses and resolutions which existed before Bugzilla 3.1.
    my @closed_bug_statuses = qw(RESOLVED VERIFIED CLOSED);
    my @resolutions = qw(FIXED INVALID WONTFIX LATER REMIND DUPLICATE WORKSFORME MOVED);

    # If we are upgrading from 3.0 or older, bug statuses are not customisable
    # and bug_status.is_open is not yet defined (hence the eval), so we use
    # the bug statuses above as they are still hardcoded.
    eval
    {
        my @st = map { $_->name } grep { !$_->is_open } Bugzilla::Status->get_all;
        my @res = map { $_->name } @{ Bugzilla->get_field('resolution')->legal_values };
        # If no closed states and resolutions were found was found, use the default list above.
        @closed_bug_statuses = @st if @st;
        @resolutions = @res if @res;
    };

    my @param_list = (
    {
        name => 'allow_commentsilent',
        type => 'b',
        default => 1,
    },

    {
        name => 'duplicate_or_move_bug_status',
        type => 's',
        choices => \@closed_bug_statuses,
        default => $closed_bug_statuses[0],
        checker => \&check_bug_status,
    },

    {
        name => 'closed_bug_status',
        type => 's',
        choices => \@closed_bug_statuses,
        default => 'CLOSED',
        checker => \&check_bug_status,
    },

    {
        name => 'duplicate_resolution',
        type => 's',
        choices => \@resolutions,
        default => 'DUPLICATE',
        checker => \&check_resolution,
    },

    {
        name => 'letsubmitterchoosepriority',
        type => 'b',
        default => 1,
    },

    {
        name => 'letsubmitterchoosemilestone',
        type => 'b',
        default => 1,
    },

    {
        name => 'musthavemilestoneonaccept',
        type => 'b',
        default => 0,
    },

    {
        name => 'commentonchange_resolution',
        type => 'b',
        default => 0,
    },

    {
        name => 'commentonduplicate',
        type => 'b',
        default => 0,
    },

    {
        name    => 'noresolveonopenblockers',
        type    => 'b',
        default => 0,
    },

    {
        name => 'assign_to_others',
        type => 'b',
        default => 1,
    },

    {
        name => 'auto_add_flag_requestees_to_cc',
        type => 'b',
        default => 1,
    },

    {
        name => 'unauth_bug_details',
        type => 'b',
        default => 0,
    },

    {
        name => 'preview_comment_lines',
        type => 't',
        default => '30',
        checker => \&check_numeric,
    },

    {
        name => 'comment_line_length',
        type => 't',
        default => '80',
        checker => \&check_numeric,
    },
    );
    return @param_list;
}

1;
