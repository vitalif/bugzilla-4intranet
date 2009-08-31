#!/usr/bin/perl -wT

use strict;

for (${Bugzilla->hook_args->{body}})
{
    s/<a[^<>]*>.*?<\/a\s*>/custis_rmlf($&)/gieso;
    s/<table[^<>]*class=[\"\']?difft[^<>]*>.*?<\/table\s*>//giso;
}

sub custis_rmlf
{
    my ($t) = @_;
    $t =~ s/[\n\r]+/ /giso;
    return $t;
}
