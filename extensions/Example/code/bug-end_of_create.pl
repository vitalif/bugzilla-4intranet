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
# The Original Code is the Bugzilla Example Plugin.
#
# The Initial Developer of the Original Code is ITA Software
# Portions created by the Initial Developer are Copyright (C) 2009 
# the Initial Developer. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Bradley Baetz <bbaetz@acm.org>

use strict;
use warnings;
use Bugzilla;

# This code doesn't actually *do* anything, it's just here to show you
# how to use this hook.
my $args = Bugzilla->hook_args;
my $bug = $args->{'bug'};
my $timestamp = $args->{'timestamp'};

my $bug_id = $bug->id;
# Uncomment this line to see a line in your webserver's error log whenever
# you file a bug.
# warn "Bug $bug_id has been filed!";
