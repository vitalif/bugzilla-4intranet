#!/usr/bin/perl -wT
# -*- Mode: perl; indent-tabs-mode: nil -*-
#
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
#                 Gavin Shelley <bugzilla@chimpychompy.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Version;
use Bugzilla::Token;

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
# There is only one section about versions in the documentation,
# so all actions point to the same page.
$vars->{'doc_section'} = 'versions.html';

my $ARGS = Bugzilla->input_params;

#
# Preliminary checks:
#

my $user = Bugzilla->login(LOGIN_REQUIRED);

$user->in_group('editcomponents')
  || scalar(@{$user->get_editable_products})
  || ThrowUserError("auth_failure", {group  => "editcomponents",
                                     action => "edit",
                                     object => "versions"});

#
# often used variables
#
my $product_name = trim($cgi->param('product') || '');
my $version_name = trim($cgi->param('version') || '');
my $action       = trim($cgi->param('action')  || '');
my $showbugcounts = (defined $cgi->param('showbugcounts'));
my $token        = $cgi->param('token');
my $isactive     = $cgi->param('isactive');

#
# product = '' -> Show nice list of products
#

unless ($product_name) {
    $vars->{'products'} = $user->get_editable_products;
    $vars->{'showbugcounts'} = $showbugcounts;

    $template->process("admin/versions/select-product.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
    exit;
}

my $product = $user->check_can_admin_product($product_name);

#
# action='' -> Show nice list of versions
#

unless ($action) {
    $vars->{'showbugcounts'} = $showbugcounts;
    $vars->{'product'} = $product;
    $template->process("admin/versions/list.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='add' -> present form for parameters for new version
#
# (next action will be 'new')
#

if ($action eq 'add') {
    $vars->{'token'} = issue_session_token('add_version');
    $vars->{'product'} = $product;
    $template->process("admin/versions/edit.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='new' -> add version entered in the 'action=add' screen
#

if ($action eq 'new') {
    check_token_data($token, 'add_version');
    my $version = Bugzilla::Version->create(
        {name => $version_name, product => $product});
    delete_token($token);

    $vars->{'message'} = 'version_created';
    $vars->{'version'} = $version;
    $vars->{'product'} = $product;
    $template->process("admin/versions/list.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='del' -> ask if user really wants to delete
#
# (next action would be 'delete')
#

if ($action eq 'del') {
    my $version = Bugzilla::Version->check({ product => $product,
                                             name    => $version_name });
    $vars->{'version'} = $version;
    $vars->{'product'} = $product;
    $vars->{'token'} = issue_session_token('delete_version');
    $template->process("admin/versions/confirm-delete.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='delete' -> really delete the version
#

if ($action eq 'delete') {
    check_token_data($token, 'delete_version');
    my $version = Bugzilla::Version->check({ product => $product, 
                                             name    => $version_name });
    $version->remove_from_db;
    delete_token($token);

    $vars->{'message'} = 'version_deleted';
    $vars->{'version'} = $version;
    $vars->{'product'} = $product;
    $vars->{'no_edit_version_link'} = 1;

    $template->process("admin/versions/list.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='edit' -> present the edit version form
#
# (next action would be 'update')
#

if ($action eq 'edit') {
    my $version = Bugzilla::Version->check({ product => $product,
                                             name    => $version_name });
    $vars->{'version'} = $version;
    $vars->{'product'} = $product;
    $vars->{'token'} = issue_session_token('edit_version');

    $template->process("admin/versions/edit.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# action='update' -> update the version
#

if ($action eq 'update') {
    check_token_data($token, 'edit_version');
    my $version_old_name = trim($cgi->param('versionold') || '');
    my $version = Bugzilla::Version->check({ product => $product,
                                             name   => $version_old_name });

    $dbh->bz_start_transaction();

    $version->set_name($version_name);
    $version->set_is_active($isactive);
    my $changes = $version->update();

    $changes->{control_lists} = 1 if $version->field->update_control_lists($version->id, $ARGS);

    $dbh->bz_commit_transaction();
    delete_token($token);

    $vars->{'message'} = 'version_updated';
    $vars->{'version'} = $version;
    $vars->{'product'} = $product;
    $vars->{'changes'} = $changes;
    $template->process("admin/versions/list.html.tmpl", $vars)
      || ThrowTemplateError($template->error());

    exit;
}

#
# No valid action found
#
ThrowUserError('no_valid_action', {'field' => "version"});
