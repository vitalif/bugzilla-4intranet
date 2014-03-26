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

    # FIELD VALUES FOR INCOMING EMAILS
    # --------------

    $schema->{emailin_fields} = {
        FIELDS => [
            address => {TYPE => 'varchar(255)', NOTNULL => 1},
            field   => {TYPE => 'varchar(255)', NOTNULL => 1},
            value   => {TYPE => 'varchar(255)', NOTNULL => 1},
        ],
        INDEXES => [
            emailin_fields_primary => { FIELDS => ['address', 'field'], TYPE => 'UNIQUE' },
        ],
    };

    # ALIASES FOR INCOMING EMAILS
    # --------------

    $schema->{emailin_aliases} = {
        FIELDS => [
            address   => {TYPE => 'varchar(255)', NOTNULL => 1},
            userid    => {TYPE => 'INT4', NOTNULL => 1,
                          REFERENCES => {TABLE => 'profiles',
                                         COLUMN => 'userid'}},
            fromldap  => {TYPE => 'BOOLEAN'},
            isprimary => {TYPE => 'BOOLEAN'},
        ],
        INDEXES => [
            emailin_aliases_address => { FIELDS => ['address'], TYPE => 'UNIQUE' },
        ],
    };

    # Bug 64562 - надо идти на дом. страницу бага после постановки, а не на post_bug.cgi
    push @{$schema->{logincookies}->{FIELDS}}, session_data => {TYPE => 'LONGBLOB'};

    # Ну и зачем авторы убрали этот индекс?
    # Bug 53687 - Тормозят запросы из Plantime в багзиллу
    push @{$schema->{longdescs}->{INDEXES}}, longdescs_who_bug_when_idx => { FIELDS => ['who', 'bug_when'] };

    # Bug 13593 - Интеграция с Wiki
    push @{$schema->{components}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};
    push @{$schema->{products}->{FIELDS}}, wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"};

    # Bug 59357 - Отключение учёта времени в отдельных продуктах
    push @{$schema->{products}->{FIELDS}}, notimetracking => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0};

    # Bug 68921 - Связь внутренний/внешний продукт
    push @{$schema->{products}->{FIELDS}}, extproduct => {TYPE => 'INT4', REFERENCES => {TABLE => 'products', COLUMN => 'id'}};

    # Bug 139829 - Ограничение CC продукта
    push @{$schema->{products}->{FIELDS}}, cc_group => {TYPE => 'varchar(255)'};

    # Bug 53725 - Версия по умолчанию
    push @{$schema->{components}->{FIELDS}}, default_version => {TYPE => 'varchar(64)', NOTNULL => 1, DEFAULT => "''"};

    # Bug 68921 - Закрытие компонента (так же как закрытие продукта), чтобы в него нельзя было ставить новые баги
    push @{$schema->{components}->{FIELDS}}, is_active => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1};

    # Bug 45485 - Scrum-карточки из Bugzilla
    $schema->{scrum_cards} = {
        FIELDS => [
            bug_id   => {TYPE => 'INT4', NOTNULL => 1},
            sprint   => {TYPE => 'varchar(255)', NOTNULL => 1},
            type     => {TYPE => 'varchar(255)', NOTNULL => 1},
            estimate => {TYPE => 'varchar(255)', NOTNULL => 1},
        ],
        INDEXES => [
            scrum_cards_primary_idx => { FIELDS => ['bug_id', 'sprint', 'type'], TYPE => 'UNIQUE' },
        ],
    };

    # Bug 63447 - Глобальная авторизация
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

    # Bug 69325 - Настройка копирования / не копирования значения поля при клонировании бага
    push @{$schema->{fielddefs}->{FIELDS}}, clone_bug => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1};

    # Bug 90854 - Тип поля "ссылка во внешнюю систему по ID"
    push @{$schema->{fielddefs}->{FIELDS}}, url => {TYPE => 'VARCHAR(255)'};

    # Bug 70605 - Кэширование зависимостей полей для поиска и формы бага на клиентской стороне
    push @{$schema->{fielddefs}->{FIELDS}}, delta_ts => {TYPE => 'DATETIME'};
    push @{$schema->{fielddefs}->{FIELDS}}, has_activity => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0};

    # Bug 73054 - Возможность автоматического добавления значений полей типа Bug ID в зависимости бага
    push @{$schema->{fielddefs}->{FIELDS}}, add_to_deps => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0};

    # Bug 68921 - Предикаты корректности из запросов поиска
    # Bug 108088 - Триггеры (пока поддерживается только 1 триггер: добавление CC)
    $schema->{checkers} = {
        FIELDS => [
            id             => {TYPE => 'INTSERIAL', NOTNULL => 1, PRIMARYKEY => 1},
            query_id       => {TYPE => 'INT4', NOTNULL => 1, REFERENCES => {TABLE => 'namedqueries', COLUMN => 'id'}},
            user_id        => {TYPE => 'INT4', REFERENCES => {TABLE => 'profiles', COLUMN => 'userid'}},
            flags          => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0},
            message        => {TYPE => 'LONGTEXT', NOTNULL => 1},
            sql_code       => {TYPE => 'LONGTEXT'},
            except_fields  => {TYPE => 'LONGBLOB'},
            triggers       => {TYPE => 'LONGBLOB'},
        ],
        INDEXES => [
            checkers_query_id_idx => { FIELDS => ['query_id'] },
        ],
    };

    # Bug 134368 - Edit comments
    $schema->{longdescs_history} = {
        FIELDS => [
            bug_id     => { TYPE => 'INT4', NOTNULL => 1, REFERENCES => { TABLE => 'bugs', COLUMN => 'bug_id' } },
            who        => { TYPE => 'INT4', NOTNULL => 1, REFERENCES => { TABLE => 'profiles', COLUMN => 'userid' } },
            bug_when   => { TYPE => 'DATETIME', NOTNULL => 1 },
            oldthetext => { TYPE => 'LONGTEXT', NOTNULL => 1 },
            thetext    => { TYPE => 'LONGTEXT', NOTNULL => 1 },
            comment_id => { TYPE => 'INT4', NOTNULL => 1 },
            comment_count => { TYPE => 'INT4', NOTNULL => 1 },
        ],
        INDEXES => [
            longdescs_history_bug_when_idx      => { FIELDS => [ 'bug_when' ] },
            longdescs_history_who_idx           => { FIELDS => [ 'who', 'bug_id' ] },
            longdescs_history_who_bug_when_idx  => { FIELDS => [ 'who', 'bug_when' ] },
            longdescs_history_bug_id_idx        => { FIELDS => [ 'bug_id', 'bug_when' ] },
        ],
    };

    return 1;
}

# Fill 'fieldvaluecontrol' table when upgrading a stock Bugzilla installation
sub _make_fieldvaluecontrol
{
    my ($dbh) = @_;

    # Dependent default values for custom fields (CustIS Bug 91153)
    $dbh->bz_add_column('fieldvaluecontrol', is_default => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0});

    if ($dbh->bz_column_info('fielddefs', 'visibility_value_id'))
    {
        # FIXME do this in other place
        $dbh->do("UPDATE fielddefs SET nullable=1 WHERE name IN ('target_milestone', 'priority', 'resolution')");
        # FIXME delete --- target_milestones and '' resolution, set MOVED resolution disabled

        # Set single select type for standard select fields
        my @ss = qw(classification product version rep_platform op_sys bug_status resolution bug_severity priority component target_milestone);
        $dbh->do("UPDATE fielddefs SET type=".FIELD_TYPE_SINGLE_SELECT()." WHERE name IN ('".join('\',\'', @ss)."')");

        # Move visibility_value_id of values of standard fields to fieldvaluecontrol (CustIS Bug 53617)
        my @standard_fields = qw(bug_status resolution priority bug_severity op_sys rep_platform);
        my $custom_fields = $dbh->selectall_arrayref(
            'SELECT * FROM fielddefs WHERE type IN (?, ?) AND (custom=1 OR name IN ('.
            join(',', ('?') x @standard_fields).'))', {Slice=>{}},
            FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT, @standard_fields);
        foreach my $field (@$custom_fields)
        {
            if ($dbh->bz_table_info($field->{name}) &&
                $dbh->bz_column_info($field->{name}, 'visibility_value_id'))
            {
                print "Migrating $field->{name}'s visibility_value_id into fieldvaluecontrol\n";
                $dbh->do(
                    "REPLACE INTO fieldvaluecontrol (field_id, visibility_value_id, value_id)".
                    " SELECT f.id, v.visibility_value_id, v.id FROM fielddefs f, `$field->{name}` v".
                    " WHERE f.name=? AND v.visibility_value_id IS NOT NULL", undef, $field->{name});
                print "Making backup of table $field->{name}\n";
                $dbh->do("CREATE TABLE `backup_$field->{name}_".time."` AS SELECT * FROM `$field->{name}`");
                print "Dropping column $field->{name}.visibility_value_id\n";
                $dbh->bz_drop_column($field->{name}, 'visibility_value_id');
            }
        }

        # Move visibility_value_id of standard fields to fieldvaluecontrol
        print "Migrating fielddefs's visibility_value_id into fieldvaluecontrol\n";
        $dbh->do(
            "REPLACE INTO fieldvaluecontrol (field_id, visibility_value_id, value_id)".
            " SELECT id, visibility_value_id, 0 FROM fielddefs WHERE visibility_value_id IS NOT NULL"
        );
        print "Making backup of table fielddefs\n";
        $dbh->do("CREATE TABLE `backup_fielddefs_".time."` AS SELECT * FROM fielddefs");
        print "Dropping column fielddefs.visibility_value_id\n";
        $dbh->bz_drop_column('fielddefs', 'visibility_value_id');

        # Copy product_id and classification_id dependencies to fieldvaluecontrol
        # so query.cgi can show/hide all fields using common code (CustIS Bug 69481)
        print "Copying standard fields product_id/classification_id to fieldvaluecontrol\n";
        for([ 'product', 'classification', 'products' ],
            [ 'component', 'product', 'components' ],
            [ 'version', 'product', 'versions' ],
            [ 'target_milestone', 'product', 'milestones' ])
        {
            my ($id) = $dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $_->[0]);
            my ($pid) = $dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=?', undef, $_->[1]);
            $dbh->do('UPDATE fielddefs SET value_field_id=? WHERE id=?', undef, $pid, $id);
            $dbh->do('DELETE FROM fieldvaluecontrol WHERE field_id=? AND value_id!=0', undef, $id);
            $dbh->do(
                'INSERT INTO fieldvaluecontrol (field_id, value_id, visibility_value_id)'.
                ' SELECT ?, id, '.$_->[1].'_id FROM '.$_->[2], undef, $id
            );
        }
    }

    # Copy useXXX to DB config
    if (Bugzilla->params->{useclassification})
    {
        my ($cl_id) = $dbh->selectrow_array('SELECT id FROM fielddefs WHERE name=\'classification\'');
        $dbh->do('UPDATE fielddefs SET value_field_id=? WHERE name=\'product\'', undef, $cl_id);
    }
    else
    {
        $dbh->do('UPDATE fielddefs SET value_field_id=NULL WHERE name=\'product\'');
    }
    require Bugzilla::Config::BugFields;
    my $h = Bugzilla::Config::BugFields->USENAMES;
    for (keys %$h)
    {
        $dbh->do('UPDATE fielddefs SET obsolete=? WHERE name=?', undef, Bugzilla->params->{$_} ? 0 : 1, $h->{$_});
    }
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

    # Bug 13593 - Интеграция с Wiki
    $dbh->bz_add_column('products', wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
    $dbh->bz_add_column('components', wiki_url => {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});

    # Bug 59357 - Отключение учёта времени в отдельных продуктах
    $dbh->bz_add_column('products', notimetracking => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0});

    # Bug 68921 - Связь внешний/внутренний продукт
    $dbh->bz_add_column('products', extproduct => {TYPE => 'INT4', REFERENCES => {TABLE => 'products', COLUMN => 'id'}});

    # Bug 139829 - Ограничение CC продукта
    $dbh->bz_add_column('products', cc_group => {TYPE => 'varchar(255)'});
    $dbh->bz_alter_column('products', cc_group => {TYPE => 'varchar(255)'});

    # Bug 53725 - Версия по умолчанию
    $dbh->bz_add_column('components', default_version => {TYPE => 'varchar(64)', NOTNULL => 1, DEFAULT => "''"});

    # Bug 68921 - Закрытие компонента (так же как закрытие продукта), чтобы в него нельзя было ставить новые баги
    $dbh->bz_add_column('components', is_active => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1});

    _make_fieldvaluecontrol($dbh);

    # Bug 64562 - Redirect to bug page after processing bug
    $dbh->bz_add_column('logincookies', session_data => {TYPE => 'LONGBLOB'});

    # Bug 95168 - Support longer TheSchwartz error messages
    $dbh->bz_alter_column('ts_error', message => {TYPE => 'MEDIUMTEXT', NOTNULL => 1}, '');

    # Bug 69766 - Default CSV charset for M1cr0$0ft Excel
    if (!$dbh->selectrow_array('SELECT name FROM setting WHERE name=\'csv_charset\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting (name, default_value, is_enabled) VALUES (\'csv_charset\', \'utf-8\', 1)');
    }
    if (!$dbh->selectrow_array('SELECT name FROM setting_value WHERE name=\'csv_charset\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting_value (name, value, sortindex) VALUES (\'csv_charset\', \'utf-8\', 10), (\'csv_charset\', \'windows-1251\', 20), (\'csv_charset\', \'koi8-r\', 30)');
    }

    # Bug 72510 - Настройка действия/недействия Silent на почту о флагах
    if (!$dbh->selectrow_array('SELECT name FROM setting WHERE name=\'silent_affects_flags\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting (name, default_value, is_enabled) VALUES (\'silent_affects_flags\', \'send\', 1)');
    }
    if (!$dbh->selectrow_array('SELECT name FROM setting_value WHERE name=\'silent_affects_flags\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting_value (name, value, sortindex) VALUES (\'silent_affects_flags\', \'send\', 10), (\'silent_affects_flags\', \'do_not_send\', 20)');
    }

    # Bug 87696 - Setting to change comments which are allowed to be marked as collapsed by default ("worktime-only")
    if (!$dbh->selectrow_array('SELECT name FROM setting WHERE name=\'showhide_comments\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting (name, default_value, is_enabled) VALUES (\'showhide_comments\', \'worktime\', 1)');
    }
    if (!$dbh->selectrow_array('SELECT name FROM setting_value WHERE name=\'showhide_comments\' LIMIT 1'))
    {
        $dbh->do('INSERT INTO setting_value (name, value, sortindex) VALUES (\'showhide_comments\', \'none\', 10), (\'showhide_comments\', \'worktime\', 20), (\'showhide_comments\', \'all\', 30)');
    }

    # Bug 100052 - Сообщения от зависимых багов
    if (!$dbh->selectrow_array('SELECT * FROM email_setting WHERE event=\''.EVT_DEPEND_REOPEN.'\' LIMIT 1'))
    {
        print "Adding 'A blocking bug is reopened or closed' mail event, On by default for all users\n";
        foreach my $rel (grep { $_ != REL_GLOBAL_WATCHER } RELATIONSHIPS)
        {
            $dbh->do(
                'INSERT INTO email_setting (user_id, relationship, event)'.
                ' SELECT p.userid, ?, ? FROM profiles p WHERE p.disable_mail=0', undef, $rel, EVT_DEPEND_REOPEN
            );
        }
    }

    # Bug 125374 - Настройки пользователя для управления шириной комментариев
    if (!$dbh->selectrow_array('SELECT * FROM setting WHERE name=\'comment_width\' LIMIT 1'))
    {
        print "Adding 'Show comment with full screen width' user general setting, On by default for all users\n";
        $dbh->do('INSERT INTO setting (name, default_value, is_enabled) VALUES (\'comment_width\', \'off\', 1)');
        $dbh->do('INSERT INTO setting_value (name, value, sortindex) VALUES (\'comment_width\', \'off\', \'10\'), (\'comment_width\', \'on\', \'20\')');
    }

    # Bug 139829 - Ограничение CC продукта: перенос из description в cc_group
    if ($dbh->selectrow_array('SELECT id FROM products WHERE description LIKE \'%[CC:%\' LIMIT 1'))
    {
        $dbh->do('
UPDATE products
SET
    cc_group = trim(
        substr(
            description,
            locate(\'[CC:\', description)+4,
            locate(\']\', description, locate(\'[CC:\', description)+4) - locate(\'[CC:\', description)-4
        )
    ),
    description = trim(
        concat(
            substr(description, 1, locate(\'[CC:\', description)-1),
            substr(description, 1 + locate(\']\', description, locate(\'[CC:\', description)+4))
        )
    )
WHERE description LIKE\'%[CC:%\'');
    }

    # Bug 138596 - Настройки пользователя для управления длинными комментариями
    if (!$dbh->selectrow_array('SELECT * FROM setting WHERE name=\'preview_long_comments\' LIMIT 1'))
    {
        print "Adding 'Fold long comments' user general setting, Off by default for all users\n";
        $dbh->do('INSERT INTO setting (name, default_value, is_enabled) VALUES (\'preview_long_comments\', \'off\', 1)');
        $dbh->do('INSERT INTO setting_value (name, value, sortindex) VALUES (\'preview_long_comments\', \'off\', \'10\'), (\'preview_long_comments\', \'on\', \'20\')');
    }

    return 1;
}

sub install_update_fielddefs
{
    my $dbh = Bugzilla->dbh;

    # Bug 69325 - Настройка копирования / не копирования значения поля при клонировании бага
    $dbh->bz_add_column('fielddefs', clone_bug => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1});

    # Bug 90854 - Тип поля "ссылка во внешнюю систему по ID"
    $dbh->bz_add_column('fielddefs', url => {TYPE => 'VARCHAR(255)'});

    # Nullable field property
    $dbh->bz_add_column('fielddefs', nullable => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 'FALSE'});

    # Bug 70605 - Кэширование зависимостей полей для поиска и формы бага на клиентской стороне
    if (!$dbh->bz_column_info('fielddefs', 'delta_ts'))
    {
        $dbh->bz_add_column('fielddefs', delta_ts => {TYPE => 'DATETIME'});
        $dbh->do('UPDATE fielddefs SET delta_ts=NOW()');
    }

    if (!$dbh->bz_column_info('fielddefs', 'has_activity'))
    {
        $dbh->bz_add_column('fielddefs', has_activity => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0});
        $dbh->do(
            'UPDATE fielddefs SET has_activity=1'.
            ' WHERE id IN (SELECT DISTINCT fieldid FROM bugs_activity)'.
            ' OR name IN (\'longdesc\', \'longdescs.isprivate\', \'commenter\', \'creation_ts\')'
        );
    }

    # Bug 73054 - Возможность автоматического добавления значений полей типа Bug ID в зависимости бага
    $dbh->bz_add_column('fielddefs', add_to_deps => {TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0});

    # Bug 70605 - Делаем вид, что изменили какое-то поле, чтобы при checksetup автоматически сбросился кэш
    $dbh->do('UPDATE fielddefs SET delta_ts=NOW() WHERE name=\'delta_ts\'');

    # Bug 69481 - Длина описания проверок
    if ($dbh->bz_column_info('checkers', 'message')->{TYPE} ne 'LONGTEXT')
    {
        $dbh->bz_alter_column('checkers', message => {TYPE => 'LONGTEXT', NOTNULL => 1});
    }

    # Bug 108088 - Триггеры (пока поддерживается только 1 триггер: добавление CC)
    $dbh->bz_add_column('checkers', triggers => {TYPE => 'LONGBLOB'});

    # Устанавливаем значение buglist в правильное
    my @yes = map { $_->{name} } grep { $_->{buglist} } Bugzilla::Field::DEFAULT_FIELDS;
    my @no = map { $_->{name} } grep { !$_->{buglist} } Bugzilla::Field::DEFAULT_FIELDS;
    $dbh->do('UPDATE fielddefs SET buglist=1 WHERE name IN (\''.join("','", @yes).'\')');
    $dbh->do('UPDATE fielddefs SET buglist=0 WHERE name IN (\''.join("','", @no).'\')');

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
