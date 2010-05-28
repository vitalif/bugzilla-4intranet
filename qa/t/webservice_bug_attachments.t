use strict;
use warnings;
use lib qw(lib);
use QA::Util;
use QA::Tests qw(STANDARD_BUG_TESTS PRIVATE_BUG_USER);
use Data::Dumper;
use List::Util qw(first);
use Test::More tests => 208;
my ($xmlrpc, $jsonrpc, $config) = get_rpc_clients();

################
# Bug ID Tests #
################

our %attachments;

sub post_bug_success {
    my ($call, $t) = @_;
    my $bugs = $call->result->{bugs};
    is(scalar keys %$bugs, 1, "Got exactly one bug")
        or diag(Dumper($call->result));

    my $bug_attachments = (values %$bugs)[0];
    # Collect attachment ids
    foreach my $alias (qw(public_bug private_bug)) {
        foreach my $is_private (0, 1) {
            my $find_desc = "${alias}_${is_private}";
            my $attachment = first { $_->{description} eq $find_desc }
                                   @$bug_attachments;
            if ($attachment) {
                $attachments{$find_desc} = $attachment->{id};
            }
        }
    }
    
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(tests => STANDARD_BUG_TESTS, method => 'Bug.attachments',
                       post_success => \&post_bug_success);
}

foreach my $alias (qw(public_bug private_bug)) {
    foreach my $is_private (0, 1) {
        ok($attachments{"${alias}_${is_private}"},
           "Found attachment id for ${alias}_${is_private}");
    }
}

####################
# Attachment Tests #
####################

# Access tests for public/private stuff, and also validate that the
# format of each return value is correct.

my @tests = (
    # Logged-out user
    { args => { attachment_ids => [$attachments{'public_bug_0'}] },
      test => 'Logged-out user can access public attachment on public'
              . '  bug by id',
    },
    { args  => { attachment_ids => [$attachments{'public_bug_1'}] },
      test  => 'Logged-out user cannot access private attachment on public bug',
      error => 'Sorry, you are not authorized',
    },
    { args  => { attachment_ids => [$attachments{'private_bug_0'}] },
      test  => 'Logged-out user cannot access attachments by id on private bug',
      error => 'You are not authorized to access',
    },
    { args  => { attachment_ids => [$attachments{'private_bug_1'}] },
      test  => 'Logged-out user cannot access private attachment on '
               . ' private bug',
      error => 'You are not authorized to access',
    },

    # Logged-in, unprivileged user.
    { user => 'unprivileged',
      args => { attachment_ids => [$attachments{'public_bug_0'}] },
      test => 'Logged-in user can see a public attachment on a public bug by id',
    },
    { user  => 'unprivileged',
      args  => { attachment_ids => [$attachments{'public_bug_1'}] },
      test  => 'Logged-in user cannot access private attachment on public bug',
      error => 'Sorry, you are not authorized',
    },
    { user  => 'unprivileged',
      args  => { attachment_ids => [$attachments{'private_bug_0'}] },
      test  => 'Logged-in user cannot access attachments by id on private bug',
      error => "You are not authorized to access",
    },
    { user  => 'unprivileged',
      args  => { attachment_ids => [$attachments{'private_bug_1'}] },
      test  => 'Logged-in user cannot access private attachment on private bug',
      error => "You are not authorized to access",
    },

    # User who can see private bugs and private attachments
    { user => PRIVATE_BUG_USER,
      args => { attachment_ids => [$attachments{'public_bug_1'}] },
      test => PRIVATE_BUG_USER . ' can see private attachment on public bug',
    },
    { user  => PRIVATE_BUG_USER,
      args  => { attachment_ids => [$attachments{'private_bug_1'}] },
      test  => PRIVATE_BUG_USER . ' can see private attachment on private bug',
    },
);

sub post_success {
    my ($call, $t, $rpc) = @_;
    is(scalar keys %{ $call->result->{attachments} }, 1,
       "Got exactly one attachment");
    my $attachment = (values %{ $call->result->{attachments} })[0];

    cmp_ok($attachment->{last_change_time}, '=~', $rpc->DATETIME_REGEX,
           "last_change_time is in the right format");
    cmp_ok($attachment->{creation_time}, '=~', $rpc->DATETIME_REGEX,
           "creation_time is in the right format");
    is($attachment->{is_url}, 0, 'is_url is 0');
    is($attachment->{is_obsolete}, 0, 'is_obsolete is 0');
    cmp_ok($attachment->{bug_id}, '=~', qr/^\d+$/,
           "bug_id is an integer");
    cmp_ok($attachment->{id}, '=~', qr/^\d+$/,
           "id is an integer");
    is($attachment->{content_type}, 'application/x-perl',
       "content_type is correct");
    cmp_ok($attachment->{file_name}, '=~', qr/^\w+\.pl$/,
           "filename is in the expected format");
    is($attachment->{attacher}, $config->{QA_Selenium_TEST_user_login},
       "attacher is the correct user");
}

foreach my $rpc ($jsonrpc, $xmlrpc) {
    $rpc->bz_run_tests(method => 'Bug.attachments', tests => \@tests,
                       post_success => \&post_success);
}
