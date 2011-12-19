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

    # CustIS Bug 71955 - first comment to the bug
    $columns->{comment0} = {
        title => "First Comment",
    };
    $columns->{lastcommenter} = {
        title => "Last Commenter",
    };
    $columns->{last_comment_time} = {
        title => "Last Comment Time",
    };
    $columns->{creation_ts_date} = {
        nocharts => 1,
        title => "Creation Date",
        name => $dbh->sql_date_format('bugs.creation_ts', '%Y-%m-%d'),
    };

    ### Testopia ###
    $columns->{test_cases} = {
        title => "Test cases",
        name  => "(SELECT ".$dbh->sql_group_concat("DISTINCT case_id", "', '")." FROM test_case_bugs tcb WHERE tcb.bug_id=bugs.bug_id)",
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
    # FIXME можно сделать JOIN'ом по bug_when=creation_ts
    # но тогда дополнительно надо COALESCE на подзапрос с isprivate
    # в случае isprivate.
    my $hint = '';
    my $dbh = Bugzilla->dbh;
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        $hint = ' FORCE INDEX (longdescs_bug_id_idx)';
    }
    my $priv = (Bugzilla->user->is_insider ? "" : "AND ldc0.isprivate=0 ");
    $columns->{comment0}->{name} =
        "(SELECT thetext FROM longdescs ldc0$hint WHERE ldc0.bug_id = bugs.bug_id $priv".
        " ORDER BY ldc0.bug_when LIMIT 1)";
    my $login = 'ldp0.login_name';
    if (!Bugzilla->user->id)
    {
        $login = $dbh->sql_string_until($login, $dbh->quote('@'));
    }
    $columns->{lastcommenter}->{name} =
        "(SELECT $login FROM longdescs ldc0$hint".
        " INNER JOIN profiles ldp0 ON ldp0.userid=ldc0.who WHERE ldc0.bug_id = bugs.bug_id $priv".
        " ORDER BY ldc0.bug_when DESC LIMIT 1)";
    $priv = (Bugzilla->user->is_insider ? "" : "AND lct.isprivate=0 ");
    $columns->{last_comment_time}->{name} =
        "(SELECT MAX(lct.bug_when) FROM longdescs lct$hint WHERE lct.bug_id = bugs.bug_id $priv)";

    return 1;
}

1;
__END__
