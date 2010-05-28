# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::Tests;
use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(
    PRIVATE_BUG_USER
    STANDARD_BUG_TESTS
    create_bug_fields
);

use constant INVALID_BUG_ID => -1;
use constant INVALID_BUG_ALIAS => 'aaaaaaa12345';
use constant PRIVATE_BUG_USER => 'QA_Selenium_TEST';

use constant CREATE_BUG => {
    'priority'     => 'Highest',
    'status'       => 'NEW',
    'version'      => 'unspecified',
    'reporter'     => 'editbugs',
    'bug_file_loc' => '',
    'description'  => '-- Comment Created By Bugzilla XML-RPC Tests --',
    'cc'           => ['unprivileged'],
    'component'    => 'TestComponent',
    'platform'     => 'All',
    'assigned_to'  => 'editbugs',
    'summary'      => 'XML-RPC Test Bug',
    'product'      => 'TestProduct',
    'op_sys'       => 'Linux',
    'severity'     => 'normal',
    'qa_contact'   => 'canconfirm',
     url           => 'http://www.bugzilla.org/',
};

sub create_bug_fields {
    my ($config) = @_;
    my %bug = %{ CREATE_BUG() };
    foreach my $field (qw(reporter assigned_to qa_contact)) {
        my $value = $bug{$field};
        $bug{$field} = $config->{"${value}_user_login"};
    }
    $bug{cc} = [map { $config->{$_ . "_user_login"} } @{ $bug{cc} }];
    return \%bug;
}

use constant STANDARD_BUG_TESTS => [
    { args  => { ids => ['private_bug'] },
      error => "You are not authorized to access",
      test  => 'Logged-out user cannot access a private bug',
    },
    { args => { ids => ['public_bug'] },
      test => 'Logged-out user can access a public bug.',
    },
    { args  =>  { ids => [INVALID_BUG_ID] },
      error =>  "not a valid bug number",
      test  =>  'Passing invalid bug id returns error "Invalid Bug ID"',
    },
    { args  =>  { ids => [undef] },
      error => "You must enter a valid bug number",
      test  =>  'Passing undef as bug id param returns error "Invalid Bug ID"',
    },
    { args  => { ids => [INVALID_BUG_ALIAS] },
      error =>  "nor an alias to a bug",
      test  => 'Passing invalid bug alias returns error "Invalid Bug Alias"',
    },

    { user  =>  'unprivileged',
      args  =>  { ids => ['private_bug'] },
      error =>  "You are not authorized to access",
      test  => 'Access to a private bug is denied to a user without privs',
    },
    { user => 'unprivileged',
      args => { ids => ['public_bug'] },
      test => 'User without privs can access a public bug by alias.',
    },
    { user => 'admin',
      args => { ids => ['public_bug'] },
      test => 'Admin can access a public bug.',
    },
    { user => PRIVATE_BUG_USER,
      args => { ids => ['private_bug'] },
      test => 'User with privs can successfully access a private bug',
    },
    # This helps webservice_bug_attachment get private attachment ids
    # from the public bug, and doesn't hurt for the other tests.
    { user => PRIVATE_BUG_USER,
      args => { ids => ['public_bug'] },
      test => 'User with privs can also access the public bug',
    },
];

1;
