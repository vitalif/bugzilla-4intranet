#!/usr/bin/perl
# Job for synchronizing bugs with SM dotProject web-service
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Job::SM;

use strict;
use base qw(TheSchwartz::Worker);
use Bugzilla::User;
use Bugzilla::SmClient;
use Bugzilla::SmMapping;

# The longest we expect a job to possibly take, in seconds.
use constant grab_for => 30;
# Retry for 30 days.
use constant max_retries => 725;

my ($SmClient, $SuperUser);

sub retry_delay
{
    my ($class, $num_retries) = @_;
    if ($num_retries < 5)
    {
        return (10, 30, 60, 300, 600)[$num_retries];
    }
    return 60*60;
}

# Worker is very simple - just takes a bug, maps it to SM fields
# and fires create-or-update on SmClient.
sub work
{
    my ($class, $job) = @_;
    my $bug_id = $job->arg->{bug_id};
    eval
    {
        $SmClient ||= Bugzilla::SmClient->new;
        $SuperUser ||= Bugzilla::User->super_user;
        local Bugzilla->request_cache->{user} = $SuperUser;
        my $bug = get_formatted_bugs({ bug_id => $bug_id })->[0];
        $bug || die "Bug $bug_id not found :-(";
        $SmClient->create_or_update($bug);
    };
    if ($@)
    {
        $job->failed($@);
    }
    else
    {
        $job->completed;
    }
}

1;
__END__
