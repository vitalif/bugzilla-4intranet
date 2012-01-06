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
# The Initial Developer of the Original Code is Matt Selsky
# Portions created by Matt Selsky are Copyright (C) 2011
# Matt Selsky. All Rights Reserved.
#
# Contributor(s): Matt Selsky <selsky@columbia.edu>

package Bugzilla::BugUrl::ReviewBoard;
use strict;
use base qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
    my ($class, $uri) = @_;
    return ($uri->path =~ m|/r/\d+/?$|) ? 1 : 0;
}

sub _check_value {
    my $class = shift;

    my $uri = $class->SUPER::_check_value(@_);

    # Review Board URLs have only one form (the trailing slash is optional):
    #   http://reviews.reviewboard.org/r/111/

    # Make sure there are no query parameters.
    $uri->query(undef);
    # And remove any # part if there is one.
    $uri->fragment(undef);

    # make sure the trailing slash is present
    if ($uri->path !~ m|/$|) {
        $uri->path($uri->path . '/');
    }

    return $uri;
}

1;
