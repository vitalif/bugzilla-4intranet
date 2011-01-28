#!/usr/bin/perl
# Прочие хуки

package CustisMiscHooks;

use strict;
use utf8;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Error;

use CustisLocalBugzillas;

# Перенаправление в "свою" багзиллу для внешних/внутренних сотрудников
sub auth_post_login
{
    my ($args) = @_;
    my $user = $args->{user};
    if ($user->settings->{redirect_me_to_my_bugzilla} &&
        lc($user->settings->{redirect_me_to_my_bugzilla}->{value}) eq "on")
    {
        my $loc = \%CustisLocalBugzillas::local_urlbase;
        my $fullurl = Bugzilla->cgi->url();
        foreach my $regemail (keys %$loc)
        {
            if ($user->login =~ /$regemail/s &&
                $fullurl !~ /\Q$loc->{$regemail}->{urlbase}\E/s)
            {
                my $relativeurl = Bugzilla->cgi->url(
                    -path_info => 1,
                    -query     => 1,
                    -relative  => 1
                );
                my $url = $loc->{$regemail}->{urlbase} . $relativeurl;
                print Bugzilla->cgi->redirect(-location => $url);
                exit;
            }
        }
    }
    return 1;
}

# Раскрытие групповых пользователей в запросе флага
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

# Напоминания о несброшенных запросах флагов
sub process_bug_after_move
{
    my ($args) = @_;

    my $cgi = Bugzilla->cgi;
    my $bug_objects = $args->{bug_objects};
    my $vars = $args->{vars};

    my $single = @$bug_objects == 1;
    my $clear_on_close =
        $cgi->param('bug_status') eq 'CLOSED' &&
        Bugzilla->user->settings->{clear_requests_on_close}->{value} eq 'on';
    my $verify_flags = $single &&
        Bugzilla->usage_mode != USAGE_MODE_EMAIL &&
        Bugzilla->user->wants_request_reminder;
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
    return 1;
}

# Интеграция с локальными Wiki-системами для нашей Bugzilla
sub quote_urls_custom_proto
{
    my ($args) = @_;
    for my $wiki (qw/wiki smwiki smboa sbwiki fawiki kswiki rdwiki gzwiki dpwiki hrwiki cbwiki gzstable orwiki rawiki/)
    {
        $args->{custom_proto}->{$wiki} = sub { processWikiUrl($wiki, @_) }
    }
    return 1;
}

# Bug 69514 - автоматическое проставление cf_extbug
# при клонировании во внутренний/внешний продукт
sub enter_bug_cloned_bug
{
    my ($args) = @_;
    if (($args->{product}->extproduct || 0) == $args->{cloned_bug}->product_id)
    {
        $args->{vars}->{cf_extbug} = $args->{cloned_bug}->id;
    }
    elsif (($args->{cloned_bug}->product_obj->extproduct || 0) == $args->{product}->id)
    {
        $args->{vars}->{dependson} = $args->{cloned_bug}->id;
        $args->{vars}->{blocked} = '';
    }
    return 1;
}

# Bug 53590 - add a comment to cloned bug
# Bug 69514 - автоматическое проставление cf_extbug
sub post_bug_post_create
{
    my ($args) = @_;
    my $cloned_bug_id = scalar Bugzilla->cgi->param('cloned_bug_id');
    my $cloned_comment = scalar Bugzilla->cgi->param('cloned_comment');
    my $bug = $args->{bug};
    if ($cloned_bug_id)
    {
        my $cmt = "Bug ".$bug->id." was cloned from ";
        if ($cloned_comment)
        {
            detaint_natural($cloned_comment);
            $cmt .= 'comment ';
            $cmt .= $cloned_comment;
        }
        else
        {
            $cmt .= 'this bug';
        }
        detaint_natural($cloned_bug_id);
        my $cloned_bug = Bugzilla::Bug->check($cloned_bug_id);
        $cloned_bug->add_comment($cmt);
        if (($cloned_bug->product_obj->extproduct || 0) == $bug->product_id &&
            !$cloned_bug->{cf_extbug})
        {
            $cloned_bug->{cf_extbug} = $bug->id;
        }
        $cloned_bug->update($bug->creation_ts);
    }
    return 1;
}

##
## НЕ-хуки:
##

# url_quote, не экранирующий /
sub url_quote_slash
{
    my ($toencode) = (@_);
    utf8::encode($toencode) # The below regex works only on bytes
        if Bugzilla->params->{utf8} && utf8::is_utf8($toencode);
    $toencode =~ s!([^a-zA-Z0-9_\-./])!uc sprintf("%%%02x",ord($1))!ego;
    return $toencode;
}

# кодирование anchor'а подзаголовка wiki-статьи
sub processWikiAnchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
    $anchor =~ tr/ /_/;
    $anchor = url_quote($anchor);
    $anchor =~ s/%/./gso;
    return $anchor;
}

# преобразование названий вики-статей в URL
sub processWikiUrl
{
    my ($wiki, $url, $anchor) = @_;
    $url = trim($url);
    $url =~ s/\s+/ /gso;
    # обычный url_quote нам не подходит, т.к. / не нужно переделывать в %2F
    $url = url_quote_slash($url);
    return Bugzilla->params->{"${wiki}_url"} . $url . '#' . processWikiAnchor($anchor);
}

1;
__END__
