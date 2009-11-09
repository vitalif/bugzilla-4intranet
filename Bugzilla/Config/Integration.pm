#!/usr/bin/perl
# Конфигурация интеграции со всевозможными Виками и Вьювисями

package Bugzilla::Config::Integration;

use strict;
use warnings;

use Bugzilla::Config::Common;

sub get_param_list
{
    return (
    {
        name => 'wiki_url',
        type => 't',
        default => 'http://wiki.office.custis.ru/wiki/index.php/',
    },

    {
        name => 'viewvc_url',
        type => 't',
        default => 'http://viewvc.office.custis.ru/viewvc.py/',
    },

    {
        name => 'smwiki_url',
        type => 't',
        default => 'http://penguin.office.custis.ru/smwiki/index.php/',
    },

    {
        name => 'smboa_url',
        type => 't',
        default => 'http://penguin.office.custis.ru/smboa/index.php/',
    },

    {
        name => 'sbwiki_url',
        type => 't',
        default => 'http://sobin.office.custis.ru/sbwiki/index.php/',
    },

    {
        name => 'rdwiki_url',
        type => 't',
        default => 'http://radey.office.custis.ru/rdwiki/index.php/',
    },

    {
        name => 'gzwiki_url',
        type => 't',
        default => 'http://gazprom.office.custis.ru/gzwiki/index.php/',
    },

    {
        name => 'gzstable_url',
        type => 't',
        default => 'http://gazprom.office.custis.ru/gzstable/index.php/',
    },

    {
        name => 'dpwiki_url',
        type => 't',
        default => 'http://depobraz.office.custis.ru/dpwiki/index.php/',
    },

    {
        name => 'hrwiki_url',
        type => 't',
        default => 'http://hrwiki.office.custis.ru/hrwiki/index.php/',
    },

    {
        name => 'cbwiki_url',
        type => 't',
        default => 'http://cbr.office.custis.ru/cbwiki/index.php/',
    },

    {
        name => 'orwiki_url',
        type => 't',
        default => 'http://lodge.office.custis.ru/orwiki/index.php/',
    },

    {
        name => 'user_mailto',
        type => 't',
        default => 'mailto:',
    },
    );
}

1;
