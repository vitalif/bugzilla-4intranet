#!/usr/bin/perl -wT
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru> (the file is rewritten)

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;

my $user = Bugzilla->login;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->input_params;

Bugzilla->switch_to_shadow_db;

my $product = Bugzilla::Product->new({ name => trim($ARGS->{product} || '') });
unless ($product && $user->can_access_product($product->name))
{
    $product = Bugzilla::Product->choose_product($user->get_accessible_products);
}

$vars->{product} = $product;

$template->process("reports/components.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
