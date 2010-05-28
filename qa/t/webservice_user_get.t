######################################
# Test for xmlrpc call to User.get() #
######################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More tests => 82;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

my $get_user = $config->{unprivileged_user_login};

# These are the basic tests. There are tests for include_fields 
# and exclude_field below.

my @tests = (
    { args => { names => [$get_user] },
      test => "Logged-out user can get unprivileged user by name"
    },
    { args  => { match => [$get_user] },
      test  => 'Logged-out user cannot use the match argument',
      error => 'Logged-out users cannot use',
    },
    { args  => { ids => [1] },
      test  => 'Logged-out users cannot use the "ids" argument',
      error => 'Logged-out users cannot use',
    },

    { user => 'unprivileged',
      args => { names => [$get_user] },
      test => "Unprivileged user can get himself",
    },
    { user => 'unprivileged',
      args => { match => [$get_user] },
      test => 'Logged-in user can use the match argument',
    },
    { user => 'unprivileged',
      args => { match => [$get_user], names => [$get_user] },
      test => 'Specifying the same thing in "match" and "names"',
    },

    { user => 'admin',
      args => { names => [$get_user] },
      test => 'Admin can get user',
    },
);

sub post_success {
    my ($call, $t) = @_;

    my $result = $call->result;
    is(scalar @{ $result->{users} }, 1, "Got exactly one user");
    my $item = $result->{users}->[0];

    if ($t->{user} && $t->{user} eq 'admin') {
        ok(exists $item->{email} && exists $item->{can_login}
           && exists $item->{email_enabled} && exists $item->{login_denied_text},
           'Admin correctly gets all user fields');
    }
    elsif ($t->{user}) {
        ok(exists $item->{email} && exists $item->{can_login},
           'Logged-in user correctly gets email and can_login');
        ok(!exists $item->{email_enabled} 
           && !exists $item->{login_denied_text},
           "Non-admin user doesn't get email_enabled and login_denied_text");
    }
    else {
        my @item_keys = sort keys %$item;
        is_deeply(\@item_keys, ['id', 'name', 'real_name'],
            'Only id, name, and real_name are returned to logged-out users');
    }
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => \@tests, method => 'User.get', 
                       post_success => \&post_success);

    #############################
    # Include and Exclude Tests #
    #############################

    my $include_nothing = $rpc->bz_call_success('User.get', {
        names => [$get_user], include_fields => ['asdfasdfsdf'],
    }, 'User.get including only invalid fields'); 
    is(scalar keys %{ $include_nothing->result->{users}->[0] }, 0, 
       'No fields returned for user');
    
    my $include_one = $rpc->bz_call_success('User.get', {
        names => [$get_user], include_fields => ['id'],
    }, 'User.get including only id');
    is(scalar keys %{ $include_one->result->{users}->[0] }, 1,
       'Only one field returned for user');
    
    my $exclude_none = $rpc->bz_call_success('User.get', {
        names => [$get_user], exclude_fields => ['asdfasdfsdf'],
    }, 'User.get excluding only invalid fields');
    is(scalar keys %{ $exclude_none->result->{users}->[0] }, 3,
       'All fields returned for user');
    
    my $exclude_one = $rpc->bz_call_success('User.get', {
        names => [$get_user], exclude_fields => ['id'],
    }, 'User.get excluding id');
    is(scalar keys %{ $exclude_one->result->{users}->[0] }, 2,
       'Only two fields returned for user');
    
    my $override = $rpc->bz_call_success('User.get', {
        names => [$get_user], include_fields => ['id', 'name'],
        exclude_fields => ['id']
    }, 'User.get with both include and exclude');
    is(scalar keys %{ $override->result->{users}->[0] }, 1,
       'Only one field returned');
    ok(exists $override->result->{users}->[0]->{name},
       '...and that field is the "name" field');
}
