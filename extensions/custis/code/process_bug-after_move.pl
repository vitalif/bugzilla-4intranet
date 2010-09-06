#!/usr/bin/perl

use strict;
use Bugzilla::Constants;
use Bugzilla::Util qw(trim);
use Bugzilla::User;
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
my $bug_objects = Bugzilla->hook_args->{bug_objects};
my $vars = Bugzilla->hook_args->{vars};

my $single = @$bug_objects == 1;
my $clear_on_close = $cgi->param('bug_status') eq 'CLOSED' && Bugzilla->params->{clear_requests_on_close};
my $verify_flags = $single && Bugzilla->usage_mode != USAGE_MODE_EMAIL && Bugzilla->user->wants_request_reminder;
my $reset_own_flags = $verify_flags && $cgi->param('comment') !~ /^\s*$/so;

if (($clear_on_close || $reset_own_flags) && !$cgi->param('force_flags'))
{
    my $flags;
    my @requery_flags;
    my $flag;
    my $login;
    # 1) Check flag requests and remind user about resetting his own incoming requests.
    # 2) When closing bugs, clear all flag requests (CustIS Bug 68430).
    # Not used in mass update and email modes.
    for my $bug (@$bug_objects)
    {
        if ($single)
        {
            for ($cgi->param())
            {
                if (/^(flag-(\d+))$/)
                {
                    $flag = Bugzilla::Flag->new({ id => $2 });
                    $flag->{status} = $cgi->param($1);
                    if (($login = trim($cgi->param("requestee-".$flag->{id}))) &&
                        ($login = login_to_id($login)))
                    {
                        $flag->{requestee_id} = $login;
                    }
                    push @$flags, $flag;
                }
            }
        }
        else
        {
            $flags = Bugzilla::Flag->match({ bug_id => $bug->id });
        }
        foreach $flag (@$flags)
        {
            if ($flag->{status} eq '?' &&
                ($clear_on_close || $flag->{requestee_id} eq Bugzilla->user->id))
            {
                if ($clear_on_close)
                {
                    $flag->{status} = 'X';
                }
                if ($verify_flags)
                {
                    push @requery_flags, $flag;
                }
                elsif ($single)
                {
                    $cgi->param('flag-'.$flag->{id} => 'X');
                }
                else
                {
                    Bugzilla::Flag->set_flag($bug, $flag);
                }
            }
        }
        if ($verify_flags && @requery_flags)
        {
            push @{$vars->{verify_flags}}, @requery_flags;
            $vars->{field_filter} = '^('.join('|', map { "flag-".$_->id } @{$vars->{verify_flags}}).')$';
            Bugzilla->template->process("bug/process/verify-flags.html.tmpl", $vars)
                || ThrowTemplateError(Bugzilla->template->error());
            exit;
        }
    }
}
