use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

my $test_bug_1 = $config->{test_bug_1};
my $test_bug_2 = $config->{test_bug_2};

# Turn on usestatuswhiteboard

log_in($sel, $config, 'admin');
set_parameters($sel, {'Bug Fields' => {'usestatuswhiteboard-on' => undef}});

# Make sure the status whiteboard is displayed and add stuff to it.

$sel->open_ok("/$config->{bugzilla_installation}/show_bug.cgi?id=$test_bug_1");
$sel->title_like(qr/^Bug $test_bug_1\b/);
$sel->is_text_present_ok("Whiteboard:");
$sel->type_ok("status_whiteboard", "[msg from test_status_whiteboard.t: x77v]");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $test_bug_1 processed");
$sel->open_ok("/$config->{bugzilla_installation}/show_bug.cgi?id=$test_bug_2");
$sel->title_like(qr/^Bug $test_bug_2\b/);
$sel->type_ok("status_whiteboard", "[msg from test_status_whiteboard.t: x77v]");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $test_bug_2 processed");

# Now search these bugs above using data being in the status whiteboard,
# and save the query.

open_advanced_search_page($sel);
$sel->remove_all_selections_ok("product");
$sel->remove_all_selections_ok("bug_status");
$sel->type_ok("status_whiteboard", "x77v");
$sel->click_ok("Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_text_present_ok("2 bugs found");
$sel->type_ok("save_newqueryname", "sw-x77v");
$sel->click_ok("remember");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search created");
my $text = trim($sel->get_text("message"));
ok($text =~ /you have a new search named sw-x77v/, 'Saved search correctly saved');

# Make sure the saved query works.

$sel->click_ok("link=sw-x77v");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List: sw-x77v");
$sel->is_text_present_ok("2 bugs found");

# The status whiteboard should no longer be displayed in both the query
# and bug view pages (query.cgi and show_bug.cgi) when usestatuswhiteboard
# is off.

set_parameters($sel, {'Bug Fields' => {'usestatuswhiteboard-off' => undef}});
$sel->click_ok("link=Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search for bugs");
ok(!$sel->is_text_present("Whiteboard:"), "Whiteboard label no longer displayed");
$sel->open_ok("/$config->{bugzilla_installation}/show_bug.cgi?id=$test_bug_1");
$sel->title_like(qr/^Bug $test_bug_1\b/);
ok(!$sel->is_text_present("Whiteboard:"), "Whiteboard label no longer displayed");

# Queries based on the status whiteboard should still work when
# the parameter is off.

$sel->click_ok("link=sw-x77v");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List: sw-x77v");
$sel->is_text_present_ok("2 bugs found");
$sel->click_ok("link=Forget Search 'sw-x77v'");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search is gone");
$sel->is_text_present_ok("OK, the sw-x77v search is gone.");

# Turn on usestatuswhiteboard again as some other scripts may expect the status
# whiteboard to be available by default.

set_parameters($sel, {'Bug Fields' => {'usestatuswhiteboard-on' => undef}});
logout($sel);
