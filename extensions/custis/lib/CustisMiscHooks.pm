#!/usr/bin/perl
# Misc hooks:
# - Expand "group" users in flag requestee
# - Set cf_extbug automatically during bug cloning
# - Filter text body of input messages to remove Outlook link URLs

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
