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

package Bugzilla::Config::BugFields;

use strict;

use Bugzilla::Config::Common;
use Bugzilla::Field;

use constant USENAMES => {
    useclassification   => 'classification',
    usetargetmilestone  => 'target_milestone',
    useqacontact        => 'qa_contact',
    usestatuswhiteboard => 'status_whiteboard',
    usevotes            => 'votes',
    usebugaliases       => 'alias',
    use_see_also        => 'see_also',
    useplatform         => 'rep_platform',
    useopsys            => 'op_sys',
};

our $sortkey = 600;

# A bridge from products.classification_id to fielddefs.visibility_field
sub set_useclassification
{
    my ($value, $param) = @_;
    $_[0] = $value ? 1 : 0;
    my $f = Bugzilla->get_field('classification');
    $f->set_obsolete($value ? 0 : 1);
    $f->update;
    my $vf = $value ? $f->id : undef;
    $f = Bugzilla->get_field('product');
    $f->set_value_field($vf);
    $f->update;
    return '';
}

# A bridge from useXXX to fielddefs.obsolete (FIXME: This should be removed at some point)
sub set_usefield
{
    my ($value, $param) = @_;
    my $f = Bugzilla->get_field(USENAMES->{$param->{name}});
    $_[0] = $value ? 1 : 0;
    $f->set_obsolete($value ? 0 : 1);
    $f->update;
    return '';
}

sub get_param_list
{
    return (
        {
            name => 'useclassification',
            type => 'b',
            default => 0,
            checker => \&set_useclassification,
        },
        {
            name => 'usetargetmilestone',
            type => 'b',
            default => 0,
            checker => \&set_usefield,
        },
        {
            name => 'useqacontact',
            type => 'b',
            default => 0,
            checker => \&set_usefield,
        },
        {
            name => 'usestatuswhiteboard',
            type => 'b',
            default => 0,
            checker => \&set_usefield,
        },
        {
            name => 'usevotes',
            type => 'b',
            default => 0,
            checker => \&set_usefield,
        },
        {
            name => 'usebugaliases',
            type => 'b',
            default => 0,
            checker => \&set_usefield,
        },
        {
            name => 'use_see_also',
            type => 'b',
            default => 1,
            checker => \&set_usefield,
        },
        {
            name => 'useplatform',
            type => 'b',
            default => 1,
            checker => \&set_usefield,
        },
        {
            name => 'auto_add_flag_requestees_to_cc',
            type => 'b',
            default => 1,
        },
        {
            name => 'useopsys',
            type => 'b',
            default => 1,
            checker => \&set_usefield,
        },
        {
            name => 'clear_requests_on_close',
            type => 'b',
            default => 1,
        },
        {
            name => 'unauth_bug_details',
            type => 'b',
            default => 0,
        },
        {
            name => 'comment_line_length',
            type => 't',
            default => '80',
            checker => \&check_numeric,
        },
        {
            name => 'preview_comment_lines',
            type => 't',
            default => '30',
            checker => \&check_numeric,
        },
    );
}

1;
