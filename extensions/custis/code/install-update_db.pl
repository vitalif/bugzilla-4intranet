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

my $dbh = Bugzilla->dbh;

# Перенос CC по умолчанию из нашей доработки initialcclist в нормальный механизм component_cc
my $ccour = $dbh->bz_column_info('components', 'initialcclist');
unless ($ccour)
{
    $ccour = $dbh->selectall_arrayref("DESC components") || [];
    $ccour = { map { ($_->[0] => 1) } @$ccour };
    $ccour = $ccour->{initialcclist} ? 1 : undef;
}

if ($ccour)
{
    print "Migrating initialcclist to component_cc...\n";
    my $cc = $dbh->selectall_arrayref("SELECT id, initialcclist FROM components") || [];
    $dbh->do("CREATE TABLE IF NOT EXISTS old_component_initialcc (id smallint(6) not null auto_increment primary key, initialcclist tinytext not null)");
    my $ins = $dbh->prepare("REPLACE INTO old_component_initialcc (id, initialcclist) VALUES (?, ?)");
    my $addcc = $dbh->prepare("REPLACE INTO component_cc (user_id, component_id) VALUES (?, ?)");
    my ($user, $uid, $list);
    my $added = [];
    foreach (@$cc)
    {
        $ins->execute(@$_);
        if ($list = $_->[1])
        {
            $list = [ split /[\s,]+/, $list ];
            for $user (@$list)
            {
                $user =~ s/^\s+|\s+$//so;
                ($uid) = $dbh->selectrow_array("SELECT userid FROM profiles WHERE login_name=?", undef, $user);
                unless ($uid)
                {
                    print "  ERROR: unknown default CC for component $_->[0]: '$user'\n";
                }
                else
                {
                    push @$added, [ $uid, $_->[0] ];
                    $addcc->execute($uid, $_->[0]);
                }
            }
        }
    }
    if ($dbh->bz_column_info('components', 'initialcclist'))
    {
        $dbh->bz_drop_column('components', 'initialcclist');
    }
    else
    {
        $dbh->do("ALTER TABLE components DROP initialcclist");
    }
    print "Successfully migrated ".scalar(@$added)." initial CC definitions\n";
    print "  (old data backed up in old_component_initialcc table)\n";
}

# Перекодировка параметров сохранённых поисков из CP-1251 в UTF-8
print "Making sure saved queries are in UTF-8...\n";
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

# Bug 13593 - Интеграция с Wiki
if (!$dbh->bz_column_info('products', 'buglist'))
{
    # Добавляем колонку wiki_url в продукты
    $dbh->bz_add_column('products', wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
}
if (!$dbh->bz_column_info('components', 'buglist'))
{
    # Добавляем колонку wiki_url в компоненты
    $dbh->bz_add_column('components', wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
}

# Bug 53725 - Версия по умолчанию
if (!$dbh->bz_column_info('components', 'default_version'))
{
    $dbh->bz_add_column('components', default_version => {TYPE => 'varchar(64)', NOTNULL => 1, DEFAULT => "''"});
}

# Bug 53617 - Ограничение Custom Fields двумя и более значениями контролирующего поля
my @standard_fields =
    qw(bug_status resolution priority bug_severity op_sys rep_platform);
my $custom_fields = $dbh->selectcol_arrayref(
    'SELECT name FROM fielddefs WHERE custom = 1 AND type IN (?,?)',
    undef, FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT);
foreach my $field (@standard_fields, @$custom_fields)
{
    next unless $dbh->bz_table_info($field);
    if ($dbh->bz_column_info($field, 'visibility_value_id'))
    {
        print "Migrating $field visibility_value_id into fieldvaluecontrol\n";
        $dbh->do(
            "REPLACE INTO fieldvaluecontrol (field_id, visibility_value_id, value_id)".
            " SELECT f.id, v.visibility_value_id, v.id FROM fielddefs f, $field v".
            " WHERE f.name=? AND v.visibility_value_id IS NOT NULL", undef, $field);
        # Пока не удаляем никаких колонок
        #$dbh->bz_drop_column($field, 'visibility_value_id');
    }
}

# Testopia:
if ($dbh->bz_table_info('test_fielddefs'))
{
    # Bug 53254 - Интеграция плана с MediaWiki
    unless ($dbh->bz_column_info('test_plans', 'wiki'))
    {
        $dbh->bz_add_column('test_plans', wiki => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
    }
    unless ($dbh->selectrow_array("SELECT name FROM test_fielddefs WHERE table_name='test_plans' AND name='wiki'"))
    {
        $dbh->do("INSERT INTO test_fielddefs (name, description, table_name) VALUES ('wiki', 'Wiki Category', 'test_plans')");
    }
}

# Bug 53635 - Переделка полей OS и Platform в Custom Fields
unless ($dbh->bz_column_info('fielddefs', 'isactive'))
{
    $dbh->bz_add_column('fielddefs', isactive => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 'TRUE'});
}
unless ($dbh->bz_column_info('fielddefs', 'defaultvalue'))
{
    $dbh->bz_add_column('fielddefs', defaultvalue => {TYPE => 'MEDIUMTEXT'});
}
