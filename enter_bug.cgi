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
# Corporation. Portions created by Netscape are Copyright (C) 1998
# Netscape Communications Corporation. All Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dave Miller <justdave@syndicomm.com>
#                 Joe Robins <jmrobins@tgix.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Shane H. W. Travis <travis@sedsystems.ca>
#                 Nitish Bezzala <nbezzala@yahoo.com>
#
# Deep refactoring by Vitaliy Filippov <vitalif@mail.ru> -- see http://wiki.4intra.net

##############################################################################
#
# enter_bug.cgi
# -------------
# Displays bug entry form. Bug fields are specified through popup menus,
# drop-down lists, or text fields. Default for these values can be
# passed in as parameters to the cgi.
#
##############################################################################

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::User;
use Bugzilla::Hook;
use Bugzilla::Product;
use Bugzilla::Classification;
use Bugzilla::Keyword;
use Bugzilla::Token;
use Bugzilla::Field;
use Bugzilla::Status;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cloned_bug;
my $cloned_bug_id;

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = $cgi->VarHash({
    (map { ($_->name => 1) } grep { $_->type == FIELD_TYPE_MULTI_SELECT } Bugzilla->active_custom_fields),
});

# All pages point to the same part of the documentation.
$vars->{doc_section} = 'bugreports.html';

my $product_name = trim($ARGS->{product} || '');
# Will contain the product object the bug is created in.
my $product;

if ($product_name eq '')
{
    # Save URL parameters
    $vars->{query_params} = http_build_query($ARGS);

    # If the user cannot enter bugs in any product, stop here.
    my @enterable_products = @{$user->get_enterable_products};
    ThrowUserError('no_products') unless scalar(@enterable_products);

    my $classification = Bugzilla->get_field('classification')->enabled ? $ARGS->{classification} : '__all';

    # Unless a real classification name is given, we sort products
    # by classification.
    my @classifications;

    unless ($classification && $classification ne '__all')
    {
        if (Bugzilla->get_field('classification')->enabled)
        {
            my $class;
            # Get all classifications with at least one enterable product.
            foreach my $product (@enterable_products)
            {
                $class->{$product->classification_id}->{object} ||=
                    new Bugzilla::Classification($product->classification_id);
                # Nice way to group products per classification, without querying
                # the DB again.
                push(@{$class->{$product->classification_id}->{products}}, $product);
            }
            @classifications = sort { $a->{object}->sortkey <=> $b->{object}->sortkey
                || lc($a->{object}->name) cmp lc($b->{object}->name) } values %$class;
        }
        else
        {
            @classifications = ({ object => undef, products => \@enterable_products });
        }
    }

    unless ($classification)
    {
        # We know there is at least one classification available,
        # else we would have stopped earlier.
        if (scalar(@classifications) > 1)
        {
            # We only need classification objects.
            $vars->{classifications} = [ map { $_->{object} } @classifications ];

            $vars->{target} = "enter_bug.cgi";
            $vars->{format} = $ARGS->{format};
            $vars->{cloned_bug_id} = $ARGS->{cloned_bug_id};
            $vars->{cloned_comment} = $ARGS->{cloned_comment};

            $template->process("global/choose-classification.html.tmpl", $vars)
                || ThrowTemplateError($template->error());
            exit;
        }
        # If we come here, then there is only one classification available.
        $classification = $classifications[0]->{object}->name;
    }

    # Keep only enterable products which are in the specified classification.
    if ($classification ne "__all")
    {
        my $class = new Bugzilla::Classification({ name => $classification });
        # If the classification doesn't exist, then there is no product in it.
        if ($class)
        {
            @enterable_products = grep { $_->classification_id == $class->id } @enterable_products;
            @classifications = ({object => $class, products => \@enterable_products});
        }
        else
        {
            @enterable_products = ();
        }
    }

    if (scalar(@enterable_products) == 0)
    {
        ThrowUserError('no_products');
    }
    elsif (scalar(@enterable_products) > 1)
    {
        $vars->{classifications} = \@classifications;
        $vars->{target} = 'enter_bug.cgi';
        $vars->{format} = $ARGS->{format};
        $vars->{cloned_bug_id} = $ARGS->{cloned_bug_id};
        $vars->{cloned_comment} = $ARGS->{cloned_comment};

        $template->process('global/choose-product.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
        exit;
    }
    else
    {
        # Only one product exists.
        $product = $enterable_products[0];
    }
}
else
{
    # Do not use Bugzilla::Product::check_product() here, else the user
    # could know whether the product doesn't exist or is not accessible.
    $product = new Bugzilla::Product({ name => $product_name });
}

# We need to check and make sure that the user has permission
# to enter a bug against this product.
$user->can_enter_product($product ? $product->name : $product_name, THROW_ERROR);

sub pick_by_ua
{
    my ($ARGS, $field) = @_;
    return $ARGS->{$field} if $ARGS->{$field};
    $field = Bugzilla->get_field($field);
    if (my $id = $field->default_value)
    {
        my ($v) = grep { $_->id == $id } @{ $field->legal_values };
        return $v->name if $v;
    }
    else
    {
        my $ua = $ENV{HTTP_USER_AGENT};
        for my $v (@{ $field->legal_values })
        {
            my $re = $v->ua_regex;
            if ($re && $ua =~ /$re/i)
            {
                return $v->name;
            }
        }
    }
    return undef;
}

sub components_json
{
    my ($product) = @_;
    my $components = {};
    for my $c (@{$product->active_components})
    {
        $components->{$c->name} = {
            name => $c->name,
            default_version => $c->default_version && $c->default_version_obj->name,
            description => html_light_quote($c->description),
            default_assignee => $c->default_assignee && $c->default_assignee->login,
            default_qa_contact => $c->default_qa_contact && $c->default_qa_contact->login,
            initial_cc => [ map { $_->login } @{$c->initial_cc} ],
            flags => {
                (map { $_->id => 1 } grep { $_->is_active } @{$c->flag_types->{bug}}),
                (map { $_->id => 1 } grep { $_->is_active } @{$c->flag_types->{attachment}}),
            },
        };
    }
    return $components;
}

##############################################################################
# End of subroutines
##############################################################################

my $has_editbugs = $user->in_group('editbugs', $product->id);
my $has_canconfirm = $user->in_group('canconfirm', $product->id);

# If a user is trying to clone a bug
#   Check that the user has authorization to view the parent bug
#   Create an instance of Bug that holds the info from the parent
$cloned_bug_id = $ARGS->{cloned_bug_id};

if ($cloned_bug_id)
{
    $cloned_bug = Bugzilla::Bug->check($cloned_bug_id);
    $cloned_bug_id = $cloned_bug->id;
}

if (scalar(@{$product->active_components}) == 1)
{
    # Only one component; just pick it.
    $ARGS->{component} = $product->components->[0]->name;
}

my %default;

$vars->{product} = $product;
$vars->{components_json} = components_json($product);
$vars->{product_flag_type_ids} = [ map { $_->id } map { @$_ } values %{$product->flag_types} ];

# CustIS Bug 65812 - Flags are not restored from bug entry template
{
    my $types = $product->flag_types->{bug};
    for (@$types)
    {
        $_->{default_value} = $ARGS->{'flag_type-'.$_->id};
        $_->{default_requestee} = $ARGS->{'requestee_type-'.$_->id};
    }
    $vars->{product_flag_types} = $types;
}

$default{assigned_to}          = $ARGS->{assigned_to};
$vars->{assigned_to_disabled}  = !$has_editbugs;
$vars->{cc_disabled}           = 0;

$default{qa_contact}           = $ARGS->{qa_contact};
$vars->{qa_contact_disabled}   = !$has_editbugs;

$vars->{cloned_bug_id}         = $cloned_bug_id;

$vars->{token}                 = issue_session_token('createbug:');

foreach my $field (Bugzilla->active_custom_fields)
{
    my $cf_name = $field->name;
    my $cf_value = $ARGS->{$cf_name};
    if (defined $cf_value)
    {
        $default{$cf_name} = $cf_value;
    }
    elsif ($field->default_value && !$field->is_select)
    {
        # Default values for select fields are filled by bug-visibility.js
        $default{$cf_name} = $field->default_value;
    }
}

# This allows the Field visibility and value controls to work with the
# Product field as a parent.
$default{product} = $product->name;
$default{product_obj} = $product;

if ($cloned_bug_id)
{
    $default{dependson} = "";
    $default{blocked} = $cloned_bug_id;

    my @cc;
    my $comp = $cloned_bug->component_obj;
    if ($comp && $product->id != $cloned_bug->product_id)
    {
        @cc = @{$comp->initial_cc || []};
    }
    elsif ($ARGS->{cc})
    {
        @cc = @{ Bugzilla::User->match({ login_name => [ split /[\s,]+/, $ARGS->{cc} ] }) };
    }
    elsif (@{$cloned_bug->cc_users})
    {
        @cc = @{$cloned_bug->cc_users};
    }

    if ($cloned_bug->reporter->id != $user->id)
    {
        push @cc, $cloned_bug->reporter;
    }

    # CustIS Bug 38616 - CC list restriction
    if (my $ccg = $product->cc_group)
    {
        my @removed;
        for (my $i = $#cc; $i >= 0; $i--)
        {
            if (!$cc[$i]->in_group_id($ccg))
            {
                push @removed, splice @cc, $i, 1;
            }
        }
        if (@removed)
        {
            Bugzilla->add_result_message({
                message => 'cc_list_restricted',
                cc_restrict_group => $product->cc_group_obj->name,
                restricted_cc => [ map { $_->login } @removed ],
            });
        }
    }

    $vars->{cc} = join ', ', map { $_->login } @cc;

    # Copy values of fields marked with 'clone_bug = TRUE'
    foreach my $field (Bugzilla->get_fields({ obsolete => 0, clone_bug => 1 }))
    {
        my $field_name = $field->name;
        next if $field_name eq 'product' || $field_name eq 'classification' ||
            $field->type == FIELD_TYPE_BUG_ID_REV ||
            !$field->check_clone($cloned_bug);
        if ($field->type == FIELD_TYPE_SINGLE_SELECT)
        {
            # component is a keyword in TT... :-X.($field_name eq 'component' ? '_' : '')
            $default{$field_name} = $cloned_bug->get_string($field_name);
        }
        elsif ($field->type == FIELD_TYPE_MULTI_SELECT)
        {
            $default{$field_name} = [ map { $_->name } @{ $cloned_bug->get_object($field_name) } ];
        }
        elsif (Bugzilla::Bug::_validate_attribute($field_name))
        {
            $default{$field_name} = $cloned_bug->$field_name;
        }
    }

    # We need to ensure that we respect the 'insider' status of
    # the first comment, if it has one. Either way, make a note
    # that this bug was cloned from another bug.

    my $cloned_comment = $ARGS->{cloned_comment} || 0;
    my $bug_desc = $cloned_bug->comments({ order => 'oldest_to_newest' });
    my ($comment_obj) = grep { $_->{count} == $cloned_comment } @$bug_desc;
    $comment_obj ||= $bug_desc->[0];
    my $isprivate = $comment_obj->is_private;

    $vars->{comment} = '';
    $vars->{commentprivacy} = 0;

    if (!$isprivate || Bugzilla->user->is_insider)
    {
        # We use "body" to avoid any format_comment text, which would be
        # pointless to clone.
        $vars->{cloned_comment} = $cloned_comment;
        $vars->{comment}        = $comment_obj->body;
        $vars->{comment}        =~ s!bug\s*#?\s*(\d+)\s*,?\s*comment\s*#?\s*(\d+)!Bug $cloned_bug_id, comment $2!gso;
        # CustIS Bug 66177: Attachment link in cloned comment
        if ($bug_desc->[$cloned_comment]->type == CMT_ATTACHMENT_CREATED)
        {
            $vars->{comment} = "Created attachment ".$comment_obj->extra_data."\n$vars->{comment}";
        }
        $vars->{commentprivacy} = $isprivate;
    }

    Bugzilla::Hook::process('enter_bug_cloned_bug', { vars => $vars, default => \%default, product => $product, cloned_bug => $cloned_bug });
} # end of cloned bug entry form
else
{
    $default{component_}    = $ARGS->{component};
    $default{priority}      = $ARGS->{priority} || Bugzilla->params->{defaultpriority};
    $default{bug_severity}  = $ARGS->{bug_severity} || Bugzilla->params->{defaultseverity};
    $default{rep_platform}  = pick_by_ua($ARGS, 'rep_platform') if Bugzilla->get_field('rep_platform')->enabled;
    $default{op_sys}        = pick_by_ua($ARGS, 'op_sys') if Bugzilla->get_field('op_sys')->enabled;

    $default{alias}          = $ARGS->{alias};
    $default{short_desc}     = $ARGS->{short_desc};
    $default{bug_file_loc}   = $ARGS->{bug_file_loc} || "http://";
    $default{keywords}       = $ARGS->{keywords};
    $default{status_whiteboard} = $ARGS->{status_whiteboard};
    $default{dependson}      = $ARGS->{dependson};
    $default{blocked}        = $ARGS->{blocked};
    $default{deadline}       = $ARGS->{deadline};
    $default{estimated_time} = 0+($ARGS->{estimated_time} || 0) || "0.0";
    $default{work_time}      = 0+($ARGS->{work_time} || 0) || "0.0";

    $vars->{cc}             = $ARGS->{cc};

    $vars->{comment}        = $ARGS->{comment};
    $vars->{commentprivacy} = $ARGS->{commentprivacy};
} # end of normal/bookmarked entry form

# IF this is a cloned bug,
# AND the clone's product is the same as the parent's
#   THEN use the version from the parent bug
# ELSE IF a version is supplied in the URL
#   THEN use it
# ELSE IF there is a default version for the selected component
#   THEN use it
# ELSE IF there is a version in the cookie
#   THEN use it (Posting a bug sets a cookie for the current version.)
# ELSE
#   The default version is the last one in the list (which, it is
#   hoped, will be the most recent one).
#
# Eventually maybe each product should have a "current version"
# parameter.
my $vercookie = $cgi->cookie('VERSION-' . $product->name);
if ($cloned_bug_id && $product->name eq $cloned_bug->product)
{
    $default{version} = $cloned_bug->version && $cloned_bug->version_obj->name;
}
elsif ($ARGS->{version})
{
    $default{version} = $ARGS->{version};
}
elsif (defined $vercookie && grep { $_ eq $vercookie } @{$vars->{version}})
{
    $default{version} = $vercookie;
}

# Get list of milestones.
if (Bugzilla->get_field('target_milestone')->enabled)
{
    if ($ARGS->{target_milestone})
    {
        $default{target_milestone} = $ARGS->{target_milestone};
    }
    else
    {
        $default{target_milestone} = $product->default_milestone && $product->default_milestone_obj->name;
    }
}

# Construct the list of allowable statuses.
my $initial_statuses = Bugzilla::Status->can_change_to();

# Exclude closed states from the UI, even if the workflow allows them.
# The back-end code will still accept them, though.
@$initial_statuses = grep { $_->name eq Bugzilla->params->{duplicate_or_move_bug_status} || $_->is_open } @$initial_statuses;

if (!$product->allows_unconfirmed)
{
    # UNCONFIRMED is illegal if allows_unconfirmed is false.
    @$initial_statuses = grep { $_->is_confirmed } @$initial_statuses;
}
scalar(@$initial_statuses) || ThrowUserError('no_initial_bug_status');

# If the user has no privs...
unless ($has_editbugs || $has_canconfirm)
{
    # ... use UNCONFIRMED if available, else use the first status of the list.
    my ($bug_status) = grep { !$_->is_confirmed } @$initial_statuses;
    $bug_status ||= $initial_statuses->[0];
    @$initial_statuses = ($bug_status);
}

$vars->{bug_status} = $initial_statuses;

# Get the default from a template value if it is legitimate.
# Otherwise, and only if the user has privs, set the default
# to the first confirmed bug status on the list, if available.

$default{bug_status} = $ARGS->{bug_status};
if (!$default{bug_status} || !grep { $_->name eq $default{bug_status} } @$initial_statuses)
{
    $default{bug_status} = $initial_statuses->[0]->name;
}

my $grouplist = $dbh->selectall_arrayref(
    'SELECT DISTINCT groups.id, groups.name, groups.description, membercontrol, othercontrol'.
    ' FROM groups LEFT JOIN group_control_map'.
    ' ON group_id = id AND product_id = ?'.
    ' WHERE isbuggroup != 0 AND isactive != 0'.
    ' ORDER BY description', undef, $product->id
);

my @groups;

foreach my $row (@$grouplist)
{
    my ($id, $groupname, $description, $membercontrol, $othercontrol) = @$row;
    # Only include groups if the entering user will have an option.
    next if !$membercontrol || $membercontrol == CONTROLMAPNA || $membercontrol == CONTROLMAPMANDATORY
        || ($othercontrol != CONTROLMAPSHOWN && $othercontrol != CONTROLMAPDEFAULT && !Bugzilla->user->in_group($groupname));
    my $check;

    # If this is a cloned bug,
    # AND the product for this bug is the same as for the original
    #   THEN set a group's checkbox if the original also had it on
    # ELSE IF this is a bookmarked template
    #   THEN set a group's checkbox if was set in the bookmark
    # ELSE
    #   set a groups's checkbox based on the group control map
    if ($cloned_bug_id && ($product->name eq $cloned_bug->product))
    {
        foreach my $i (0..$#{$cloned_bug->groups})
        {
            if ($cloned_bug->groups->[$i]->{bit} == $id)
            {
                $check = $cloned_bug->groups->[$i]->{ison};
            }
        }
    }
    elsif ($ARGS->{maketemplate})
    {
        $check = $ARGS->{"bit-$id"} || 0;
    }
    else
    {
        # Checkbox is checked by default if $control is a default state.
        $check = $membercontrol == CONTROLMAPDEFAULT
            || $othercontrol == CONTROLMAPDEFAULT && !Bugzilla->user->in_group($groupname);
    }

    my $group = {
        bit => $id,
        checked => $check,
        description => $description,
    };

    push @groups, $group;
}

$vars->{group} = \@groups;

Bugzilla::Hook::process('enter_bug_entrydefaultvars', { vars => $vars });

$vars->{default} = \%default;

my $format = $template->get_format('bug/create/create', $ARGS->{format}, $ARGS->{ctype});

$cgi->send_header($format->{ctype});
$template->process($format->{template}, $vars)
    || ThrowTemplateError($template->error());
exit;
