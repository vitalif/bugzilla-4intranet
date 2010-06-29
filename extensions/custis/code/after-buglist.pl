#!/usr/bin/perl

use strict;
use Bugzilla::Util qw(trim);
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
my $vars = Bugzilla->hook_args->{vars};
if ($cgi->param('format') eq 'scrum')
{
    my $s = $vars->{scrum_select} = $cgi->param('scrum_select');
    if ($s)
    {
        my ($sprint) = $cgi->param('scrum_sprint') =~ /^(.*)$/so;
        $vars->{scrum_sprint} = $sprint;
        my ($type) = $cgi->param('scrum_type') =~ /^(.*)$/so;
        $vars->{scrum_type} = $type;
        my $e = Bugzilla->dbh->selectall_arrayref(
            'SELECT bug_id, estimate FROM scrum_cards WHERE bug_id IN ('.
            join(',', ('?') x @{$vars->{buglist}}) . ') AND sprint=? AND type=?',
            undef, @{$vars->{buglist}}, $sprint, $type
        );
        $vars->{scrum_estimates} = { map { @$_ } @$e };
    }
}
