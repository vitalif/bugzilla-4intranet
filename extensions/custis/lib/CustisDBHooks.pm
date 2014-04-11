#!/usr/bin/perl
# Хуки для обновлений базы

package CustisDBHooks;

use strict;
use utf8;
use Encode;
use URI::Escape;
use Bugzilla::Constants;
use Bugzilla::Field;

# Модификации схемы БД
sub db_schema_abstract_schema
{
    my ($args) = @_;
    my $schema = $args->{schema};

    # Bug 63447 - Simple Global Authentication provider for web applications
    $schema->{globalauth} = {
        FIELDS => [
            id     => {TYPE => 'varchar(255)', NOTNULL => 1},
            secret => {TYPE => 'varchar(255)', NOTNULL => 1},
            expire => {TYPE => 'bigint', NOTNULL => 1},
        ],
        INDEXES => [
            globalauth_primary_idx => { FIELDS => ['id'], TYPE => 'UNIQUE' },
        ],
    };

    return 1;
}

# ./checksetup'овые обновления базы
sub install_update_db
{
    my ($args) = @_;

    my $dbh = Bugzilla->dbh;

    # Перенос CC по умолчанию из нашей доработки initialcclist в нормальный механизм component_cc
    my $ccour = $dbh->bz_column_info('components', 'initialcclist');

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
        print "Successfully migrated ".scalar(@$added)." initial CC definitions\n";
        print "  (old data backed up in old_component_initialcc table)\n";
    }

    # Перекодировка параметров сохранённых поисков из CP-1251 в UTF-8
    print "Making sure saved queries are in UTF-8...\n";
    my $nq = $dbh->selectall_arrayref("SELECT * FROM namedqueries WHERE POSITION('%' IN query) > 0", {Slice=>{}});
    if ($nq)
    {
        my $q;
        foreach (@$nq)
        {
            $q = $_->{query};
            $q =~ s/(\%[0-9A-F]{2})+/_sure_utf8($&)/iegso;
            $dbh->do("UPDATE namedqueries SET query=? WHERE id=?", undef, $q, $_->{id}) if $q ne $_->{query};
        }
    }

    return 1;
}

# Проверка кодировки URL-кодированной строки - если не UTF-8, перекодирует в UTF-8 из CP1251
# (TODO remove hardcoded CP1251)
sub _sure_utf8
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

1;
__END__
