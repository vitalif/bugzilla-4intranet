#!/usr/bin/perl -wT
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is mozilla.org code.
#
# The Initial Developer of the Original Code is Holger
# Schurig. Portions created by Holger Schurig are
# Copyright (C) 1999 Holger Schurig. All
# Rights Reserved.
#
# Contributor(s): Holger Schurig <holgerschurig@nikocity.de>
#                 Terry Weissman <terry@mozilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Akamai Technologies <bugzilla-dev@akamai.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Component;
use Bugzilla::Token;

my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};
$vars->{doc_section} = 'components.html';

my $user = Bugzilla->login(LOGIN_REQUIRED);

$user->in_group('editcomponents')
    || scalar(@{$user->get_editable_products})
    || ThrowUserError('auth_failure', {
        group  => 'editcomponents',
        action => 'edit',
        object => 'components'
    });

my $comp_name     = trim($ARGS->{component} || '');
my $action        = trim($ARGS->{action} || '');
my $showbugcounts = defined $ARGS->{showbugcounts};
my $token         = $ARGS->{token};

unless ($ARGS->{product})
{
    # Select product
    $vars->{products} = $user->get_editable_products;
    $vars->{showbugcounts} = $showbugcounts;
    $template->process('admin/components/select-product.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

# Check product admin permission
my $product = $user->check_can_admin_product($ARGS->{product});

if (!$action)
{
    # Show nice list of components
    $vars->{showbugcounts} = $showbugcounts;
    $vars->{product} = $product;
    $template->process('admin/components/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'add')
{
    # Present form for parameters for new component (next action will be 'new')
    $vars->{token} = issue_session_token('add_component');
    $vars->{product} = $product;
    $template->process('admin/components/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'new')
{
    # Add component entered in the 'action=add' screen
    check_token_data($token, 'add_component');

    # Do the user matching
    Bugzilla::User::match_field({
        initialowner     => { 'type' => 'single' },
        initialqacontact => { 'type' => 'single' },
        initialcc        => { 'type' => 'multi'  },
    });

    my $component = Bugzilla::Component->new;
    $component->set_all({
        name             => $comp_name,
        product_id       => $product,
        description      => $ARGS->{description},
        initialowner     => $ARGS->{initialowner},
        initialqacontact => $ARGS->{initialqacontact},
        wiki_url         => $ARGS->{wiki_url},
        cc               => $ARGS->{initialcc},
        isactive         => $ARGS->{isactive},
    });
    $component->update;
    # XXX We should not be creating series for products that we didn't create series for.
    $component->create_series;

    $vars->{message} = 'component_created';
    $vars->{comp} = $component;
    $vars->{product} = $product;
    delete_token($token);

    $template->process('admin/components/list.html.tmpl', $vars)
      || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'del')
{
    # Ask if user really wants to delete (next action would be 'delete')
    $vars->{token} = issue_session_token('delete_component');
    $vars->{comp} = Bugzilla::Component->check({ product => $product, name => $comp_name });
    $vars->{product} = $product;

    $template->process('admin/components/confirm-delete.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'delete')
{
    # Really delete the component
    check_token_data($token, 'delete_component');
    my $component = Bugzilla::Component->check({ product => $product, name => $comp_name });
    $component->remove_from_db;

    $vars->{message} = 'component_deleted';
    $vars->{comp} = $component;
    $vars->{product} = $product;
    $vars->{no_edit_component_link} = 1;
    delete_token($token);

    $template->process('admin/components/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'edit')
{
    # Present the edit component form (next action would be 'update')
    $vars->{token} = issue_session_token('edit_component');
    my $component = Bugzilla::Component->check({ product => $product, name => $comp_name });
    $vars->{comp} = $component;
    $vars->{initial_cc_names} = join(', ', map($_->login, @{$component->initial_cc}));
    $vars->{product} = $product;
    $template->process('admin/components/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
elsif ($action eq 'update')
{
    # Update the component
    check_token_data($token, 'edit_component');

    # Do the user matching
    Bugzilla::User::match_field({
        initialowner     => { 'type' => 'single' },
        initialqacontact => { 'type' => 'single' },
        initialcc        => { 'type' => 'multi'  },
    });

    my $component = Bugzilla::Component->check({ product => $product, name => $ARGS->{componentold} });
    $component->set_all({
        name             => $comp_name,
        product_id       => $product,
        description      => $ARGS->{description},
        initialowner     => $ARGS->{initialowner},
        initialqacontact => $ARGS->{initialqacontact},
        wiki_url         => $ARGS->{wiki_url},
        cc               => $ARGS->{initialcc},
        isactive         => $ARGS->{isactive},
    });
    my $changes = $component->update;

    $changes->{control_lists} = 1 if Bugzilla->get_field('component')->update_control_lists($component->id, $ARGS);

    $vars->{message} = 'component_updated';
    $vars->{comp} = $component;
    $vars->{product} = $product;
    $vars->{changes} = $changes;
    delete_token($token);

    $template->process('admin/components/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# No valid action found
#
ThrowUserError('no_valid_action', { field => 'component' });
