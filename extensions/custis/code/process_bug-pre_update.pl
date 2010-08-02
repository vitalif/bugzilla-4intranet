#!/usr/bin/perl

use strict;
use Bugzilla::Util qw(trim);
use Bugzilla::Error;

my $bugs = Bugzilla->hook_args->{bugs};
my $st = [];
foreach my $bug (@$bugs)
{
    my $old = Bugzilla::Bug->new({ id => $bug->id });
    my $nok = {};
    if ($bug->product eq 'TN-RMS' &&
        $old->{bug_status} ne 'CLOSED' && $bug->{bug_status} eq 'CLOSED')
    {
        $nok->{s} = 1 if $bug->{cf_sprint} =~ /^\s*$/so;
        $nok->{w} = 1 if $bug->{status_whiteboard} =~ /^\s*$/so;
        $nok->{a} = 1 if $bug->{cf_agreement} =~ /^[\s-]*$/so;
    }
    elsif (($bug->product eq 'NewPlatform' && $bug->component ne 'components' && $bug->component ne 'misc' || $bug->product eq 'CIS-Forms') &&
        $old->{bug_status} ne 'ASSIGNED' && $bug->{bug_status} eq 'ASSIGNED')
    {
        $nok->{s} = 1 if $bug->{cf_sprint} =~ /^\s*$/so;
    }
    if (%$nok)
    {
        $nok->{bug} = $bug;
        push @$st, $nok;
    }
}
if (@$st)
{
    ThrowUserError('rms_fields_empty', { not_ok_bugs => $st });
}
