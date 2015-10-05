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
#               Terry Weissman <terry@mozilla.org>
#               Dawn Endico <endico@mozilla.org>
#               Joe Robins <jmrobins@tgix.com>
#               Gavin Shelley <bugzilla@chimpychompy.org>
#               Frédéric Buclin <LpSolit@gmail.com>
#               Greg Hendricks <ghendricks@novell.com>
#               Lance Larsh <lance.larsh@oracle.com>
#               Elliotte Martin <elliotte.martin@yahoo.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Product;
use Bugzilla::Classification;
use Bugzilla::Token;

my $user = Bugzilla->login(LOGIN_REQUIRED);
my $whoid = $user->id;

my $dbh = Bugzilla->dbh;
my $ARGS = Bugzilla->input_params;
my $template = Bugzilla->template;
my $vars = {};
# Remove this as soon as the documentation about products has been
# improved and each action has its own section.
$vars->{doc_section} = 'products.html';

$user->in_group('editcomponents') ||
    scalar(@{$user->get_editable_products}) ||
    ThrowUserError('auth_failure', {
        group  => 'editcomponents',
        action => 'edit',
        object => 'products',
    });

#
# often used variables
#
my $classification_name = trim($ARGS->{classification} || '');
my $product_name = trim($ARGS->{product} || '');
my $action  = trim($ARGS->{action}  || '');
my $token = $ARGS->{token};
my $useclassification = Bugzilla->get_field('classification')->enabled;

#
# product = '' -> Show nice list of classifications (if
# classifications enabled)
#

if ($useclassification && !$classification_name && !$product_name)
{
    my $class;
    if ($user->in_group('editcomponents'))
    {
        $class = [Bugzilla::Classification->get_all];
    }
    else
    {
        # Only keep classifications containing at least one product
        # which you can administer.
        my $products = $user->get_editable_products;
        my %class_ids = map { $_->classification_id => 1 } @$products;
        $class = Bugzilla::Classification->new_from_list([keys %class_ids]);
    }
    $vars->{classifications} = $class;

    $template->process('admin/products/list-classifications.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action = '' -> Show a nice list of products, unless a product
#                is already specified (then edit it)
#

if (!$action && !$product_name)
{
    my $classification;
    my $products;

    if ($useclassification)
    {
        $classification = Bugzilla::Classification->check($classification_name);
        $products = $user->get_editable_products($classification->id);
        $vars->{classification} = $classification;
    }
    else
    {
        $products = $user->get_editable_products;
    }

    $vars->{products} = $products;
    $vars->{showbugcounts} = $ARGS->{showbugcounts} ? 1 : 0;

    $template->process('admin/products/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='add' -> present form for parameters for new product
#
# (next action will be 'new')
#

if ($action eq 'add')
{
    # The user must have the global editcomponents privs to add
    # new products.
    $user->in_group('editcomponents') || ThrowUserError('auth_failure', {
        group  => 'editcomponents',
        action => 'add',
        object => 'products',
    });

    if ($useclassification)
    {
        my $classification = Bugzilla::Classification->check($classification_name);
        $vars->{classification} = $classification;
        $vars->{classifications} = [ Bugzilla::Classification->get_all ];
    }
    $vars->{token} = issue_session_token('add_product');
    $vars->{all_groups} = Bugzilla::Group->match({isactive => 1, isbuggroup => 1});

    $template->process('admin/products/create.html.tmpl', $vars)
        || ThrowTemplateError($template->error());

    exit;
}

#
# action='new' -> add product entered in the 'action=add' screen
#

if ($action eq 'new')
{
    # The user must have the global editcomponents privs to add
    # new products.
    $user->in_group('editcomponents') || ThrowUserError('auth_failure', {
        group  => 'editcomponents',
        action => 'add',
        object => 'products',
    });

    check_token_data($token, 'add_product');

    my %create_params = (
        classification   => $classification_name,
        name             => $product_name,
        description      => $ARGS->{description},
        entryheaderhtml  => $ARGS->{entryheaderhtml},
        version          => $ARGS->{version},
        isactive         => $ARGS->{is_active},
        allows_unconfirmed => $ARGS->{allows_unconfirmed},
        wiki_url         => $ARGS->{wiki_url},
        notimetracking   => $ARGS->{notimetracking},
        extproduct       => $ARGS->{extproduct},
        cc_group         => $ARGS->{cc_group} || '',
    );
    if (Bugzilla->get_field('votes')->enabled)
    {
        $create_params{votesperuser}   = $ARGS->{votesperuser};
        $create_params{maxvotesperbug} = $ARGS->{maxvotesperbug};
        $create_params{votestoconfirm} = $ARGS->{votestoconfirm};
    }
    my $product = Bugzilla::Product->create(\%create_params);

    # Create groups and series for the new product, if requested.
    $product->_create_bug_group() if $ARGS->{makeproductgroup};
    $product->_create_series() if $ARGS->{createseries};

    delete_token($token);

    $vars->{message} = 'product_created';
    $vars->{product} = $product;
    if ($useclassification)
    {
        $vars->{classification} = new Bugzilla::Classification($product->classification_id);
    }
    $vars->{token} = issue_session_token('edit_product');

    $template->process('admin/products/edit.html.tmpl', $vars)
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
    my $product = $user->check_can_admin_product($product_name);

    if ($useclassification)
    {
        $vars->{classification} = new Bugzilla::Classification($product->classification_id);
    }
    $vars->{product} = $product;
    $vars->{token} = issue_session_token('delete_product');

    Bugzilla::Hook::process('product_confirm_delete', { vars => $vars });

    $template->process('admin/products/confirm-delete.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='delete' -> really delete the product
#

if ($action eq 'delete')
{
    my $product = $user->check_can_admin_product($product_name);
    check_token_data($token, 'delete_product');

    $product->remove_from_db({ delete_series => $ARGS->{delete_series}});
    delete_token($token);

    $vars->{message} = 'product_deleted';
    $vars->{product} = $product;
    $vars->{no_edit_product_link} = 1;

    if ($useclassification)
    {
        $vars->{classifications} = $user->in_group('editcomponents') ?
            [Bugzilla::Classification->get_all] : $user->get_selectable_classifications;

        $template->process('admin/products/list-classifications.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
    }
    else
    {
        $vars->{products} = $user->get_editable_products;

        $template->process('admin/products/list.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
    }
    exit;
}

#
# action='edit' -> present the 'edit product' form
# If a product is given with no action associated with it, then edit it.
#
# (next action would be 'update')
#

if ($action eq 'edit' || (!$action && $product_name))
{
    my $product = $user->check_can_admin_product($product_name);

    if ($useclassification)
    {
        $vars->{classification} = $product->classification_obj;
        $vars->{classifications} = [ Bugzilla::Classification->get_all ];
    }
    $vars->{product} = $product;
    $vars->{token} = issue_session_token('edit_product');
    $vars->{all_groups} = Bugzilla::Group->match({isactive => 1, isbuggroup => 1});

    $template->process('admin/products/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='update' -> update the product
#
if ($action eq 'update')
{
    check_token_data($token, 'edit_product');
    my $product_old_name = trim($ARGS->{product_old_name} || '');
    my $product = $user->check_can_admin_product($product_old_name);

    if ($useclassification)
    {
        $vars->{old_classification} = $product->classification_obj;
        $product->set_classification($ARGS->{classification});
    }
    $product->set_name($product_name);
    $product->set_wiki_url($ARGS->{wiki_url});
    $product->set_notimetracking($ARGS->{notimetracking});
    $product->set_extproduct($ARGS->{extproduct});
    $product->set_cc_group($ARGS->{cc_group} || '');
    $product->set_description($ARGS->{description});
    $product->set_entryheaderhtml($ARGS->{entryheaderhtml});
    $product->set_is_active($ARGS->{is_active});
    if (Bugzilla->get_field('votes')->enabled)
    {
        $product->set_votes_per_user($ARGS->{votesperuser});
        $product->set_votes_per_bug($ARGS->{maxvotesperbug});
        $product->set_votes_to_confirm($ARGS->{votestoconfirm});
    }
    $product->set_allows_unconfirmed($ARGS->{allows_unconfirmed});

    my $changes = $product->update();

    $changes->{control_lists} = 1 if $product->field->update_control_lists($product->id, $ARGS);

    delete_token($token);

    if ($useclassification)
    {
        $vars->{classification} = $product->classification_obj;
    }
    $vars->{product} = $product;
    $vars->{unconfirmed_states} = [ map { $_->name } grep { !$_->is_confirmed } Bugzilla::Status->get_all ];
    $vars->{changes} = $changes;

    $template->process('admin/products/updated.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='editgroupcontrols' -> display product group controls
#

if ($action eq 'editgroupcontrols')
{
    my $product = $user->check_can_admin_product($product_name);

    $vars->{product} = $product;
    $vars->{token} = issue_session_token('edit_group_controls');

    $template->process('admin/products/groupcontrol/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# action='updategroupcontrols' -> update product group controls
#

if ($action eq 'updategroupcontrols')
{
    my $product = $user->check_can_admin_product($product_name);
    check_token_data($token, 'edit_group_controls');

    my @now_na = ();
    my @now_mandatory = ();
    my %membercontrol_g;
    my %othercontrol_g;
    foreach my $f (keys %$ARGS)
    {
        if ($f =~ /^group_(\d+)$/)
        {
            my $count_id = $1;
            my $id = $ARGS->{$f};
            next if !$id;
            trick_taint($id);
            if ($ARGS->{"membercontrol_$count_id"} == CONTROLMAPNA)
            {
                push @now_na, $id;
            }
            elsif ($ARGS->{"membercontrol_$count_id"} == CONTROLMAPMANDATORY)
            {
                push @now_mandatory, $id;
            }
            $membercontrol_g{$id} = $ARGS->{"membercontrol_$count_id"};
            $othercontrol_g{$id} = $ARGS->{"othercontrol_$count_id"};
        }
    }

    if (!defined $ARGS->{confirmed})
    {
        my $na_groups;
        if (@now_na)
        {
            $na_groups = $dbh->selectall_arrayref(
                'SELECT groups.name, COUNT(bugs.bug_id) AS count FROM bugs' .
                ' INNER JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id' .
                ' INNER JOIN groups ON bug_group_map.group_id = groups.id' .
                ' WHERE groups.id IN (' . join(', ', @now_na) . ') AND bugs.product_id = ? ' .
                $dbh->sql_group_by('groups.name'),
                {Slice => {}}, $product->id
            );
        }

        # return the mandatory groups which need to have bug entries
        # added to the bug_group_map and the corresponding bug count

        my $mandatory_groups;
        if (@now_mandatory)
        {
            $mandatory_groups = $dbh->selectall_arrayref(
                'SELECT groups.name, ('.
                    ' SELECT COUNT(bugs.bug_id) FROM bugs'.
                    ' WHERE bugs.product_id = ? AND bugs.bug_id NOT IN ('.
                        ' SELECT bug_group_map.bug_id FROM bug_group_map'.
                        ' WHERE bug_group_map.group_id = groups.id'.
                    ')) AS count'.
                ' FROM groups WHERE groups.id IN (' . join(', ', @now_mandatory) . ')'.
                ' ORDER BY groups.name', {Slice => {}}, $product->id
            );
            # remove zero counts
            @$mandatory_groups = grep { $_->{count} } @$mandatory_groups;

        }
        if (($na_groups && scalar(@$na_groups))
            || ($mandatory_groups && scalar(@$mandatory_groups)))
        {
            $vars->{product} = $product;
            $vars->{na_groups} = $na_groups;
            $vars->{mandatory_groups} = $mandatory_groups;
            $template->process('admin/products/groupcontrol/confirm-edit.html.tmpl', $vars)
                || ThrowTemplateError($template->error());
            exit;
        }
    }

    my $groups = Bugzilla::Group->match({isactive => 1, isbuggroup => 1});
    foreach my $group (@$groups)
    {
        my $group_id = $group->id;
        $product->set_group_controls($group, {
            entry          => $ARGS->{"entry_$group_id"} || 0,
            membercontrol  => $membercontrol_g{$group_id} || CONTROLMAPNA,
            othercontrol   => $othercontrol_g{$group_id} || CONTROLMAPNA,
            canedit        => $ARGS->{"canedit_$group_id"} || 0,
            editcomponents => $ARGS->{"editcomponents_$group_id"} || 0,
            editbugs       => $ARGS->{"editbugs_$group_id"} || 0,
            canconfirm     => $ARGS->{"canconfirm_$group_id"} || 0,
        });
    }
    my $changes = $product->update;

    delete_token($token);

    $vars->{product} = $product;
    $vars->{changes} = $changes;

    $template->process('admin/products/groupcontrol/updated.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

#
# No valid action found
#

ThrowUserError('no_valid_action', {field => 'product'});
