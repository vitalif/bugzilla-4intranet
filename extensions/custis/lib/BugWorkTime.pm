#!/usr/bin/perl

package BugWorkTime;

use strict;
use POSIX;

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Util;
use Bugzilla::Token;

# Used by mass worktime editing forms
# Returns 0 if update is unsuccessful, 1 if OK
sub FixWorktime
{
    my ($bug, $wtime, $comment, $timestamp, $userid) = @_;
    $bug = Bugzilla::Bug->new({ id => $bug, for_update => 1 }) unless ref $bug;
    return 0 unless $bug;
    return 1 unless $comment || $wtime;

    my $remaining_time = $bug->remaining_time;
    my $newrtime = $remaining_time - $wtime;
    $newrtime = 0 if $newrtime < 0;

    $bug->add_comment($comment || "Fix worktime", {
        work_time => $wtime,
        bug_when  => $timestamp,
        who       => $userid || Bugzilla->user->id,
    });
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

# пропорциональное или равномерное распределение времени по пользователям
# с пропорцией, взятой из этого или из другого ($other_bug_id) бага
sub DistributeWorktime
{
    my ($bug, $t, $comment, $timestamp, $from, $to, $min_inc, $other_bug_id) = @_;
    $comment ||= "Fix worktime";

    my $dbh = Bugzilla->dbh;
    my ($sql, @bind);
    $sql = 'SELECT who, SUM(work_time) wt FROM longdescs WHERE bug_id=?';
    @bind = ($other_bug_id || $bug->id);
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
    my $propo = $dbh->selectall_hashref($sql, 'who', undef, @bind);
    $propo = { map { $_ => $propo->{$_}->{wt} } keys %$propo };
    my $sum = 0;
    my $n = keys(%$propo) || return undef;
    $sum += $propo->{$_} for keys %$propo;

    my $nt;
    for (keys %$propo)
    {
        $nt = $sum ? $t*$propo->{$_}/$sum : $t/$n;
        $nt = POSIX::floor($nt*100+0.5)/100;
        if (abs($nt) < $min_inc || $t*$nt < 0)
        {
            # не размазываем время совсем уж мелкими суммами
            # и размазываем только суммами того же знака, что и вся сумма
            $sum -= $propo->{$_};
            $n--;
            next;
        }
        # корректируем ошибки округления, чтобы сумма всё равно сходилась
        $sum -= $propo->{$_};
        $t -= $nt;
        $n--;
        $propo->{$_} = $nt;
        $bug->add_comment($comment, {
            work_time => $nt,
            bug_when  => $timestamp,
            who       => $_,
        });
    }

    my $remaining_time = $bug->remaining_time;
    my $newrtime = $remaining_time - $t;
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

# CustIS Bug 68921 - "Супер-TodayWorktime", или массовая фиксация трудозатрат
# по нескольким багам, за нескольких сотрудников, за различные периоды.
# Для фиксации времени задним числом / другим юзером требует группу worktimeadmin.

# Обработать POST-запрос к SuperWorkTime
sub HandleSuperWorktime
{
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    my $template = Bugzilla->template;
    $vars->{wt_admin} = Bugzilla->user->in_group('worktimeadmin');
    my $args = $cgi->Vars;
    # обрабатываем списанное время и делаем редирект на себя же
    if ($args->{save_worktime})
    {
        check_token_data($args->{token}, 'superworktime');
        my $wt_user = $args->{worktime_user} || undef;
        my $wt_date = $args->{worktime_date};
        my $comment = $args->{comment};
        # Парсим дату
        $wt_date .= POSIX::strftime(' %H:%M:%S', localtime) if $wt_date !~ / /;
        eval
        {
            $wt_date = datetime_from($wt_date);
            $wt_date = $wt_date->ymd . ' ' . $wt_date->hms;
        };
        # Если не распарсилось или мы не можем списывать задним числом - undef
        if ($@ || !$vars->{wt_admin})
        {
            $wt_date = undef;
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
        # $other_bug_id - это баг, из которого берётся пропорция для расписывания времени по юзерам
        my $other_bug_id = $args->{divide_other_bug_id};
        trick_taint($tsfrom);
        trick_taint($tsto);
        trick_taint($other_bug_id);
        my @bugids = map { /^wtime_(\d+)$/ } keys %$args;
        if ($other_bug_id && (my @bi = grep { $_ != $other_bug_id } @bugids) != @bugids)
        {
            # перемещаем $other_bug_id в конец, чтобы не сбить пропорцию в процессе списывания времени
            @bugids = (@bi, $other_bug_id);
        }
        my ($ok, $rollback) = 0;
        Bugzilla->request_cache->{checkers_hide_error} = 1;
        Bugzilla->dbh->bz_start_transaction();
        foreach (@bugids)
        {
            $t = $args->{"wtime_$_"};
            if ($t)
            {
                Bugzilla->dbh->bz_start_transaction();
                if ($bug = Bugzilla::Bug->new({ id => $_, for_update => 1 }))
                {
                    # Юзеры хотят цельный коммит и построчную диагностику...
                    # Так что если хотя бы одно изменение не пройдёт, потом сделаем полный откат
                    if ($wt_user)
                    {
                        # Списываем время на одного юзера
                        $ok = BugWorkTime::FixWorktime($bug, $t, $comment, $wt_date, $wt_user->id);
                    }
                    else
                    {
                        # Распределяем время по участникам
                        $ok = BugWorkTime::DistributeWorktime(
                            $bug, $t, $comment, $wt_date, $tsfrom, $tsto,
                            $args->{divide_min_inc}, $other_bug_id
                        );
                    }
                }
                if ($ok)
                {
                    Bugzilla->dbh->bz_commit_transaction();
                }
                else
                {
                    $rollback = 1;
                }
            }
            $cgi->delete("wtime_$_");
        }
        if ($rollback)
        {
            # Цельный откат, если хотя бы одно изменение блокируется
            Bugzilla->dbh->bz_rollback_transaction();
        }
        else
        {
            Bugzilla->dbh->bz_commit_transaction();
        }
        Checkers::show_checker_errors();
        $cgi->delete('save_worktime');
        print $cgi->redirect(-location => $cgi->self_url);
        exit;
    }
}

1;
__END__
