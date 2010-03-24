#!/usr/bin/perl

use strict;

my $columns = Bugzilla->hook_args->{columns};

push @$columns, 'dependson', 'blocked';
