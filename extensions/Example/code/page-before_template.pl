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
# The Initial Developer of the Original Code is Canonical Ltd.
# Portions created by Canonical Ltd. are Copyright (C) 2009 
# Canonical Ltd. All Rights Reserved.
#
# Contributor(s):
#   Max Kanat-Alexander <mkanat@bugzilla.org>


use strict;
use warnings;
use Bugzilla;

my %args = %{ Bugzilla->hook_args };
my ($vars, $page) = @args{qw(vars page_id)};

# You can see this hook in action by loading page.cgi?id=example.html
if ($page eq 'example.html') {
    $vars->{cgi_variables} = { Bugzilla->cgi->Vars };
}
