#!/usr/bin/perl

package Bugzilla::Checker;

use strict;
use base 'Bugzilla::Object';

use JSON;
use Bugzilla::Search::Saved;

use constant DB_TABLE => 'checkers';

use constant DB_COLUMNS => (
    # <Это состояние> задаётся соответствием запросу поиска.
    'query_id',
    'user_id',
    # Два типа:
    # Check  = запрещается переход багов в это состояние из любого другого
    #          ("проверка корректности изменений")
    # Freeze = запрещается переход багов из этого состояния в любое другое
    #          ("заморозка бага")
    'is_freeze',
    'is_fatal',
    'message',
    # SQL-код генерировать при каждом изменении бага долго, поэтому кэшируем
    'sql_code',
    'except_fields',
);
use constant NAME_FIELD => 'message';
use constant ID_FIELD   => 'query_id';
use constant LIST_ORDER => NAME_FIELD;

use constant REQUIRED_CREATE_FIELDS => qw(query_id message);

use constant VALIDATORS => {
    query_id => \&check_query_id,
    is_fatal => \&Bugzilla::Object::check_boolean,
    is_freeze => \&Bugzilla::Object::check_boolean,
};

use constant UPDATE_COLUMNS => (
    'is_freeze',
    'is_fatal',
    'message',
    'sql_code',
    'except_fields',
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
    my $params = new Bugzilla::CGI($query->url);
    $params->delete('bug_id_type', 'bug_id');
    my $search = new Bugzilla::Search(
        params => $params,
        fields => [ 'bug_id' ],
        user   => Bugzilla::User->super_user,
    );
    my $sql = $search->getSQL();
    $sql =~ s/ORDER\s+BY.*?$//iso;
    $sql =~ s/^\s*SELECT.*?FROM//iso;
    $self->set_sql_code($sql);
}

# Создание нового предиката - сразу кэшируется SQL-код
sub create
{
    my ($class, $params) = @_;
    Bugzilla::Object::create(@_);
    my $self = $class->new($params->{query_id});
    $self->update if $self;
    return $self;
}

# Обновление - всегда перекэшируется SQL-код
sub update
{
    my $self = shift;
    $self->refresh_sql;
    $self->SUPER::update(@_);
}

# Проверяем, что такой поиск существует и доступен пользователю
sub check_query_id
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

sub query_id        { $_[0]->{query_id} }
sub user_id         { $_[0]->{user_id} }
sub is_freeze       { $_[0]->{is_freeze} }
sub is_fatal        { $_[0]->{is_fatal} }
sub message         { $_[0]->{message} }
sub sql_code        { $_[0]->{sql_code} }

# { deny_all => 1|0, except_fields => { field_name => value } }
# when value is undef, then the change of field with name=field_name to any value is an exception
# when value is not undef, then only the change to value=value is an exception
sub except_fields
{
    my $self = shift;
    if (!exists $self->{except_fields_obj})
    {
        $self->{except_fields_obj} = $self->{except_fields} ? decode_json($self->{except_fields}) : undef;
    }
    return $self->{except_fields_obj};
}

sub deny_all
{
    my $self = shift;
    return $self->except_fields ? $self->except_fields->{deny_all} : 1;
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
sub set_is_freeze       { $_[0]->set('is_freeze', $_[1]) }
sub set_is_fatal        { $_[0]->set('is_fatal', $_[1]) }
sub set_message         { $_[0]->set('message', $_[1]) }
sub set_sql_code        { $_[0]->set('sql_code', $_[1]) }

sub set_except_fields
{
    my ($self, $value) = @_;
    $self->set('except_fields', encode_json($value));
    delete $self->{except_fields_obj};
}

1;
__END__
