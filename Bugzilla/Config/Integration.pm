#!/usr/bin/perl
# Integration with other systems (MediaWiki, ViewVC, etc) config

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
        name => 'login_urlbase_redirects',
        type => 'l',
        default => '',
    },
    );
}

1;
__END__
