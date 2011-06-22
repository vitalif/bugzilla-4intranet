#!/usr/bin/perl
# CustIS Bug 68921 - "Предикаты проверки корректности"
# - Задаётся сохранённый запрос поиска.
# - Принимается что баги, соответствующие (или НЕ соответствующие) этому запросу
#   до (или после) любых изменений - некорректные, и надо выдать предупреждение или ошибку.
# - Выставляется флажок, можно ли всё-таки оставлять комментарии без рабочего времени.

package Checkers;

use strict;
use POSIX qw(strftime);

use Bugzilla;
use Bugzilla::Checker;
use Bugzilla::Search::Saved;
use Bugzilla::Error;

our $THROW_ERROR = 1; # 0 во время массовых изменений

sub refresh_checker
{
    my ($query) = @_;
    my $dbh = Bugzilla->dbh;
    my ($chk) = @{ Bugzilla::Checker->match({ query_id => $query->id }) };
    $chk && $chk->update;
}

sub all
{
    my $c = Bugzilla->request_cache;
    if (!$c->{checkers})
    {
        $c->{checkers} = { map { $_->id => $_ } Bugzilla::Checker->get_all };
    }
    return $c->{checkers};
}

# Запустить набор проверок по одному багу
# $mask - маска из флагов, которые нужно проверять для фильтрации проверок
# $flags - требуемые значения этих флагов
# Т.е. check(..., CF_UPDATE, CF_FREEZE | CF_UPDATE) выберет проверки
# с флагом CF_UPDATE, но без флага CF_FREEZE
sub check
{
    my ($bug_id, $flags, $mask) = @_;
    $mask ||= 0;
    $flags ||= 0;
    $bug_id = $bug_id->bug_id if ref $bug_id;
    $bug_id = int($bug_id) || return;
    my $all = all();
    my $sql = [];
    my @bind;
    my ($s, $i);
    for (values %$all)
    {
        if (($_->flags & $mask) == $flags)
        {
            $s = $_->sql_code;
            $i = $_->id;
            $s =~ s/^(.*)(GROUP\s+BY)/SELECT $i id FROM $1 AND bugs.bug_id=? $2/iso;
            push @$sql, $s;
            push @bind, $bug_id;
        }
    }
    @$sql || return [];
    $sql = "(" . join(") UNION ALL (", @$sql) . ")";
    $sql = Bugzilla->dbh->prepare_cached($sql);
    $sql->execute(@bind);
    my $checked = [];
    push @$checked, $all->{$i} while (($i) = $sql->fetchrow_array);
    return $checked;
}

sub alert
{
    my ($bug, $is_new) = @_;
    my (@fatal, @warn);
    map { $_->is_fatal ? push(@fatal, $_) : push(@warn, $_) } @{$bug->{failed_checkers}};
    my $force = 1 && Bugzilla->cgi->param('force_checkers');
    if (!@fatal && (!@warn || $force))
    {
        # фатальных нет, нефатальных либо тоже нет, либо пользователь сказал "DO WHAT I SAY"
        $bug->{passed_checkers} = 1;
    }
    else
    {
        # откатываем изменения
        $bug->{passed_checkers} = 0;
        # bugs_fulltext нужно откатывать отдельно...
        if ($is_new)
        {
            Bugzilla->dbh->do('DELETE FROM bugs_fulltext WHERE bug_id=?', undef, $bug->bug_id);
        }
        else
        {
            $bug->_sync_fulltext;
        }
        # нужно откатить изменения ТОЛЬКО ОДНОГО бага (см. process_bug.cgi)
        Bugzilla->dbh->bz_rollback_to_savepoint;
        if ($THROW_ERROR)
        {
            Bugzilla->template->process("verify-checkers.html.tmpl", {
                failed => [ $bug ],
                allow_commit => !@fatal,
                exclude_params_re => '^force_checkers$',
            }) || ThrowTemplateError(Bugzilla->template->error);
            exit;
        }
    }
}

sub freeze_failed_checkers
{
    my $failedbugs = shift;
    $failedbugs && @$failedbugs || return undef;
    return [ map { [ $_->bug_id, [ map { $_->id } @{$_->{failed_checkers}} ] ] } @$failedbugs ];
}

sub unfreeze_failed_checkers
{
    my $freezed = shift;
    $freezed && @$freezed || return undef;
    my @r;
    for (@$freezed)
    {
        my ($bug, $cl) = @$_;
        $bug = Bugzilla::Bug->check($bug);
        $bug->{failed_checkers} = Bugzilla::Checker->new_from_list($cl);
        push @r, $bug;
    }
    return \@r;
}

sub filter_failed_checkers
{
    my ($checkers, $changes, $bug) = @_;
    # фильтруем подошедшие проверки по изменённым полям
    my @rc;
    for (@$checkers)
    {
        my $e = $_->except_fields;
        my $ok = 1;
        if ($_->deny_all)
        {
            # разрешить только изменения полей-исключений только на значения-исключения
            for (keys %$changes)
            {
                # если это поле не перечислено в списке исключений ЛИБО
                # если в исключениях задано разрешённое новое значение, и у нас не оно
                if (!exists $e->{$_} || (defined $e->{$_} && $changes->{$_}->[1] ne $e->{$_}))
                {
                    $ok = 0;
                    last;
                }
            }
        }
        else
        {
            # запретить изменения полей-исключений на значения-исключения
            for (keys %$e)
            {
                # специальное псевдо-поле, означающее списание времени задним числом
                # а значение этого псевдо-поля означает списание времени датой меньшей этого значения
                # т.е. например запретить изменения поля "work_time_date" на дату "2010-09-01"
                # значит запретить списывать время задним числом на даты раньше 2010-09-01
                if ($_ eq 'work_time_date')
                {
                    my $today_date = strftime('%Y-%m-%d', localtime);
                    my $min_backdate = $e->{$_} || $today_date;
                    my $min_comment_date;
                    foreach (@{$bug->{added_comments} || []})
                    {
                        my $cd = $_->{bug_when} || $today_date;
                        if (!$min_comment_date || $cd lt $min_comment_date)
                        {
                            $min_comment_date = $cd;
                        }
                    }
                    if ($min_comment_date && $min_backdate gt $min_comment_date)
                    {
                        $ok = 0;
                        last;
                    }
                }
                elsif ($changes->{$_} && (!defined $e->{$_} || $changes->{$_}->[1] eq $e->{$_}))
                {
                    $ok = 0;
                    last;
                }
            }
        }
        push @rc, $_ unless $ok;
    }
    @$checkers = @rc;
}

# hooks:

sub bug_pre_update
{
    my ($args) = @_;
    my $bug = $args->{bug};
    # запускаем проверки, работающие ДО внесения изменений (заморозка багов)
    $bug->{failed_checkers} = check($bug->bug_id, CF_FREEZE | CF_UPDATE, CF_FREEZE | CF_UPDATE);
    return 1;
}

sub bug_end_of_update
{
    my ($args) = @_;

    my $bug = $args->{bug};
    my $changes = { %{ $args->{changes} } }; # копируем хеш
    $changes->{longdesc} = $args->{bug}->{added_comments} && @{ $args->{bug}->{added_comments} }
        ? [ '', scalar @{$args->{bug}->{added_comments}} ] : undef;

    # запускаем проверки, работающие ПОСЛЕ внесения изменений
    push @{$bug->{failed_checkers}}, @{ check($bug->bug_id, CF_UPDATE, CF_FREEZE | CF_UPDATE) };

    if (@{$bug->{failed_checkers}})
    {
        filter_failed_checkers($bug->{failed_checkers}, $changes, $bug);
    }

    # ругаемся/откатываем изменения, если что-то есть
    if (@{$bug->{failed_checkers}})
    {
        alert($bug);
        %{ $args->{changes} } = ();
        $bug->{added_comments} = undef;
    }
    return 1;
}

sub post_bug_post_create
{
    my ($args) = @_;
    my $bug = $args->{bug};
    # При создании бага сия радость по изменениям не фильтруеццо!
    $bug->{failed_checkers} = check($bug->bug_id, CF_CREATE, CF_CREATE);
    if (@{$bug->{failed_checkers}})
    {
        alert($bug, 1);
    }
    return 1;
}

sub savedsearch_post_update
{
    my ($args) = @_;
    refresh_checker($args->{search});
    return 1;
}

# Конец checksetup'а - обновляем SQL-код проверок
sub install_before_final_checks
{
    Bugzilla->request_cache->{user} = Bugzilla::User->super_user;
    eval { $_->update } for Bugzilla::Checker->get_all;
    return 1;
}

1;
__END__