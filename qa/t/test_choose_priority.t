use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

log_in($sel, $config, 'admin');
set_parameters($sel, { "Bug Change Policies" => {"letsubmitterchoosepriority-off" => undef} });
file_bug_in_product($sel, "TestProduct");
ok(!$sel->is_text_present("Priority"), "The Priority label is not present");
ok(!$sel->is_element_present("//select[\@name='priority']"), "The Priority drop-down menu is not present");
set_parameters($sel, { "Bug Change Policies" => {"letsubmitterchoosepriority-on" => undef} });
file_bug_in_product($sel, "TestProduct");
$sel->is_text_present_ok("Priority");
$sel->is_element_present_ok("//select[\@name='priority']");
logout($sel);
