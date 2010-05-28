use strict;
use warnings;
use lib qw(lib);
use Test::More "no_plan";
use QA::Util;

my ($sel, $config) = get_selenium();

$sel->open_ok("/$config->{bugzilla_installation}/long_list.cgi?id=1");
$sel->title_is("Full Text Bug Listing", "Display bug as format for printing");
my $text = $sel->get_text("//h1");
$text =~ s/[\r\n\t\s]+/ /g;
is($text, 'Bug 1', 'Display bug 1 specifically');
