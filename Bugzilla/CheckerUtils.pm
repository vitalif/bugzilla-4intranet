#!/usr/bin/perl
# Bug change check predicates (originally CustIS Bug 68921)
# License: Dual-license GPL 3.0+ or MPL 1.1+

# Idea:
# - The user specifies a saved search.
# - Before or after each bug update, the saved search is executed on updated bugs.
#   It is also possible to run the check when only the specific bug fields are updated.
# - If bug is matched by this saved search, we assume it is in an "incorrect" state,
#   and show an error or a warning.

package Bugzilla::CheckerUtils;

use strict;
use POSIX qw(strftime);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Checker;
use Bugzilla::Search::Saved;
use Bugzilla::Error;
use Bugzilla::Util;

sub refresh_checker
{
    my ($query) = @_;
    my $dbh = Bugzilla->dbh;
    my ($chk) = @{ Bugzilla::Checker->match({ query_id => $query->id }) };
    $chk && $chk->update;
}

sub all
{
    my $c = Bugzilla->request_cache;
    if (!$c->{checkers})
    {
        $c->{checkers} = { map { $_->id => $_ } Bugzilla::Checker->get_all };
    }
    return $c->{checkers};
}

# Run a set of checks for a single bug. Checks are selected based on their flags,
# such that (<flags> & $mask) = $flags. I.e. check(..., CF_UPDATE, CF_FREEZE | CF_UPDATE)
# will select checks with CF_UPDATE, but without CF_FREEZE.
sub check
{
    my ($bug_id, $flags, $mask) = @_;
    $mask ||= 0;
    $flags ||= 0;
    $bug_id = $bug_id->bug_id if ref $bug_id;
    $bug_id = int($bug_id) || return;
    my $all = all();
    my $sql = [];
    my @bind;
    my ($s, $i);
    for (values %$all)
    {
        if (($_->flags & $mask) == $flags)
        {
            $s = $_->sql_code;
            push @$sql, $s;
            push @bind, $bug_id;
        }
    }
    @$sql || return [];
    $sql = join(" UNION ALL ", @$sql);
    $sql = Bugzilla->dbh->prepare_cached($sql);
    $sql->execute(@bind);
    my $checked = [];
    push @$checked, $all->{$i} while (($i) = $sql->fetchrow_array);
    return $checked;
}

# Run checks and rollback changes to the last SAVEPOINT if there are failed ones.
# If only "soft" checks are failed and Bugzilla->request_cache->{checkers_hide_error} is false,
# the warning message with a "Do what I say" button is shown and the request is terminated.
# The function returns true if all checks passed, or if the user said "do what i say" for
# non-fatal checks, and sets $bug->{passed_checkers} to the same value.
sub alert
{
    my ($bug, $is_new) = @_;
    my (@fatal, @warn);
    for (@{$bug->{failed_checkers} || []})
    {
        if ($_->triggers)
        {
            # Triggers never result in an error
        }
        elsif ($_->is_fatal)
        {
            push(@fatal, $_);
        }
        else
        {
            push(@warn, $_);
        }
    }
    my $force = 1 && Bugzilla->input_params->{force_checkers};
    if (!@fatal && (!@warn || $force))
    {
        # Either there are no errors or there are only non-fatal ones and the used clicked "DO WHAT I SAY"
        $bug->{passed_checkers} = 1;
    }
    else
    {
        my $dbh = Bugzilla->dbh;
        # Some checks failed. Roll changes back.
        $bug->{passed_checkers} = 0;
        # bugs_fulltext is non-transactional...
        if ($is_new)
        {
            $dbh->do('DELETE FROM bugs_fulltext WHERE '.$dbh->FULLTEXT_ID_FIELD.'=?', undef, $bug->bug_id);
        }
        else
        {
            $bug->_sync_fulltext;
        }
        # Rollback changes of a SINGLE bug (see process_bug.cgi)
        $dbh->bz_rollback_to_savepoint;
        if (!Bugzilla->request_cache->{checkers_hide_error})
        {
            show_checker_errors(freeze_failed_checkers([ $bug ]));
        }
    }
    return $bug->{passed_checkers};
}

# Show check error message
sub show_checker_errors
{
    my ($bugs) = @_;
    $bugs ||= saved_failed_checkers();
    return if !grep { !$_->{passed_checkers} } @$bugs;
    if (Bugzilla->error_mode != ERROR_MODE_WEBPAGE)
    {
        my $info = [
            map { {
                bug_id => $_->bug_id,
                errors => [ map { $_->message } grep { !$_->triggers } @{$_->{failed_checkers}} ]
            } }
            grep { @{$_->{failed_checkers} || []} } @$bugs
        ];
        ThrowUserError('checks_failed', { bugs => $info });
    }
    @{Bugzilla->result_messages} = ();
    my $fatal = 1 && (grep { grep { $_->{is_fatal} } @{$_->{failed_checkers} || []} } @$bugs);
    delete Bugzilla->input_params->{force_checkers};
    Bugzilla->template->process("bug/process/verify-checkers.html.tmpl", {
        script_name => Bugzilla->cgi->script_name,
        failed => $bugs,
        allow_commit => !$fatal,
    }) || ThrowTemplateError(Bugzilla->template->error);
    exit;
}

sub freeze_failed_checkers
{
    my $failedbugs = shift;
    $failedbugs && @$failedbugs || return undef;
    return [
        map { {
            bug_id => $_->bug_id,
            failed_checkers => [ map { {
                name => $_->name,
                is_fatal => $_->is_fatal,
                is_freeze => $_->is_freeze,
                message => $_->message,
            } } @{$_->{failed_checkers}} ]
        } } grep { @{$_->{failed_checkers} || []} } @$failedbugs
    ];
}

sub filter_failed_checkers
{
    my ($checkers, $changes, $bug) = @_;
    # Filter failed checkers by changes
    my @rc;
    for (@$checkers)
    {
        if ($_->triggers)
        {
            # Skip triggers
            push @rc, $_;
            next;
        }
        my $e = $_->except_fields;
        my $ok = 1;
        if ($_->deny_all)
        {
            # Allow only changes of except_fields to except values
            for (keys %$changes)
            {
                # If the field is not listed in except_fields, OR
                # if there is a specific value in except_fields and our one is not equal
                if (!exists $e->{$_} || (defined $e->{$_} && $changes->{$_}->[1] ne $e->{$_}))
                {
                    $ok = 0;
                    last;
                }
            }
        }
        else
        {
            # Forbid changes of except_fields to except values
            for (keys %$e)
            {
                # work_time_date is a special pseudo-field meaning addition of backdated worktime
                # the value of this pseudo-field is the date before which it is forbidden to fix worktime
                # for example except_fields={work_time_date=2010-09-01} means forbid fixing worktime
                # for dates before 2010-09-01
                if ($_ eq 'work_time_date')
                {
                    my $today_date = strftime('%Y-%m-%d', localtime);
                    my $min_backdate = $e->{$_} || $today_date;
                    my $min_comment_date;
                    foreach (@{$bug->{added_comments} || []})
                    {
                        my $cd = $_->{bug_when} || $today_date;
                        if (!$min_comment_date || $cd lt $min_comment_date)
                        {
                            $min_comment_date = $cd;
                        }
                    }
                    if ($min_comment_date && $min_backdate gt $min_comment_date)
                    {
                        $ok = 0;
                        last;
                    }
                }
                elsif ($changes->{$_} && (!defined $e->{$_} || $changes->{$_}->[1] eq $e->{$_}))
                {
                    $ok = 0;
                    last;
                }
            }
        }
        push @rc, $_ unless $ok;
    }
    @$checkers = @rc;
}

# Run triggers for bug $bug from $bug->{failed_checkers}
sub run_triggers
{
    my ($bug) = @_;
    my $modified = 0;
    for (my $i = $#{$bug->{failed_checkers}}; $i >= 0; $i--)
    {
        my $checker = $bug->{failed_checkers}->[$i];
        if ($checker->triggers)
        {
            # FIXME Only "add CC" and "clear flag" triggers are supported by now, but it's not that hard to support more
            if ($checker->triggers->{add_cc})
            {
                for (split /[\s,]+/, $checker->triggers->{add_cc})
                {
                    $bug->add_cc($_);
                    $modified = 1;
                }
            }
            if ($checker->triggers->{clear_flags})
            {
                my %del_flags = map { $_ => 1 } split /[\s,]*,+[\s,]*/, $checker->triggers->{clear_flags};
                for my $flag (@{$bug->flags})
                {
                    if ($del_flags{$flag->name})
                    {
                        $bug->make_dirty;
                        Bugzilla::Flag->set_flag($bug, {
                            id => $flag->id,
                            status => 'X',
                            requestee => $flag->requestee && $flag->requestee->login,
                        });
                        $modified = 1;
                    }
                }
            }
        }
        # FIXME Show information about the applied trigger (use result_messages)
        splice @{$bug->{failed_checkers}}, $i, 1;
    }
    return $modified;
}

sub saved_failed_checkers
{
    my ($create_if_not_found) = @_;
    for my $msg (@{ Bugzilla->result_messages })
    {
        if ($msg->{message} eq 'checkers_failed')
        {
            return $msg->{failed_checkers} ||= [];
        }
    }
    if ($create_if_not_found)
    {
        my $list = [];
        Bugzilla->add_result_message({
            message => 'checkers_failed',
            failed_checkers => $list,
        });
        return $list;
    }
    return undef;
}

# hooks:

sub bug_pre_update
{
    my ($args) = @_;
    my $bug = $args->{bug};
    # Run checks BEFORE updating the bug. These are "freezers" and triggers.
    $bug->{failed_checkers} = check($bug->bug_id, CF_FREEZE | CF_UPDATE, CF_FREEZE | CF_UPDATE);
    run_triggers($bug);
    return 1;
}

sub bug_end_of_update
{
    my ($args) = @_;

    my $bug = $args->{bug};
    my $changes = { %{ $args->{changes} } }; # copy hash
    $changes->{longdesc} = $args->{bug}->{added_comments} && @{ $args->{bug}->{added_comments} }
        ? [ '', scalar @{$args->{bug}->{added_comments}} ] : undef;

    # run checks AFTER updating the bug (normal "checkers")
    push @{$bug->{failed_checkers}}, @{ check($bug->bug_id, CF_UPDATE, CF_FREEZE | CF_UPDATE) };

    # filter by changes
    if (@{$bug->{failed_checkers}})
    {
        filter_failed_checkers($bug->{failed_checkers}, $changes, $bug);
    }

    # complain and roll changes back if there are failed checks
    if (@{$bug->{failed_checkers}})
    {
        alert($bug);
        # remember failed checks in result_messages
        push @{saved_failed_checkers(1)}, @{ freeze_failed_checkers([ $bug ]) };
    }

    return 1;
}

sub bug_end_of_create
{
    my ($args) = @_;
    my $bug = $args->{bug};
    # We don't filter anything by field changes when creating bugs!
    $bug->{failed_checkers} = check($bug->bug_id, CF_CREATE, CF_CREATE);
    if (@{$bug->{failed_checkers}})
    {
        alert($bug, 1);
    }
    # Triggers are ran in a separate UPDATE on bug creation.
    if (run_triggers($bug))
    {
        $bug->update;
    }
    return 1;
}

sub savedsearch_post_update
{
    my ($args) = @_;
    refresh_checker($args->{search});
    return 1;
}

# Refresh cached SQL code of checks at the end of checksetup.pl
sub install_before_final_checks
{
    my ($args) = @_;
    print "Refreshing Checkers SQL...\n" if !$args->{silent};
    Bugzilla->request_cache->{user} = Bugzilla::User->super_user;
    for (Bugzilla::Checker->get_all)
    {
        eval { $_->update };
        if ($@)
        {
            warn $@;
        }
    }
    return 1;
}

1;
__END__
