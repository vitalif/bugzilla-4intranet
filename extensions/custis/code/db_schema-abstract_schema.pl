#!/usr/bin/perl -wT

use strict;
my $schema = Bugzilla->hook_args->{schema};

# FIELD VALUES FOR INCOMING EMAILS
# --------------

$schema->{emailin_fields} = {
    FIELDS => [
        address => {TYPE => 'varchar(255)', NOTNULL => 1},
        field   => {TYPE => 'varchar(255)', NOTNULL => 1},
        value   => {TYPE => 'varchar(255)', NOTNULL => 1},
    ],
    INDEXES => [
        emailin_fields_primary => { FIELDS => ['address', 'field'], TYPE => 'UNIQUE' },
    ],
};
