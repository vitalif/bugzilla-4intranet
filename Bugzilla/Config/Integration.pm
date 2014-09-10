#!/usr/bin/perl
# Integration with other systems (MediaWiki, ViewVC, etc) config

package Bugzilla::Config::Integration;

use strict;
use warnings;

our $sortkey = 910;

sub get_param_list
{
    return (
    {
        name => 'gravatar_url',
        type => 't',
        default => 'http://www.gravatar.com/avatar/$MD5',
    },

    {
        name => 'wiki_url',
        type => 't',
        default => '',
    },

    {
        name => 'viewvc_url',
        type => 't',
        default => '',
    },

    {
        name => 'mediawiki_urls',
        type => 'l',
        default => '',
    },

    {
        name => 'user_mailto',
        type => 't',
        default => 'mailto:',
    },

    {
        name => 'ext_disable_refresh_views',
        type => 'b',
        default => 0,
    },

    {
        name => 'see_also_url_regexes',
        type => 'l',
        default =>
'# Launchpad bug-tracker URLs
^(?^i:https?://[^/]*launchpad\.net)/.*bugs?/(\d+) https://launchpad.net/bugs/$1
# Google Code bug-tracker URLs
^(?^i:https?://code\.google\.com)/p/([^/]+)/issues/detail\?(?:[^&]+=[^&]*&)*id=(\d+) http://code.google.com/p/$1/issues/detail?id=$2
# Debian BTS URLs
^(?^i:https?://bugs\.debian\.org)/cgi-bin/bugreport\.cgi\?(?:[^&]+=[^&]*&)*bug=(\d+) http://bugs.debian.org/$1
^(?^i:https?://bugs\.debian\.org)/(\d+) http://bugs.debian.org/$1
# URLs that look like Bugzilla
^(?^i:https?://([^/]*))/show_bug\.cgi\?(?:[^&]+=[^&]*&)*id=(\d+) http://$1/show_bug.cgi?id=$2'
    },
    );
}

1;
__END__
