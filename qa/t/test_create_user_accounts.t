use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Set the email regexp for new bugzilla accounts to end with @bugzilla.test.

log_in($sel, $config, 'admin');
set_parameters($sel, { "User Authentication" => {"createemailregexp" => {type => "text", value => '[^@]+@bugzilla\.test'}} });
logout($sel);

# Create a valid account. We need to randomize the login address, because a request
# expires after 3 days only and this test can be executed several times per day.
my $valid_account = 'selenium-' . random_string(10) . '@bugzilla.test';

$sel->click_ok("link=Home");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bugzilla Main Page");
$sel->is_text_present_ok("Open a New Account");
$sel->click_ok("link=Open a New Account");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Create a new Bugzilla account");
$sel->type_ok("login", $valid_account);
$sel->click_ok("send");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Request for new user account '$valid_account' submitted");
$sel->is_text_present_ok("A confirmation email has been sent");

# Try creating the same account again. It's too soon.
$sel->click_ok("link=Home");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bugzilla Main Page");
$sel->is_text_present_ok("Open a New Account");
$sel->click_ok("link=Open a New Account");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Create a new Bugzilla account");
$sel->type_ok("login", $valid_account);
$sel->click_ok("send");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Too Soon For New Token");
my $error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg =~ /Please wait a while and try again/, "Too soon for this account");

# These accounts do not pass the regexp.
my @accounts = ('test@yahoo.com', 'test@bugzilla.net', 'test@bugzilla..test');
foreach my $account (@accounts) {
    $sel->click_ok("link=New Account");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Create a new Bugzilla account");
    $sel->type_ok("login", $account);
    $sel->click_ok("send");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Account Creation Restricted");
    $sel->is_text_present_ok("User account creation has been restricted.");
}

# These accounts are illegal.
@accounts = ('test\bugzilla@bugzilla.test', 'test@bugzilla.org@bugzilla.test');
foreach my $account (@accounts) {
    $sel->click_ok("link=New Account");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Create a new Bugzilla account");
    $sel->type_ok("login", $account);
    $sel->click_ok("send");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Invalid Email Address");
    my $error_msg = trim($sel->get_text("error_msg"));
    _ok($error_msg =~ /^The e-mail address you entered (\S+) didn't pass our syntax checking/, "Invalid email address detected");
}

# This account already exists.
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Create a new Bugzilla account");
$sel->type_ok("login", $config->{admin_user_login});
$sel->click_ok("send");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Account Already Exists");
$error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg eq "There is already an account with the login name $config->{admin_user_login}.", "Account already exists");

# Turn off user account creation.
log_in($sel, $config, 'admin');
set_parameters($sel, { "User Authentication" => {"createemailregexp" => {type => "text", value => ''}} });
logout($sel);

# Make sure that links pointing to createaccount.cgi are all deactivated.
_ok(!$sel->is_text_present("New Account"), "No link named 'New Account'");
$sel->click_ok("link=Home");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bugzilla Main Page");
_ok(!$sel->is_text_present("Open a New Account"), "No link named 'Open a New Account'");
$sel->open_ok("/$config->{bugzilla_installation}/createaccount.cgi");
$sel->title_is("Account Creation Disabled");
$error_msg = trim($sel->get_text("error_msg"));
_ok($error_msg =~ /^User account creation has been disabled/,
   "User account creation disabled");

# Re-enable user account creation.

log_in($sel, $config, 'admin');
set_parameters($sel, { "User Authentication" => {"createemailregexp" => {type => "text", value => '.*'}} });

# Make sure selenium-<random_string>@bugzilla.test has not be added to the DB yet.
go_to_admin($sel);
$sel->click_ok("link=Users");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search users");
$sel->type_ok("matchstr", $valid_account);
$sel->click_ok("search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Select user");
$sel->is_text_present_ok("0 users found");
logout($sel);
