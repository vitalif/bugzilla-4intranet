# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Config::DependencyGraph;

use 5.10.1;
use strict;

use Bugzilla::Config::Common;

our $sortkey = 800;

sub get_param_list {
  my $class = shift;
  my @param_list = (
  {
   name => 'webdotbase',
   type => 't',
   default => 'http://www.research.att.com/~north/cgi-bin/webdot.cgi/%urlbase%',
   checker => \&check_webdotbase
  },

  {
   name => 'webtwopibase',
   type => 't',
   default => '',
   checker => \&check_webdotbase
  },

  {
   name => 'graph_rankdir',
   type => 's',
   choices => ['LR', 'RL', 'TB', 'BT'],
   default => 'LR'
  },

  {
   name => 'localdottimeout',
   type => 't',
   default => '5'
  },

  {
   name => 'graph_font',
   type => 't',
   default => '',
  },

  {
   name => 'graph_font_size',
   type => 't',
   default => '8',
  },

  );
  return @param_list;
}

1;
