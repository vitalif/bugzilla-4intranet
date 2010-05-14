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
# The Original Code is the Bugzilla Testopia System.
#
# The Initial Developer of the Original Code is Greg Hendricks.
# Portions created by Greg Hendricks are Copyright (C) 2006
# Novell. All Rights Reserved.
#
# Contributor(s): Greg Hendricks <ghendricks@novell.com>

use strict;
no warnings qw(void); # Avoid "useless use of a constant in void context"
use Bugzilla::Extension;
use Testopia::Constants;

my $REQUIRED_MODULES = [
    {
        package => 'JSON',
        module  => 'JSON',
        version => '2.10'
    },
    {
        package => 'Text-Diff',
        module  => 'Text::Diff',
        version => '0.35'
    },
];

my $OPTIONAL_MODULES = [
    {
        package => 'Text-CSV',
        module  => 'Text::CSV',
        version => '1.06',
        feature => 'CSV Importing of test cases'
    },
    {
        package => 'GD-Graph3d',
        module  => 'GD::Graph3d',
        version => '0.63'
    },
    {
        package => 'XML Schema Validator',
        module  => 'XML::Validator::Schema',
        version => '1.10',
        feature => 'XML Importing of test cases and plans'
    },
    {
        package => 'XML Schema Parser',
        module  => 'XML::SAX::ParserFactory',
        version => 0,
        feature => 'XML Importing of test cases and plans'
    },
    {
        package => 'XML Twig',
        module  => 'XML::Twig',
        version => 0,
        feature => 'XML Importing of test cases and plans'
    }
];

required_modules('testopia', $REQUIRED_MODULES);
optional_modules('testopia', $OPTIONAL_MODULES);
extension_version('testopia', Testopia::Constants::TESTOPIA_VERSION);

1;
