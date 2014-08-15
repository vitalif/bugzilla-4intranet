#!/usr/bin/perl
# Misc hooks:
# - Expand "group" users in flag requestee
# - Remember about nonanswered flag requests
# - Automatic settings of cf_extbug

package CustisMiscHooks;

use strict;
use utf8;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Error;

# Expand CUSTIS-specific "group" users in flag requestee
sub flag_check_requestee_list
{
    my ($args) = @_;
    my $requestees = $args->{requestees};
    if (@$requestees)
    {
        my $group_users = Bugzilla->dbh->selectall_arrayref(
            'SELECT watcher.*, watched.login_name group_user FROM profiles watcher, watch, profiles watched WHERE watcher.userid=watch.watcher AND watched.userid=watch.watched AND watched.login_name IN ('.
            join(',', ('?') x @$requestees).') AND watched.disable_mail>0 AND watched.realname LIKE \'Группа%\'', {Slice=>{}}, @$requestees
        );
        my %del = map { ($_->{group_user} => 1) } @$group_users;
        @$requestees = ((grep { !$del{$_} } @$requestees), (map { $_->{login_name} } @$group_users));
    }
    return 1;
}

# Remind about flag requests during bug changes
sub process_bug_after_move
{
    my ($args) = @_;

    my $ARGS = Bugzilla->input_params;
    my $bug_objects = $args->{bug_objects};
    my $vars = $args->{vars};

    my $single = @$bug_objects == 1;
    my $clear_on_close =
        $ARGS->{bug_status} eq 'CLOSED' &&
        Bugzilla->user->settings->{clear_requests_on_close}->{value} eq 'on';
    my $verify_flags = $single &&
        Bugzilla->usage_mode != USAGE_MODE_EMAIL &&
        Bugzilla->user->wants_request_reminder;
    my $reset_own_flags = $verify_flags && $ARGS->{comment} !~ /^\s*$/so;

    if (($clear_on_close || $reset_own_flags) && !$ARGS->{force_flags})
    {
        my $flags;
        my @requery_flags;
        my $flag;
        my $login;
        # 1) Check flag requests and remind user about resetting his own incoming requests.
        # 2) When closing bugs, clear all flag requests (CustIS Bug 68430).
        for my $bug (@$bug_objects)
        {
            if ($single)
            {
                for (keys %$ARGS)
                {
                    if (/^(flag-(\d+))$/)
                    {
                        $flag = Bugzilla::Flag->new({ id => $2 });
                        $flag->{status} = $ARGS->{$_};
                        if (($login = trim($ARGS->{"requestee-".$flag->{id}})) &&
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
                        delete $ARGS->{'flag-'.$flag->{id}};
                    }
                    elsif ($single)
                    {
                        $ARGS->{'flag-'.$flag->{id}} = 'X';
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
                Bugzilla->template->process("bug/process/verify-flags.html.tmpl", $vars)
                    || ThrowTemplateError(Bugzilla->template->error());
                exit;
            }
        }
    }
    return 1;
}

# Bug 69514 - Automatic setting of cf_extbug during clone to internal/external product
sub enter_bug_cloned_bug
{
    my ($args) = @_;
    if (($args->{product}->extproduct || 0) == $args->{cloned_bug}->product_id)
    {
        $args->{default}->{cf_extbug} = $args->{cloned_bug}->id;
    }
    elsif (($args->{cloned_bug}->product_obj->extproduct || 0) == $args->{product}->id)
    {
        $args->{default}->{dependson} = $args->{cloned_bug}->id;
        $args->{default}->{blocked} = '';
    }
    return 1;
}

# Bug 69514 - Automatic setting of cf_extbug during clone to external product
sub post_bug_cloned_bug
{
    my ($args) = @_;
    if (($args->{cloned_bug}->product_obj->extproduct || 0) == $args->{bug}->product_id &&
        !$args->{cloned_bug}->{cf_extbug})
    {
        $args->{cloned_bug}->{cf_extbug} = $args->{bug}->id;
    }
    return 1;
}

# Filter text body of input messages to remove Outlook link URLs.
sub emailin_filter_body
{
    my ($args) = @_;

    for (${$args->{body}})
    {
        if (/From:\s+bugzilla-daemon(\s*[a-z0-9_\-]+\s*:.*?\n)*\s*Bug\s*\d+<[^>]*>\s*\([^\)]*\)\s*/iso)
        {
            my ($pr, $ps) = ($`, $');
            $ps =~ s/\n+(\r*\n+)+/\n/giso;
            $_ = $pr . $ps;
            s!from\s+.*?<http://plantime[^>]*search=([^>]*)>!from $1!giso;
            s!((Comment|Bug)\s+\#?\d+)<[^<>]*>!$1!giso;
            s!\n[^\n]*<http://plantime[^>]*search=[^>]*>\s+changed:[ \t\r]*\n.*?$!!iso;
            s/\s*\n--\s*Configure\s*bugmail<[^>]*>(([ \t\r]*\n[^\n]*)*)//iso;
        }
    }
    return 1;
}

1;
__END__
