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
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::ModPerl;

use strict;

# If you have an Apache2::Status handler in your Apache configuration,
# you need to load Apache2::Status *here*, so that Apache::DBI can
# report information to Apache2::Status.
#use Apache2::Status ();

# We don't want to import anything into the global scope during
# startup, so we always specify () after using any module in this
# file.

use Apache2::ServerUtil;
use CGI qw(-no_xhtml -oldstyle_urls :private_tempfiles :unique_headers SERVER_PUSH);
CGI->compile(qw(:cgi -no_xhtml -oldstyle_urls :private_tempfiles
                :unique_headers SERVER_PUSH :push));
use Template::Config ();
Template::Config->preload();

use Bugzilla ();
use Bugzilla::Constants ();
use Bugzilla::CGI ();
use Bugzilla::Mailer ();
use Bugzilla::Template ();
use Bugzilla::Util ();

my $cgi_path = Bugzilla::Constants::bz_locations()->{'cgi_path'};

# Set up the configuration for the web server
my $server = Apache2::ServerUtil->server;
my $conf = <<EOT;
# Make sure each httpd child receives a different random seed (bug 476622)
PerlChildInitHandler "sub { srand(); }"
<Directory "$cgi_path">
    AddHandler perl-script .cgi
    # No need to PerlModule these because they're already defined in mod_perl.pl
    PerlResponseHandler Bugzilla::ModPerl::ResponseHandler
    PerlCleanupHandler  Bugzilla::ModPerl::CleanupHandler
    PerlOptions +ParseHeaders
    Options +ExecCGI
    AllowOverride Limit
    DirectoryIndex index.cgi index.html
</Directory>
EOT

if ($^O =~ /MSWin32/i)
{
    $conf = "<Perl>\nuse lib qw(lib/win32);\n</Perl>\n$conf";
}

$server->add_config([split("\n", $conf)]);


package Bugzilla::ModPerl::ResponseHandler;
use strict;
use base qw(ModPerl::Registry);
use Bugzilla;

sub handler : method {
    my $class = shift;

    # $0 is broken under mod_perl before 2.0.2, so we have to set it
    # here explicitly or init_page's shutdownhtml code won't work right.
    $0 = $ENV{'SCRIPT_FILENAME'};

    Bugzilla::init_page();
    return $class->SUPER::handler(@_);
}


package Bugzilla::ModPerl::CleanupHandler;
use strict;
use Apache2::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    Bugzilla::_cleanup();
    # Sometimes mod_perl doesn't properly call DESTROY on all
    # the objects in pnotes()
    foreach my $key (keys %{$r->pnotes}) {
        delete $r->pnotes->{$key};
    }

    return Apache2::Const::OK;
}

1;
