#!/usr/bin/perl

use strict;

my $columns = Bugzilla->hook_args->{columns};

$columns->{dependson} = {
    name  => "(SELECT GROUP_CONCAT(bugblockers.dependson SEPARATOR ',') FROM dependencies bugblockers WHERE bugblockers.blocked=bugs.bug_id)",
    title => "Bug dependencies",
};

$columns->{blocked} = {
    name  => "(SELECT GROUP_CONCAT(bugblocked.blocked SEPARATOR ',') FROM dependencies bugblocked WHERE bugblocked.dependson=bugs.bug_id)",
    title => "Bugs blocked",
};
