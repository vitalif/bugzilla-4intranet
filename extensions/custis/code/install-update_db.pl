#!/usr/bin/perl
# ./checksetup'овые обновления базы

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

# Перекодировка параметров сохранённых поисков из CP-1251 в UTF-8
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

# Добавляем колонку wiki_url в продукты и компоненты
if (!$dbh->bz_column_info('products', 'buglist'))
{
    $dbh->bz_add_column('products', 'wiki_url', {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
}

if (!$dbh->bz_column_info('components', 'buglist'))
{
    $dbh->bz_add_column('components', 'wiki_url', {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
}
