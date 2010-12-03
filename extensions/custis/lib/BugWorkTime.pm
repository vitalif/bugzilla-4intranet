#!/usr/bin/perl

package BugWorkTime;

use strict;
use POSIX;
use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Util;

# used by mass worktime editing forms
sub FixWorktime
{
    my ($bug, $wtime, $comment, $timestamp, $userid) = @_;
    $bug = Bugzilla::Bug->new({ id => $bug, for_update => 1 }) unless ref $bug;
    return undef unless $bug && ($comment || $wtime);

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

    # stop bugmail
    Bugzilla->dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id=?', undef, $bug->id);

    return 1;
}

# пропорциональное или равномерное распределение времени по пользователям
sub DistributeWorktime
{
    my ($bug, $t, $comment, $timestamp, $from, $to, $min_inc) = @_;
    $comment ||= "Fix worktime";

    my $dbh = Bugzilla->dbh;
    my ($sql, @bind);
    $sql = 'SELECT who, SUM(work_time) wt FROM longdescs WHERE bug_id=?';
    @bind = ($bug->id);
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
        $nt = int($nt*100)/100;
        if (abs($nt) < $min_inc || ($nt < 0) xor ($sum > 0))
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

    # stop bugmail
    Bugzilla->dbh->do('UPDATE bugs SET lastdiffed=NOW() WHERE bug_id=?', undef, $bug->id);
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
    # обрабатываем списанное время и делаем редирект на себя же
    if ($cgi->param('save_worktime'))
    {
        my $wt_user = $cgi->param('worktime_user') || undef;
        my $wt_date = $cgi->param('worktime_date');
        my $comment = $cgi->param('comment');
        # Парсим дату
        $wt_date .= POSIX::strftime(' %H:%M:%S', localtime) if $wt_date !~ / /;
        eval
        {
            $wt_date = from_datetime($wt_date);
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
        $cgi->delete('save_worktime');
        my ($bug, $t);
        my ($tsfrom, $tsto) = (scalar($cgi->param('chfieldfrom')) || '', scalar($cgi->param('chfieldto')) || '');
        trick_taint($tsfrom);
        trick_taint($tsto);
        foreach ($cgi->param)
        {
            if (/^wtime_(\d+)$/)
            {
                $t = $cgi->param($_);
                if ($t)
                {
                    Bugzilla->dbh->bz_start_transaction();
                    if ($bug = Bugzilla::Bug->new({ id => $1, for_update => 1 }))
                    {
                        if ($wt_user)
                        {
                            # списываем время на одного юзера
                            BugWorkTime::FixWorktime($bug, $t, $comment, $wt_date, $wt_user->id);
                        }
                        else
                        {
                            # распределяем время по участникам
                            BugWorkTime::DistributeWorktime($bug, $t, $comment, $wt_date, $tsfrom, $tsto, scalar $cgi->param('divide_min_inc'));
                        }
                    }
                    Bugzilla->dbh->bz_commit_transaction();
                }
                $cgi->delete($_);
            }
        }
        print $cgi->redirect(-location => $cgi->self_url);
        exit;
    }
}

1;
__END__
