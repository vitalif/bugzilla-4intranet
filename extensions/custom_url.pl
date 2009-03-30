#!/usr/bin/perl
# Custom URL protocol definitions for CustIS Bugzilla

use Bugzilla::Util;

sub processWikiAnchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
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

return {
    wiki   => sub { processWikiUrl("wiki", @_) },
    smwiki => sub { processWikiUrl("smwiki", @_) },
    smboa  => sub { processWikiUrl("smboa", @_) },
    sbwiki => sub { processWikiUrl("sbwiki", @_) },
    fawiki => sub { processWikiUrl("fawiki", @_) },
    kswiki => sub { processWikiUrl("kswiki", @_) },
    rdwiki => sub { processWikiUrl("rdwiki", @_) },
    gzwiki => sub { processWikiUrl("gzwiki", @_) },
    dpwiki => sub { processWikiUrl("dpwiki", @_) },
};
