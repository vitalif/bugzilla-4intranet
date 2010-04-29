#!/usr/bin/perl

use strict;
use FlushViews;

my $name = Bugzilla->hook_args->{search}->user->login;
$name =~ s/\@.*$//so;
refresh_views([ $name ]);
