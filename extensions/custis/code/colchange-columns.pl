#!/usr/bin/perl

use strict;

my $columns = Bugzilla->hook_args->{columns};

push @$columns, 'dependson', 'blocked';

push @$columns, 'flags', 'requests';

push @$columns, 'interval_time';
