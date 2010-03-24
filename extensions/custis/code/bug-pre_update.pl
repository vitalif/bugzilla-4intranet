#!/usr/bin/perl

use strict;
use Bugzilla::Util qw(trim);
use Bugzilla::Error;

my $bug = Bugzilla->hook_args->{bug};
my $old = Bugzilla::Bug->new({ id => $bug->id });
my $nok = {};
if ($bug->product eq 'TN-RMS' && $old->{bug_status} ne 'CLOSED' &&
    $bug->{bug_status} eq 'CLOSED')
{
    $nok->{s} = 1 if $bug->{cf_sprint} =~ /^\s*$/so;
    $nok->{w} = 1 if $bug->{status_whiteboard} =~ /^\s*$/so;
    $nok->{a} = 1 if $bug->{cf_agreement} =~ /^[\s-]*$/so;
    if (%$nok)
    {
        ThrowUserError('rms_fields_empty', $nok);
    }
}
