#!/usr/bin/perl

$/ = undef;
while(<>)
{
    s!/\*.*?\*/!!gso;
    s!^\s+!!gmo;
    s!^(//.*)?(\n|$)!!gmo;
    print;
}
