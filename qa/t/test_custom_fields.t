use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();
log_in($sel, $config, 'admin');

# Create new bug to test custom fields

file_bug_in_product($sel, 'TestProduct');
$sel->type_ok("short_desc", "What's your ID?");
$sel->type_ok("comment", "I only want the ID of this bug to generate a unique custom field name.");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug \d+ Submitted/, "Bug created");
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');

# Create custom fields

go_to_admin($sel);
$sel->click_ok("link=Custom Fields");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Fields");
$sel->click_ok("link=Add a new custom field");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add a new Custom Field");
$sel->type_ok("name", "cf_qa_freetext_$bug1_id");
$sel->type_ok("desc", "Freetext$bug1_id");
$sel->select_ok("type", "label=Free Text");
$sel->type_ok("sortkey", $bug1_id);
# These values are off by default.
$sel->value_is("enter_bug", "off");
$sel->value_is("obsolete", "off");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Field Created");
$sel->is_text_present_ok("The new custom field \'cf_qa_freetext_$bug1_id\' has been successfully created.");
$sel->click_ok("link=Add a new custom field");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add a new Custom Field");
$sel->type_ok("name", "cf_qa_list_$bug1_id");
$sel->type_ok("desc", "List$bug1_id");
$sel->select_ok("type", "label=Drop Down");
$sel->type_ok("sortkey", $bug1_id);
$sel->click_ok("enter_bug");
$sel->value_is("enter_bug", "on");
$sel->click_ok("new_bugmail");
$sel->value_is("new_bugmail", "on");
$sel->value_is("obsolete", "off");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Field Created");
$sel->is_text_present_ok("The new custom field \'cf_qa_list_$bug1_id\' has been successfully created.");

# Add values to the custom fields.

$sel->click_ok("link=cf_qa_list_$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit the Custom Field \'cf_qa_list_$bug1_id\' (List$bug1_id)");
$sel->click_ok("link=Edit legal values for this field");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select value for the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add Value for the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->type_ok("value", "have fun?");
$sel->type_ok("sortkey", "805");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("New Field Value Created");
$sel->is_text_present_ok("The value have fun? has been added as a valid choice for the List$bug1_id (cf_qa_list_$bug1_id) field.");
$sel->click_ok("link=Add");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Add Value for the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->type_ok("value", "storage");
$sel->type_ok("sortkey", "49");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("New Field Value Created");
$sel->is_text_present_ok("The value storage has been added as a valid choice for the List$bug1_id (cf_qa_list_$bug1_id) field.");

# Create new bug to test custom fields in bug creation page

file_bug_in_product($sel, 'TestProduct');
$sel->is_text_present_ok("List$bug1_id:");
$sel->is_element_present_ok("cf_qa_list_$bug1_id");
$sel->type_ok("short_desc", "Et de un");
$sel->type_ok("comment", "hops!");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug \d+ Submitted/, "Bug created");
my $bug2_id = $sel->get_value('//input[@name="id" and @type="hidden"]');

# Both fields are editable.

$sel->type_ok("cf_qa_freetext_$bug1_id", "bonsai");
$sel->selected_label_is("cf_qa_list_$bug1_id", "---");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug2_id processed");
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->type_ok("cf_qa_freetext_$bug1_id", "dumbo");
$sel->select_ok("cf_qa_list_$bug1_id", "label=storage");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed");
$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->click_ok("link=Format For Printing");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Full Text Bug Listing");
$sel->is_text_present_ok("Freetext$bug1_id: dumbo");
$sel->is_text_present_ok("List$bug1_id: storage");
$sel->type_ok("quicksearch_top", $bug2_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug2_id/);
$sel->select_ok("cf_qa_list_$bug1_id", "label=storage");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug2_id processed");

# Test searching for bugs using the custom fields

open_advanced_search_page($sel);
$sel->remove_all_selections_ok("product");
$sel->add_selection_ok("product", "TestProduct");
$sel->remove_all_selections("bug_status");
$sel->select_ok("field0-0-0", "label=List$bug1_id");
$sel->select_ok("type0-0-0", "label=is equal to");
$sel->type_ok("value0-0-0", "storage");
$sel->click_ok("Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_text_present_ok("2 bugs found");
$sel->is_text_present_ok("What's your ID?");
$sel->is_text_present_ok("Et de un");

# Now edit custom fields in mass changes.

$sel->click_ok("link=Change Several Bugs at Once");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->click_ok("check_all");
$sel->select_ok("cf_qa_list_$bug1_id", "label=---");
$sel->type_ok("cf_qa_freetext_$bug1_id", "thanks");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bugs processed");
$sel->click_ok("link=bug $bug2_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug2_id/);
$sel->value_is("cf_qa_freetext_$bug1_id", "thanks");
$sel->selected_label_is("cf_qa_list_$bug1_id", "---");
$sel->select_ok("cf_qa_list_$bug1_id", "label=storage");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug2_id processed");

# Delete the existing '---' field value.

go_to_admin($sel);
$sel->click_ok("link=Field Values");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit values for which field?");
$sel->click_ok("link=List$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select value for the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->click_ok("//a[contains(\@href, 'editvalues.cgi?action=del&field=cf_qa_list_$bug1_id&value=have%20fun%3F')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Value \'have fun?\' from the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->is_text_present_ok("Do you really want to delete this value?");
$sel->click_ok("delete");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Field Value Deleted");

# This value cannot be deleted as it's in use.

$sel->click_ok("//a[contains(\@href, 'editvalues.cgi?action=del&field=cf_qa_list_$bug1_id&value=storage')]");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Delete Value \'storage\' from the \'List$bug1_id\' (cf_qa_list_$bug1_id) field");
$sel->is_text_present_ok("There is 1 bug with this field value");

# Mark the <select> field as obsolete, making it unavailable in bug reports.

go_to_admin($sel);
$sel->click_ok("link=Custom Fields");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Fields");
$sel->click_ok("link=cf_qa_list_$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit the Custom Field \'cf_qa_list_$bug1_id\' (List$bug1_id)");
$sel->click_ok("obsolete");
$sel->value_is("obsolete", "on");
$sel->click_ok("edit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Field Updated");
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->value_is("cf_qa_freetext_$bug1_id", "thanks");
ok(!$sel->is_element_present("cf_qa_list_$bug1_id"), "The custom list is not visible");

# Custom fields are also viewable by logged out users.

logout($sel);
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("Freetext$bug1_id: thanks");

# Powerless users should still be able to CC themselves when
# custom fields are in use.

log_in($sel, $config, 'unprivileged');
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("Freetext$bug1_id: thanks");
$sel->click_ok("cc_edit_area_showhide");
$sel->type_ok("newcc", $config->{unprivileged_user_login});
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug $bug1_id processed");
logout($sel);

# Disable the remaining free text field.

log_in($sel, $config, 'admin');
go_to_admin($sel);
$sel->click_ok("link=Custom Fields");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Fields");
$sel->click_ok("link=cf_qa_freetext_$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Edit the Custom Field \'cf_qa_freetext_$bug1_id\' (Freetext$bug1_id)");
$sel->click_ok("obsolete");
$sel->value_is("obsolete", "on");
$sel->click_ok("edit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Custom Field Updated");
logout($sel);
