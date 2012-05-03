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

1;
__END__
