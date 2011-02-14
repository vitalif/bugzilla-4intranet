#!/usr/bin/perl
# CustIS Bug 61728 - external SQL interface to Bugzilla's bug tables

package FlushViews;

use strict;
use Bugzilla::CGI;
use Bugzilla::User;
use Bugzilla::Search;

our @ISA = qw(Exporter);
our @EXPORT = qw(refresh_views);

sub refresh_views
{
    refresh_some_views();
    return 1;
}

# Refresh views, optionally only for $users = [ 'username@domain.org', ... ]
sub refresh_some_views
{
    my ($users) = @_;
    my %u = ( map { $_ => 1 } @{ $users || [] } );
    my $dbh = Bugzilla->dbh;
    my $r = $dbh->real_table_list('view$%$bugs', 'VIEW');
    # Save current user
    my $old_user = Bugzilla->user;
    for (@$r)
    {
        # Determine user
        my (undef, $user, $query) = split /\$/, $_, -1;
        !%u || $u{$user} or next;
        my ($userid) = $dbh->selectrow_array('SELECT userid FROM profiles WHERE login_name LIKE ? ORDER BY userid LIMIT 1', undef, $user.'@%');
        $userid or next;
        my $userobj = Bugzilla::User->new($userid) or next;
        # Modify current user (hack)
        Bugzilla->request_cache->{user} = $userobj;
        # Determine saved search
        my $q = $query;
        $q =~ tr/_/%/;
        ($q) = $dbh->selectrow_array('SELECT name FROM namedqueries WHERE userid=? AND name LIKE ? LIMIT 1', undef, $userid, $q);
        $q or next;
        my $storedquery = Bugzilla::Search::LookupNamedQuery($q, $userid, undef, 0) or next;
        my $cgi = new Bugzilla::CGI($storedquery);
        # get SQL code
        my $search = new Bugzilla::Search(
            params => $cgi,
            fields => [ 'bug_id', grep { $_ ne 'bug_id' } split /[ ,]+/, $cgi->param('columnlist') ],
            user   => $userobj,
        ) or next;
        my $sqlquery = $search->getSQL();
        $sqlquery =~ s/ORDER\s+BY\s+bugs.bug_id//so;
        # Recreate views
        $dbh->do('DROP VIEW IF EXISTS view$'.$user.'$'.$query.'$longdescs');
        $dbh->do('DROP VIEW IF EXISTS view$'.$user.'$'.$query.'$bugs_activity');
        $dbh->do('DROP VIEW IF EXISTS view$'.$user.'$'.$query.'$scrum_cards');
        $dbh->do('DROP VIEW IF EXISTS view$'.$user.'$'.$query.'$bugs');
        $dbh->do('CREATE '.($dbh->isa('Bugzilla::DB::Mysql') ? 'SQL SECURITY DEFINER' : '').' VIEW view$'.$user.'$'.$query.'$bugs AS '.$sqlquery);
        $dbh->do('CREATE '.($dbh->isa('Bugzilla::DB::Mysql') ? 'SQL SECURITY DEFINER' : '').' VIEW view$'.$user.'$'.$query.'$longdescs AS SELECT l.bug_id, u.login_name, l.bug_when, l.thetext, l.work_time FROM longdescs l INNER JOIN view$'.$user.'$'.$query.'$bugs b ON b.bug_id=l.bug_id INNER JOIN profiles u ON u.userid=l.who'.($userobj->is_insider?'':' WHERE l.isprivate=0'));
        $dbh->do('CREATE '.($dbh->isa('Bugzilla::DB::Mysql') ? 'SQL SECURITY DEFINER' : '').' VIEW view$'.$user.'$'.$query.'$bugs_activity AS SELECT a.bug_id, u.login_name, a.bug_when, f.name field_name, a.removed, a.added FROM bugs_activity a INNER JOIN view$'.$user.'$'.$query.'$bugs b ON b.bug_id=a.bug_id INNER JOIN profiles u ON u.userid=a.who INNER JOIN fielddefs f ON f.id=a.fieldid');
        $dbh->do('CREATE '.($dbh->isa('Bugzilla::DB::Mysql') ? 'SQL SECURITY DEFINER' : '').' VIEW view$'.$user.'$'.$query.'$scrum_cards AS SELECT s.* FROM scrum_cards s INNER JOIN view$'.$user.'$'.$query.'$bugs b ON b.bug_id=s.bug_id');
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

1;
__END__
