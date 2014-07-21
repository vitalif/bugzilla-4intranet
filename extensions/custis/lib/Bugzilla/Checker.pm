#!/usr/bin/perl

package Bugzilla::Checker;

use strict;
use base qw(Bugzilla::Object Exporter);

use JSON;
use Bugzilla::Search;
use Bugzilla::Search::Saved;
use Bugzilla::Error;

use constant DB_TABLE => 'checkers';

use constant {
    # Да => проверка старого состояния бага ("заморозка")
    # Нет => проверка нового состояния бага ("проверка новых значений")
    CF_FREEZE => 0x01,
    # Да => ошибка, нет => предупреждение
    CF_FATAL  => 0x02,
    # Да => проверять при создании бага, нет => не проверять
    CF_CREATE => 0x04,
    # Да => проверять при обновлении бага, нет => не проверять
    CF_UPDATE => 0x08,
    # Да => запрещать изменения всех полей, кроме except_fields
    # Нет => разрешать изменения всех полей, кроме except_fields
    CF_DENY   => 0x10,
};

our @EXPORT = qw(CF_FREEZE CF_FATAL CF_CREATE CF_UPDATE CF_DENY);

use constant DB_COLUMNS => (
    'id',
    # <Это состояние> задаётся соответствием запросу поиска.
    'query_id',
    # Кто создал
    'user_id',
    # Флаги
    'flags',
    # Сообщение об ошибке в случае некорректности
    'message',
    # SQL-код генерировать при каждом изменении бага долго, поэтому кэшируем
    'sql_code',
    # Поля-исключения: если CF_DENY, то разрешить только их,
    # если !(flags & CF_DENY), то запретить только их,
    # если !(flags & CF_DENY) и их нет, то flags |= CF_DENY
    'except_fields',
    # Триггеры - действия над полями багов (требует CF_FREEZE и !CF_FATAL)
    'triggers',
);
use constant NAME_FIELD => 'message';
use constant ID_FIELD   => 'id';
use constant LIST_ORDER => NAME_FIELD;

use constant REQUIRED_CREATE_FIELDS => qw(query_id message);

use constant VALIDATORS => {
    query_id => \&_check_query_id,
    flags    => \&_check_flags,
};

use constant UPDATE_COLUMNS => (
    'query_id',
    'flags',
    'message',
    'sql_code',
    'except_fields',
    'triggers',
);

# Перепостроение и перекэширование SQL-запроса в базу
#  от имени суперпользователя (без проверок групп).
# На всякий случай из запроса убирается ORDER BY и SELECT ... FROM,
#  а потом при исполнении приписывается.
# Вообще проверка работает дёрганьем SQL-запроса с добавленным условием
#  на bugs.bug_id=...
sub refresh_sql
{
    my $self = shift;
    my ($query) = @_;
    if (!$query || $query->id != $self->query_id)
    {
        $query = $self->query;
    }
    my $search = new Bugzilla::Search(
        params => http_decode_query($query->url),
        fields => [ 'bug_id' ],
        user   => $query->user,
    );
    my $terms = Bugzilla::Search::simplify_expression([
        'AND_MANY', { term => 'bugs.bug_id=?' },
        $search->{terms_without_security}
    ]);
    my $sql = $search->get_expression_sql($terms, 'force joins');
    $sql =~ s/^\s*SELECT.*?FROM/SELECT DISTINCT $self->{id} FROM/;
    $self->set_sql_code($sql);
}

# Создание нового предиката - сразу кэшируется SQL-код
sub create
{
    my ($class, $params) = @_;
    if ($params->{except_fields})
    {
        $params->{except_fields} = encode_json($params->{except_fields});
    }
    if ($params->{triggers})
    {
        $params->{triggers} = encode_json($params->{triggers});
    }
    my $self = Bugzilla::Object::create($class, $params);
    $self->update;
    $self->query->set_shared_with_group(Bugzilla::Group->check({ name => 'bz_editcheckers' }));
    return $self;
}

# Обновление - всегда перекэшируется SQL-код
sub update
{
    my $self = shift;
    $self->refresh_sql;
    $self->query->set_shared_with_group(Bugzilla::Group->check({ name => 'bz_editcheckers' }));
    if ($self->triggers)
    {
        $self->{flags} |= CF_FREEZE;
    }
    $self->SUPER::update(@_);
}

# Проверяем, что такой поиск существует и доступен пользователю
sub _check_query_id
{
    my ($invocant, $value, $field) = @_;
    my $q = Bugzilla::Search::Saved->check({ id => $value });
    # Потенциально мы разрешаем создавать предикаты
    # на основе расшаренных другими людьми поисков,
    # но в интерфейсе этого сейчас нет
    if ($q->user->id != Bugzilla->user->id &&
        (!$q->shared_with_group || !Bugzilla->user->in_group($q->shared_with_group)))
    {
        ThrowUserError('query_access_denied', { query => $q });
    }
    # Тоже наша доработка - в сохранённый поиск может быть сохранён просто левый URL
    if ($q->url =~ /^[a-z][a-z0-9]*:/iso)
    {
        ThrowUserError('query_not_savedsearch', { query => $q });
    }
    return $q->id;
}

sub _check_flags
{
    my ($invocant, $value, $field) = @_;
    $value = int($value);
    return $value;
}

sub id              { $_[0]->{id} }
sub query_id        { $_[0]->{query_id} }
sub user_id         { $_[0]->{user_id} }
sub message         { $_[0]->{message} }
sub sql_code        { $_[0]->{sql_code} }
sub flags           { $_[0]->{flags} }

# Отдельные флаги
sub is_freeze       { $_[0]->{flags} & CF_FREEZE }
sub is_fatal        { ($_[0]->{flags} & CF_FATAL) && !$_[0]->triggers }
sub on_create       { $_[0]->{flags} & CF_CREATE }
sub on_update       { $_[0]->{flags} & CF_UPDATE }
sub deny_all        { $_[0]->{flags} & CF_DENY }

# { field_name => value }
# Исключать изменения поля field_name на значение value,
# либо на любое значение, если value = undef
sub except_fields
{
    my $self = shift;
    if (!exists $self->{except_fields_obj})
    {
        $self->{except_fields_obj} = $self->{except_fields} ? decode_json($self->{except_fields}) : undef;
    }
    return $self->{except_fields_obj};
}

# { field_name => value }
# Изменить значение поля field_name на value. Для полей с множествами значений
# field_name также может быть add_<field_name> или remove_<field_name>, что означает
# добавить значение или удалить значение соответственно.
# FIXME Пока поддерживается только add_cc.
sub triggers
{
    my $self = shift;
    if (!exists $self->{triggers_obj})
    {
        $self->{triggers_obj} = $self->{triggers} ? decode_json($self->{triggers}) : undef;
    }
    return $self->{triggers_obj};
}

sub name
{
    my $self = shift;
    return $self->query->name;
}

sub query
{
    my $self = shift;
    if (!$self->{query})
    {
        $self->{query} = Bugzilla::Search::Saved->new({ id => $self->query_id });
    }
    return $self->{query};
}

sub user
{
    my $self = shift;
    if (!$self->{user})
    {
        $self->{user} = Bugzilla::User->new({ id => $self->user_id });
    }
    return $self->{user};
}

sub set_query_id        { $_[0]->set('query_id', Bugzilla::Search::Saved->check({ id => $_[1] })->id) }
sub set_user_id         { $_[0]->set('user_id', Bugzilla::User->check({ userid => $_[1] })->id) }
sub set_flags           { $_[0]->set('flags', $_[1]) }
sub set_message         { $_[0]->set('message', $_[1]) }
sub set_sql_code        { $_[0]->set('sql_code', $_[1]) }

sub set_except_fields
{
    my ($self, $value) = @_;
    $self->set('except_fields', $value ? encode_json($value) : undef);
    delete $self->{except_fields_obj};
}

sub set_triggers
{
    my ($self, $value) = @_;
    $self->set('triggers', $value ? encode_json($value) : undef);
    delete $self->{triggers_obj};
}

1;
__END__
