#!/usr/bin/perl

use strict;
use CustisLocalBugzillas;

my $vars = Bugzilla->hook_args->{vars};

# Hack into urlbase and set it to be correct for email recipient
CustisLocalBugzillas::HackIntoUrlbase($vars->{to});
