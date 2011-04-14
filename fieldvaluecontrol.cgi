#!/usr/bin/perl -wT
# Bug 70605 - Client-side caching of field value visibility data

use strict;
use lib qw(. lib);

use HTTP::Date;
use POSIX;

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Constants;

my $args = Bugzilla->cgi->Vars;
my $user = Bugzilla->login(~LOGIN_REQUIRED);

my $ctype = 'text/javascript'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : '');

# Refresh field cache
Bugzilla->cache_fields;
my $touched = datetime_from(Bugzilla->request_cache->{fields_delta_ts})->epoch;

my $user_tag = 'JS'.($args->{type}||'x').($user->id||0);
my ($req_tag) = ($ENV{HTTP_IF_NONE_MATCH} || '') =~ /(JS[a-z0-9_]{3,})/iso;

if ($ENV{HTTP_IF_MODIFIED_SINCE} && $user_tag eq $req_tag)
{
    my $if_modified = str2time($ENV{HTTP_IF_MODIFIED_SINCE});
    if ($if_modified >= $touched)
    {
        Bugzilla->send_header(
            -etag => $user_tag,
            -last_modified => time2str($touched),
            -status => '304 Not Modified',
            -type => $ctype,
        );
        exit;
    }
}

Bugzilla->send_header(
    -etag => $user_tag,
    -type => 'text/javascript'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : ''),
    -last_modified => time2str($touched),
);

$args->{type} ||= '';
if ($args->{type} eq 'search')
{
    my $json = bz_encode_json(Bugzilla->full_json_query_visibility);
    print "var qfVisCached = '$user_tag-".time."';\nvar qfVisibility = $json;";
}
elsif ($args->{type} eq 'bug')
{
    my $json = {};
    for (Bugzilla->get_fields({ is_select => 1, obsolete => 0 }))
    {
        $json->{$_->name} = $_->json_visibility;
    }
    $json = bz_encode_json($json);
    print "var show_fields_cached = '$user_tag-".time."';\nshow_fields = $json;";
}
