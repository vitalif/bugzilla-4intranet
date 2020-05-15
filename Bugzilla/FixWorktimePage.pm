#!/usr/bin/perl
# "Super-Fix-Worktime" page - allows to enter worktime for many bugs at once,
# even for past dates and/or for other users, if you have 'superworktime' privilege.
# Originally CustIS Bug 68921.
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::FixWorktimePage;

use strict;
use POSIX;

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::Util;
use Bugzilla::Token;

# Загрузить из бага bug_id время за период $from..$to
# в разрезе по пользователям, и вернуть в виде { user_id => work_time }
sub LoadTimes
{
    my ($bug_id, $from, $to) = @_;
    my $sql = 'SELECT who, SUM(work_time) wt FROM longdescs WHERE bug_id=?';
    my @bind = ($bug_id);
    if ($from)
    {
        $sql .= ' AND bug_when>=?';
        push @bind, $from;
    }
    if ($to)
    {
        $sql .= ' AND bug_when<?';
        push @bind, $to;
    }
    $sql .= ' GROUP BY who';
    my $propo = Bugzilla->dbh->selectall_hashref($sql, 'who', undef, @bind);
    $propo = { map { $_ => $propo->{$_}->{wt} } keys %$propo };
    return $propo;
}

# Отмасштабировать время $propo = { key => work_time } так, чтобы
# сумма стала равна $newsum, а отдельные элементы не были меньше $min.
sub Scale
{
    my ($propo, $newsum, $min) = @_;
    if (scalar(keys %$propo) == 1)
    {
        # Если элемент один, размазывать там нечего
        return { keys %$propo => $newsum };
    }
    my $sum = 0;
    my $n = keys %$propo;
    $sum += $propo->{$_} for keys %$propo;
    my $new = {};
    my $nt;
    # Сортировка сама по себе не так важна, важно вначале
    # обрабатывать меньшие значения, чтобы большие размазались корректно
    # Граничный ошибочный случай - 1 баг с большим значением в начале
    # и много мелких в конце - в этом случае сумма не сойдётся.
    for (sort { $propo->{$a} <=> $propo->{$b} } keys %$propo)
    {
        $nt = $sum ? $propo->{$_}*$newsum/$sum : $newsum/$n;
        $nt = POSIX::floor($nt*100+0.5)/100;
        if (abs($nt) < $min || $newsum*$nt < 0)
        {
            # не размазываем время совсем уж мелкими суммами
            # и размазываем только суммами того же знака, что и вся сумма
            $sum -= $propo->{$_};
            $n--;
            next;
        }
        # корректируем ошибки округления, чтобы сумма всё равно сходилась
        $sum -= $propo->{$_};
        $newsum -= $nt;
        $n--;
        $new->{$_} = $nt;
    }
    return $new;
}

# Добавить к багу $bug (Bugzilla::Bug) на момент $timestamp,
# с комментарием $comment или "Fix worktime" рабочее время из
# $times = { $user_id => $work_time, ... }
# Возвращает 1 если всё нормально, 0 если обновление блокировано проверками.
# При этом _комментарий_ к багу добавляется задним числом от заданного пользователя,
# но _изменения_ (Show Bug History) логгируются всегда от имени текущего пользователя.
# Так сделано в Bugzilla::Bug и в этом даже есть некая логика (хотя бы можно посмотреть,
# из-под кого в реальности фиксировалось время).
sub AddWorktime
{
    my ($bug, $comment, $timestamp, $times) = @_;
    $comment ||= "Fix worktime";

    my $sum = 0;
    for (keys %$times)
    {
        next unless $times->{$_};
        $sum += $times->{$_};
        $bug->add_comment($comment, {
            work_time => $times->{$_},
            bug_when  => $timestamp,
            who       => $_,
            type      => $timestamp lt $bug->delta_ts ? CMT_BACKDATED_WORKTIME : CMT_WORKTIME,
        });
    }
    return 1 unless $sum;

    my $remaining_time = $bug->remaining_time;
    my $newrtime = $remaining_time - $sum;
    $newrtime = 0 if $newrtime < 0;
    $bug->set('remaining_time', $newrtime) if $newrtime != $remaining_time;

    $bug->update();

    if (@{$bug->{failed_checkers} || []} && !$bug->{passed_checkers})
    {
        return 0;
    }
    else
    {
        # stop bugmail
        Bugzilla->dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id=?', undef, $bug->id);
    }

    return 1;
}

# Используется только fill-day-worktime.cgi (старый Today Worktime)
sub FixWorktime
{
    my ($bug, $wtime, $comment, $timestamp, $userid) = @_;
    return 1 unless $wtime;
    $bug = Bugzilla::Bug->check({ id => $bug, for_update => 1 }) unless ref $bug;
    return 0 unless $bug;
    return AddWorktime($bug, $comment, $timestamp, { ($userid || Bugzilla->user->id) => $wtime });
}

# Пропорциональное или равномерное распределение времени по пользователям
# с пропорцией, взятой из этого бага или подсунутой в $propo = { user_id => work_time }
sub DistributeWorktime
{
    my ($bug, $t, $comment, $timestamp, $from, $to, $min_inc, $propo) = @_;
    return 1 unless $t;

    $propo ||= LoadTimes($bug->id, $from, $to);
    return 1 unless %$propo;

    my $times = Scale($propo, $t, $min_inc);
    return AddWorktime($bug, $comment, $timestamp, $times);
}

# Разбираем дату
sub ParseWtDate
{
    my ($wt_date) = @_;
    # Списывать будем последней секундой дня, если дата в прошлом
    $wt_date .= ' 23:59:59' if $wt_date !~ / /;
    eval
    {
        $wt_date = datetime_from($wt_date);
        if ($wt_date->epoch > time)
        {
            # Если время было не указано, а дата текущая, получится
            # дата в будущем (23:59:59) - значит списываем текущим временем
            $wt_date = undef;
        }
        else
        {
            $wt_date = $wt_date->ymd . ' ' . $wt_date->hms;
        }
    };
    # Если не распарсилась - не будем втихаря списывать
    # на текущее число, а сообщим об ошибке формата
    if ($@)
    {
        ThrowUserError('illegal_date', {
            date => $_[0],
            format => 'YYYY-MM-DD HH:MM:SS',
        });
    }
    return $wt_date;
}

# Ищем юзера, если больше одного - предлагаем выбор
sub MatchWtUser
{
    my ($wt_user) = @_;
    my $matches = Bugzilla::User::match_name($wt_user);
    if (scalar(@$matches) != 1)
    {
        Bugzilla->cgi->delete('worktime_user');
        my $vars = {};
        $vars->{matches} = { 'worktime_user' => { $wt_user => { users => $matches } } };
        $vars->{matchsuccess} = @$matches ? 1 : 0;
        Bugzilla->template->process("global/confirm-user-match.html.tmpl", $vars)
            || ThrowTemplateError(Bugzilla->template->error());
        exit;
    }
    return $matches->[0];
}

# Списать время из $times на набор багов с комментарием $comment на время $timestamp
# $times формата { bug_id => { user_id => work_time, ... }, ... }
sub MassAddWorktime
{
    my ($times, $comment, $timestamp) = @_;
    Bugzilla->request_cache->{checkers_hide_error} = 1;
    my ($ok, $rollback) = 0;
    my $bug;
    for (keys %$times)
    {
        Bugzilla->dbh->bz_start_transaction();
        $ok = 1;
        if ($bug = Bugzilla::Bug->new({ id => $_, for_update => 1 }))
        {
            $ok = AddWorktime($bug, $comment, $timestamp, $times->{$_});
        }
        if ($ok)
        {
            # Юзеры хотят цельный коммит и построчную диагностику...
            # Так что коммитим в SAVEPOINT, а потом, если хотя бы одно изменение
            # не пройдёт, сделаем полный откат
            Bugzilla->dbh->bz_commit_transaction();
        }
        else
        {
            # А если не OK, значит нас уже обломали Checkers'ы,
            # а они сами откатывают транзакцию до последнего Savepoint'а
            $rollback = 1;
        }
    }
    return !$rollback;
}

# Подготовить время для списания:
# $times         - введённые часы или пропорция по багам
# $tsfrom, $tsto - выбранный период времени
# $wt_user       - выбранный пользователь
# $other_bug_id  - откуда взять пропорцию участия пользователей
# $move_time     - флаг "перенести время с other_bug_id"
# Возвращает хешреф в формате { bug_id => { user_id => время } }
sub PrepareWorktime
{
    my ($times, $wt_user, $tsfrom, $tsto, $other_bug_id, $move_time, $min_inc) = @_;
    my $user_times;
    my $r = {};
    if ($other_bug_id)
    {
        $user_times = LoadTimes($other_bug_id, $tsfrom, $tsto);
        $user_times = { $wt_user->id => $user_times->{$wt_user->id} || 0 } if $wt_user;
        my $sum = 0;
        $sum += $_ for values %$user_times;
        if (!$sum)
        {
            # Если хотели взять пропорцию из бага, а в него не списано время - ругнёмся
            ThrowUserError('move_worktime_empty', {
                bug_id => $other_bug_id,
                from   => $tsfrom,
                to     => $tsto,
                who    => $wt_user,
            });
        }
    }
    if ($wt_user)
    {
        # Списываем заданное время на одного участника
        $r->{$_} = { $wt_user->id => $times->{$_} } for keys %$times;
    }
    elsif ($move_time && $other_bug_id)
    {
        # Если также отмечено move_time, то введённое значение времени игнорируется,
        # берётся из $other_bug_id для каждого его участника за заданный период,
        # распределяется по багам в соответствии с пропорцией $times, и потом
        # и потом списывается с отрицательным знаком в $other_bug_id.
        # Получается перенос времени пользователей с одного бага на множество других...
        delete $times->{$other_bug_id};
        my $proportion = $times;
        $r = {};
        for my $uid (keys %$user_times)
        {
            my $scaled = Scale($proportion, $user_times->{$uid}, $min_inc);
            for (keys %$scaled)
            {
                $r->{$_}->{$uid} = $scaled->{$_};
            }
            $r->{$other_bug_id}->{$uid} = -$user_times->{$uid};
        }
    }
    else
    {
        # Распределяем время по нескольким участникам
        for (keys %$times)
        {
            $r->{$_} = Scale($user_times || LoadTimes($_, $tsfrom, $tsto), $times->{$_}, $min_inc);
        }
    }
    return $r;
}

# Обработать запрос к SuperWorkTime
# $vars - выходные переменные для шаблона
# $args - входные параметры запроса
sub HandleSuperWorktime
{
    my ($vars, $args) = @_;
    my $template = Bugzilla->template;
    $vars->{wt_admin} = Bugzilla->user->in_group('worktimeadmin');
    # Обрабатываем списанное время, а потом делаем редирект на себя же
    if ($args->{save_worktime})
    {
        # Проверяем токен
        check_token_data($args->{token}, 'superworktime');
        my ($wt_user, $wt_date);
        my $comment = $args->{comment};
        if ($vars->{wt_admin})
        {
            # Парсим дату, только если можем списывать задним числом
            $wt_date = ParseWtDate($args->{worktime_date});
            $wt_user = MatchWtUser($args->{worktime_user}) if $args->{worktime_user};
        }
        else
        {
            # Если мы не можем списывать задним юзером - форсим текущего юзера
            $wt_user = Bugzilla->user;
        }
        # Заданный в поиске период времени
        my ($tsfrom, $tsto) = ($args->{chfieldfrom} || '', $args->{chfieldto} || '');
        # Точность распределения времени - время распределяется на части, не большие, чем $min_inc
        my $min_inc = $args->{divide_min_inc};
        # $other_bug_id - это баг, из которого берётся пропорция для расписывания времени по юзерам
        my $other_bug_id = $args->{divide_other_bug_id};
        trick_taint($_) for $tsfrom, $tsto, $other_bug_id;
        my $times = {};
        my $t;
        foreach (map { /^wtime_(\d+)$/ } keys %$args)
        {
            $t = $args->{"wtime_$_"};
            $times->{$_} = Bugzilla::Bug::ValidateTime($t, 'work_time') if $t;
        }
        # В транзакции сначала готовим, потом коммитим
        Bugzilla->dbh->bz_start_transaction();
        $times = PrepareWorktime($times, $wt_user, $tsfrom, $tsto, $other_bug_id, $args->{move_time}, $min_inc);
        if ($args->{dry_run})
        {
            # Тестовый проход - не списываем, а только показываем результат
            # Просто форму показать нельзя, т.к. может быть списание за нескольких участников,
            # а на форме его отразить негде :(
            Bugzilla->dbh->bz_commit_transaction();
            my $user_times = {};
            foreach my $bug_id (keys %$times)
            {
                foreach my $user_id (keys %{$times->{$bug_id}})
                {
                    $user_times->{$user_id}->{$bug_id} = $times->{$bug_id}->{$user_id};
                }
            }
            my $users = {};
            foreach my $user (@{ Bugzilla::User->new_from_list([ keys %$user_times ]) })
            {
                $users->{$user->id} = $user;
            }
            $vars->{test_times_by_bug} = $times;
            $vars->{test_times_by_user} = $user_times;
            $vars->{users} = $users;
            $vars->{round} = sub { ($_[0] < 0 ? -int(-$_[0]*100+0.5) : int($_[0]*100+0.5))/100 };
            $template->process('worktime/dry-run.html.tmpl', $vars);
            exit;
        }
        else
        {
            # Удаляем параметры
            if (MassAddWorktime($times, $comment, $wt_date))
            {
                Bugzilla->dbh->bz_commit_transaction();
                delete_token($args->{token});
            }
            else
            {
                # Цельный откат, если хотя бы одно изменение заблокировано проверками
                Bugzilla->dbh->bz_rollback_transaction();
                Bugzilla::CheckerUtils::show_checker_errors();
            }
            delete $args->{$_} for 'token', 'save_worktime', grep { /^wtime_(\d+)$/ } keys %$args;
            print Bugzilla->cgi->redirect(-location => 'buglist.cgi?'.http_build_query($args));
            exit;
        }
    }
}

sub HandlePrioritize
{
    my ($vars, $args) = @_;
    # Меняем приоритеты, а потом делаем редирект на себя же
    if ($args->{save})
    {
        my $dbh = Bugzilla->dbh;
        # Проверяем токен
        check_token_data($args->{token}, 'prioritize');
        $dbh->bz_start_transaction();
        my $changes = {};
        for my $k (keys %$args)
        {
            if ($k =~ /^new_(.*)_(\d+)$/s)
            {
                my $bugid = $2;
                my $field = $1;
                $changes->{$bugid}->{$field} = $args->{$k};
            }
        }
        my $failed = 0;
        my $r = {};
        for my $bugid (keys %$changes)
        {
            my $bug = Bugzilla::Bug->new({ id => $bugid, for_update => 1 });
            if ($bug)
            {
                for my $field (keys %{$changes->{$bugid}})
                {
                    $bug->set($field, $changes->{$bugid}->{$field});
                }
                $dbh->bz_start_transaction();
                $bug->update();
                if (@{$bug->{failed_checkers} || []} && !$bug->{passed_checkers})
                {
                    $failed = 1;
                    next;
                }
                else
                {
                    # Не отправлять почту
                    $dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id=?', undef, $bug->id);
                    $dbh->bz_commit_transaction();
                }
            }
        }
        delete_token($args->{token});
        if (!$failed)
        {
            $dbh->bz_commit_transaction();
        }
        else
        {
            $dbh->bz_rollback_transaction();
            Bugzilla::CheckerUtils::show_checker_errors();
        }
        # Удаляем параметры
        delete $args->{$_} for 'format', 'prio_field', 'token', 'save', grep { /^new_(.*)_(\d+)$/ } keys %$args;
        print Bugzilla->cgi->redirect(-location => 'buglist.cgi?'.http_build_query($args));
        exit;
    }
}

1;
__END__
