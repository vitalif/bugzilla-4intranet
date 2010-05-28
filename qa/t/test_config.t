use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# Turn on 'requirelogin' and log out.

log_in($sel, $config, 'admin');
set_parameters($sel, { "User Authentication" => {"requirelogin-on" => undef} });
logout($sel);

# Accessing config.cgi should display no sensitive data.

$sel->open_ok("/$config->{bugzilla_installation}/config.cgi", undef, "Go to config.cgi (JS format)");
$sel->is_text_present_ok("var status = [ ];");
$sel->is_text_present_ok("var status_open = [ ];");
$sel->is_text_present_ok("var status_closed = [ ];");
$sel->is_text_present_ok("var resolution = [ ];");
$sel->is_text_present_ok("var keyword = [ ];");
$sel->is_text_present_ok("var platform = [ ];");
$sel->is_text_present_ok("var severity = [ ];");
$sel->is_text_present_ok("var field = [\n];");

ok(!$sel->is_text_present("cf_"), "No custom field displayed");
ok(!$sel->is_text_present("component["), "No component displayed");
ok(!$sel->is_text_present("version["), "No version displayed");
ok(!$sel->is_text_present("target_milestone["), "No target milestone displayed");

# Turn on 'requirelogin' and log out.

log_in($sel, $config, 'admin');
set_parameters($sel, { "User Authentication" => {"requirelogin-off" => undef} });
logout($sel);
