#!/usr/bin/perl
# ��� ��������������� � ���� ��������

package Bugzilla::CustisLocalBugzillas;

use strict;

our %local_urlbase = (
    '[^\@]+\@custis\.ru'    => {
        # ����� ����������� �� ���������� � ���������� ��������
        urlbase => "http://bugs.office.custis.ru/bugs/",
    },
    '[^\@]+\@(sportmaster\.ru|ilion\.ru|sportmaster\.com\.ua|scn\.ru|mbr\.ru|ilion\.ru|vek\.ru|bis\.overta\.ru)' => {
        force   => 1,
        urlbase => "http://penguin.office.custis.ru/bugzilla/",
    },
    '[^\@]+\@(sobin\.ru)'   => {
        force   => 1,
        urlbase => "http://sobin.office.custis.ru/sbbugs/",
    },
);

# Urlbase, �������������� �������� Bugzilla::Util::correct_urlbase
our $HackIntoCorrectUrlbase = undef;
my $oldurlbase;

sub HackIntoUrlbase
{
    my ($userlogin) = @_;
    unless ($userlogin)
    {
        Bugzilla->params->{urlbase} = $oldurlbase if $oldurlbase;
        return $HackIntoCorrectUrlbase = undef;
    }
    foreach (keys %local_urlbase)
    {
        if ($userlogin =~ /$_/s && $local_urlbase{$_}{force})
        {
            $HackIntoCorrectUrlbase = $local_urlbase{$_}{urlbase};
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
