##########################################################
# Test for xmlrpc call to User.login() and User.logout() #
##########################################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More tests => 42;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

use constant INVALID_EMAIL => '@invalid_user@';

my $user = $config->{unprivileged_user_login};
my $pass = $config->{unprivileged_user_passwd};
my $error = "The username or password you entered is not valid";

my @tests = (
    { user => 'unprivileged',
      test => "Unprivileged user can log in successfully",
    },

    { args  => { login => $user, password => '' },
      error => $error,
      test  => "Empty password can't log in",
    },
    { args  => { login => '', password => $pass },
      error => $error,
      test  => "Empty login can't log in",
    },

    { args  => { login => INVALID_EMAIL, password => $pass },
      error => $error,
      test  => "Invalid email can't log in",
    },
    { args  => { login => $user, password => '*' },
      error => $error,
      test  => "Invalid password can't log in",
    },

    { args  => { login    => $config->{disabled_user_login}, 
                 password => $config->{disabled_user_passwd} },
      error => "!!This is the text!!",
      test  => "Can't log in with a disabled account",
    },
    { args  => { login => $config->{disabled_user_login}, password => '*' },
      error => $error,
      test  => "Logging in with invalid password doesn't show disabledtext",
    },
);

foreach my $rpc ($jsonrpc, $xmlrpc) {
    for my $t (@tests) {
        if ($t->{user}) {
            $rpc->bz_log_in($t->{user});
            $rpc->bz_call_success('User.logout');
        }
        else {
            $rpc->bz_call_fail('User.login', $t->{args}, $t->{error}, $t->{test});
        }
    }
}
