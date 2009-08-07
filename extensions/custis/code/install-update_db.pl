#!/usr/bin/perl
# Перекодировка параметров сохранённых поисков из CP-1251 в UTF-8

use strict;
use utf8;
use Encode;
use URI::Escape;

sub sure_utf8
{
    my ($s) = @_;
    $s = uri_unescape($s);
    Encode::_utf8_on($s);
    my $v = utf8::valid($s);
    Encode::_utf8_off($s);
    Encode::from_to($s, 'cp1251', 'utf8') unless $v;
    $s = uri_escape($s);
    return $s;
}

print "Making sure saved queries are in UTF-8...\n";
my $dbh = Bugzilla->dbh;
my $nq = $dbh->selectall_arrayref("SELECT * FROM namedqueries WHERE query LIKE '%\\%%'", {Slice=>{}});
if ($nq)
{
    my $q;
    foreach (@$nq)
    {
        $q = $_->{query};
        $q =~ s/(\%[0-9A-F]{2})+/sure_utf8($&)/iegso;
        $dbh->do("UPDATE namedqueries SET query=? WHERE id=?", undef, $q, $_->{id}) if $q ne $_->{query};
    }
}
