#!/usr/bin/perl
# CustIS-specific Bugzilla extensions (not useful for other people)

use strict;
use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Extension;

my $REQUIRED_MODULES = [];
my $OPTIONAL_MODULES = [];

required_modules('custishacks', $REQUIRED_MODULES);
optional_modules('custishacks', $OPTIONAL_MODULES);
clear_hooks('custishacks');

# DB changes
set_hook('custishacks', 'db_schema_abstract_schema', 'CustisHacks::db_schema_abstract_schema');
set_hook('custishacks', 'install_update_db', 'CustisHacks::install_update_db');

if (Bugzilla->installation_mode) {
    set_hook('custishacks', 'install_update_db', 'CustisHacks::update_cf_wbs');
} else {
    CustisHacks::update_cf_wbs();
}

# Search column
set_hook('custishacks', 'buglist_static_columns', 'CustisHacks::buglist_static_columns');

# Sending bugs to SM/dotProject
set_hook('custishacks', 'bug_end_of_create', 'CustisHacks::sync_bug');
set_hook('custishacks', 'bug_end_of_update', 'CustisHacks::sync_bug');

# Redirect users to "their" bugzilla according to params.login_urlbase_redirects
set_hook('custishacks', 'auth_post_login', 'CustisLocalBugzillas::auth_post_login');

1;
__END__
