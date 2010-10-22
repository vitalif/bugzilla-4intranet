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
    my ($users) = @_;
    my %u = ( map { $_ => 1 } @{ $users || [] } );
    my $dbh = Bugzilla->dbh;
    my $r = $dbh->selectcol_arrayref('SHOW TABLES LIKE \'view$%$bugs\'');
    for (@$r)
    {
        my (undef, $user, $query) = split /\$/, $_, -1;
        !%u || $u{$user} or next;
        my ($userid) = $dbh->selectrow_array('SELECT userid FROM profiles WHERE login_name LIKE ? ORDER BY userid LIMIT 1', undef, $user.'@%');
        $userid or next;
        my $userobj = Bugzilla::User->new($userid) or next;
        my $q = $query;
        $q =~ tr/_/ /;
        my $storedquery = Bugzilla::Search::LookupNamedQuery($q, $userid, undef, 0) or next;
        my $cgi = new Bugzilla::CGI($storedquery);
        my $search = new Bugzilla::Search(
            params => $cgi,
            fields => [ 'bug_id', grep { $_ ne 'bug_id' } split /[ ,]+/, $cgi->param('columnlist') ],
            user   => $userobj,
        ) or next;
        my $sqlquery = $search->getSQL();
        $sqlquery =~ s/ORDER\s+BY\s+`?bugs`?.`?bug_id`?//so;
        $dbh->do('DROP VIEW IF EXISTS `view$'.$user.'$'.$query.'$bugs`');
        $dbh->do('DROP VIEW IF EXISTS `view$'.$user.'$'.$query.'$longdescs`');
        $dbh->do('DROP VIEW IF EXISTS `view$'.$user.'$'.$query.'$bugs_activity`');
        $dbh->do('DROP VIEW IF EXISTS `view$'.$user.'$'.$query.'$scrum_cards`');
        $dbh->do('CREATE SQL SECURITY DEFINER VIEW `view$'.$user.'$'.$query.'$bugs` AS '.$sqlquery);
        $dbh->do('CREATE SQL SECURITY DEFINER VIEW `view$'.$user.'$'.$query.'$longdescs` AS SELECT l.bug_id, u.login_name, l.bug_when, l.thetext, l.work_time FROM longdescs l INNER JOIN `view$'.$user.'$'.$query.'$bugs` b ON b.bug_id=l.bug_id INNER JOIN profiles u ON u.userid=l.who'.($userobj->is_insider?'':' WHERE l.isprivate=0'));
        $dbh->do('CREATE SQL SECURITY DEFINER VIEW `view$'.$user.'$'.$query.'$bugs_activity` AS SELECT a.bug_id, u.login_name, a.bug_when, f.name field_name, a.removed, a.added FROM bugs_activity a INNER JOIN `view$'.$user.'$'.$query.'$bugs` b ON b.bug_id=a.bug_id INNER JOIN profiles u ON u.userid=a.who INNER JOIN fielddefs f ON f.id=a.fieldid');
        $dbh->do('CREATE SQL SECURITY DEFINER VIEW `view$'.$user.'$'.$query.'$scrum_cards` AS SELECT s.* FROM scrum_cards s INNER JOIN `view$'.$user.'$'.$query.'$bugs` b ON b.bug_id=s.bug_id');
    }
}

# hooks:
sub savedsearch_post_update
{
    my ($args) = @_;
    my $name = $args->{search}->user->login;
    $name =~ s/\@.*$//so;
    refresh_views([ $name ]);
    return 1;
}

1;
__END__
