#!/usr/bin/perl
# Хуки в список багов

package CustisBuglistHooks;

use strict;
use Bugzilla::Search;
use Bugzilla::Util;

sub buglist_static_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};
    my $dbh = Bugzilla->dbh;

    $columns->{flags} = {
        name  =>
"(SELECT ".$dbh->sql_group_concat($dbh->sql_string_concat('col_ft.name', 'col_f.status'), "', '")."
FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id
WHERE col_f.bug_id=bugs.bug_id AND (col_ft.is_requesteeble=0 OR col_ft.is_requestable=0))",
        title => "Flags",
    };

    $columns->{requests} = {
        name  =>
"(SELECT ".
    $dbh->sql_group_concat(
        $dbh->sql_string_concat(
            'col_ft.name', 'col_f.status',
            'CASE WHEN col_p.login_name IS NULL THEN \'\' ELSE '.
                $dbh->sql_string_concat("' '", 'col_p.login_name').' END'
        ), "', '"
    )."
FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id
LEFT JOIN profiles col_p ON col_f.requestee_id=col_p.userid
WHERE col_f.bug_id=bugs.bug_id AND col_ft.is_requesteeble=1 AND col_ft.is_requestable=1)",
        title => "Requests",
    };

    # CustIS Bug 68921 (see also Bugzilla::Search)
    $columns->{interval_time} = { %{$columns->{work_time}} };
    $columns->{interval_time}->{title} = 'Period worktime';

    # CustIS Bug 71955 - first comment to the bug
    $columns->{comment0} = {
        title => "First Comment",
    };

    ### Testopia ###
    $columns->{test_cases} = {
        title => "Test cases",
        name  => "(SELECT ".$dbh->sql_group_concat("case_id", "', '")." FROM (SELECT DISTINCT tcb.case_id FROM test_case_bugs tcb WHERE tcb.bug_id=bugs.bug_id) t)",
    };
    ### end Testopia ###

    # Нужно для SuperWorkTime, однако эта необходимость следует
    # из неидеальности buglist.cgi - он не выводит баги объектами
    $columns->{product_notimetracking} = {
        name => 'map_products.notimetracking',
        joins => $columns->{product}->{joins},
        nobuglist => 1,
        nocharts => 1,
    };

    $columns->{relevance}->{title} = 'Relevance';

    return 1;
}

sub buglist_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

    # CustIS Bug 71955 - first comment to the bug
    $columns->{comment0}->{name} =
        "(SELECT thetext FROM longdescs ldc0 WHERE ldc0.bug_id = bugs.bug_id ".
        (Bugzilla->user->is_insider ? "" : "AND ldc0.isprivate=0 ")." ORDER BY ldc0.bug_when LIMIT 1)";

    return 1;
}

1;
__END__
