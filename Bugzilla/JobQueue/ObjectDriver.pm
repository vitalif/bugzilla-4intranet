#!/usr/bin/perl

package Bugzilla::JobQueue::ObjectDriver;

use strict;
use Bugzilla;
use base qw(Data::ObjectDriver::Driver::DBI);

sub init_db
{
    return Bugzilla->dbh_main;
}
*dbh = *init_db;

1;
__END__
