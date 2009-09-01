#!/usr/bin/perl -wT

use strict;

for (${Bugzilla->hook_args->{body}})
{
    s/<table[^<>]*class=[\"\']?difft[^<>]*>.*?<\/table\s*>//giso;
    s/<a[^<>]*>.*?<\/a\s*>/custis_rmlf($&)/gieso;
}

sub custis_rmlf
{
    my ($t) = @_;
    $t =~ s/[\n\r]+/ /giso;
    return $t;
}
