##########################################
# Test for xmlrpc call to Bug.comments() #
##########################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use QA::Tests qw(STANDARD_BUG_TESTS PRIVATE_BUG_USER);
use Test::More tests => 138;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

################
# Bug ID Tests #
################

sub post_bug_success {
    my ($call, $t) = @_;
    is(scalar keys %{ $call->result->{bugs} }, 1, "Got exactly one bug");
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => STANDARD_BUG_TESTS, method => 'Bug.comments',
                       post_success => \&post_bug_success);
}

####################
# Comment ID Tests #
####################

# First, create comments using add_comment.

our %comments = (
    public_comment_public_bug  => 0,
    public_comment_private_bug  => 0,
    private_comment_public_bug  => 0,
    private_comment_private_bug => 0,
);

my @add_comment_tests;

foreach my $key (keys %comments) {
    $key =~ /^([a-z]+)_comment_(\w+)$/;
    my $is_private = ($1 eq 'private' ? 1 : 0);
    my $bug_alias = $2;
    push(@add_comment_tests, { args => { id => $bug_alias, comment => $key,
                                         private => $is_private },
                               test => "Add comment: $key",
                               user => PRIVATE_BUG_USER });
}

# Set the comment id for each comment that we add, so we can test getting
# them back, later.
sub post_add {
    my ($call, $t) = @_;
    my $key = $t->{args}->{comment};
    $comments{$key} = $call->result->{id};
}


foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => \@add_comment_tests,
                       method => 'Bug.add_comment', post_success => \&post_add);
}

# Now check access on each private and public comment

my @comment_tests = (
    # Logged-out user
    { args => { comment_ids => [$comments{'public_comment_public_bug'}] },
      test => 'Logged-out user can access public comment on public bug by id',
    },
    { args  => { comment_ids => [$comments{'private_comment_public_bug'}] },
      test  => 'Logged-out user cannot access private comment on public bug',
      error => 'is private',
    },
    { args  => { comment_ids => [$comments{'public_comment_private_bug'}] },
      test  => 'Logged-out user cannot access comments by id on private bug',
      error => 'You are not authorized to access',
    },
    { args  => { comment_ids => [$comments{'private_comment_private_bug'}] },
      test  => 'Logged-out user cannot access private comment on private bug',
      error => 'You are not authorized to access',
    },

    # Logged-in, unprivileged user.
    { user => 'unprivileged',
      args => { comment_ids => [$comments{'public_comment_public_bug'}] },
      test => 'Logged-in user can see a public comment on a public bug by id',
    },
    { user  => 'unprivileged',
      args  => { comment_ids => [$comments{'private_comment_public_bug'}] },
      test  => 'Logged-in user cannot access private comment on public bug',
      error => 'is private',
    },
    { user  => 'unprivileged',
      args  => { comment_ids => [$comments{'public_comment_private_bug'}] },
      test  => 'Logged-in user cannot access comments by id on private bug',
      error => "You are not authorized to access",
    },
    { user  => 'unprivileged',
      args  => { comment_ids => [$comments{'private_comment_private_bug'}] },
      test  => 'Logged-in user cannot access private comment on private bug',
      error => "You are not authorized to access",
    },

    # User who can see private bugs and private comments
    { user => PRIVATE_BUG_USER,
      args => { comment_ids => [$comments{'private_comment_public_bug'}] },
      test => PRIVATE_BUG_USER . ' can see private comment on public bug',
    },
    { user  => PRIVATE_BUG_USER,
      args  => { comment_ids => [$comments{'private_comment_private_bug'}] },
      test  => PRIVATE_BUG_USER . ' can see private comment on private bug',
    },
);

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => \@comment_tests, method => 'Bug.comments');
}
