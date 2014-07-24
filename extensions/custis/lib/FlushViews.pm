#!/usr/bin/perl
# CustIS Bug 61728 - external SQL interface to Bugzilla's bug tables

package FlushViews;

use strict;
use Bugzilla::User;
use Bugzilla::Search;

our @ISA = qw(Exporter);
our @EXPORT = qw(refresh_views);

sub refresh_views
{
    refresh_some_views();
    return 1;
}

# MySQL has a limitation on views! :-(
# Views in MySQL cannot include a subquery in the FROM clause.
# We bypass it by creating a view for every such subquery.
sub recurse_create_view
{
    my ($dbh, $name, $sql, $index) = @_;
    # We need recursive regular expressions, available from Perl 5.10.0
    require 5.010;
    my $myname = $name;
    if (!$index)
    {
        my $i = 0;
        $index = \$i;
    }
    else
    {
        $myname .= '_'.$$index;
    }
    # Match and replace subqueries in the FROM part of the query
    $sql =~ s/(FROM|JOIN) \s* \(\s* SELECT((?:
        [^\(\)\"\'\\]+ |
        \"(?:(?:[^\"\\]+|\\[\"\\])*)\" |
        \'(?:(?:[^\'\\]+|\\[\'\\])*)\' |
        \( (?2) \)
    )+) \)/($$index++), "$1 ".recurse_create_view($dbh, $name, "SELECT$2", $index)/gexiso;
    $dbh->do("DROP VIEW IF EXISTS $myname");
    $dbh->do("CREATE SQL SECURITY DEFINER VIEW $myname AS $sql");
    return $myname;
}

# Refresh views, optionally only for $users = [ 'username@domain.org', ... ]
sub refresh_some_views
{
    my ($users) = @_;
    my %u;
    for (@{$users || []})
    {
        $_ = lc $_;
        s/[^a-z0-9]+/_/giso;
        $_ = "_$_" if !/^[a-z]/;
        $u{$_} = 1;
    }
    my $dbh = Bugzilla->dbh;
    my $r = $dbh->real_table_list('view$%$bugs', 'VIEW');
    # Save current user
    my $old_user = Bugzilla->user;
    for (@$r)
    {
        # Determine user
        my (undef, $user, $query) = split /\$/, $_, -1;
        !%u || $u{$user} or next;
        my $q = $user;
        $q =~ tr/_/%/;
        my ($userid) = $dbh->selectrow_array('SELECT userid FROM profiles WHERE login_name LIKE ? ORDER BY userid LIMIT 1', undef, $q.'@%');
        $userid or next;
        my $userobj = Bugzilla::User->new($userid) or next;
        # Modify current user (hack)
        Bugzilla->request_cache->{user} = $userobj;
        # Determine saved search
        $q = $query;
        $q =~ tr/_/%/;
        ($q) = $dbh->selectrow_array('SELECT name FROM namedqueries WHERE userid=? AND name LIKE ? LIMIT 1', undef, $userid, $q);
        $q or next;
        my $storedquery = Bugzilla::Search::Saved->new({ name => $q, user => $userid }) or next;
        $storedquery = http_decode_query($storedquery->query);
        # get SQL code
        my $search = new Bugzilla::Search(
            params => $storedquery,
            fields => [ 'bug_id', grep { $_ ne 'bug_id' } split(/[ ,]+/, $storedquery->{columnlist} || '') ],
            user   => $userobj,
        ) or next;
        # Re-create views
        my $drop = "DROP VIEW IF EXISTS view\$$user\$$query\$";
        my $create = "CREATE VIEW view\$$user\$$query\$";
        my $bugid_query = $search->bugid_query;
        my $bugids = "view\$$user\$$query\$bugids";
        if ($dbh->isa('Bugzilla::DB::Mysql'))
        {
            $create = "CREATE SQL SECURITY DEFINER VIEW view\$$user\$$query\$";
            recurse_create_view($dbh, $bugids, $bugid_query);
        }
        else
        {
            $dbh->do($drop.'bugids');
            $dbh->do("CREATE VIEW $bugids AS $bugid_query");
        }
        my $sql = $search->getSQL;
        $sql =~ s/\(\s*\Q$bugid_query\E\s*\)/$bugids/s;
        $dbh->do($drop.'bugs');
        $dbh->do($drop.'longdescs');
        $dbh->do($drop.'bugs_activity');
        $dbh->do($drop.'scrum_cards');
        $dbh->do($create.'bugs AS '.$sql);
        $dbh->do($create.'longdescs AS SELECT l.bug_id, u.login_name, l.bug_when, l.thetext, l.work_time FROM longdescs l INNER JOIN '.$bugids.' b ON b.bug_id=l.bug_id INNER JOIN profiles u ON u.userid=l.who'.($userobj->is_insider?'':' WHERE l.isprivate=0'));
        $dbh->do($create.'bugs_activity AS SELECT a.bug_id, u.login_name, a.bug_when, f.name field_name, a.removed, a.added FROM bugs_activity a INNER JOIN '.$bugids.' b ON b.bug_id=a.bug_id INNER JOIN profiles u ON u.userid=a.who INNER JOIN fielddefs f ON f.id=a.fieldid');
        $dbh->do($create.'scrum_cards AS SELECT s.* FROM scrum_cards s INNER JOIN '.$bugids.' b ON b.bug_id=s.bug_id');
    }
    # Restore current user
    Bugzilla->request_cache->{user} = $old_user;
}

# hooks:
sub savedsearch_post_update
{
    my ($args) = @_;
    my $name = $args->{search}->user->login;
    $name =~ s/\@.*$//so;
    refresh_some_views([ $name ]);
    return 1;
}

sub editusers_post_update_delete
{
    my ($args) = @_;
    my $name = $args->{userid};
    if ($name)
    {
        $name = user_id_to_login($name);
        $name =~ s/\@.*$//so;
        refresh_some_views([ $name ]);
    }
    return 1;
}

sub install_before_final_checks
{
    print "Refreshing Views...\n";
    refresh_views();
}

1;
__END__
