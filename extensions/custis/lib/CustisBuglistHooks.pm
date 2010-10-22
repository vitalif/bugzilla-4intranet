#!/usr/bin/perl
# Хуки в список багов

package CustisBuglistHooks;

use strict;

sub buglist_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

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
WHERE col_f.bug_id=bugs.bug_id AND (col_ft.is_requesteeble=0 OR col_ft.is_requestable=0))",
        title => "Flags",
    };

    $columns->{requests} = {
        name  =>
"(SELECT GROUP_CONCAT(CONCAT(col_ft.name,col_f.status,CASE WHEN col_p.login_name IS NULL THEN '' ELSE CONCAT(' ',col_p.login_name) END) SEPARATOR ', ')
FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id
LEFT JOIN profiles col_p ON col_f.requestee_id=col_p.userid
WHERE col_f.bug_id=bugs.bug_id AND col_ft.is_requesteeble=1 AND col_ft.is_requestable=1)",
        title => "Requests",
    };

    # CustIS Bug 68921 (see also Bugzilla::Search)
    $columns->{interval_time} = $columns->{actual_time};
    return 1;
}

sub colchange_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

    push @$columns, 'dependson', 'blocked';
    push @$columns, 'flags', 'requests';
    push @$columns, 'interval_time';

    return 1;
}

1;
__END__
