#!/usr/bin/perl

use strict;
use utf8;
use Bugzilla::User;

my $requestees = Bugzilla->hook_args->{requestees};
if (@$requestees)
{
    my $group_users = Bugzilla->dbh->selectall_arrayref(
        'SELECT watcher.*, watched.login_name group_user FROM profiles watcher, watch, profiles watched WHERE watcher.userid=watch.watcher AND watched.userid=watch.watched AND watched.login_name IN ('.
        join(',', ('?') x @$requestees).') AND watched.disable_mail AND watched.realname LIKE "Группа%"', {Slice=>{}}, @$requestees
    );
    my %del = map { ($_->{group_user} => 1) } @$group_users;
    @$requestees = ((grep { !$del{$_} } @$requestees), (map { $_->{login_name} } @$group_users));
}
