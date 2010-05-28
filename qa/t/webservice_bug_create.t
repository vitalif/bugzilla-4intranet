########################################
# Test for xmlrpc call to Bug.create() #
########################################

use strict;
use warnings;
use lib qw(lib);
use Test::More tests => 172;
use QA::Util;
use QA::Tests qw(create_bug_fields);

my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

########################
# Bug.create() testing #
########################

my $bug_fields = create_bug_fields($config);

# hash to contain all the possible $bug_fields values that
# can be passed to createBug()
my $fields = {
    summary => {
        undefined => {
            faultstring => 'You must enter a summary for this bug',
            value       => undef
        },
    },

    product => {
        undefined => { faultstring => 'You must select/enter a product.', value => undef },
        invalid =>
            { faultstring => 'does not exist', value => 'does-not-exist' },
    },

    component => {
        undefined => {
            faultstring => 'you must first choose a component',
            value       => undef
        },
        invalid => {
            faultstring => "There is no component named 'does-not-exist'",
            value => 'does-not-exist'
        },
    },

    version => {
        undefined =>
            { faultstring => 'You must select/enter a version.', value => undef },
        invalid => {
            faultstring => "There is no version named 'does-not-exist' in the 'TestProduct' product.",
            value       => 'does-not-exist'
        },
    },
    platform => {
        undefined =>
            { faultstring => 'You must select/enter a Hardware.', 
              value => '' },
        invalid => {
            faultstring => "There is no Hardware named 'does-not-exist'.",
            value       => 'does-not-exist'
        },
    },

    status => {
        invalid => {
            faultstring => "There is no status named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },

    severity => {
        undefined =>
            { faultstring => 'You must select/enter a Severity.', 
              value => '' },
        invalid => {
            faultstring => "There is no Severity named 'does-not-exist'.",
            value       => 'does-not-exist'
        },
    },

    priority => {
        undefined =>
            { faultstring => 'You must select/enter a Priority.', 
              value => '' },
        invalid => {
            faultstring => "There is no Priority named 'does-not-exist'.",
            value       => 'does-not-exist'
        },
    },

    op_sys => {
        undefined => {
            faultstring => 'You must select/enter a OS.',
            value       => ''
        },
        invalid => {
            faultstring => "There is no OS named 'does-not-exist'.",
            value       => 'does-not-exist'
        },
    },

    cc => {
        invalid => {
            faultstring => 'not a valid username',
            value       => ['nonuserATbugillaDOTorg']
        },
    },

    assigned_to => {
        invalid => {
            faultstring => "There is no user named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },
    qa_contact => {
        invalid => {
            faultstring => "There is no user named 'does-not-exist'",
            value       => 'does-not-exist'
        },
    },
    alias => {
        long => {
            faultstring => 'Bug aliases cannot be longer than 20 characters',
            value       => 'MyyyyyyyyyyyyyyyyyyBugggggggggggggggggggggg'
        },
        existing => {
            faultstring => 'already taken the alias',
            value       => 'public_bug'
        },
        numeric => {
            faultstring => 'aliases cannot be merely numbers',
            value       => '12345'
        },
        commma_or_space_separated => {
            faultstring => 'contains one or more commas or spaces',
            value       => 'Bug 12345'
        },

    },
};

foreach my $rpc ($jsonrpc, $xmlrpc) {
    # test calling Bug.create without logging into bugzilla
    my $create_call = $rpc->bz_call_fail('Bug.create', $bug_fields,
        'You must log in', 'Cannot file bugs as logged-out user');

    $rpc->bz_log_in('editbugs');

    # run the tests for all the invalid values that can be passed 
    # to Bug.create()
    foreach my $f (sort keys %{$fields}) {
        foreach my $val (sort keys %{$fields->{$f}}) {
            my %bug_fields_hash = %$bug_fields;
            my $bug_fields_copy = \%bug_fields_hash;
            $bug_fields_copy->{$f} = $fields->{$f}->{$val}->{value};
            my $expected_faultstring = $fields->{$f}->{$val}->{faultstring};

            my $fail_call = $rpc->bz_call_fail('Bug.create', $bug_fields_copy, 
                $expected_faultstring, "Specifying $val $f fails");
        }
    }

    # after the loop ends all the $bug_fields value will be set to valid
    # this is done by the sort so call create bug with the valid $bug_fields
    # to run the test for the successful creation of the bug
    my $success_create = $rpc->bz_call_success('Bug.create', $bug_fields);
    my $bug_id = $success_create->result->{id};
    cmp_ok($bug_id, 'gt', 0,
           "Created new bug with id " . $success_create->result->{id});

    # Make sure that the bug that we created has the field values we specified.
    my $bug_result = $rpc->bz_call_success('Bug.get', { ids => [$bug_id] });
    my $bug = $bug_result->result->{bugs}->[0];
    isa_ok($bug, 'HASH', "Bug $bug_id");
    # We have to limit the fields checked because Bug.get only returns certain 
    # fields.
    foreach my $field (qw(assigned_to component priority product severity 
                          status summary)) 
    {
        is($bug->{$field}, $bug_fields->{$field}, "$field has the right value");
    };

    $rpc->bz_call_success('User.logout');
}
