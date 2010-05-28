use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# 1st step: turn on usetargetmilestone, musthavemilestoneonaccept and letsubmitterchoosemilestone.

log_in($sel, $config, 'admin');
set_parameters($sel, {'Bug Fields'          => {'usetargetmilestone-on'          => undef},
                      'Bug Change Policies' => {'musthavemilestoneonaccept-on'   => undef,
                                                'letsubmitterchoosemilestone-on' => undef},
                     }
              );

# 2nd step: Add the milestone "2.0" (with sortkey = 10) to the TestProduct product.

edit_product($sel, "TestProduct");
$sel->click_ok("link=Edit milestones:", undef, "Go to the Edit milestones page");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Select milestone of product 'TestProduct'", "Display milestones");
$sel->click_ok("link=Add", undef, "Go add a new milestone");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Add Milestone to Product 'TestProduct'", "Enter new milestone");
$sel->type_ok("milestone", "2.0", "Set its name to 2.0");
$sel->type_ok("sortkey", "10", "Set its sortkey to 10");
$sel->click_ok("create", undef, "Submit data");
$sel->wait_for_page_to_load(WAIT_TIME);
# If the milestone already exists, that's not a big deal. So no special action
# is required in this case.
$sel->title_is("Milestone Created", "Milestone Created");

# 3rd step: file a new bug, leaving the milestone alone (should fall back to the default one).

file_bug_in_product($sel, "TestProduct");
$sel->selected_label_is("component", "TestComponent", "Component already selected (no other component defined)");
$sel->selected_label_is("target_milestone", "---", "Default milestone selected");
$sel->selected_label_is("version", "unspecified", "Version already selected (no other version defined)");
$sel->type_ok("short_desc", "Target Milestone left to default", "Enter bug summary");
$sel->type_ok("comment", "Created by Selenium to test 'musthavemilestoneonaccept'", "Enter bug description");
$sel->click_ok("commit", undef, "Commit bug data to post_bug.cgi");
$sel->wait_for_page_to_load(WAIT_TIME);
my $bug1_id = $sel->get_value("//input[\@name='id' and \@type='hidden']");
$sel->title_like(qr/Bug $bug1_id Submitted/, "Bug $bug1_id created");

# 4th step: edit the bug (test musthavemilestoneonaccept ON).

$sel->select_ok("bug_status", "label=ASSIGNED", "Change bug status to ASSIGNED");
$sel->click_ok("commit", undef, "Save changes");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Milestone Required", "Change rejected: musthavemilestoneonaccept is on but the milestone selected is the default one");
$sel->is_text_present_ok("You must select a target milestone", undef, "Display error message");
# We cannot use go_back_ok() because we just left post_bug.cgi where data has been submitted using POST.
$sel->type_ok("quicksearch_top", $bug1_id, "go_back() doesn't like POST, enter the bug ID in the QuickSearch box");
$sel->click_ok("find_top", undef, "Go to bug $bug1_id");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->select_ok("target_milestone", "label=2.0", "Select a non-default milestone");
$sel->click_ok("commit", undef, "Save changes (2nd attempt)");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed", undef, "Changes saved");

# 5th step: create another bug.

file_bug_in_product($sel, "TestProduct");
$sel->select_ok("target_milestone", "label=2.0", "Set the milestone to 2.0");
$sel->selected_label_is("component", "TestComponent", "Component already selected (no other component defined)");
$sel->selected_label_is("version", "unspecified", "Version already selected (no other version defined)");
$sel->type_ok("short_desc", "Target Milestone set to non-default", "Enter bug summary");
$sel->type_ok("comment", "Created by Selenium to test 'musthavemilestoneonaccept'", "Enter bug description");
$sel->click_ok("commit", undef, "Commit bug data to post_bug.cgi");
$sel->wait_for_page_to_load(WAIT_TIME);
my $bug2_id = $sel->get_value("//input[\@name='id' and \@type='hidden']");
$sel->title_like(qr/Bug $bug2_id Submitted/, "Bug $bug2_id created");

# 6th step: edit the bug (test musthavemilestoneonaccept ON).

$sel->select_ok("bug_status", "label=ASSIGNED");
$sel->click_ok("commit");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Bug $bug2_id processed");

# 7th step: test validation methods for milestones.

$sel->open_ok("/$config->{bugzilla_installation}/editmilestones.cgi");
$sel->title_is("Edit milestones for which product?");
$sel->click_ok("link=TestProduct");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Select milestone of product 'TestProduct'");
$sel->click_ok("link=2.0");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Edit Milestone '2.0' of product 'TestProduct'");
$sel->type_ok("milestone", "1.0");
$sel->value_is("milestone", "1.0");
$sel->click_ok("update");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Milestone Updated");
$sel->click_ok("link=Add");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Add Milestone to Product 'TestProduct'");
$sel->type_ok("milestone", "1.5");
$sel->value_is("milestone", "1.5");
$sel->type_ok("sortkey", "99999999999999999");
$sel->value_is("sortkey", "99999999999999999");
$sel->click_ok("create");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Invalid Milestone Sortkey");
my $error_msg = trim($sel->get_text("error_msg"));
ok($error_msg =~ /^The sortkey '99999999999999999' is not in the range/, "Invalid sortkey");
$sel->go_back_ok();
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->type_ok("sortkey", "-polu7A");
$sel->value_is("sortkey", "-polu7A");
$sel->click_ok("create");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Invalid Milestone Sortkey");
$error_msg = trim($sel->get_text("error_msg"));
ok($error_msg =~ /^The sortkey '-polu7A' is not in the range/, "Invalid sortkey");
$sel->go_back_ok();
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->click_ok("link='TestProduct'");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Select milestone of product 'TestProduct'");
$sel->click_ok("link=Delete");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Delete Milestone of Product 'TestProduct'");
$sel->is_text_present_ok("When you delete this milestone", undef, "Warn the user about bugs being affected");
$sel->click_ok("delete");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Milestone Deleted");

# 8th step: make sure the (now deleted) milestone of the bug has fallen back to the default milestone.

$sel->open_ok("/$config->{bugzilla_installation}/show_bug.cgi?id=$bug1_id");
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok('regexp:Target Milestone:\W+---', undef, "Milestone has fallen back to the default milestone");

# 9th step: file another bug.

file_bug_in_product($sel, "TestProduct");
$sel->selected_label_is("target_milestone", "---", "Default milestone selected");
$sel->selected_label_is("component", "TestComponent");
$sel->type_ok("short_desc", "Only one Target Milestone available", "Enter bug summary");
$sel->type_ok("comment", "Created by Selenium to test 'musthavemilestoneonaccept'", "Enter bug description");
$sel->click_ok("commit", undef, "Commit bug data to post_bug.cgi");
$sel->wait_for_page_to_load(WAIT_TIME);
my $bug3_id = $sel->get_value("//input[\@name='id' and \@type='hidden']");
$sel->title_like(qr/Bug $bug3_id Submitted/);

# 10th step: musthavemilestoneonaccept must have no effect as there is
#            no other milestone available besides the default one.

$sel->select_ok("bug_status", "label=ASSIGNED");
$sel->click_ok("commit");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Bug $bug3_id processed");

# 11th step: turn musthavemilestoneonaccept back to OFF.

set_parameters($sel, {'Bug Change Policies' => {'musthavemilestoneonaccept-off' => undef}});
logout($sel);
