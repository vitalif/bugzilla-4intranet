#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
# Page listing users who can access a bug
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Andrey Krasilnikov, Vitaliy Filippov

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

################################################################################
# Main Body Execution
################################################################################

viewlist();
exit;

sub viewlist {
    my $cgi = Bugzilla->cgi;
    my $template = Bugzilla->template;
    my $vars = {};

    my $user = Bugzilla->login();

    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check(scalar $cgi->param('id'));
    my $bugid = $bug->id;
    my $user_list = $bug->get_access_user_list();

    $vars->{'user_list'} = $user_list;
    $vars->{'count_user_list'} = scalar @$user_list;
    $vars->{'bug'} = $bug;

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("bug/checkaccess.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}
