#!/usr/bin/perl
# Misc hooks:
# - Expand "group" users in flag requestee
# - Remember about nonanswered flag requests
# - Automatic settings of cf_extbug
# - Add a comment to cloned bug
# - Expand MediaWiki urls

package CustisMiscHooks;

use strict;
use utf8;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Error;

# Expand "group" users in flag requestee
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

# Bug 69514 - Automatic setting of cf_extbug during clone to internal/external product
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
# Bug 69514 - automatic setting of cf_extbug during clone to external product
sub bug_end_of_create
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

# MediaWiki link integration
sub quote_urls_custom_proto
{
    my ($args) = @_;
    for (split /\n/, Bugzilla->params->{mediawiki_urls})
    {
        my ($wiki, $url) = split /\s+/, trim($_), 2;
        $args->{custom_proto}->{$wiki} = sub { process_wiki_url($url, @_) } if $wiki && $url;
    }
    return 1;
}

##
## NON-HOOK FUNCTIONS
##

# MediaWiki page anchor encoding
sub process_wiki_anchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
    $anchor =~ tr/ /_/;
    $anchor = url_quote($anchor);
    $anchor =~ s/\%3A/:/giso;
    $anchor =~ tr/%/./;
    return $anchor;
}

# Convert MediaWiki page titles to URLs
sub process_wiki_url
{
    my ($base, $url, $anchor) = @_;
    $url = trim($url);
    $url =~ s/\s+/_/gso;
    # Use url_quote without converting / to %2F
    $url = url_quote_noslash($url);
    return $base . $url . '#' . process_wiki_anchor($anchor);
}

1;
__END__
