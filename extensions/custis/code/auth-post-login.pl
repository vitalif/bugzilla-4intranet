#!/usr/bin/perl

use strict;
use Bugzilla::Util qw(trim);
use CustisLocalBugzillas;

my $user = Bugzilla->hook_args->{user};
if ($user->settings->{redirect_me_to_my_bugzilla} &&
    lc($user->settings->{redirect_me_to_my_bugzilla}->{value}) eq "on")
{
    my $loc = \%CustisLocalBugzillas::local_urlbase;
    my $fullurl = Bugzilla->cgi->url();
    foreach my $regemail (keys %$loc)
    {
        if ($user->login =~ /$regemail/s &&
            $fullurl !~ /\Q$loc->{$regemail}->{urlbase}\E/s)
        {
            my $relativeurl = Bugzilla->cgi->url(
                -path_info => 1,
                -query     => 1,
                -relative  => 1
            );
            my $url = $loc->{$regemail}->{urlbase} . $relativeurl;
            print Bugzilla->cgi->redirect(-location => $url);
            exit;
        }
    }
}
