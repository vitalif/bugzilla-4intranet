#!/usr/bin/perl

use strict;
use Bugzilla::Extension;

my $REQUIRED_MODULES = [
    {
        package => 'Data-Dumper',
        module  => 'Data::Dumper',
        version => 0,
    },
];

my $OPTIONAL_MODULES = [
    {
        package => 'Acme',
        module  => 'Acme',
        version => 1.11,
        feature => ['example_acme'],
    },
];

required_modules('example', $REQUIRED_MODULES);
optional_modules('example', $OPTIONAL_MODULES);
extension_version('example', '1.0');

1;
