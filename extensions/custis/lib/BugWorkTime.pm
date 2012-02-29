#!/usr/bin/perl
# CustIS Bug 68921 - "Супер-TodayWorktime", или массовая фиксация трудозатрат
# по нескольким багам, за нескольких сотрудников, за различные периоды.
# Для фиксации времени задним числом / другим юзером требует группу worktimeadmin.

package BugWorkTime;

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
    my $sum = 0;
    my $n = keys %$propo;
    $sum += $propo->{$_} for keys %$propo;
    my $new = {};
    my $nt;
    for (keys %$propo)
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
    $bug->remaining_time($newrtime) if $newrtime != $remaining_time;

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

# Обработать запрос к SuperWorkTime
sub HandleSuperWorktime
{
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    my $template = Bugzilla->template;
    $vars->{wt_admin} = Bugzilla->user->in_group('worktimeadmin');
    # обрабатываем списанное время и делаем редирект на себя же
    if ($cgi->param('save_worktime'))
    {
        my $args = { %{ $cgi->Vars } };
        check_token_data($args->{token}, 'superworktime');
        my $wt_user = $args->{worktime_user} || undef;
        my $wt_date;
        my $comment = $args->{comment};
        # Парсим дату, только если можем списывать задним числом
        if ($vars->{wt_admin})
        {
            $wt_date = $args->{worktime_date};
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
                    date => $args->{worktime_date},
                    format => 'YYYY-MM-DD HH:MM:SS',
                });
            }
        }
        if (!$vars->{wt_admin})
        {
            # Если мы не можем списывать задним юзером - текущий юзер
            $wt_user = Bugzilla->user;
        }
        elsif ($wt_user)
        {
            # Ищем юзера, если больше одного - предлагаем выбор
            my $matches = Bugzilla::User::match($wt_user);
            if (scalar(@$matches) != 1)
            {
                $cgi->delete('worktime_user');
                $vars->{matches} = { 'worktime_user' => { $wt_user => { users => $matches } } };
                $vars->{matchsuccess} = @$matches ? 1 : 0;
                $template->process("global/confirm-user-match.html.tmpl", $vars)
                    || ThrowTemplateError($template->error());
                exit;
            }
            $wt_user = $matches->[0];
        }
        else
        {
            $wt_user = undef;
        }
        my ($bug, $t);
        my ($tsfrom, $tsto) = ($args->{chfieldfrom} || '', $args->{chfieldto} || '');
        my $min_inc = $args->{divide_min_inc};
        # $other_bug_id - это баг, из которого берётся пропорция для расписывания времени по юзерам
        my $other_bug_id = $args->{divide_other_bug_id};
        # Если также отмечено move_time, то само введённое значение времени вообще игнорируется,
        # берётся из $other_bug_id, и потом убирается из $other_bug_id (списывается с отрицательным знаком)
        # Вещь довольно безумная - перемещение времени с бага на баги...
        my $move_time = $args->{move_time};
        trick_taint($_) for $tsfrom, $tsto, $other_bug_id;
        my $times = {};
        foreach (map { /^wtime_(\d+)$/ } keys %$args)
        {
            $t = $args->{"wtime_$_"};
            if ($t)
            {
                $times->{$_} = $t;
            }
            $cgi->delete("wtime_$_");
        }
        $cgi->delete('save_worktime');
        Bugzilla->dbh->bz_start_transaction();
        if ($move_time && $other_bug_id)
        {
            # Если хотим переместить время, загружаем сумму из $other_bug_id
            $move_time = Bugzilla->dbh->selectrow_array(
                'SELECT SUM(work_time) FROM longdescs WHERE bug_id=?'.
                ($tsfrom ? ' AND bug_when>=?' : '').
                ($tsto ? ' AND bug_when<?' : ''),
                undef, int($other_bug_id), ($tsfrom ? $tsfrom : ()), ($tsto ? $tsto : ())
            );
            if (!$move_time)
            {
                # Если хотели что-то переместить, а там ничего нет - ругнёмся
                ThrowUserError('move_worktime_empty', { bug_id => $other_bug_id, from => $tsfrom, to => $tsto });
            }
            delete $times->{$other_bug_id};
            $times = Scale($times, $move_time, $min_inc);
            $times->{$other_bug_id} = -$move_time;
        }
        Bugzilla->request_cache->{checkers_hide_error} = 1;
        my $propo;
        if ($other_bug_id)
        {
            # Загружаем пропорцию заранее - и оптимальнее, и по пути не собьётся
            $propo = LoadTimes($other_bug_id, $tsfrom, $tsto);
        }
        my ($ok, $rollback) = 0;
        for (keys %$times)
        {
            Bugzilla->dbh->bz_start_transaction();
            if ($bug = Bugzilla::Bug->new({ id => $_, for_update => 1 }))
            {
                # Юзеры хотят цельный коммит и построчную диагностику...
                # Так что если хотя бы одно изменение не пройдёт, потом сделаем полный откат
                if ($wt_user)
                {
                    # Списываем время на одного юзера
                    $ok = FixWorktime($bug, $times->{$_}, $comment, $wt_date, $wt_user->id);
                }
                else
                {
                    # Распределяем время по участникам
                    $ok = DistributeWorktime(
                        $bug, $times->{$_}, $comment, $wt_date, $tsfrom, $tsto, $min_inc, $propo
                    );
                }
            }
            if ($ok)
            {
                Bugzilla->dbh->bz_commit_transaction();
            }
            else
            {
                # А если не OK, значит нас уже обломали Checkers'ы,
                # а они сами откатывают транзакцию до последнего Savepoint'а
                $rollback = 1;
            }
        }
        if ($rollback)
        {
            # Цельный откат, если хотя бы одно изменение заблокировано проверками
            Bugzilla->dbh->bz_rollback_transaction();
        }
        else
        {
            Bugzilla->dbh->bz_commit_transaction();
            delete_token($args->{token});
        }
        Checkers::show_checker_errors();
        print $cgi->redirect(-location => $cgi->self_url);
        exit;
    }
}

1;
__END__
