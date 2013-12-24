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
use Bugzilla::UserAgent;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cloned_bug;
my $cloned_bug_id;

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

# All pages point to the same part of the documentation.
$vars->{'doc_section'} = 'bugreports.html';

my $product_name = trim($cgi->param('product') || '');
# Will contain the product object the bug is created in.
my $product;

if ($product_name eq '') {
    # If the user cannot enter bugs in any product, stop here.
    my @enterable_products = @{$user->get_enterable_products};
    ThrowUserError('no_products') unless scalar(@enterable_products);

    my $classification = Bugzilla->params->{'useclassification'} ?
        scalar($cgi->param('classification')) : '__all';

    # Unless a real classification name is given, we sort products
    # by classification.
    my @classifications;

    unless ($classification && $classification ne '__all') {
        if (Bugzilla->params->{'useclassification'}) {
            my $class;
            # Get all classifications with at least one enterable product.
            foreach my $product (@enterable_products) {
                $class->{$product->classification_id}->{'object'} ||=
                    new Bugzilla::Classification($product->classification_id);
                # Nice way to group products per classification, without querying
                # the DB again.
                push(@{$class->{$product->classification_id}->{'products'}}, $product);
            }
            @classifications = sort {$a->{'object'}->sortkey <=> $b->{'object'}->sortkey
                                     || lc($a->{'object'}->name) cmp lc($b->{'object'}->name)}
                                    (values %$class);
        }
        else {
            @classifications = ({object => undef, products => \@enterable_products});
        }
    }

    unless ($classification) {
        # We know there is at least one classification available,
        # else we would have stopped earlier.
        if (scalar(@classifications) > 1) {
            # We only need classification objects.
            $vars->{'classifications'} = [map {$_->{'object'}} @classifications];

            $vars->{'target'} = "enter_bug.cgi";
            $vars->{'format'} = $cgi->param('format');
            $vars->{'cloned_bug_id'} = $cgi->param('cloned_bug_id');
            $vars->{'cloned_comment'} = $cgi->param('cloned_comment');

            $template->process("global/choose-classification.html.tmpl", $vars)
               || ThrowTemplateError($template->error());
            exit;
        }
        # If we come here, then there is only one classification available.
        $classification = $classifications[0]->{'object'}->name;
    }

    # Keep only enterable products which are in the specified classification.
    if ($classification ne "__all") {
        my $class = new Bugzilla::Classification({'name' => $classification});
        # If the classification doesn't exist, then there is no product in it.
        if ($class) {
            @enterable_products
              = grep {$_->classification_id == $class->id} @enterable_products;
            @classifications = ({object => $class, products => \@enterable_products});
        }
        else {
            @enterable_products = ();
        }
    }

    if (scalar(@enterable_products) == 0) {
        ThrowUserError('no_products');
    }
    elsif (scalar(@enterable_products) > 1) {
        $vars->{'classifications'} = \@classifications;
        $vars->{'target'} = "enter_bug.cgi";
        $vars->{'format'} = $cgi->param('format');
        $vars->{'cloned_bug_id'} = $cgi->param('cloned_bug_id');
        $vars->{'cloned_comment'} = $cgi->param('cloned_comment');

        $template->process("global/choose-product.html.tmpl", $vars)
          || ThrowTemplateError($template->error());
        exit;
    } else {
        # Only one product exists.
        $product = $enterable_products[0];
    }
}
else {
    # Do not use Bugzilla::Product::check_product() here, else the user
    # could know whether the product doesn't exist or is not accessible.
    $product = new Bugzilla::Product({'name' => $product_name});
}

##############################################################################
# Useful Subroutines
##############################################################################
sub formvalue {
    my ($name, $default) = (@_);
    return Bugzilla->cgi->param($name) || $default || "";
}

##############################################################################
# End of subroutines
##############################################################################

my $has_editbugs = $user->in_group('editbugs', $product->id);
my $has_canconfirm = $user->in_group('canconfirm', $product->id);

# If a user is trying to clone a bug
#   Check that the user has authorization to view the parent bug
#   Create an instance of Bug that holds the info from the parent
$cloned_bug_id = $cgi->param('cloned_bug_id');

if ($cloned_bug_id) {
    $cloned_bug = Bugzilla::Bug->check($cloned_bug_id);
    $cloned_bug_id = $cloned_bug->id;
}

if (scalar(@{$product->active_components}) == 1) {
    # Only one component; just pick it.
    $cgi->param('component', $product->components->[0]->name);
    $cgi->param('version', $product->components->[0]->default_version);
}

my %default;

$vars->{'product'}               = $product;

# CustIS Bug 65812 - Flags are not restored from bug entry template
{
    my $types = $product->flag_types->{bug};
    for (@$types)
    {
        $_->{default_value} = formvalue('flag_type-'.$_->id);
        $_->{default_requestee} = formvalue('requestee_type-'.$_->id);
    }
    $vars->{product_flag_types} = $types;
}

$vars->{'priority'}              = get_legal_field_values('priority');
$vars->{'bug_severity'}          = get_legal_field_values('bug_severity');
$vars->{'rep_platform'}          = get_legal_field_values('rep_platform') if Bugzilla->params->{useplatform};
$vars->{'op_sys'}                = get_legal_field_values('op_sys') if Bugzilla->params->{useopsys};

$vars->{'assigned_to'}           = formvalue('assigned_to');
$vars->{'assigned_to_disabled'}  = !$has_editbugs;
$vars->{'cc_disabled'}           = 0;

$vars->{'qa_contact'}           = formvalue('qa_contact');
$vars->{'qa_contact_disabled'}  = !$has_editbugs;

$vars->{'cloned_bug_id'}         = $cloned_bug_id;

$vars->{'token'} = issue_session_token('create_bug');

my @enter_bug_fields = grep { $_->enter_bug } Bugzilla->active_custom_fields;
foreach my $field (@enter_bug_fields) {
    my $cf_name = $field->name;
    my $cf_value = $cgi->param($cf_name);
    if (defined $cf_value) {
        if ($field->type == FIELD_TYPE_MULTI_SELECT) {
            $cf_value = [$cgi->param($cf_name)];
        }
        $default{$cf_name} = $vars->{$cf_name} = $cf_value;
    }
}

# This allows the Field visibility and value controls to work with the
# Classification and Product fields as a parent.
$default{'classification'} = $product->classification->name;
$default{'product'} = $product->name;
$default{'product_obj'} = $product;

if ($cloned_bug_id) {

    $default{'component_'}    = $cloned_bug->component;
    $default{'priority'}      = $cloned_bug->priority;
    $default{'bug_severity'}  = $cloned_bug->bug_severity;
    $default{'rep_platform'}  = $cloned_bug->rep_platform if Bugzilla->params->{useplatform};
    $default{'op_sys'}        = $cloned_bug->op_sys if Bugzilla->params->{useopsys};

    $vars->{'assigned_to'}  ||= $cloned_bug->component_obj->default_assignee->login;
    $vars->{'qa_contact'}   ||= $cloned_bug->component_obj->default_qa_contact->login;
    $vars->{'short_desc'}     = $cloned_bug->short_desc;
    $vars->{'bug_file_loc'}   = $cloned_bug->bug_file_loc;
    $vars->{'keywords'}       = $cloned_bug->keywords;
    $vars->{'dependson'}      = "";
    $vars->{'blocked'}        = $cloned_bug_id;
    $vars->{'deadline'}       = $cloned_bug->deadline;
    $vars->{'status_whiteboard'} = $cloned_bug->status_whiteboard;

    my @cc;
    my $comp = Bugzilla::Component->new({ product => $product, name => $cloned_bug->component });
    if ($comp && $product->id != $cloned_bug->product_id) {
        @cc = map { $_->login } @{$comp->initial_cc || []};
    } elsif (formvalue('cc')) {
        @cc = split /[\s,]+/, formvalue('cc');
    } elsif (defined $cloned_bug->cc) {
        @cc = @{$cloned_bug->cc};
    }

    if ($cloned_bug->reporter->id != $user->id) {
        push @cc, $cloned_bug->reporter->login;
    }

    # CustIS Bug 38616 - CC list restriction
    if ($product->cc_restrict_group)
    {
        my $removed = $product->restrict_cc(\@cc, 'login_name');
        if ($removed && @$removed)
        {
            $vars->{restricted_cc} = [ map { $_->login } @$removed ];
            $vars->{cc_restrict_group} = $product->cc_restrict_group;
            $vars->{message} = 'cc_list_restricted';
        }
    }

    $vars->{cc} = join ', ', @cc;

    # Copy values of custom fields marked with 'clone_bug = TRUE'
    # But don't copy values of custom fields which are invisible for the new product
    my @clone_bug_fields = grep { $_->clone_bug &&
        (!$_->visibility_field || $_->visibility_field->name ne 'product' ||
        $_->has_visibility_value($product))
    } Bugzilla->active_custom_fields;
    foreach my $field (@clone_bug_fields)
    {
        my $field_name = $field->name;
        $vars->{$field_name} = $cloned_bug->$field_name;
    }

    # We need to ensure that we respect the 'insider' status of
    # the first comment, if it has one. Either way, make a note
    # that this bug was cloned from another bug.

    my $cloned_comment = formvalue('cloned_comment', 0);
    my $bug_desc = $cloned_bug->comments({ order => 'oldest_to_newest' });
    my ($comment_obj) = grep { $_->{count} == $cloned_comment } @$bug_desc;
    $comment_obj ||= $bug_desc->[0];
    my $isprivate = $comment_obj->is_private;

    $vars->{'comment'} = "";
    $vars->{'comment_is_private'} = 0;

    if (!$isprivate || $user->is_insider) {
        # We use "body" to avoid any format_comment text, which would be
        # pointless to clone.
        $vars->{'cloned_comment'} = $cloned_comment;
        $vars->{'comment'}        = $comment_obj->body;
        $vars->{'comment'}        =~ s!bug\s*#?\s*(\d+)\s*,?\s*comment\s*#?\s*(\d+)!Bug $cloned_bug_id, comment $2!gso;
        # CustIS Bug 66177: Attachment link in cloned comment
        if ($bug_desc->[$cloned_comment]->type == CMT_ATTACHMENT_CREATED)
        {
            $vars->{comment} = "Created attachment ".$comment_obj->extra_data."\n$vars->{comment}";
        }
        $vars->{'comment_is_private'} = $isprivate;
    }

    Bugzilla::Hook::process('enter_bug_cloned_bug', { vars => $vars, product => $product, cloned_bug => $cloned_bug });
} # end of cloned bug entry form

else {
    $default{'component_'}    = formvalue('component');
    $default{'priority'}      = formvalue('priority', Bugzilla->params->{'defaultpriority'});
    $default{'bug_severity'}  = formvalue('bug_severity', Bugzilla->params->{'defaultseverity'});
    $default{'rep_platform'}  = formvalue('rep_platform', 
                                          Bugzilla->params->{'defaultplatform'} || detect_platform());
    $default{'op_sys'}        = formvalue('op_sys', 
                                          Bugzilla->params->{'defaultopsys'} || detect_op_sys());

    $vars->{'alias'}          = formvalue('alias');
    $vars->{'short_desc'}     = formvalue('short_desc');
    $vars->{'bug_file_loc'}   = formvalue('bug_file_loc', "http://");
    $vars->{'keywords'}       = formvalue('keywords');
    $vars->{'status_whiteboard'} = formvalue('status_whiteboard');
    $vars->{'dependson'}      = formvalue('dependson');
    $vars->{'blocked'}        = formvalue('blocked');
    $vars->{'deadline'}       = formvalue('deadline');
    $vars->{'estimated_time'} = 0+formvalue('estimated_time') || "0.0";
    $vars->{'work_time'}      = 0+formvalue('work_time') || "0.0";

    $vars->{'cc'}             = join(', ', $cgi->param('cc'));

    $vars->{'comment'}        = formvalue('comment');
    $vars->{'comment_is_private'} = formvalue('comment_is_private');

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
$vars->{'version'} = $product->versions;

my $version_cookie = $cgi->cookie("VERSION-" . $product->name);

if ( ($cloned_bug_id) &&
     ($product->name eq $cloned_bug->product ) ) {
    $default{'version'} = $cloned_bug->version;
} elsif (formvalue('version')) {
    $default{'version'} = formvalue('version');
} elsif (defined $version_cookie
         and grep { $_->name eq $version_cookie } @{ $vars->{'version'} })
{
    $default{'version'} = $version_cookie;
} else {
    $default{'version'} = $vars->{'version'}->[$#{$vars->{'version'}}]->name;
}

# Get list of milestones.
if ( Bugzilla->params->{'usetargetmilestone'} ) {
    $vars->{'target_milestone'} = $product->milestones;
    if (formvalue('target_milestone')) {
       $default{'target_milestone'} = formvalue('target_milestone');
    } else {
       $default{'target_milestone'} = $product->default_milestone;
    }
}

# Construct the list of allowable statuses.
my @statuses = @{ Bugzilla::Bug->new_bug_statuses($product) };
# Exclude closed states from the UI, even if the workflow allows them.
# The back-end code will still accept them, though.
# XXX We should remove this when the UI accepts closed statuses and update
# Bugzilla::Bug->default_bug_status.
@statuses = grep { $_->name eq 'RESOLVED' || $_->is_open } @statuses;

scalar(@statuses) || ThrowUserError('no_initial_bug_status');

$vars->{'bug_status'} = \@statuses;
$vars->{resolution} = [ grep ($_, @{get_legal_field_values('resolution')}) ];

# Get the default from a template value if it is legitimate.
# Otherwise, and only if the user has privs, set the default
# to the first confirmed bug status on the list, if available.

my $picked_status = formvalue('bug_status');
if ($picked_status and grep($_->name eq $picked_status, @statuses)) {
    $default{'bug_status'} = formvalue('bug_status');
} else {
    $default{'bug_status'} = Bugzilla::Bug->default_bug_status(@statuses);
}

my $grouplist = $dbh->selectall_arrayref(
                  q{SELECT DISTINCT groups.id, groups.name, groups.description,
                                    membercontrol, othercontrol
                      FROM groups
                 LEFT JOIN group_control_map
                        ON group_id = id AND product_id = ?
                     WHERE isbuggroup != 0 AND isactive != 0
                  ORDER BY description}, undef, $product->id);

my @groups;

foreach my $row (@$grouplist) {
    my ($id, $groupname, $description, $membercontrol, $othercontrol) = @$row;
    # Only include groups if the entering user will have an option.
    next if ((!$membercontrol) 
               || ($membercontrol == CONTROLMAPNA) 
               || ($membercontrol == CONTROLMAPMANDATORY)
               || (($othercontrol != CONTROLMAPSHOWN) 
                    && ($othercontrol != CONTROLMAPDEFAULT)
                    && (!Bugzilla->user->in_group($groupname)))
             );
    my $check;

    # If this is a cloned bug, 
    # AND the product for this bug is the same as for the original
    #   THEN set a group's checkbox if the original also had it on
    # ELSE IF this is a bookmarked template
    #   THEN set a group's checkbox if was set in the bookmark
    # ELSE
    #   set a groups's checkbox based on the group control map
    #
    if ( ($cloned_bug_id) &&
         ($product->name eq $cloned_bug->product ) ) {
        foreach my $i (0..(@{$cloned_bug->groups} - 1) ) {
            if ($cloned_bug->groups->[$i]->{'bit'} == $id) {
                $check = $cloned_bug->groups->[$i]->{'ison'};
            }
        }
    }
    elsif(formvalue("maketemplate") ne "") {
        $check = formvalue("bit-$id", 0);
    }
    else {
        # Checkbox is checked by default if $control is a default state.
        $check = (($membercontrol == CONTROLMAPDEFAULT)
                 || (($othercontrol == CONTROLMAPDEFAULT)
                      && (!Bugzilla->user->in_group($groupname))));
    }

    my $group = 
    {
        'bit' => $id , 
        'checked' => $check , 
        'description' => $description 
    };

    push @groups, $group;
}
$default{'groups'} = \@groups;

# Custis Bug 66910
my @keyword_list = Bugzilla::Keyword->get_all();
my @keyword_list_out = map { { name => $_->{name} } } @keyword_list;
$vars->{keyword_list} = \@keyword_list_out;
# END Custis Bug 66910

Bugzilla::Hook::process('enter_bug_entrydefaultvars', { vars => $vars });

$vars->{'default'} = \%default;

my $format = $template->get_format("bug/create/create",
                                   scalar $cgi->param('format'), 
                                   scalar $cgi->param('ctype'));

$cgi->send_header($format->{'ctype'});
$template->process($format->{'template'}, $vars)
  || ThrowTemplateError($template->error());
exit;
