#!/usr/bin/perl -wT
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
#                 Myk Melez <myk@mozilla.org>
#                 Gervase Markham <gerv@gerv.net>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::Diff;
use Bugzilla::Constants;

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};

###############################################################################
# Begin Data/Security Validation
###############################################################################

# Check whether or not the user is currently logged in. 
Bugzilla->login();

# Make sure the bug ID is a positive integer representing an existing
# bug that the user is authorized to access.
my $id = $cgi->param('id');
my $bug = Bugzilla::Bug->check($id);

###############################################################################
# End Data/Security Validation
###############################################################################

# Run queries against the shadow DB. In the worst case, new changes are not
# visible immediately due to replication lag.
Bugzilla->switch_to_shadow_db;

my $operations;
($operations, $vars->{'incomplete_data'}) =
    Bugzilla::Bug::GetBugActivity($bug->id);

for (my $i = 0; $i < scalar @$operations; $i++)
{
    my $lines = 0;
    for (my $j = 0; $j < scalar @{$operations->[$i]->{changes}}; $j++)
    {
        my $change = $operations->[$i]->{changes}->[$j];
        my $field = Bugzilla->get_field($change->{fieldname});
        if ($change->{fieldname} eq 'longdesc' || $field->{type} eq FIELD_TYPE_TEXTAREA)
        {
            my $diff = new Bugzilla::Diff($change->{removed}, $change->{added})->get_table;
            $operations->[$i]->{changes}->[$j]->{lines} = $diff;
            $lines += scalar @$diff;
        }
        else
        {
            $lines++;
        }
    }
    $operations->[$i]->{total_lines} = $lines;
}

$vars->{'operations'} = $operations;
$vars->{'bug'} = $bug;

$template->process("bug/activity/show.html.tmpl", $vars)
  || ThrowTemplateError($template->error());
exit;
