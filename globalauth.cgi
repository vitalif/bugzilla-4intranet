#!/usr/bin/perl -wT
# CustIS Bug 63447 - Сервер глобальной авторизации

use utf8;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Constants;

use Encode;
use HTTP::Request::Common;
use LWP::Simple qw($ua);
use URI;
use URI::QueryParam;
use URI::Escape;
use JSON;

my $gc_prob = 0.01;

my $cgi  = Bugzilla->cgi;
my $args = { %{ $cgi->Vars } };
my $check = $args->{ga_check} ? 1 : 0; # если 1 и пользователь не вошёл, входа не требовать

# требуем входа, если пришёл пользователь (в запросе нет ключа) и в запросе не сказано "не требовать входа"
my $user = Bugzilla->login(!$args->{ga_key} && !$check ? LOGIN_REQUIRED : !LOGIN_REQUIRED);
my $dbh  = Bugzilla->dbh;

my $expire = Bugzilla->params->{globalauth_expire} || 86400;

my $id;
# только серверная сторона
if (($id = $args->{ga_id}) && !$args->{ga_client})
{
    if (rand() < $gc_prob)
    {
        $dbh->do("DELETE FROM globalauth WHERE expire < UNIX_TIMESTAMP()");
    }
    trick_taint($id);
    # приём ID и ключа от клиента
    my $key = $args->{ga_key};
    if ($key)
    {
        trick_taint($key);
        $dbh->do("REPLACE INTO globalauth SET id=?, secret=?, expire=?", undef, $id, $key, time+$expire);
        $cgi->send_header;
        print "1"; # потенциально здесь любой JSON
        exit;
    }
    # передача данных авторизации клиенту
    else
    {
        my $tm;
        ($key, $tm) = $dbh->selectrow_array("SELECT secret, expire FROM globalauth WHERE id=?", undef, $id);
        if ($key && time > $tm)
        {
            $key = undef;
            $dbh->do("DELETE FROM globalauth WHERE id=?", undef, $id);
            die "GlobalAuth key expired";
        }
        if ($key)
        {
            my $url = $args->{ga_url};
            if (!$url)
            {
                # ошибко :(
                $cgi->send_header;
                print "Global Auth: No ga_url in request for ID=$id";
                warn "Global Auth: No ga_url in request for ID=$id";
                exit;
            }
            $url = URI->new($url);
            my $authdata;
            if ($user && $user->id)
            {
                # почтовые алиасы
                my $rows = $dbh->selectall_arrayref("SELECT * FROM emailin_aliases WHERE userid=?", {Slice=>{}}, $user->id);
                my $aliases = {};
                my $primary_email;
                for (@$rows)
                {
                    if ($_->{isprimary})
                    {
                        $primary_email = $_->{address};
                    }
                    $aliases->{$_->{address}} = 1;
                }
                $aliases->{$user->email} = 1;
                $primary_email ||= $user->email;
                # собираем данные
                $authdata = {
                    user_email          => $primary_email,
                    user_real_name      => $user->name,
                    user_name           => $user->login,
                    user_email_aliases  => [ sort keys %$aliases ],
                    # включаем также информацию о правах пользователя
                    user_groups         => [ map { $_->name } @{ $user->groups } ],
                    #selectable_products => [ map { $_->name } @{ $user->get_selectable_products } ], # пока не нужно
                    #editable_products   => [ map { $_->name } @{ $user->get_editable_products } ],   # пока не нужно
                    # информация об источнике данных
                    auth_source         => 'Bugzilla',
                    auth_server         => correct_urlbase().'/globalauth.cgi',
                    auth_site           => correct_urlbase(),
                };
                # кодируем данные в JSON
                $authdata = { ga_data => encode_json($authdata) };
            }
            else
            {
                $authdata = { ga_nologin => 1 };
            }
            $authdata->{ga_id} = $id;
            $authdata->{ga_key} = $key;
            # TODO LWPx::ParanoidAgent
            $ua->timeout(Bugzilla->params->{globalauth_timeout} || 30);
            # отправляем запрос серверу клиента
            my $res = $ua->request(POST "$url", Content => $authdata);
            # и делаем перенаправление в браузере
            {
                no utf8;
                # URI::QueryParam имеет проблемы с утф'ом...
                $url->query_param(ga_id => $id);
                $url->query_param(ga_res => $res->code);
            }
            $dbh->do("DELETE FROM globalauth WHERE id=?", undef, $id);
            print $cgi->redirect(-location => "$url");
            exit;
        }
        else
        {
            die "Global Auth key not found";
        }
    }
}
else
{
    die("Global Auth client mode disabled in Bugzilla");
}

1;
__END__
