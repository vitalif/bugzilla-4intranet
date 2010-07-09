#!/usr/bin/perl
# Сервер глобальной авторизации

use utf8;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::User;
use Bugzilla::Constants;

use HTTP::Request::Common;
use LWP::Simple qw($ua);
use URI;
use URI::QueryParam;
use URI::Escape;
use JSON;

my $cgi  = Bugzilla->cgi;
my $args = $cgi->Vars;
my $check = $args->{ga_check} ? 1 : 0; # если 1 и пользователь не вошёл, входа не требовать

# требуем входа, если пришёл пользователь (в запросе нет ключа) и в запросе не сказано "не требовать входа"
my $user = Bugzilla->login(!$args->{ga_key} && !$check ? LOGIN_REQUIRED : !LOGIN_REQUIRED);
my $dbh  = Bugzilla->dbh;

my $expire = Bugzilla->params->{globalauth_expire} || 86400;

my $id;
# только серверная сторона
if (($id = $args->{ga_id}) && !$args->{ga_client})
{
    # приём ID и ключа от клиента
    my $key = $args->{ga_key};
    if ($key)
    {
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
        if (time > $tm)
        {
            $key = undef;
            $dbh->do("DELETE FROM globalauth WHERE id=?", undef, $id);
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
                $authdata = {
                    user_email         => $primary_email,
                    user_real_name     => $user->name,
                    user_name          => $user->login,
                    user_email_aliases => [ sort keys %$aliases ],
                };
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
            $url->query_param(ga_id => $id);
            $url->query_param(ga_res => $res->code);
            $dbh->do("DELETE FROM globalauth WHERE id=?", undef, $id);
            print $cgi->redirect(-location => "$url");
            exit;
        }
    }
}

$cgi->send_header;
print "Unknown action passed to Global Auth";
exit;

1;
__END__
