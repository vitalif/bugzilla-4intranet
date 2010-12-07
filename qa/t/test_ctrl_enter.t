use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

log_in($sel, $config, 'admin');
file_bug_in_product($sel, 'TestProduct');
$sel->type_ok("short_desc", "Aries");
$sel->type_ok("comment", "1st constellation");
$sel->control_key_down;
$sel->key_press("comment", "\\13");
$sel->control_key_up;
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug \d+ Submitted/);
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');

$sel->type_ok('quicksearch_top', $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/, "Display bug $bug1_id");
$sel->type_ok("comment_textarea", "I did some work"); # CustIS s/comment/comment_textarea/
$sel->control_key_down;
$sel->key_press("comment_textarea", "\\13");
$sel->control_key_up;
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed");

delete_bugs($sel, $config, [$bug1_id]);
