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
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Myk Melez <myk@mozilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

################################################################################
# Script Initialization
################################################################################

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Flag;
use Bugzilla::FlagType;
use Bugzilla::Group;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Bug;
use Bugzilla::Attachment;
use Bugzilla::Token;

local our $ARGS = Bugzilla->input_params;
local our $template = Bugzilla->template;
local our $vars = {};

# Make sure the user is logged in and is an administrator.
my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editflagtypes') || ThrowUserError("auth_failure", {
    group  => "editflagtypes",
    action => "edit",
    object => "flagtypes",
});

# We need this everywhere.
$vars = get_products_and_components($vars);

################################################################################
# Main Body Execution
################################################################################

# All calls to this script should contain an "action" variable whose value
# determines what the user wants to do.  The code below checks the value of
# that variable and runs the appropriate code.

# Determine whether to use the action specified by the user or the default.
my $action = $ARGS->{action} || 'list';
my $token  = $ARGS->{token};
my @categoryActions;

if (@categoryActions = grep(/^categoryAction-.+/, keys %$ARGS))
{
    $categoryActions[0] =~ s/^categoryAction-//;
    processCategoryChange($categoryActions[0], $token);
    exit;
}

if    ($action eq 'list')           { ft_list();        }
elsif ($action eq 'enter')          { edit($action);    }
elsif ($action eq 'copy')           { edit($action);    }
elsif ($action eq 'edit')           { edit($action);    }
elsif ($action eq 'insert')         { insert($token);   }
elsif ($action eq 'update')         { update($token);   }
elsif ($action eq 'confirmdelete')  { confirmDelete();  } 
elsif ($action eq 'delete')         { deleteType($token); }
elsif ($action eq 'deactivate')     { deactivate($token); }
else {
    ThrowCodeError("action_unrecognized", { action => $action });
}

exit;

################################################################################
# Functions
################################################################################

sub get_prod_comp
{
    my $product = $ARGS->{product} || undef;
    my $component;
    if ($product)
    {
        $product = Bugzilla::Product::check_product($product);
        $component = $ARGS->{component} || undef;
        $component = Bugzilla::Component->check({ product => $product, name => $component }) if $component;
    }
    return ($product, $component);
}

sub ft_list
{
    my ($product, $component) = get_prod_comp();
    my $product_id = $product ? $product->id : 0;
    my $component_id = $component ? $component->id : 0;
    my $show_flag_counts = $ARGS->{show_flag_counts} && 1;

    # Define the variables and functions that will be passed to the UI template.
    $vars->{selected_product} = $ARGS->{product};
    $vars->{selected_component} = $ARGS->{component};

    my $bug_flagtypes;
    my $attach_flagtypes;

    # If a component is given, restrict the list to flag types available
    # for this component.
    if ($component)
    {
        $bug_flagtypes = $component->flag_types->{bug};
        $attach_flagtypes = $component->flag_types->{attachment};

        # Filter flag types if a group ID is given.
        $bug_flagtypes = filter_group($bug_flagtypes);
        $attach_flagtypes = filter_group($attach_flagtypes);
    }
    # If only a product is specified but no component, then restrict the list
    # to flag types available in at least one component of that product.
    elsif ($product)
    {
        $bug_flagtypes = $product->flag_types->{bug};
        $attach_flagtypes = $product->flag_types->{attachment};

        # Filter flag types if a group ID is given.
        $bug_flagtypes = filter_group($bug_flagtypes);
        $attach_flagtypes = filter_group($attach_flagtypes);
    }
    # If no product is given, then show all flag types available.
    else
    {
        $bug_flagtypes = Bugzilla::FlagType::match({
            target_type => 'bug', group => $ARGS->{group}
        });
        $attach_flagtypes = Bugzilla::FlagType::match({
            target_type => 'attachment', group => $ARGS->{group}
        });
    }

    if ($show_flag_counts)
    {
        my %bug_lists;
        my %map = ('+' => 'granted', '-' => 'denied', '?' => 'pending');
        foreach my $flagtype (@$bug_flagtypes, @$attach_flagtypes)
        {
            $bug_lists{$flagtype->id} = {};
            my $flags = Bugzilla::Flag->match({type_id => $flagtype->id});
            # Build lists of bugs, triaged by flag status.
            push @{$bug_lists{$flagtype->id}->{$map{$_->status}}}, $_->bug_id for @$flags;
        }
        $vars->{bug_lists} = \%bug_lists;
        $vars->{show_flag_counts} = 1;
    }

    $vars->{bug_types} = $bug_flagtypes;
    $vars->{attachment_types} = $attach_flagtypes;

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("admin/flag-type/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub edit
{
    my ($action) = @_;
    my $flag_type;
    my $target_type;
    if ($action eq 'enter')
    {
        $target_type = $ARGS->{target_type} eq 'attachment' ? 'attachment' : 'bug';
    }
    else
    {
        $flag_type = validateID();
    }

    $vars->{last_action} = $ARGS->{action};
    if ($ARGS->{action} eq 'enter' || $ARGS->{action} eq 'copy')
    {
        $vars->{action} = "insert";
        $vars->{token} = issue_session_token('add_flagtype');
    }
    else
    {
        $vars->{action} = "update";
        $vars->{token} = issue_session_token('edit_flagtype');
    }

    # If copying or editing an existing flag type, retrieve it.
    if ($ARGS->{action} eq 'copy' || $ARGS->{action} eq 'edit')
    {
        $vars->{type} = $flag_type;
    }
    # Otherwise set the target type (the minimal information about the type
    # that the template needs to know) from the URL parameter and default
    # the list of inclusions to all categories.
    else
    {
        my %inclusions;
        $inclusions{"0:0"} = "__Any__:__Any__";
        $vars->{type} = {
            target_type => $target_type,
            inclusions  => \%inclusions,
        };
    }
    # Get a list of groups available to restrict this flag type against.
    my @groups = Bugzilla::Group->get_all;
    $vars->{groups} = \@groups;

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("admin/flag-type/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub processCategoryChange
{
    my ($categoryAction, $token) = @_;

    my @inclusions = list $ARGS->{inclusions};
    my @exclusions = list $ARGS->{exclusions};
    if ($categoryAction eq 'include')
    {
        my ($product, $component) = get_prod_comp();
        my $category = ($product ? $product->id : 0) . ":" . ($component ? $component->id : 0);
        push(@inclusions, $category) unless grep($_ eq $category, @inclusions);
    }
    elsif ($categoryAction eq 'exclude')
    {
        my ($product, $component) = get_prod_comp();
        my $category = ($product ? $product->id : 0) . ":" . ($component ? $component->id : 0);
        push(@exclusions, $category) unless grep($_ eq $category, @exclusions);
    }
    elsif ($categoryAction eq 'removeInclusion')
    {
        my %rem = map { $_ => 1 } list $ARGS->{inclusion_to_remove};
        @inclusions = grep { !$rem{$_} } @inclusions;
    }
    elsif ($categoryAction eq 'removeExclusion')
    {
        my %rem = map { $_ => 1 } list $ARGS->{exclusion_to_remove};
        @exclusions = grep { !$rem{$_} } @exclusions;
    }

    # Convert the array @clusions('prod_ID:comp_ID') back to a hash of
    # the form %clusions{'prod_ID:comp_ID'} = 'prod_name:comp_name'
    my %inclusions = clusion_array_to_hash(\@inclusions);
    my %exclusions = clusion_array_to_hash(\@exclusions);

    my @groups = Bugzilla::Group->get_all;
    $vars->{groups} = \@groups;
    $vars->{action} = $ARGS->{action};

    my $type = {};
    foreach my $key (keys %$ARGS)
    {
        $type->{$key} = $ARGS->{$key};
    }
    # That's what I call a big hack. The template expects to see a group object.
    # This script needs some rewrite anyway.
    $type->{grant_group} = {};
    $type->{grant_group}->{name} = $ARGS->{grant_group};
    $type->{request_group} = {};
    $type->{request_group}->{name} = $ARGS->{request_group};

    $type->{inclusions} = \%inclusions;
    $type->{exclusions} = \%exclusions;
    $vars->{type} = $type;
    $vars->{token} = $token;

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("admin/flag-type/edit.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

# Convert the array @clusions('prod_ID:comp_ID') back to a hash of
# the form %clusions{'prod_ID:comp_ID'} = 'prod_name:comp_name'
sub clusion_array_to_hash
{
    my $array = shift;
    my %hash;
    my %products;
    my %components;
    foreach my $ids (@$array)
    {
        trick_taint($ids);
        my ($product_id, $component_id) = split(":", $ids);
        my $product_name = "__Any__";
        if ($product_id)
        {
            $products{$product_id} ||= new Bugzilla::Product($product_id);
            $product_name = $products{$product_id}->name if $products{$product_id};
        }
        my $component_name = "__Any__";
        if ($component_id)
        {
            $components{$component_id} ||= new Bugzilla::Component($component_id);
            $component_name = $components{$component_id}->name if $components{$component_id};
        }
        $hash{$ids} = "$product_name:$component_name";
    }
    return %hash;
}

sub insert
{
    my $token = shift;
    check_token_data($token, 'add_flagtype');

    Bugzilla->dbh->bz_start_transaction;

    my $ft = Bugzilla::FlagType->create({
        map { ($_ => $ARGS->{$_}) } (Bugzilla::FlagType->UPDATE_COLUMNS, 'cc_list')
    });

    # Populate the list of inclusions/exclusions for this flag type.
    validateAndSubmit($ft->id);

    Bugzilla->dbh->bz_commit_transaction;

    $vars->{name} = $ft->name;
    $vars->{message} = "flag_type_created";
    delete_token($token);

    $vars->{bug_types} = Bugzilla::FlagType::match({ target_type => 'bug' });
    $vars->{attachment_types} = Bugzilla::FlagType::match({ target_type => 'attachment' });

    $template->process("admin/flag-type/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub update
{
    my $token = shift;
    check_token_data($token, 'edit_flagtype');

    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    my $flag_type = validateID();
    for (Bugzilla::FlagType->UPDATE_COLUMNS, 'cc_list')
    {
        $flag_type->set($_, $ARGS->{$_});
    }
    $flag_type->update;

    # Update the list of inclusions/exclusions for this flag type.
    validateAndSubmit($flag_type->id);

    $dbh->bz_commit_transaction();

    # Clear existing flags for bugs/attachments in categories no longer on 
    # the list of inclusions or that have been added to the list of exclusions.
    my $flag_ids = $dbh->selectcol_arrayref(
        'SELECT DISTINCT flags.id FROM flags'.
        ' INNER JOIN bugs ON flags.bug_id = bugs.bug_id'.
        ' LEFT JOIN flaginclusions AS i ON (flags.type_id = i.type_id'.
        ' AND (bugs.product_id = i.product_id OR i.product_id IS NULL)'.
        ' AND (bugs.component_id = i.component_id OR i.component_id IS NULL))'.
        ' WHERE flags.type_id = ? AND i.type_id IS NULL',
        undef, $flag_type->id
    );
    Bugzilla::Flag->force_retarget($flag_ids);

    $flag_ids = $dbh->selectcol_arrayref(
        'SELECT DISTINCT flags.id FROM flags'.
        ' INNER JOIN bugs ON flags.bug_id = bugs.bug_id'.
        ' INNER JOIN flagexclusions AS e ON flags.type_id = e.type_id'.
        ' WHERE flags.type_id = ?'.
        ' AND (bugs.product_id = e.product_id OR e.product_id IS NULL)'.
        ' AND (bugs.component_id = e.component_id OR e.component_id IS NULL)',
        undef, $flag_type->id
    );
    Bugzilla::Flag->force_retarget($flag_ids);

    # Now silently remove requestees from flags which are no longer
    # specifically requestable.
    if (!$flag_type->is_requesteeble)
    {
        $dbh->do('UPDATE flags SET requestee_id = NULL WHERE type_id = ?', undef, $flag_type->id);
    }

    $vars->{name} = $flag_type->name;
    $vars->{message} = "flag_type_changes_saved";
    delete_token($token);

    $vars->{bug_types} = Bugzilla::FlagType::match({ target_type => 'bug' });
    $vars->{attachment_types} = Bugzilla::FlagType::match({ target_type => 'attachment' });

    $template->process("admin/flag-type/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub confirmDelete
{
    my $flag_type = validateID();

    $vars->{flag_type} = $flag_type;
    $vars->{token} = issue_session_token('delete_flagtype');

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("admin/flag-type/confirm-delete.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub deleteType
{
    my $token = shift;
    check_token_data($token, 'delete_flagtype');
    my $flag_type = validateID();
    my $id = $flag_type->id;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    # Get the name of the flag type so we can tell users
    # what was deleted.
    $vars->{name} = $flag_type->name;

    $dbh->do('DELETE FROM flags WHERE type_id = ?', undef, $id);
    $dbh->do('DELETE FROM flaginclusions WHERE type_id = ?', undef, $id);
    $dbh->do('DELETE FROM flagexclusions WHERE type_id = ?', undef, $id);
    $dbh->do('DELETE FROM flagtypes WHERE id = ?', undef, $id);
    $dbh->bz_commit_transaction();

    $vars->{message} = "flag_type_deleted";
    delete_token($token);

    $vars->{bug_types} = Bugzilla::FlagType::match({'target_type' => 'bug'});
    $vars->{attachment_types} = Bugzilla::FlagType::match({'target_type' => 'attachment'});

    $template->process("admin/flag-type/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub deactivate
{
    my $token = shift;
    check_token_data($token, 'delete_flagtype');
    my $flag_type = validateID();
    validateIsActive();

    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    $dbh->do('UPDATE flagtypes SET is_active = 0 WHERE id = ?', undef, $flag_type->id);
    $dbh->bz_commit_transaction();

    $vars->{message} = "flag_type_deactivated";
    $vars->{flag_type} = $flag_type;
    delete_token($token);

    $vars->{bug_types} = Bugzilla::FlagType::match({'target_type' => 'bug'});
    $vars->{attachment_types} = Bugzilla::FlagType::match({'target_type' => 'attachment'});

    # Generate and return the UI (HTML page) from the appropriate template.
    $template->process("admin/flag-type/list.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}

sub get_products_and_components
{
    my $vars = shift;
    my @products = Bugzilla::Product->get_all;
    # We require all unique component names.
    my %components;
    foreach my $product (@products)
    {
        foreach my $component (@{$product->components})
        {
            $components{$component->name} = 1;
        }
    }
    $vars->{products} = \@products;
    $vars->{components} = [sort(keys %components)];
    return $vars;
}

################################################################################
# Data Validation / Security Authorization
################################################################################

sub validateID
{
    my $id = $ARGS->{id};
    my $flag_type = new Bugzilla::FlagType($id)
        || ThrowCodeError('flag_type_nonexistent', { id => $id });
    return $flag_type;
}

# At this point, values either come the DB itself or have been recently
# added by the user and have passed all validation tests.
# The only way to have invalid product/component combinations is to
# hack the URL. So we silently ignore them, if any.
sub validateAndSubmit
{
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;

    # Cache product objects.
    my %products;
    foreach my $category_type ("inclusions", "exclusions")
    {
        # Will be used several times below.
        my $sth = $dbh->prepare(
            "INSERT INTO flag$category_type (type_id, product_id, component_id) VALUES (?, ?, ?)"
        );

        $dbh->do("DELETE FROM flag$category_type WHERE type_id = ?", undef, $id);
        foreach my $category (list $ARGS->{$category_type})
        {
            trick_taint($category);
            my ($product_id, $component_id) = split(":", $category);
            # Does the product exist?
            if ($product_id)
            {
                $products{$product_id} ||= new Bugzilla::Product($product_id);
                next unless defined $products{$product_id};
            }
            # A component was selected without a product being selected.
            next if (!$product_id && $component_id);
            # Does the component belong to this product?
            if ($component_id)
            {
                my @match = grep {$_->id == $component_id} @{$products{$product_id}->components};
                next unless scalar(@match);
            }
            $product_id ||= undef;
            $component_id ||= undef;
            $sth->execute($id, $product_id, $component_id);
        }
    }
}

sub filter_group
{
    my $flag_types = shift;
    return $flag_types unless $ARGS->{group};

    my $gid = $ARGS->{group};
    my @flag_types = grep {
        $_->grant_group && $_->grant_group->id == $gid ||
        $_->request_group && $_->request_group->id == $gid
    } @$flag_types;

    return \@flag_types;
}
