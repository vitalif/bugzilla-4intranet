#########################################
# Test for xmlrpc call to Bug.history() #
#########################################

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
    isa_ok($call->result->{bugs}->[0]->{history}, 'ARRAY', "Bug's history");
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => STANDARD_BUG_TESTS,
                       method => 'Bug.history', post_success => \&post_success);
}
