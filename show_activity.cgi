#!/usr/bin/perl -wT
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
use Bugzilla::Constants;

my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};

# Check whether or not the user is currently logged in.
Bugzilla->login();

# Run queries against the shadow DB. In the worst case, new changes are not
# visible immediately due to replication lag.
Bugzilla->switch_to_shadow_db;

my $class = Bugzilla->get_class($ARGS->{class} || 'bug');
if ($class->name ne 'bug')
{
    # FIXME: How to check permissions for deleted objects?
    $vars->{class} = $class;
    $vars->{id} = int($ARGS->{id});
    $vars->{obj} = $class->type->new($vars->{id});
    $vars->{operations} = $class->type->get_history($vars->{id});
    $template->process("admin/fieldvalues/history.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

# Make sure the bug ID is a positive integer representing an existing
# bug that the user is authorized to access.
my $bug = Bugzilla::Bug->check($ARGS->{id});

my $operations;
($operations, $vars->{incomplete_data}) = Bugzilla::Bug::GetBugActivity($bug->id);

$vars->{operations} = $operations;
$vars->{bug} = $bug;

$template->process("bug/activity/show.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
