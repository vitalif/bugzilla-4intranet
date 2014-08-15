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

# Hooks allowing to create MySQL Views representing saved searches for users
if (!Bugzilla->params->{ext_disable_refresh_views})
{
    set_hook('custis', 'editgroups_post_create',        'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_delete',        'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_edit',          'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_remove_regexp', 'FlushViews::refresh_views');
    set_hook('custis', 'editusersingroup_post_add',     'FlushViews::refresh_views');
    set_hook('custis', 'editusers_post_delete',         'FlushViews::editusers_post_update_delete');
    set_hook('custis', 'editusers_post_update',         'FlushViews::editusers_post_update_delete');
    set_hook('custis', 'savedsearch_post_update',       'FlushViews::savedsearch_post_update');
    add_hook('custis', 'install_before_final_checks',   'FlushViews::install_before_final_checks');
}

# Hooks for bug change correctness checks
set_hook('custis', 'bug_pre_update',                'Checkers::bug_pre_update');
set_hook('custis', 'bug_end_of_update',             'Checkers::bug_end_of_update');
set_hook('custis', 'bug_end_of_create',             'Checkers::bug_end_of_create');
add_hook('custis', 'savedsearch_post_update',       'Checkers::savedsearch_post_update');
add_hook('custis', 'install_before_final_checks',   'Checkers::install_before_final_checks');

# Other hooks
set_hook('custis', 'flag_check_requestee_list',     'CustisMiscHooks::flag_check_requestee_list');
set_hook('custis', 'process_bug_after_move',        'CustisMiscHooks::process_bug_after_move');
set_hook('custis', 'enter_bug_cloned_bug',          'CustisMiscHooks::enter_bug_cloned_bug');
set_hook('custis', 'post_bug_cloned_bug',           'CustisMiscHooks::post_bug_cloned_bug');
set_hook('custis', 'emailin_filter_body',           'CustisMiscHooks::emailin_filter_body');

1;
__END__
