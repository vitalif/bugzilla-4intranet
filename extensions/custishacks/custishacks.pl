#!/usr/bin/perl
# CustIS-specific Bugzilla extensions (not useful for other people)

use strict;
use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Extension;

my $REQUIRED_MODULES = [
    {
        package => 'SOAP-WSDL',
        module  => 'SOAP::WSDL',
        version => '2.00.10',
        feature => 'Synchronisation with SM/dotProject',
    },
];
my $OPTIONAL_MODULES = [];

required_modules('custishacks', $REQUIRED_MODULES);
optional_modules('custishacks', $OPTIONAL_MODULES);
clear_hooks('custishacks');

# DB changes
set_hook('custishacks', 'db_schema_abstract_schema', 'CustisHacks::db_schema_abstract_schema');
set_hook('custishacks', 'install_update_db', 'CustisHacks::install_update_db');

# Sending bugs to SM/dotProject
set_hook('custishacks', 'bug_end_of_create', 'CustisHacks::bug_end_of_create');
set_hook('custishacks', 'bug_end_of_update', 'CustisHacks::bug_end_of_update');

# Redirect users to "their" bugzilla according to params.login_urlbase_redirects
set_hook('custishacks', 'auth_post_login', 'CustisLocalBugzillas::auth_post_login');

1;
__END__
