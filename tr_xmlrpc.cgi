#!/usr/bin/perl -wT
####!/usr/bin/perl -d:ptkdb -wT
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
# Contributor(s): Marc Schumann <wurblzap@gmail.com>
#                 Dallas Harken <dharken@novell.com>

sub BEGIN
{
    # For use with ptkdb.
    $ENV{DISPLAY}=":0.0";
}

use strict;
use lib qw(. lib);

use XMLRPC::Transport::HTTP;
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::WebService;

Bugzilla->usage_mode(USAGE_MODE_WEBSERVICE);

die 'Content-Type must be "text/xml" when using API' unless
    $ENV{'CONTENT_TYPE'} eq 'text/xml';

my $dispatch = { 'TestPlan'    => 'Bugzilla::WebService::Testopia::TestPlan',
                 'TestCase'    => 'Bugzilla::WebService::Testopia::TestCase',
                 'TestRun'     => 'Bugzilla::WebService::Testopia::TestRun',
                 'TestCaseRun' => 'Bugzilla::WebService::Testopia::TestCaseRun',
                 'Product'     => 'Bugzilla::WebService::Testopia::Product',
                 'Environment' => 'Bugzilla::WebService::Testopia::Environment',
                 'Build'       => 'Bugzilla::WebService::Testopia::Build',
                 'Testopia'    => 'Bugzilla::WebService::Testopia::Testopia',
                 'User'        => 'Bugzilla::WebService::User',
               };
my $response = Bugzilla::WebService::XMLRPC::Transport::HTTP::CGI
    ->dispatch_with($dispatch)
    ->on_action(sub { Bugzilla::WebService::handle_login($dispatch, @_) } )
    ->handle;
    