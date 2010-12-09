#!/usr/bin/perl -wT
# Bug 70605 - Client-side caching of field control data

use strict;
use lib qw(. lib);

use HTTP::Date;
use POSIX;

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Constants;

my $VERSION = "$Revision$";

my $args = Bugzilla->cgi->Vars;
my $user = Bugzilla->login(~LOGIN_REQUIRED);

my $ctype = 'text/javascript'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : '');
my ($touched) = Bugzilla->dbh->selectrow_array('SELECT MAX(delta_ts) FROM fielddefs');
$touched = datetime_from($touched)->epoch;

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

if ($args->{type} eq 'search')
{
    my $json = bz_encode_json(Bugzilla->full_json_query_visibility);
    print "qfVisibility = $json;";
}
elsif ($args->{type} eq 'bug')
{
    my $json = {};
    for (Bugzilla->get_fields({ is_select => 1, obsolete => 0 }))
    {
        $json->{$_->name} = $_->json_visibility;
    }
    $json = bz_encode_json($json);
    print "show_fields = $json;";
}
