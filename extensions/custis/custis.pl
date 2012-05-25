#!/usr/bin/perl
# CustIS-расширения Bugzilla
# Разумеется, далеко не все - только часть, отсаженная на Hooks
# Раньше (до svn 998) все эти хуки жили в отдельных файлах в extensions/custis/code/*.pl
#  что было совместимо со стандартной системой хуков Bugzilla, которую убрали в 3.6.

use strict;
use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Extension;

my $REQUIRED_MODULES = [
    {
        package => 'Text-TabularDisplay',
        module  => 'Text::TabularDisplay',
        feature => 'Table formatting inside bug comments',
    },
];
my $OPTIONAL_MODULES =
[
    {
        package => 'Spreadsheet-ParseExcel',
        module  => 'Spreadsheet::ParseExcel',
        version => '0.54',
        feature => 'Import of binary Excel files (*.xls)',
    },
    {
        package => 'Spreadsheet-XLSX',
        module  => 'Spreadsheet::XLSX',
        version => '0.1',
        feature => 'Import of OOXML Excel files (*.xlsx)',
    },
    {
        package => 'Net-IP-Match-XS',
        module  => 'Net::IP::Match::XS',
        feature => 'FOF-Sudo system-to-system authorization',
    },
    {
        package => 'LWP-MediaTypes',
        module  => 'LWP::MediaTypes',
        feature => 'Guessing attachment types',
    },
];

required_modules('custis', $REQUIRED_MODULES);
optional_modules('custis', $OPTIONAL_MODULES);
clear_hooks('custis');

# Изменения схемы БД
set_hook('custis', 'db_schema_abstract_schema',     'CustisDBHooks::db_schema_abstract_schema');
set_hook('custis', 'install_update_db',             'CustisDBHooks::install_update_db');
set_hook('custis', 'install_update_fielddefs',      'CustisDBHooks::install_update_fielddefs');

# Хуки в показ списка багов
set_hook('custis', 'buglist_static_columns',        'CustisBuglistHooks::buglist_static_columns');
set_hook('custis', 'buglist_columns',               'CustisBuglistHooks::buglist_columns');

# Хуки в обработку почты
set_hook('custis', 'bugmail_pre_template',          'CustisMailHooks::bugmail_pre_template');
set_hook('custis', 'bugmail_post_send',             'CustisMailHooks::bugmail_post_send');
set_hook('custis', 'flag_notify_pre_template',      'CustisMailHooks::flag_notify_pre_template');
set_hook('custis', 'flag_notify_post_send',         'CustisMailHooks::flag_notify_post_send');
set_hook('custis', 'emailin_filter_body',           'CustisMailHooks::emailin_filter_body');
set_hook('custis', 'emailin_filter_html',           'CustisMailHooks::emailin_filter_html');

# Хуки для предоставления View'шек в базе для доступа извне
if (!Bugzilla->params->{ext_disable_refresh_views})
{
    set_hook('custis', 'editgroups_post_create',        'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_delete',        'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_edit',          'FlushViews::refresh_views');
    set_hook('custis', 'editgroups_post_remove_regexp', 'FlushViews::refresh_views');
    set_hook('custis', 'editusersingroup_post_add',     'FlushViews::refresh_views');
    set_hook('custis', 'editusers_post_delete',         'FlushViews::editusers_post_update_delete');
    set_hook('custis', 'editusers_post_update',         'FlushViews::editusers_post_update_delete');
    set_hook('custis', 'savedsearch_post_update',       [ 'FlushViews::savedsearch_post_update' ]);
    add_hook('custis', 'install_before_final_checks',   'FlushViews::install_before_final_checks');
}

# Хуки для синхронизации тест-плана Testopia с Wiki-категорией
set_hook('custis', 'tr_show_plan_after_fetch',      'CustisTestPlanSync::tr_show_plan_after_fetch');

# Хуки для системы проверки корректности изменений багов
set_hook('custis', 'bug_pre_update',                'Checkers::bug_pre_update');
set_hook('custis', 'bug_end_of_update',             'Checkers::bug_end_of_update');
set_hook('custis', 'bug_end_of_create',             'Checkers::bug_end_of_create');
add_hook('custis', 'savedsearch_post_update',       'Checkers::savedsearch_post_update');
add_hook('custis', 'install_before_final_checks',   'Checkers::install_before_final_checks');

# Прочие хуки
set_hook('custis', 'flag_check_requestee_list',     'CustisMiscHooks::flag_check_requestee_list');
set_hook('custis', 'process_bug_after_move',        'CustisMiscHooks::process_bug_after_move');
set_hook('custis', 'quote_urls_custom_proto',       'CustisMiscHooks::quote_urls_custom_proto');
set_hook('custis', 'enter_bug_cloned_bug',          'CustisMiscHooks::enter_bug_cloned_bug');
add_hook('custis', 'bug_end_of_create',             'CustisMiscHooks::bug_end_of_create');

1;
__END__
