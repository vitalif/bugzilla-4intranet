#!/usr/bin/perl
# Интеграция с Wiki для нашей Bugzilla

use strict;
use Bugzilla::Util;

sub processWikiAnchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
    $anchor =~ tr/ /_/;
    $anchor = url_quote($anchor);
    $anchor =~ s/%/./gso;
    return $anchor;
}

sub processWikiUrl
{
    my ($wiki, $url, $anchor) = @_;
    $url = trim($url);
    $url =~ s/\s+/ /gso;
    $url = url_quote($url);
    return Bugzilla->params->{"${wiki}_url"} . $url . '#' . processWikiAnchor($anchor);
}

for my $wiki (qw/wiki smwiki smboa sbwiki fawiki kswiki rdwiki gzwiki dpwiki hrwiki cbwiki/)
{
    Bugzilla->hook_args->{custom_proto}->{$wiki} = sub { processWikiUrl($wiki, @_) }
}
