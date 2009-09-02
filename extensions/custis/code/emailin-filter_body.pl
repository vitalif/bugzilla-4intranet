#!/usr/bin/perl -wT

use strict;

for (${Bugzilla->hook_args->{body}})
{
    if (/From:\s+bugzilla-daemon(\s*[a-z0-9_\-]+\s*:.*?\n)*\s*Bug\s*\d+<[^>]*>\s*\([^\)]*\)\s*/iso)
    {
        my ($pr, $ps) = ($`, $');
        $ps =~ s/\n+(\r*\n+)+/\n/giso;
        $_ = $pr . $ps;
        s!from\s+.*?<http://plantime[^>]*search=([^>]*)>!from $1!giso;
        s!((Comment|Bug)\s+\#?\d+)<[^<>]*>!$1!giso;
        s!\n[^\n]*<http://plantime[^>]*search=[^>]*>\s+changed:[ \t\r]*\n.*?$!!iso;
        s/\s*\n--\s*Configure\s*bugmail<[^>]*>(([ \t\r]*\n[^\n]*)*)//iso;
    }
}
