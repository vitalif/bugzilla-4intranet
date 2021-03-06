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
# Contributor(s): Joel Peshkin <bugreport@peshkin.net>

# This script is used by testserver.pl to confirm that cgi scripts
# are being run instead of shown. This script does not rely on database access
# or correct params.

use strict;
use POSIX;
use File::Basename;

print "HTTP/1.1 200 OK\n";
print "Content-Type: text/plain\n\n";
print "OK\n";
my ($group) = POSIX::getgrgid(POSIX::getegid());
$group ||= '';
open FD, ">".dirname($0)."/data/testserver_report";
print FD $::ENV{SERVER_SOFTWARE} . "\n$group\n";
close FD;
exit;
