#!/usr/bin/perl
# Хуки в список багов

package CustisBuglistHooks;

use strict;
use Bugzilla::Search;
use Bugzilla::Util;

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
    $columns->{interval_time} = { %{$columns->{actual_time}} };
    $columns->{interval_time}->{title} = 'Period worktime';

    # CustIS Bug 71955 - first comment to the bug
    $columns->{comment0} = {
        name  =>
            "(SELECT thetext FROM longdescs ldc0 WHERE ldc0.bug_id = bugs.bug_id ".
            (Bugzilla->user->is_insider ? "" : "AND ldc0.isprivate=0 ")." ORDER BY ldc0.bug_when LIMIT 1)",
        title => "First Comment",
    };

    ### Testopia ###
    $columns->{test_cases} = {
        title => "Test cases",
        name  => "(SELECT GROUP_CONCAT(DISTINCT tcb.case_id SEPARATOR ', ') FROM test_case_bugs tcb WHERE tcb.bug_id=bugs.bug_id)",
    };
    ### end Testopia ###

    $columns->{relevance}->{title} = 'Relevance';

    return 1;
}

sub colchange_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

    my $defs = Bugzilla::Search->COLUMNS;
    for (sort keys %$defs)
    {
        push @$columns, $_ if lsearch($columns, $_) < 0 && $_ ne 'bug_id';
    }
    @$columns = sort { $defs->{$a}->{title} cmp $defs->{$b}->{title} } @$columns;

    return 1;
}

1;
__END__
