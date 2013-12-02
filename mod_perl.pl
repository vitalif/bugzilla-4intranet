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

# This sets up our libpath without having to specify it in the mod_perl
# configuration.
use File::Basename;
use lib dirname(__FILE__);
use Bugzilla::Constants ();
use lib Bugzilla::Constants::bz_locations()->{'ext_libpath'};

# If you have an Apache2::Status handler in your Apache configuration,
# you need to load Apache2::Status *here*, so that any later-loaded modules
# can report information to Apache2::Status.
#use Apache2::Status ();

# We don't want to import anything into the global scope during
# startup, so we always specify () after using any module in this
# file.

use Apache2::ServerUtil;
use ModPerl::RegistryLoader ();
use File::Basename ();

# This loads most of our modules.
use Bugzilla ();
# Loading Bugzilla.pm doesn't load this, though, and we want it preloaded.
use Bugzilla::BugMail ();
use Bugzilla::CGI ();
use Bugzilla::Extension ();
use Bugzilla::Install::Requirements ();
use Bugzilla::Util ();

# Pre-compile the CGI.pm methods that we're going to use.
Bugzilla::CGI->compile(qw(:cgi :push));
if (0) {
    require Apache2::SizeLimit;
    # This means that every httpd child will die after processing
    # a CGI if it is taking up more than 70MB of RAM all by itself.
    Apache2::SizeLimit->set_max_unshared_size(70_000);
}
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
    PerlCleanupHandler  Apache2::SizeLimit Bugzilla::ModPerl::CleanupHandler
    PerlOptions +ParseHeaders
    Options +ExecCGI
    AllowOverride Limit FileInfo Indexes
    DirectoryIndex index.cgi index.html
</Directory>
EOT

$server->add_config([split("\n", $conf)]);

# Pre-load all extensions
$Bugzilla::extension_packages = Bugzilla::Extension->load_all();

# Have ModPerl::RegistryLoader pre-compile all CGI scripts.
my $rl = new ModPerl::RegistryLoader();
# If we try to do this in "new" it fails because it looks for a 
# Bugzilla/ModPerl/ResponseHandler.pm
$rl->{package} = 'Bugzilla::ModPerl::ResponseHandler';
my $feature_files = Bugzilla::Install::Requirements::map_files_to_features();
foreach my $file (glob "$cgi_path/*.cgi") {
    my $base_filename = File::Basename::basename($file);
    if (my $feature = $feature_files->{$base_filename}) {
        next if !Bugzilla->feature($feature);
    }
    Bugzilla::Util::trick_taint($file);
    $rl->handler($file, $file);
}

package Bugzilla::ModPerl::ResponseHandler;
use strict;
use base qw(ModPerl::Registry);
use Bugzilla;

sub handler : method {
    my $class = shift;

    # $0 is broken under mod_perl before 2.0.2, so we have to set it
    # here explicitly or init_page's shutdownhtml code won't work right.
    $0 = $ENV{'SCRIPT_FILENAME'};

    if ($Bugzilla::RELOAD_MODULES)
    {
        reload();
    }
    Bugzilla::init_page();
    return $class->SUPER::handler(@_);
}

sub error_check
{
    my $self = shift;
    if ($@ && !(ref $@ eq 'APR::Error' && $@ == ModPerl::EXIT))
    {
        die $@;
    }
    return $self->SUPER::error_check(@_);
}

my $STATS;

# To reload Perl modules on-the-fly (debug purposes),
# add the following to Apache config before "PerlConfigRequire ......./bugzilla3/mod_perl.pl;"
# <Perl>
#   $Bugzilla::RELOAD_MODULES = 1;
#   $^P |= 0x10;
# </Perl>
sub reload
{
    my ($file, $mtime);
    for my $key (keys %INC)
    {
        $file = $INC{$key} or next;
        $file =~ /\.p[ml]$/i or next; # do not reload *.cgi

        $mtime = (stat $file)[9];
        # Startup time as default
        $STATS->{$file} = $^T unless defined $STATS->{$file};

        # Modified
        if ($mtime > $STATS->{$file})
        {
            print STDERR __PACKAGE__ . ": $key -> $file modified, reloading\n";
            unload($key) or next;
            eval { require $key };
            if ($@)
            {
                warn $@;
            }
            $STATS->{$file} = $mtime;
        }
    }
}

sub unload
{
    my ($key) = @_;
    my $file = $INC{$key} or return;
    my @subs = grep { index($DB::sub{$_}, "$file:") == 0 } keys %DB::sub;
    for my $sub (@subs)
    {
        eval { undef &$sub };
        if ($@)
        {
            # TODO не выгружать то, что не можем выгрузить, ибо
            # иначе часть выгружается, а часть нет, и потом всё
            # равно всё дохнет.
            warn "Can't unload sub '$sub' in '$file': $@";
            return undef;
        }
        delete $DB::sub{$sub};
    }
    delete $INC{$key};
    return 1;
}

package Bugzilla::ModPerl::CleanupHandler;
use strict;
use Apache2::Const -compile => qw(OK);

sub handler {
    my $r = shift;
	
    # Sometimes mod_perl doesn't properly call DESTROY on all
    # the objects in pnotes()
    foreach my $key (keys %{$r->pnotes}) {
        delete $r->pnotes->{$key};
    }

    return Apache2::Const::OK;
}

1;
