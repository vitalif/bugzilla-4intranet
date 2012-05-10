#!/usr/bin/perl
# Feature not-so-useful for average Bugzilla installation:
# Allows to redirect certain users to another Bugzilla url.
# Mostly useful when you have several Bugzilla frontends which
# share one database, with different parameters.

package CustisLocalBugzillas;

use strict;

## Hook function

# Redirect users to "their" bugzillas according to params.login_urlbase_redirects
sub auth_post_login
{
    my ($args) = @_;
    my $user = $args->{user};
    if ($user->settings->{redirect_me_to_my_bugzilla} &&
        lc($user->settings->{redirect_me_to_my_bugzilla}->{value}) eq "on")
    {
        my $fullurl = Bugzilla->cgi->url();
        foreach (local_urlbase())
        {
            my ($re, $url) = @$_;
            if ($user->login =~ /$re/s &&
                $fullurl !~ /\Q$url\E/s)
            {
                my $relativeurl = Bugzilla->cgi->url(
                    -path_info => 1,
                    -query     => 1,
                    -relative  => 1
                );
                $url .= $relativeurl;
                print Bugzilla->cgi->redirect(-location => $url);
                exit;
            }
        }
    }
    return 1;
}

my ($local_urlbase, $local_urlbase_cached);

# Returns array [[login_regexp,urlbase],...]
sub local_urlbase
{
    if (!$local_urlbase || $local_urlbase_cached < Bugzilla->params_modified)
    {
        $local_urlbase = [];
        $local_urlbase_cached = Bugzilla->params_modified;
        my @base = split /\n/, Bugzilla->params->{login_urlbase_redirects};
        for (@base)
        {
            s/^\s+//so;
            s/\s+$//so;
            my ($login_regexp, $urlbase) = split /\s+/, $_, 2;
            if ($login_regexp && $urlbase)
            {
                push @$local_urlbase, [ qr/$login_regexp/s, $urlbase ];
            }
        }
    }
    return @$local_urlbase;
}

# Urlbase for Bugzilla::Util::correct_urlbase
our $HackIntoCorrectUrlbase = undef;
my $oldurlbase;

sub HackIntoUrlbase
{
    my ($userlogin) = @_;
    $HackIntoCorrectUrlbase = undef;
    unless ($userlogin)
    {
        Bugzilla->params->{urlbase} = $oldurlbase if $oldurlbase;
        return $HackIntoCorrectUrlbase;
    }
    foreach (local_urlbase())
    {
        my ($re, $url) = @$_;
        if ($userlogin =~ /$re/s)
        {
            $HackIntoCorrectUrlbase = $url;
            last;
        }
    }
    if ($HackIntoCorrectUrlbase)
    {
        $oldurlbase = Bugzilla->params->{urlbase};
        Bugzilla->params->{urlbase} = $HackIntoCorrectUrlbase;
    }
    else
    {
        $oldurlbase = undef;
    }
    return $HackIntoCorrectUrlbase;
}

1;
__END__
