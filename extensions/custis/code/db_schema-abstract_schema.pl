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

# ALIASES FOR INCOMING EMAILS
# --------------

$schema->{emailin_aliases} = {
    FIELDS => [
        address  => {TYPE => 'varchar(255)', NOTNULL => 1},
        userid   => {TYPE => 'INT3', NOTNULL => 1,
                     REFERENCES => {TABLE => 'profiles',
                                    COLUMN => 'userid'}},
        fromldap => {TYPE => 'BOOLEAN'},
    ],
    INDEXES => [
        emailin_aliases_address => { FIELDS => ['address'], TYPE => 'UNIQUE' },
    ],
};
