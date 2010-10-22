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

my @REAL_UPDATE_COLUMNS = qw(is_freeze is_fatal message);

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
        my $ch;
        if ($params->{create})
        {
            $ch = Bugzilla::Checker->create({
                (map { ($_ => $params->{$_}) } 'query_id', @REAL_UPDATE_COLUMNS),
                user_id => $user->id,
            });
        }
        else
        {
            $ch = Bugzilla::Checker->check({ id => $id });
            my $f;
            for (@REAL_UPDATE_COLUMNS)
            {
                $f = "set_$_";
                $ch->$f($params->{$_});
            }
        }
        # поля-исключения: если deny_all=1, то разрешить только их,
        # если deny_all=0, то запретить только их,
        # если deny_all=0 и их нет, то deny_all=1
        my $except = { deny_all => $params->{deny_all}, except_fields => {} };
        for (keys %$params)
        {
            if (/^except_field_(\d+)$/so)
            {
                $except->{except_fields}->{$params->{$_}} =
                    $params->{"except_field_$1_value"} || undef;
            }
        }
        if (!%{$except->{except_fields}})
        {
            $except = undef;
        }
        $ch->set_except_fields($except);
        $ch->update;
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
    my $f = [ Bugzilla->get_fields ];
    @$f = sort { lc $a->description cmp lc $b->description } grep { $_->name !~ /\.|^owner_idle_time$|^commenter$/ } @$f;
    $vars->{my_fielddefs} = $f;
    if (!$vars->{create})
    {
        $vars->{checker} = Bugzilla::Checker->new({ id => $id });
    }
    else
    {
        $vars->{checker} = { deny_all => 1 };
    }
}

$template->process('edit-checkers.html.tmpl', $vars)
  || ThrowTemplateError($template->error());

__END__
