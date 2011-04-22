use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Turn on the usevisibilitygroups param so that some users are invisible.

log_in($sel, $config, 'admin');
set_parameters($sel, { "Group Security" => {"usevisibilitygroups-on" => undef} });
logout($sel);

# You can see all users from editusers.cgi, but once you leave this page,
# usual group visibility restrictions apply and the "powerless" user cannot
# be sudo'ed as he is in no group.

log_in($sel, $config, 'editbugs');
go_to_admin($sel);
$sel->click_ok("link=Users");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search users");
$sel->type_ok("matchstr", $config->{unprivileged_user_login});
$sel->select_ok("matchtype", "label=exact (find this user)");
$sel->click_ok("search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Edit user .* <\Q$config->{unprivileged_user_login}\E>/);
$sel->value_is("login", $config->{unprivileged_user_login});
$sel->click_ok("link=Impersonate this user");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Begin sudo session");
$sel->value_is("target_login", $config->{unprivileged_user_login});
$sel->type_ok("reason", "Selenium test about sudo sessions");
$sel->type_ok("Bugzilla_password", $config->{editbugs_user_passwd}, "Enter admin password");
$sel->click_ok('//input[@value="Begin Session"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
my $error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg eq "$config->{unprivileged_user_login} does not exist or you are not allowed to see that user.",
   "Cannot impersonate users you cannot see");
logout($sel);

# Turn off the usevisibilitygroups param so that all users are visible again.

log_in($sel, $config, 'admin');
set_parameters($sel, { "Group Security" => {"usevisibilitygroups-off" => undef} });
logout($sel);

# The "powerless" user can now be sudo'ed.

log_in($sel, $config, 'editbugs');
go_to_admin($sel);
$sel->click_ok("link=Users");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search users");
$sel->type_ok("matchstr", $config->{unprivileged_user_login});
$sel->select_ok("matchtype", "label=exact (find this user)");
$sel->click_ok("search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Edit user .* <\Q$config->{unprivileged_user_login}\E>/);
$sel->value_is("login", $config->{unprivileged_user_login});
$sel->click_ok("link=Impersonate this user");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Begin sudo session");
$sel->value_is("target_login", $config->{unprivileged_user_login});
$sel->type_ok("Bugzilla_password", $config->{editbugs_user_passwd}, "Enter admin password");
$sel->click_ok('//input[@value="Begin Session"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Sudo session started");
my $text = trim($sel->get_text("message"));
_ok($text =~ /The sudo session has been started/, "The sudo session has been started");

# Make sure this user is not an admin and has no privs at all, and that
# he cannot access editusers.cgi (despite the sudoer can).

$sel->click_ok("link=Preferences");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");
$sel->click_ok("link=Permissions");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");
#$sel->is_text_present_ok("There are no permission bits set on your account"); # Valid only for empty DB
# We access the page directly as there is no link pointing to it.
$sel->open_ok("/$config->{bugzilla_installation}/editusers.cgi");
$sel->title_is("Authorization Required");
$error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg =~ /^Sorry, you aren't a member of the 'editusers' group/, "Not a member of the editusers group");
$sel->click_ok("link=end session");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Sudo session complete");
$sel->is_text_present_ok("The sudo session has been ended");

# Try to access the sudo page directly, with no credentials.

$sel->open_ok("/$config->{bugzilla_installation}/relogin.cgi?action=begin-sudo");
$sel->title_is("Password Required");

# Now try to start a sudo session directly, with all required credentials.

$sel->open_ok("/$config->{bugzilla_installation}/relogin.cgi?action=begin-sudo&Bugzilla_login=$config->{admin_user_login}&Bugzilla_password=$config->{admin_user_passwd}&target_login=$config->{admin_user_login}", undef, "Impersonate a user directly by providing all required data");
$sel->title_is("Preparation Required");

# The link should populate the target_login field correctly.
# Note that we are trying to sudo an admin, which is not allowed.

$sel->click_ok("link=start your session normally");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Begin sudo session");
$sel->value_is("target_login", $config->{admin_user_login});
$sel->type_ok("reason", "Selenium hack");
$sel->type_ok("Bugzilla_password", $config->{admin_user_passwd}, "Enter admin password");
$sel->click_ok('//input[@value="Begin Session"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Protected");
$error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg =~ /^The user $config->{admin_user_login} may not be impersonated by sudoers/, "Cannot impersonate administrators");

# Now try to sudo a non-existing user account, with no password.

$sel->go_back_ok();
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Begin sudo session");
$sel->type_ok("target_login", 'foo@bar.com');
$sel->click_ok('//input[@value="Begin Session"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Invalid Username Or Password");

# Same as above, but with your password.

$sel->open_ok("/$config->{bugzilla_installation}/relogin.cgi?action=prepare-sudo&target_login=foo\@bar.com");
$sel->title_is("Begin sudo session");
$sel->value_is("target_login", 'foo@bar.com');
$sel->type_ok("Bugzilla_password", $config->{admin_user_passwd}, "Enter admin password");
$sel->click_ok('//input[@value="Begin Session"]');
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Match Failed");
$error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg eq 'foo@bar.com does not exist or you are not allowed to see that user.', "Cannot impersonate non-existing accounts");
logout($sel);