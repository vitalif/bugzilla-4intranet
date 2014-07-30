#!/usr/bin/perl -wT
# Preset field editor for incoming email
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::User;
use Bugzilla::Util;
use Mail::RFC822::Address qw(valid);

my $dbh      = Bugzilla->dbh;
my $user     = Bugzilla->login(LOGIN_REQUIRED);
my $template = Bugzilla->template;
my $userid   = $user->id;
my $params   = Bugzilla->input_params;

unless ($user->in_group('admin'))
{
    ThrowUserError("auth_failure", {
        group  => "admin",
        action => "edit",
        object => "e-mail parse parameters",
    });
}

my $vars = {
    mode_add => $params->{add} ? 1 : 0,
    email    => $params->{email} || '',
    curfield => $params->{field} || '',
    value    => $params->{value} || '',
};

if ($params->{do})
{
    if ($vars->{mode_add})
    {
        my ($e, $f, $v) = @$params{qw(email field value)};
        if (valid($e) && $f)
        {
            $dbh->do("INSERT INTO `emailin_fields` SET `address`=?, `field`=?, `value`=?",
                undef, $e, $f, $v);
            print Bugzilla->cgi->redirect(-location => "editemailin.cgi");
            exit;
        }
        else
        {
            $vars->{bad} = 1;
        }
    }
    else
    {
        my $change = [];
        my $del = [];
        for (keys %$params)
        {
            if (/^f_(.*?)_(.*?)$/so && !$params->{"del_$1_$2"})
            {
                push @$change, [ $1, $2, $params->{$_} ];
            }
            elsif (/^del_(.*?)_(.*?)$/so)
            {
                push @$del, [ $1, $2 ];
            }
        }
        if (@$change)
        {
            $dbh->do(
                "REPLACE INTO `emailin_fields` (`address`, `field`, `value`) VALUES ".
                join(",", ("(?,?,?)") x @$change), undef, map { @$_ } @$change
            );
        }
        if (@$del)
        {
            $dbh->do(
                "DELETE FROM `emailin_fields` WHERE (`address`,`field`) IN (".
                join(",", ("(?,?)") x @$del) . ")", undef, map { @$_ } @$del
            );
        }
        print Bugzilla->cgi->redirect(-location => "editemailin.cgi");
        exit;
    }
}

if (!$vars->{mode_add})
{
    $vars->{fields} = $dbh->selectall_arrayref(
        "SELECT * FROM `emailin_fields` ORDER BY `address`, `field`",
        {Slice=>{}}
    ) || [];
}

$template->process("admin/editemailin.html.tmpl", $vars)
    || ThrowTemplateError($template->error());

1;
__END__
