#!/usr/bin/perl
# Для перенаправления в свою багзиллу

package Bugzilla::CustisLocalBugzillas;

use strict;

our %localizer = (
    '[^\@]+\@custis\.ru'    => "http://bugs.office.custis.ru/bugs/",
    '[^\@]+\@(sportmaster\.ru|ilion\.ru|sportmaster\.com\.ua|scn\.ru|mbr\.ru|ilion\.ru|vek\.ru|bis\.overta\.ru)' => "http://penguin.office.custis.ru/bugzilla/",
    '[^\@]+\@(sobin\.ru)'   => "http://sobin.office.custis.ru/sbbugs/",
    '[^\@]+\@(yandex\.ru)'  => "http://wws-fomin.office.custis.ru/bugzilla/",
    '[^\@]+\@(hrendel\.ru)' => "http://ws-fomin.office.custis.ru/bugzilla/",
);

sub CorrectLinksToLocalBugzilla
{
    my ($userlogin, $msg) = (@_);
    foreach my $regemail1 (keys %localizer)
    {
        if ($userlogin =~ /$regemail1/s)
        {
            foreach my $regemail2 (keys %localizer)
            {
                if ($userlogin !~ /$regemail2/s)
                {
                    $msg =~ s/\Q$localizer{$regemail2}\E/$localizer{$regemail1}/gs;
                }
            }
        }
    }
    return $msg;
}

1;
__END__
