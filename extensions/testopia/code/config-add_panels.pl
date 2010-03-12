#!/usr/bin/perl

use strict;

Bugzilla->hook_args->{panel_modules}->{Testopia} = 'extensions::testopia::lib::Testopia::Config';
