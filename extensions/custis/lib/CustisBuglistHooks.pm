#!/usr/bin/perl
# Custom buglist columns

package CustisBuglistHooks;

use strict;
use Bugzilla::Search;
use Bugzilla::Util;
use Bugzilla::Constants;

# "Static" column definitions - freely cached by Bugzilla forever
sub buglist_static_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};
    my $dbh = Bugzilla->dbh;

    # CustIS Bug 71955 - first comment to the bug
    $columns->{comment0} = {
        title => "First Comment",
        noreports => 1,
    };
    # CustIS Bug 98364 - last comment to the bug
    $columns->{lastcomment} = {
        title => "Last Comment",
        noreports => 1,
    };

    # Last commenter and last comment time
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

    # Needed for SuperWorkTime, would not be needed if buglist.cgi loaded bugs as objects
    $columns->{product_notimetracking} = {
        name => 'map_products.notimetracking',
        joins => $columns->{product}->{joins},
        nobuglist => 1,
        nocharts => 1,
    };

    $columns->{relevance}->{title} = 'Relevance';

    # CustIS Bug 121622 - "WBS enabled" column
    my $cf = Bugzilla->get_field('cf_wbs');
    if ($cf && $cf->type == FIELD_TYPE_SINGLE_SELECT)
    {
        my $t = $cf->name;
        $columns->{$t.'_enabled'} = {
            title => $cf->description.' is enabled',
            name => "$t.isactive",
            joins => [ "LEFT JOIN $t ON $t.value=bugs.$t" ],
        };
    }

    return 1;
}

# "Dynamic" column definitions - rebuilt over static during each request
sub buglist_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

    # CustIS Bug 71955 - first comment to the bug
    my $hint = '';
    my $dbh = Bugzilla->dbh;
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        $hint = ' FORCE INDEX (longdescs_bug_id_idx)';
    }
    my $priv = (Bugzilla->user->is_insider ? "" : "AND ldc0.isprivate=0 ");
    # Not using JOIN (it could be joined on bug_when=creation_ts),
    # because it would require COALESCE to an 'isprivate' subquery
    # for private comments.
    $columns->{comment0}->{name} =
        "(SELECT thetext FROM longdescs ldc0$hint WHERE ldc0.bug_id = bugs.bug_id $priv".
        " ORDER BY ldc0.bug_when LIMIT 1)";
    # CustIS Bug 98364 - last comment to the bug
    $columns->{lastcomment}->{name} =
        "(SELECT thetext FROM longdescs ldc0$hint WHERE ldc0.bug_id = bugs.bug_id $priv".
        " ORDER BY ldc0.bug_when DESC LIMIT 1)";

    # Last commenter and last comment time
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
