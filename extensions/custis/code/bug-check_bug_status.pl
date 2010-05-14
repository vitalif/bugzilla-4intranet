#!/usr/bin/perl

use strict;
use Bugzilla::Util qw(trim);
use Bugzilla::Error;

my $a = Bugzilla->hook_args;
my $nok = {};
if ($a->{bug} && $a->{bug}->product eq 'TN-RMS' &&
    $a->{old_status}->name ne 'CLOSED' && $a->{new_status}->name eq 'CLOSED')
{
    $nok->{s} = 1 if $a->{bug}->{cf_sprint} =~ /^\s*$/so;
    $nok->{w} = 1 if $a->{bug}->{status_whiteboard} =~ /^\s*$/so;
    $nok->{a} = 1 if $a->{bug}->{cf_agreement} =~ /^[\s-]*$/so;
    if (%$nok)
    {
        ThrowUserError('rms_fields_empty', $nok);
    }
}
