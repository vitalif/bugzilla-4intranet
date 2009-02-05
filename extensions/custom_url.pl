#!/usr/bin/perl
# Custom URL protocol definitions for CustIS Bugzilla

use Bugzilla::Util;

sub processWikiAnchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
    $anchor = url_quote(substr($anchor,1));
    $anchor =~ s/%/./g;
    return $anchor;
}

sub processWikiUrl
{
    Bugzilla->params->{$_[0]."_url"} . $_[1] . '#' . processWikiAnchor($_[2]);
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
};
