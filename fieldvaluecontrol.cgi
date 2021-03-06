#!/usr/bin/perl -wT
# Client-side caching of field and value dependencies (CustIS Bug 70605)
# Author: (c) 2010+ Vitaliy Filippov <vitalif@mail.ru>
# License: Dual-license GPL 3.0+ or MPL 1.1+

use strict;
use lib qw(. lib);

use HTTP::Date;
use POSIX;

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Constants;

my $args = Bugzilla->input_params;
my $user = Bugzilla->login(~LOGIN_REQUIRED);

my $ctype = 'text/javascript'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : '');

# Refresh field cache
Bugzilla->cache_fields;
my $touched = datetime_from(Bugzilla->request_cache->{fields_delta_ts})->epoch;

my $user_tag = 'JSmeta'.($user->id||0);
my ($req_tag) = ($ENV{HTTP_IF_NONE_MATCH} || '') =~ /(JS[a-z0-9_]{3,})/iso;

if ($ENV{HTTP_IF_MODIFIED_SINCE} && $user_tag eq $req_tag)
{
    my $if_modified = str2time($ENV{HTTP_IF_MODIFIED_SINCE});
    if ($if_modified >= $touched)
    {
        Bugzilla->send_header(
            -etag => $user_tag,
            -date => time2str($touched),
            -last_modified => time2str($touched),
            -status => '304 Not Modified',
            -type => $ctype,
            -cache_control => 'private, no-cache, must-revalidate',
        );
        exit;
    }
}

Bugzilla->send_header(
    -etag => $user_tag,
    -type => $ctype,
    -last_modified => time2str($touched),
    -cache_control => 'private, no-cache, must-revalidate',
);

my $json = {};
for (Bugzilla->get_fields({ obsolete => 0 }))
{
    $json->{$_->name} = $_->json_visibility;
}

$json = bz_encode_json($json);
print "var field_metadata_cached = '$user_tag-".time."';
var field_metadata = $json;
";
exit;
