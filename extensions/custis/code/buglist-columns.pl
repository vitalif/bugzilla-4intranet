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

$columns->{flags} = {
    name  =>
"(SELECT GROUP_CONCAT(CONCAT(col_ft.name,col_f.status) SEPARATOR ', ')
FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id
WHERE col_f.bug_id=bugs.bug_id AND col_ft.is_requesteeble=0)",
    title => "Flags",
};

$columns->{requests} = {
    name  =>
"(SELECT GROUP_CONCAT(CONCAT(col_ft.name,col_f.status,CASE WHEN col_p.login_name IS NULL THEN '' ELSE CONCAT(' ',col_p.login_name) END) SEPARATOR ', ')
FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id
LEFT JOIN profiles col_p ON col_f.requestee_id=col_p.userid
WHERE col_f.bug_id=bugs.bug_id AND col_ft.is_requesteeble=1)",
    title => "Requests",
};
