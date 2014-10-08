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
#                 Gervase Markham <gerv@gerv.net>

use strict;
use lib qw(. lib);
use Bugzilla;

my $ARGS = Bugzilla->input_params;

# Convert comma/space separated elements into separate params
my $buglist = $ARGS->{buglist} || $ARGS->{bug_id} || $ARGS->{id};
my @ids = split /[\s,]+/, $buglist;
my $ids = join '', map { $_ = "&id=" . $_ } @ids;

print Bugzilla->cgi->redirect("show_bug.cgi?format=multiple$ids");
exit;
