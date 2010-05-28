###########################################
# Test for xmlrpc call to Bug.get_bugs()  #
###########################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use QA::Tests qw(STANDARD_BUG_TESTS);
use Test::More tests => 78;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

sub post_success {
    my ($call, $t) = @_;

    is(scalar @{ $call->result->{bugs} }, 1, "Got exactly one bug");
    if ($t->{user} && $t->{user} eq 'admin') {
        ok(exists $call->result->{bugs}->[0]->{internals}{estimated_time}
           && exists $call->result->{bugs}->[0]->{internals}{remaining_time}
           && exists $call->result->{bugs}->[0]->{internals}{deadline},
           'Admin correctly gets time-tracking fields');
    }
    else {
        ok(!exists $call->result->{bugs}->[0]->{internals}{estimated_time}
           && !exists $call->result->{bugs}->[0]->{internals}{remaining_time}
           && !exists $call->result->{bugs}->[0]->{internals}{deadline},
           'Time-tracking fields are not returned to logged-out users');
    }
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => STANDARD_BUG_TESTS,
                       method => 'Bug.get', post_success => \&post_success);
}
