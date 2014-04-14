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
my $ARGS = Bugzilla->cgi->VarHash;

Bugzilla->switch_to_shadow_db;

my $product = new Bugzilla::Product({ name => trim($ARGS->{product} || '') });
unless ($product && $user->can_access_product($product->name))
{
    # Products which the user is allowed to see.
    my $products = $user->get_accessible_products;
    if (!@$products)
    {
        ThrowUserError('no_products');
    }
    if (Bugzilla->params->{useclassification} && $ARGS->{classification} ne '__all')
    {
        my $cl = Bugzilla::Classification->new({ name => trim($ARGS->{classification} || '') });
        if (!$cl)
        {
            my $acc = [ keys %{ { map { $_->classification_id => 1 } @$products } } ];
            $vars->{classifications} = Bugzilla::Classification->new_from_list($acc);
            $vars->{target} = 'describecomponents.cgi';
            $template->process('global/choose-classification.html.tmpl', $vars)
                || ThrowTemplateError($template->error());
            exit;
        }
        $vars->{classifications} = [ {
            object => $cl,
            products => [ grep { $_->classification_id == $cl->id } @$products ],
        } ];
    }
    else
    {
        $vars->{classifications} = [ {
            object => undef,
            products => $products
        } ];
    }
    $vars->{target} = 'describecomponents.cgi';
    $template->process('global/choose-product.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

$vars->{product} = $product;

$template->process("reports/components.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
