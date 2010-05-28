#########################################################
# Test for xmlrpc call to User.offer_account_by_email() #
#########################################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More tests => 26;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

# These are the characters that are actually invalid per RFC.
use constant INVALID_EMAIL => '()[]\;:,<>@webservice.test';

sub new_login {
    return 'requested_' . random_string() . '@webservice.test';
}

# Have to wrap @tests in the foreach so that new_login returns something
# different each time.
foreach my $rpc ($jsonrpc, $xmlrpc) {
    my @tests = (
        # Login name checks.
        { args  => { },
          error => "argument was not set",
          test  => 'Leaving out email argument fails',
        },
        { args  => { email => '' },
          error => "argument was not set",
          test  => "Passing an empty email argument fails",
        },
        { args  => { email => INVALID_EMAIL },
          error => "didn't pass our syntax checking",
          test  => 'Invalid email address fails',
        },
        { args  => { email => $config->{unprivileged_user_login} },
          error => "There is already an account",
          test  => 'Trying to use an existing login name fails',
        },
    
        { args => { email => new_login() },
          test => 'Valid, non-existing email passes.', 
        },
    );
    
    $rpc->bz_run_tests(tests => \@tests,
                       method => 'User.offer_account_by_email');
}
