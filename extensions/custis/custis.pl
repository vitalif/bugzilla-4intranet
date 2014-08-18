#!/usr/bin/perl
# Not really an extension -- can't be disabled, because many core files in our version
# depend on features implemented here.
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

# FIXME: Most of these 'non-disableable' features should be moved into core.

use strict;
use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Extension;

my $REQUIRED_MODULES = [];
my $OPTIONAL_MODULES = [];

required_modules('custis', $REQUIRED_MODULES);
optional_modules('custis', $OPTIONAL_MODULES);
clear_hooks('custis');

# Other hooks
set_hook('custis', 'flag_check_requestee_list', 'CustisMiscHooks::flag_check_requestee_list');
set_hook('custis', 'enter_bug_cloned_bug',      'CustisMiscHooks::enter_bug_cloned_bug');
set_hook('custis', 'post_bug_cloned_bug',       'CustisMiscHooks::post_bug_cloned_bug');
set_hook('custis', 'emailin_filter_body',       'CustisMiscHooks::emailin_filter_body');

1;
__END__
