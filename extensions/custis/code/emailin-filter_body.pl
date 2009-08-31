#!/usr/bin/perl -wT

use strict;

for (${Bugzilla->hook_args->{body}})
{
    if (s/From:\s+bugzilla-daemon(\s*[a-z0-9_\-]+\s*:.*?\n)*\s*Bug\s*\d+<[^>]*>\s*\([^\)]*\)\s*//iso)
    {
        s!from\s+.*?<http://plantime[^>]*search=([^>]*)>!from $1!;
        s/\s*\n--\s*Configure\s*bugmail<[^>]*>([ \t]*\n[^\n]*)*//iso;
    }
}
