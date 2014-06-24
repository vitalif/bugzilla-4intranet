use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

log_in($sel, $config, 'admin');
go_to_admin($sel);
$sel->click_ok("link=Sanity Check", undef, "Go to Sanity Check (no parameter)");
$sel->wait_for_page_to_load(WAIT_TIME);
$sel->title_is("Sanity Check", "Display sanitycheck.cgi");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?rebuildvotecache=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with rebuildvotecache=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?createmissinggroupcontrolmapentries=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with createmissinggroupcontrolmapentries=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?repair_creation_date=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with repair_creation_date=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?repair_bugs_fulltext=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with repair_bugs_fulltext=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?rescanallBugMail=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with rescanallBugMail=1");
$sel->is_text_present_ok("found with possibly unsent mail", undef, "Look for unsent bugmail");
# sanitycheck.cgi always stops after looking for unsent bugmail. So we cannot rely on
# "Sanity check completed." to determine if an error has been thrown or not.
ok(!$sel->is_text_present("Software error"), "No error thrown");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?remove_invalid_bug_references=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with remove_invalid_bug_references=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?remove_invalid_attach_references=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with remove_invalid_attach_references=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?remove_old_whine_targets=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with remove_old_whine_targets=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
$sel->open_ok("/$config->{bugzilla_installation}/sanitycheck.cgi?repair_bugs_fulltext=1");
$sel->title_is("Sanity Check", "Call sanitycheck.cgi with repair_bugs_fulltext=1");
$sel->is_text_present_ok("Sanity check completed.", undef, "Page displayed correctly");
logout($sel);
