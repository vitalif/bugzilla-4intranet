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
#                 Daniel Raichle <draichle@gmx.net>
#                 Dave Miller <justdave@syndicomm.com>
#                 Alexander J. Vincent <ajvincent@juno.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Greg Hendricks <ghendricks@novell.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Marc Schumann <wurblzap@gmail.com>
#                 Byron Jones <bugzilla@glob.com.au>

################################################################################
# Script Initialization
################################################################################

# Make it harder for us to do dangerous things in Perl.
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Bug;
use Bugzilla::Field;

# For most scripts we don't make $cgi and $template global variables. But
# when preparing Bugzilla for mod_perl, this script used these
# variables in so many subroutines that it was easier to just
# make them globals.
local our $cgi = Bugzilla->cgi;
local our $template = Bugzilla->template;
local our $vars = {};

################################################################################
# Main Body Execution
################################################################################

my $user = Bugzilla->login();

viewlist();
exit;

sub viewlist {
    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check(scalar $cgi->param('id'));
    my $bugid = $bug->id;
    my $user_list = $bug->getAccessUserList();

    $vars->{'user_list'} = $user_list;
    $vars->{'count_user_list'} = scalar @$user_list;
    $vars->{'bug'} = $bug;

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("pages/checkaccess.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
}

