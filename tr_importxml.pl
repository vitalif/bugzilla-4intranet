#!/usr/bin/perl -w 
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
# Contributor(s): Dawn Endico <endico@mozilla.org>
#                 Gregary Hendricks <ghendricks@novell.com>
#                 Vance Baarda <vrb@novell.com> 


# This script reads in xml bug data from standard input and inserts 
# a new bug into bugzilla. Everything before the beginning <?xml line
# is removed so you can pipe in email messages.

use strict;

# figure out which path this script lives in. Set the current path to
# this and add it to @INC so this will work when run as part of mail
# alias by the mailer daemon
# since "use lib" is run at compile time, we need to enclose the
# $::path declaration in a BEGIN block so that it is executed before
# the rest of the file is compiled.
BEGIN {
 $::path = $0;
 $::path =~ m#(.*)/[^/]+#;
 $::path = $1;
 $::path ||= '.';  # $0 is empty at compile time.  This line will
                   # have no effect on this script at runtime.
}

chdir $::path;
use lib ( $::path, "extensions/testopia/lib" );

use Bugzilla;
use Testopia::Importer;

use XML::Twig;
use Getopt::Long;
use Pod::Usage;

# Keep the template from spitting out garbage
Bugzilla->usage_mode(USAGE_MODE_CMDLINE);
Bugzilla->error_mode(ERROR_MODE_DIE);

my $debug = 0;
my $help  = 0;
my $login = undef;
my $pass  = undef; 
my $product;
my $plans;

my $result = GetOptions(
    "verbose|debug+" => \$debug,
                        "help|?"         => \$help,
                        "login=s"        => \$login,
    "pass=s"         => \$pass,
    "product=s"      => \$product,
    "plans=s"        => \$plans, 
);

pod2usage(0) if $help;

use constant DEBUG_LEVEL => 2;
use constant ERR_LEVEL => 1;

sub Debug {
    return unless ($debug);
    my ( $message, $level ) = (@_);
    print STDERR "ERR: " . $message . "\n" if ( $level == ERR_LEVEL );
    print STDERR "$message\n" if ( ( $debug == $level ) && ( $level == DEBUG_LEVEL ) );
}

Debug( "Reading xml", DEBUG_LEVEL );

my $xml;
my $filename;
if ( $#ARGV == -1 ) {

    # Read STDIN in slurp mode. VERY dangerous, but we live on the wild side ;-)
    local ($/);
    $xml = <>;
}
elsif ( $#ARGV == 0 ) {
    $xml = $ARGV[0];
}
else {
    pod2usage(0);
}

# Log in if credentials are provided.
if ( defined $login ) {
    Debug( "Logging in as '$login'", DEBUG_LEVEL );

    # Make sure no user is logged in
    Bugzilla->logout();
    my $cgi = Bugzilla->cgi();
    $cgi->param( "Bugzilla_login",    $login );
    $cgi->param( "Bugzilla_password", $pass );

    Bugzilla->login();
}
                        
Debug( "Parsing tree", DEBUG_LEVEL );

my $testopiaXml = new Testopia::Importer;
$testopiaXml->debug($debug);
$testopiaXml->parse( $xml, $product, $plans );

exit 0;

__END__

=head1 NAME

tr_importxml - Import Testopia data from xml.

=head1 SYNOPSIS

    tr_importxml.pl [options] [file]

 Options:
       -? --help        Brief help message.
       -v --verbose     Print error and debug information. 
                        Multiple -v options increase verbosity.
       --login          Login ID (email address)
       --pass           Password
       --product        Name of product to import plans into. (Overrides product value in XML)
       --plans          Comma separated list of plan numbers to import cases into. (Overrides values in XML)
                        
       With no file read standard input.

=head1 OPTIONS

=over 8

=item B<-?>

    Print a brief help message and exits.

=item B<-v>

    Print error and debug information. Multiple -v increases verbosity

=back

=head1 DESCRIPTION

     This script is used import Test Plans and Test Cases into Testopia.
     

=cut
