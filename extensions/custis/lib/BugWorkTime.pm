#!/usr/bin/perl

package BugWorkTime;

use strict;
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
    my ($bug, $t, $comment, $timestamp, $from, $to) = @_;
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
    my $sum = 0;
    my $n = keys(%$propo) || return undef;
    $sum += $propo->{$_} for keys %$propo;

    my $nt;
    for (keys %$propo)
    {
        $nt = $sum > 0 ? $t*$propo->{$_}/$sum : $t/$n;
        $nt = int($nt*100)/100;
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
        trick_taint($wt_date);
        my ($ts, $nd, $nt) = Bugzilla->dbh->selectrow_array('SELECT DATE(?), CURRENT_DATE(), CURRENT_TIME()', undef, $wt_date);
        $ts = $ts && $vars->{wt_admin} ? $ts : $nd;
        $ts .= ' ' . $nt;
        if (!$vars->{wt_admin})
        {
            $wt_user = Bugzilla->user;
        }
        elsif ($wt_user)
        {
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
        elsif ($Bugzilla::Search::interval_who)
        {
            $wt_user = $Bugzilla::Search::interval_who;
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
                            BugWorkTime::FixWorktime($bug, $t, $comment, $ts, $wt_user->id);
                        }
                        else
                        {
                            BugWorkTime::DistributeWorktime($bug, $t, $comment, $ts, $tsfrom, $tsto);
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
