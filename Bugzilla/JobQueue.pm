# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::JobQueue;

use strict;

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Install::Util qw(install_string);
use base qw(TheSchwartz);

# This maps job names for Bugzilla::JobQueue to the appropriate modules.
# If you add new types of jobs, you should add a mapping here.
use constant JOB_MAP => {
    send_mail => 'Bugzilla::Job::Mailer',
};

# Without a driver cache TheSchwartz opens a new database connection
# for each email it sends.  This cached connection doesn't persist
# across requests.
use constant DRIVER_CACHE_TIME => 300; # 5 minutes

sub job_map {
    if (!defined(Bugzilla->request_cache->{job_map})) {
        my $job_map = JOB_MAP;
        Bugzilla::Hook::process('job_map', { job_map => $job_map });
        Bugzilla->request_cache->{job_map} = $job_map;
    }
    
    return Bugzilla->request_cache->{job_map};
}

sub new {
    my $class = shift;

    if (!Bugzilla->feature('jobqueue')) {
        ThrowUserError('feature_disabled', { feature => 'jobqueue' });
    }

    my $lc = Bugzilla->localconfig;
    # We need to use the main DB as TheSchwartz module is going
    # to write to it.
    my $self = $class->SUPER::new(
        databases => [{
            dsn    => Bugzilla->dbh_main->{private_bz_dsn},
            user   => $lc->{db_user},
            pass   => $lc->{db_pass},
            prefix => 'ts_',
        }],
        driver_cache_expiration => DRIVER_CACHE_TIME,
        prioritize => 1,
    );

    return $self;
}

# A way to get access to the underlying databases directly.
sub bz_databases {
    my $self = shift;
    my @hashes = keys %{ $self->{databases} };
    return map { $self->driver_for($_) } @hashes;
}

# inserts a job into the queue to be processed and returns immediately
sub insert {
    my $self = shift;
    my $job = shift;

    if (!ref($job)) {
        my $mapped_job = Bugzilla::JobQueue->job_map()->{$job};
        ThrowCodeError('jobqueue_no_job_mapping', { job => $job })
            if !$mapped_job;

        $job = new TheSchwartz::Job(
            funcname => $mapped_job,
            arg      => $_[0],
            priority => $_[1] || 5
        );
    }
    
    my $retval = $self->SUPER::insert($job);
    # XXX Need to get an error message here if insert fails, but
    # I don't see any way to do that in TheSchwartz.
    ThrowCodeError('jobqueue_insert_failed', { job => $job, errmsg => $@ })
        if !$retval;
 
    return $retval;
}

1;

__END__

=head1 NAME

Bugzilla::JobQueue - Interface between Bugzilla and TheSchwartz.

=head1 SYNOPSIS

 use Bugzilla;

 my $obj = Bugzilla->job_queue();
 $obj->insert('send_mail', { msg => $message });

=head1 DESCRIPTION

Certain tasks should be done asyncronously.  The job queue system allows
Bugzilla to use some sort of service to schedule jobs to happen asyncronously.

=head2 Inserting a Job

See the synopsis above for an easy to follow example on how to insert a
job into the queue.  Give it a name and some arguments and the job will
be sent away to be done later.
