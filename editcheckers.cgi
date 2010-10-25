#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
# Редактор предикатов корректности изменений
# (c) Vitaliy Filippov 2010 <vitalif@mail.ru>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Checker;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Token;

my $template = Bugzilla->template;
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $cgi = Bugzilla->cgi;
my $params = $cgi->Vars;
my $vars = {};

$user->in_group('bz_editcheckers')
  || ThrowUserError('auth_failure', {group  => 'bz_editcheckers',
                                     action => 'modify',
                                     object => 'checkers'});

my $id = $params->{query_id};
defined($id) && detaint_natural($id);
if ($params->{save})
{
    if ($params->{edit})
    {
        check_token_data($params->{token}, 'editcheckers');
        # Заполняем поля-исключения
        my $except = {};
        for (keys %$params)
        {
            if (/^except_field_(\d+)$/so && $params->{$_})
            {
                $except->{$params->{$_}} =
                    $params->{"except_field_$1_value"} || undef;
            }
        }
        $except = undef if !%$except;
        if (!$params->{deny_all} && !$except)
        {
            $params->{deny_all} = 1;
        }
        my $flags =
            ($params->{is_freeze} ? 1 : 0) * CF_FREEZE |
            ($params->{is_fatal} ? 1 : 0)  * CF_FATAL  |
            ($params->{on_update} ? 1 : 0) * CF_UPDATE |
            ($params->{on_create} ? 1 : 0) * CF_CREATE |
            ($params->{deny_all} ? 1 : 0)  * CF_DENY;
        # Ошибка, если CF_CREATE & (есть except_fields).
        if (($flags & CF_CREATE) && $except)
        {
            ThrowUserError('chk_create_except');
        }
        # Создаём/обновляем
        my $ch;
        if ($params->{create})
        {
            $ch = Bugzilla::Checker->create({
                query_id => $params->{query_id},
                user_id  => $user->id,
                message  => $params->{query_id},
                flags    => $flags,
                except_fields => $except,
            });
        }
        else
        {
            $ch = Bugzilla::Checker->check({ id => $id });
            $ch->set_message($params->{message});
            $ch->set_flags($flags);
            $ch->set_except_fields($except);
            $ch->update;
        }
        delete_token($params->{token});
    }
    elsif ($params->{delete})
    {
        Bugzilla->dbh->do('DELETE FROM checkers WHERE query_id=?', undef, $id);
    }
    print $cgi->redirect(-location => 'editcheckers.cgi');
    exit;
}

my $modes = { list => 'list', edit => 'edit' };
$vars->{mode} = $modes->{$params->{mode}} || 'list';

if ($vars->{mode} eq 'list')
{
    $vars->{checkers} = Bugzilla->dbh->selectall_arrayref('SELECT * FROM checkers WHERE user_id=?', {Slice=>{}}, $user->id);
    bless $_, 'Bugzilla::Checker' for @{$vars->{checkers}};
}
else
{
    $vars->{token} = issue_session_token('editcheckers');
    $vars->{create} = $params->{create} ? 1 : 0;
    # Есть специальное поле "longdesc", означающее добавление комментариев
    my $f = [ Bugzilla->get_fields ];
    @$f = sort { lc $a->description cmp lc $b->description } grep { $_->name !~ /
        \. | ^owner_idle_time$ | ^commenter$ | ^content$ | ^assignee_accessible$ |
        ^creation_ts$ | ^days_elapsed$ | ^qacontact_accessible$ /xs } @$f;
    $vars->{my_fielddefs} = $f;
    if (!$vars->{create})
    {
        $vars->{checker} = Bugzilla::Checker->new({ id => $id });
    }
    else
    {
        $vars->{checker} = { is_fatal => 1, deny_all => 1, on_update => 1 };
    }
}

$template->process('edit-checkers.html.tmpl', $vars)
  || ThrowTemplateError($template->error());

__END__
