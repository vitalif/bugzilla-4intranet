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
# The Initial Developer of the Original Code is Matt Masson.
# Portions created by Matt Masson are Copyright (C) 2000 Matt Masson.
# All Rights Reserved.
#
# Contributors : Matt Masson <matthew@zeroknowledge.com>
#                Gavin Shelley <bugzilla@chimpychompy.org>
#                Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Milestone;
use Bugzilla::Token;

my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};
# There is only one section about milestones in the documentation,
# so all actions point to the same page.
$vars->{doc_section} = 'milestones.html';

#
# Preliminary checks:
#

my $user = Bugzilla->login(LOGIN_REQUIRED);

$user->in_group('editcomponents')
    || scalar(@{$user->get_editable_products})
    || ThrowUserError("auth_failure", {
        group  => "editcomponents",
        action => "edit",
        object => "milestones",
    });

#
# often used variables
#
my $product_name   = trim($ARGS->{product}   || '');
my $milestone_name = trim($ARGS->{milestone} || '');
my $sortkey        = trim($ARGS->{sortkey}   || 0);
my $action         = trim($ARGS->{action}    || '');
my $showbugcounts  = defined $ARGS->{showbugcounts};
my $token          = $ARGS->{token};
my $isactive       = $ARGS->{isactive};

#
# product = '' -> Show nice list of products
#

unless ($product_name)
{
    $vars->{products} = $user->get_editable_products;
    $vars->{showbugcounts} = $showbugcounts;
    $template->process("admin/milestones/select-product.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

my $product = $user->check_can_admin_product($product_name);

#
# action='' -> Show nice list of milestones
#

unless ($action)
{
    $vars->{showbugcounts} = $showbugcounts;
    $vars->{product} = $product;
    $template->process("admin/milestones/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='change_empty' -> Enable/disable empty milestone
#
if ($action eq 'change_empty' && Bugzilla->get_field('target_milestone')->null_field_id == Bugzilla->get_field('product')->id)
{
    my $f = ($ARGS->{allow_empty} ? 'add' : 'delete').'_visibility_values';
    Bugzilla->get_field('target_milestone')->$f(FLAG_NULLABLE, [ $product->id ]);
    print Bugzilla->cgi->redirect('editmilestones.cgi?product='.url_quote($product->name));
    exit;
}

#
# action='add' -> present form for parameters for new milestone
#
# (next action will be 'new')
#

if ($action eq 'add')
{
    $vars->{token} = issue_session_token('add_milestone');
    $vars->{product} = $product;
    $template->process("admin/milestones/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='new' -> add milestone entered in the 'action=add' screen
#

if ($action eq 'new')
{
    check_token_data($token, 'add_milestone');
    my $milestone = Bugzilla::Milestone->create({
        name    => $milestone_name,
        product => $product,
        sortkey => $sortkey,
    });
    delete_token($token);
    $vars->{message} = 'milestone_created';
    $vars->{milestone} = $milestone;
    $vars->{product} = $product;
    $template->process("admin/milestones/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='del' -> ask if user really wants to delete
#
# (next action would be 'delete')
#

if ($action eq 'del')
{
    my $milestone = Bugzilla::Milestone->check({
        product => $product,
        name    => $milestone_name,
    });

    $vars->{milestone} = $milestone;
    $vars->{product} = $product;
    $vars->{token} = issue_session_token('delete_milestone');

    $template->process("admin/milestones/confirm-delete.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='delete' -> really delete the milestone
#

if ($action eq 'delete')
{
    check_token_data($token, 'delete_milestone');
    my $milestone = Bugzilla::Milestone->check({
        product => $product,
        name    => $milestone_name,
    });
    $milestone->remove_from_db;
    delete_token($token);

    $vars->{message} = 'milestone_deleted';
    $vars->{milestone} = $milestone;
    $vars->{product} = $product;
    $vars->{no_edit_milestone_link} = 1;

    $template->process("admin/milestones/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='edit' -> present the edit milestone form
#
# (next action would be 'update')
#

if ($action eq 'edit')
{
    my $milestone = Bugzilla::Milestone->check({
        product => $product,
        name    => $milestone_name,
    });

    $vars->{milestone} = $milestone;
    $vars->{product} = $product;
    $vars->{token} = issue_session_token('edit_milestone');

    $template->process("admin/milestones/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='update' -> update the milestone
#

if ($action eq 'update')
{
    check_token_data($token, 'edit_milestone');
    my $milestone_old_name = trim($ARGS->{milestoneold} || '');
    my $milestone = Bugzilla::Milestone->check({
        product => $product,
        name    => $milestone_old_name,
    });

    $milestone->set_name($milestone_name);
    $milestone->set_sortkey($sortkey);
    $milestone->set_is_active($isactive);
    my $changes = $milestone->update();

    $changes->{control_lists} = 1 if $milestone->field->update_control_lists($milestone->id, $ARGS);

    delete_token($token);

    $vars->{message} = 'milestone_updated';
    $vars->{milestone} = $milestone;
    $vars->{product} = $product;
    $vars->{changes} = $changes;
    $template->process("admin/milestones/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# No valid action found
#
ThrowUserError('no_valid_action', {'field' => "target_milestone"});
