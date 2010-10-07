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
        address   => {TYPE => 'varchar(255)', NOTNULL => 1},
        userid    => {TYPE => 'INT3', NOTNULL => 1,
                      REFERENCES => {TABLE => 'profiles',
                                     COLUMN => 'userid'}},
        fromldap  => {TYPE => 'BOOLEAN'},
        isprimary => {TYPE => 'BOOLEAN'},
    ],
    INDEXES => [
        emailin_aliases_address => { FIELDS => ['address'], TYPE => 'UNIQUE' },
    ],
};

# Bug 64562 - надо идти на дом. страницу бага после постановки, а не на post_bug.cgi
push @{$schema->{logincookies}->{FIELDS}}, session_data => {TYPE => 'blob'};

# Ну и зачем авторы убрали этот индекс?
# Bug 53687 - Тормозят запросы из Plantime в багзиллу
push @{$schema->{longdescs}->{INDEXES}}, { FIELDS => ['who', 'bug_when'] };

# Bug 13593 - Интеграция с Wiki
push @{$schema->{components}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};
push @{$schema->{products}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};

# Bug 59357 - Отключение учёта времени в отдельных продуктах
push @{$schema->{products}->{FIELDS}}, notimetracking => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0};

# Bug 53725 - Версия по умолчанию
push @{$schema->{components}->{FIELDS}}, default_version => {TYPE => 'varchar(64)', NOTNULL => 1, DEFAULT => "''"};

# Bug 68921 - Закрытие компонента (так же как закрытие продукта), чтобы в него нельзя было ставить новые баги
push @{$schema->{components}->{FIELDS}}, is_active => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1};

# Bug 53617 - Ограничение Custom Fields двумя и более значениями контролирующего поля
$schema->{fieldvaluecontrol} = {
    FIELDS => [
        field_id => {TYPE => 'INT3', NOTNULL => 1},
        value_id => {TYPE => 'INT2', NOTNULL => 1},
        visibility_value_id => {TYPE => 'INT2', NOTNULL => 1},
    ],
    INDEXES => [
        fieldvaluecontrol_primary_idx =>
            {FIELDS => ['field_id', 'visibility_value_id', 'value_id'],
             TYPE => 'UNIQUE'},
    ],
};

# Bug 45485 - Scrum-карточки из Bugzilla
$schema->{scrum_cards} = {
    FIELDS => [
        bug_id   => {TYPE => 'INT3', NOTNULL => 1},
        sprint   => {TYPE => 'varchar(255)', NOTNULL => 1},
        type     => {TYPE => 'varchar(255)', NOTNULL => 1},
        estimate => {TYPE => 'varchar(255)', NOTNULL => 1},
    ],
    INDEXES => [
        scrum_cards_primary_idx => { FIELDS => ['bug_id', 'sprint', 'type'], TYPE => 'UNIQUE' },
    ],
};

# Bug 63447 - Глобальная авторизация
$schema->{globalauth} = {
    FIELDS => [
        id     => {TYPE => 'varchar(255)', NOTNULL => 1},
        secret => {TYPE => 'varchar(255)', NOTNULL => 1},
        expire => {TYPE => 'bigint', NOTNULL => 1},
    ],
    INDEXES => [
        globalauth_primary_idx => { FIELDS => ['id'], TYPE => 'UNIQUE' },
    ],
};

# Bug 69325 - Настройка копирования / не копирования значения поля при клонировании бага
push @{$schema->{fielddefs}->{FIELDS}}, clone_bug => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1};
