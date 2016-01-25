#!/usr/bin/perl -wT
# Bug data correctness checker editor
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

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
my $params = Bugzilla->input_params;
my $vars = {};

$user->in_group('bz_editcheckers') || ThrowUserError('auth_failure', {
    group  => 'bz_editcheckers',
    action => 'modify',
    object => 'checkers',
});

my $id = $params->{id};
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
        # Триггеры
        my $triggers;
        for (keys %$params)
        {
            if ($params->{$_} !~ /^\s*$/so && /^triggers_(.*)$/so)
            {
                $triggers->{$1} = $params->{$_};
            }
        }
        # Создаём/обновляем
        my $ch;
        if ($params->{create})
        {
            $ch = Bugzilla::Checker->create({
                query_id => $params->{query_id},
                user_id  => $user->id,
                message  => $params->{message},
                flags    => $flags,
                except_fields => $except,
                triggers => $triggers,
                bypass_group_id => $params->{bypass_group_id},
            });
        }
        else
        {
            $ch = Bugzilla::Checker->check({ id => $id });
            $ch->set('query_id', $params->{query_id});
            $ch->set('bypass_group_id', $params->{bypass_group_id});
            $ch->set_message($params->{message});
            $ch->set_flags($flags);
            $ch->set_except_fields($except);
            $ch->set_triggers($triggers);
            $ch->update;
        }
        delete_token($params->{token});
    }
    elsif ($params->{delete})
    {
        Bugzilla->dbh->do('DELETE FROM checkers WHERE id=?', undef, $id);
    }
    print Bugzilla->cgi->redirect(-location => 'editcheckers.cgi');
    exit;
}

my $modes = { list => 'list', edit => 'edit' };
$vars->{mode} = $modes->{$params->{mode}} || 'list';

if ($vars->{mode} eq 'list')
{
    $vars->{checkers} = Bugzilla->dbh->selectall_arrayref('SELECT * FROM checkers', {Slice=>{}});
    bless $_, 'Bugzilla::Checker' for @{$vars->{checkers}};
}
else
{
    $vars->{token} = issue_session_token('editcheckers');
    $vars->{create} = $params->{create} ? 1 : 0;
    $vars->{all_groups} = [ Bugzilla::Group->get_all ];
    # Есть специальное поле "longdesc", означающее добавление комментариев
    my $f = [ Bugzilla->get_fields ];
    @$f = sort { lc $a->description cmp lc $b->description } grep { $_->name !~ /
        \. | ^cclist_accessible$ | ^creation_ts$ | ^reporter_accessible$ /xs } @$f;
    # Ещё есть специальное поле "work_time_date", означающее списание времени задним числом
    push @$f, { description => 'Backdated worktime', name => 'work_time_date' };
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

$template->process('admin/edit-checkers.html.tmpl', $vars)
  || ThrowTemplateError($template->error());
exit;

__END__
