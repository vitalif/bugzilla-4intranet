use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

# We have to upload files from the local computer. This requires
# chrome privileges.
my ($sel, $config) = get_selenium(CHROME_MODE);

# set the insidergroup parameter to the admin group, and make sure
# we can view attachments.

log_in($sel, $config, 'admin');
set_parameters($sel, { "Group Security" => {"insidergroup" => {type => "select", value => "admin"}},
                       "Attachments"    => {"allow_attachment_display-on" => undef}
                     });

# First create a new bug with a private attachment.

file_bug_in_product($sel, "TestProduct");
$sel->type_ok("short_desc", "Some comments are private");
$sel->type_ok("comment", "and some attachments too, like this one.");
$sel->check_ok("commentprivacy");
$sel->click_ok('//input[@value="Add an attachment"]');
$sel->type_ok("data", "/var/www/html/selenium/bugzilla/patch.diff");
$sel->type_ok("description", "private attachment, v1");
$sel->check_ok("ispatch");
$sel->click_ok("commit");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug \d+ Submitted/);
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');
$sel->is_text_present_ok("private attachment, v1 (");
$sel->is_text_present_ok("and some attachments too, like this one.");
$sel->is_checked_ok('//a[@id="comment_link_0"]/../..//div//input[@type="checkbox"]');

# Now attach a public patch to the existing bug.

$sel->click_ok("link=Add an attachment");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Create New Attachment for Bug #$bug1_id");
$sel->type_ok("data", "/var/www/html/selenium/bugzilla/patch.diff");
$sel->type_ok("description", "public attachment, v2");
$sel->check_ok("ispatch");
# The existing attachment name must be displayed, to mark it as obsolete.
$sel->is_text_present_ok("private attachment, v1");
$sel->type_ok("comment", "this patch is public. Everyone can see it.");
$sel->value_is("isprivate", "off");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Attachment \d+ added to Bug \d+/);

# We need to store the attachment ID.

my $alink = $sel->get_attribute('//a[@title="public attachment, v2"]@href');
$alink =~ /id=(\d+)/;
my $attachment1_id = $1;

# Be sure to redisplay the same bug, and make sure the new attachment is visible.

$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("public attachment, v2");
$sel->is_text_present_ok("this patch is public. Everyone can see it.");
ok(!$sel->is_checked('//a[@id="comment_link_1"]/../..//div//input[@type="checkbox"]'), "Public attachment is visible");
logout($sel);

# A logged out user cannot see the private attachment, only the public one.
# Same for a user with no privs.

foreach my $user ('', 'unprivileged') {
    log_in($sel, $config, $user) if $user;
    $sel->type_ok("quicksearch_top", $bug1_id);
    $sel->click_ok("find_top");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_like(qr/^Bug $bug1_id/);
    ok(!$sel->is_text_present("private attachment, v1"), "Private attachment not visible");
    $sel->is_text_present_ok("public attachment, v2");
    ok(!$sel->is_text_present("and some attachments too, like this one"), "Private comment not visible");
    $sel->is_text_present_ok("this patch is public. Everyone can see it.");
}

# Powerless users will always be able to view their own attachments, even
# when those are marked private by a member of the insider group.

$sel->click_ok("link=Add an attachment");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Create New Attachment for Bug #$bug1_id");
$sel->type_ok("data", "/var/www/html/selenium/bugzilla/patch.diff");
$sel->check_ok("ispatch");
# The user doesn't have editbugs privs.
$sel->is_text_present_ok("[no attachments can be made obsolete]");
$sel->type_ok("description", "My patch, which I should see, always");
$sel->type_ok("comment", "This is my patch!");
$sel->click_ok("create");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Attachment \d+ added to Bug \d+/);
$alink = $sel->get_attribute('//a[@title="My patch, which I should see, always"]@href');
$alink =~ /id=(\d+)/;
my $attachment2_id = $1;
$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("My patch, which I should see, always (");
$sel->is_text_present_ok("This is my patch!");
logout($sel);

# Let the admin mark the powerless user's attachment as private.

log_in($sel, $config, 'admin');
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->click_ok('//a[@href="attachment.cgi?id=' . $attachment2_id . '&action=edit"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Attachment $attachment2_id Details for Bug $bug1_id");
$sel->check_ok("isprivate");
$sel->type_ok("comment", "Making the powerless user's patch private.");
$sel->click_ok("update");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Changes Submitted to Attachment $attachment2_id of Bug $bug1_id");
$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("My patch, which I should see, always (");
$sel->is_checked_ok('//a[@id="comment_link_3"]/../..//div//input[@type="checkbox"]');
$sel->is_text_present_ok("Making the powerless user's patch private.");
logout($sel);

# A logged out user cannot see private attachments.

$sel->type_ok("quicksearch_top", "$bug1_id");
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
ok(!$sel->is_text_present("private attachment, v1"), "Private attachment not visible to logged out users");
ok(!$sel->is_text_present("My patch, which I should see, always ("), "Private attachment not visible to logged out users");
$sel->is_text_present_ok("This is my patch!");
ok(!$sel->is_text_present("Making the powerless user's patch private"), "Private attachment not visible to logged out users");

# A powerless user can only see private attachments he owns.

log_in($sel, $config, 'unprivileged');
$sel->type_ok("quicksearch_top", "$bug1_id");
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id/);
$sel->is_text_present_ok("My patch, which I should see, always (");
$sel->click_ok("link=My patch, which I should see, always");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
# No title displayed while viewing an attachment.
$sel->title_is("");
$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
logout($sel);
log_in($sel, $config, 'admin');
set_parameters($sel, { 
    "Group Security" => {"insidergroup" => { type => "select", 
                                             value => "QA-Selenium-TEST" }},
});
logout($sel);
