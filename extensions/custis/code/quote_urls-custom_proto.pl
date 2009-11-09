#!/usr/bin/perl
# Интеграция с Wiki для нашей Bugzilla

use strict;
use utf8;
use Bugzilla::Util;

sub url_quote_slash
{
    my ($toencode) = (@_);
    utf8::encode($toencode) # The below regex works only on bytes
        if Bugzilla->params->{utf8} && utf8::is_utf8($toencode);
    $toencode =~ s!([^a-zA-Z0-9_\-./])!uc sprintf("%%%02x",ord($1))!ego;
    return $toencode;
}

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
    # обычный url_quote нам не подходит, т.к. / не нужно переделывать в %2F
    $url = url_quote_slash($url);
    return Bugzilla->params->{"${wiki}_url"} . $url . '#' . processWikiAnchor($anchor);
}

for my $wiki (qw/wiki smwiki smboa sbwiki fawiki kswiki rdwiki gzwiki dpwiki hrwiki cbwiki gzstable orwiki/)
{
    Bugzilla->hook_args->{custom_proto}->{$wiki} = sub { processWikiUrl($wiki, @_) }
}
