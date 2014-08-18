#!/usr/bin/perl
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
# The Initial Developer of the Original Code is Frédéric Buclin.
# Portions created by Frédéric Buclin are Copyright (C) 2009
# Frédéric Buclin. All Rights Reserved.
#
# Contributor(s): 
#   Frédéric Buclin <LpSolit@gmail.com>
#   Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;
use Bugzilla::Extension;

my $VERSION = '1.0';
my $REQUIRED_MODULES = [
  {
      package => 'PerlMagick',
      module  => 'Image::Magick',
      version => 0,
  },
];

extension_version('BmpConvert', $VERSION);
required_modules('BmpConvert', $REQUIRED_MODULES);
clear_hooks('BmpConvert');
set_hook('BmpConvert', 'attachment_process_data', 'BmpConvert::attachment_process_data');
set_hook('BmpConvert', 'attachment_post_create_result', 'BmpConvert::attachment_post_create_result');

1;
__END__
