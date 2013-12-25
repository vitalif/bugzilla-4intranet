# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
use Bugzilla::Extension;
use Bugzilla::Hook;

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
set_hook('BmpConvert', 'attachment_process_data', 'BmpConvert::attachment_process_data');
set_hook('BmpConvert', 'attachment_post_create', 'BmpConvert::attachment_post_create');
set_hook('BmpConvert', 'attachment_post_create_result', 'BmpConvert::attachment_post_create_result');
