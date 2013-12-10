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

# A bridge from useXXX to fielddefs.obsolete
sub set_usefield
{
    my ($value, $param) = @_;
    my $f = Bugzilla->get_field(USENAMES->{$param->{name}});
    $_[0] = $value ? 1 : 0;
    $f->set_obsolete($value ? 0 : 1);
    $f->update;
    return '';
}

sub get_param_list {
  my $class = shift;

  my @legal_priorities = @{get_legal_field_values('priority')};
  my @legal_severities = @{get_legal_field_values('bug_severity')};
  my @legal_platforms  = @{get_legal_field_values('rep_platform')};
  my @legal_OS         = @{get_legal_field_values('op_sys')};

  my @param_list = (
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
   name => 'use_see_also',
   type => 'b',
   default => 1,
   checker => \&set_usefield,
  },

  {
   name => 'defaultpriority',
   type => 's',
   choices => \@legal_priorities,
   default => $legal_priorities[-1],
   checker => \&check_priority
  },

  {
   name => 'defaultseverity',
   type => 's',
   choices => \@legal_severities,
   default => $legal_severities[-1],
   checker => \&check_severity
  },

  {
   name => 'useplatform',
   type => 'b',
   default => 1,
   checker => \&set_usefield,
  },

  {
   name => 'defaultplatform',
   type => 's',
   choices => ['', @legal_platforms],
   default => '',
   checker => \&check_platform
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
   name => 'defaultopsys',
   type => 's',
   choices => ['', @legal_OS],
   default => '',
   checker => \&check_opsys
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
  );
  return @param_list;
}

1;
