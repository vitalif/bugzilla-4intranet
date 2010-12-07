use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Very simple test script to test if bug creation with minimal data
# passes successfully for different user privileges.
#
# More elaborate tests exist in other scripts. This doesn't mean this
# one could not be improved a bit.

my @kill_bugs;

foreach my $user (qw(admin unprivileged canconfirm)) {
    log_in($sel, $config, $user);
    file_bug_in_product($sel, "TestProduct");
    $sel->type_ok("short_desc", "Bug created by Selenium",
                  "Enter bug summary");
    $sel->type_ok("comment", "--- Bug created by Selenium ---",
                  "Enter bug description");
    $sel->click_ok("commit", undef, "Submit bug data to post_bug.cgi");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_like(qr/Bug \d+ Submitted/, "Bug created");
    push @kill_bugs, $sel->get_value('//input[@name="id" and @type="hidden"]');
    logout($sel);
}

log_in($sel, $config, 'admin');
delete_bugs($sel, $config, \@kill_bugs);
logout($sel);
