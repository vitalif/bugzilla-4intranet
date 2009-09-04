#!/usr/bin/perl -wT
# Модификации схемы БД

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

# Ну и зачем авторы убрали этот индекс?
# Bug 53687 - Тормозят запросы из Plantime в багзиллу
push @{$schema->{longdescs}->{INDEXES}}, { FIELDS => ['who', 'bug_when'] };

# Bug 13593 - Интеграция с Wiki
push @{$schema->{components}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};
push @{$schema->{products}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};

# Bug 53725 - Версия по умолчанию
push @{$schema->{components}->{FIELDS}}, default_version => {TYPE => 'varchar(64)', NOTNULL => 1, DEFAULT => "''"};
