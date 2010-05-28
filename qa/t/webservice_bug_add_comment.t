#############################################
# Test for xmlrpc call to Bug.add_comment() #
#############################################

use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use Test::More tests => 130;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

use constant INVALID_BUG_ID => -1;
use constant INVALID_BUG_ALIAS => 'aaaaaaa12345';
use constant PRIVS_USER => 'QA_Selenium_TEST';
use constant TIMETRACKING_USER => 'admin';

use constant TEST_COMMENT => '--- Test Comment From QA Tests ---';
use constant TOO_LONG_COMMENT => 'a' x 100000;

my @tests = (
    # Permissions
    { args  => { id => 'public_bug', comment => TEST_COMMENT },
      error => 'You must log in',
      test  => 'Logged-out user cannot comment on a public bug',
    },
    { args  => { id => 'private_bug', comment => TEST_COMMENT },
      error => "You must log in",
      test  => 'Logged-out user cannot comment on a private bug',
    },
    { user  => 'unprivileged',
      args  => { id => 'private_bug', comment => TEST_COMMENT },
      error => "not authorized to access",
      test  => "Unprivileged user can't comment on a private bug",
    },

    # Test ID parameter
    { user  => 'unprivileged',
      args  => { comment => TEST_COMMENT },
      error => 'a id argument',
      test  => 'Failing to pass the "id" param fails',
    },
    { user  => 'unprivileged',
      args  => { id => INVALID_BUG_ID, comment => TEST_COMMENT },
      error => "not a valid bug number",
      test  => 'Passing invalid bug id returns error "Invalid Bug ID"',
    },
    { user  => 'unprivileged',
      args  => { id => '', comment => TEST_COMMENT },
      error => "You must enter a valid bug number",
      test  => 'Passing empty bug id param returns error "Invalid Bug ID"',
    },
    { user  => 'unprivileged',
      args  => { id => INVALID_BUG_ALIAS, comment => TEST_COMMENT },
      error => "nor an alias to a bug",
      test  => 'Passing invalid bug alias returns error "Invalid Bug Alias"',
    },

    # Test Comment parameter
    { user  => 'unprivileged',
      args  => { id => 'public_bug' },
      error => 'a comment argument',
      test  => 'Failing to pass the "comment" parameter fails',
    },
    { user  => 'unprivileged',
      args  => { id => 'public_bug', comment => '' },
      error => "a comment argument",
      test  => 'Passing an empty comment fails',
    },
    { user  => 'unprivileged',
      args  => { id => 'public_bug', comment => ' ' },
      error => 'a comment argument',
      test  => 'Passing only a space for comment fails',
    },
    { user  => 'unprivileged',
      args  => { id => 'public_bug', comment => " \t\n\n\r\n\r\n\r " },
      error => 'a comment argument',
      test  => 'Passing only whitespace (including newlines) fails',
    },
    { user  => 'unprivileged',
      args  => { id => 'public_bug', comment => TOO_LONG_COMMENT },
      error => "cannot be longer than",
      test  => "Passing a comment that's too long fails",
    },

    # Testing the "private" parameter happens in the tests for Bug.comments

    # Test work_time parameter
    # XXX Should be testing permissions on the work_time parameter,
    # but we currently have no way to verify whether or not time was
    # added to the bug, and there's no error thrown if you lack perms.
    { user  => 'admin',
      args  => { id => 'public_bug', comment => TEST_COMMENT,
                 work_time => 'aaa' },
      error => "is not a numeric value",
      test  => "Passing a non-numeric work_time fails",
    },
    { user  => 'admin',
      args  => { id => 'public_bug', comment => TEST_COMMENT,
                 work_time => '1234567890' },
      error => 'more than the maximum',
      test  => 'Passing too large of a work_time fails',
    },
    { user  => 'admin',
      args  => { id => 'public_bug', comment => '',
                 work_time => '1.0' },
      error => 'a comment argument',
      test  => 'Passing a work_time with an empty comment fails',
    },

    # Success tests
    { user => 'unprivileged',
      args => { id => 'public_bug', comment => TEST_COMMENT },
      test => 'Unprivileged user can add a comment to a public bug',
    },
    { user => 'unprivileged',
      args => { id => 'public_bug', comment => " \n" . TEST_COMMENT },
      test => 'Can add a comment to a bug where the first line is whitespace',
    },
    { user => 'QA_Selenium_TEST',
      args => { id => 'private_bug', comment => TEST_COMMENT },
      test => 'Privileged user can add a comment to a private bug',
    },
    { user => 'admin',
      args => { id => 'public_bug', comment => TEST_COMMENT,
                work_time => '1.5' },
      test => 'Timetracking user can add work_time to a bug',
    },
    # XXX Need to verify that the comment added actually has work_time.
    { user => 'admin',
      args => { id => 'public_bug', comment => TEST_COMMENT,
                isprivate => 1 },
      test => 'Insidergroup user can add a private comment',
    },
    # XXX Need to verify that the comment added was actually private.
);

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => \@tests, method => 'Bug.add_comment');
}
