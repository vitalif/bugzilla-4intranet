#!/usr/bin/perl
# Конфигурация интеграции со всевозможными Виками и Вьювисями

package extensions::custis::lib::Config;

use strict;
use warnings;

use Bugzilla::Config::Common;

sub get_param_list
{
    return (
    {
        name => 'wiki_url',
        type => 's',
        default => 'http://wiki.office.custis.ru/wiki/index.php/',
    },

    {
        name => 'viewvc_url',
        type => 's',
        default => 'http://viewvc.office.custis.ru/viewvc.py/',
    },

    {
        name => 'smwiki_url',
        type => 's',
        default => 'http://penguin.office.custis.ru/smwiki/index.php/',
    },

    {
        name => 'smboa_url',
        type => 's',
        default => 'http://penguin.office.custis.ru/smboa/index.php/',
    },

    {
        name => 'sbwiki_url',
        type => 's',
        default => 'http://sobin.office.custis.ru/sbwiki/index.php/',
    },

    {
        name => 'rdwiki_url',
        type => 's',
        default => 'http://radey.office.custis.ru/rdwiki/index.php/',
    },
    );
}

1;
