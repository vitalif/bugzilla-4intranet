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
    # Save URL parameters
    $vars->{query_params} = http_build_query({ %{ $cgi->Vars } });

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

# We need to check and make sure that the user has permission
# to enter a bug against this product.
$user->can_enter_product($product ? $product->name : $product_name, THROW_ERROR);

##############################################################################
# Useful Subroutines
##############################################################################
sub formvalue {
    my ($name, $default) = (@_);
    return Bugzilla->cgi->param($name) || $default || "";
}

# Takes the name of a field and a list of possible values for that 
# field. Returns the first value in the list that is actually a 
# valid value for that field.
# The field should be named after its DB table.
# Returns undef if none of the platforms match.
sub pick_valid_field_value (@) {
    my ($field, @values) = @_;
    my $dbh = Bugzilla->dbh;

    foreach my $value (@values) {
        return $value if $dbh->selectrow_array(
            "SELECT 1 FROM $field WHERE value = ?", undef, $value); 
    }
    return undef;
}

sub pickplatform {
    return formvalue("rep_platform") if formvalue("rep_platform");

    my @platform;

    if (Bugzilla->params->{'defaultplatform'}) {
        @platform = Bugzilla->params->{'defaultplatform'};
    } else {
        # If @platform is a list, this function will return the first
        # item in the list that is a valid platform choice. If
        # no choice is valid, we return "Other".
        for ($ENV{'HTTP_USER_AGENT'}) {
        #PowerPC
            /\(.*PowerPC.*\)/i && do {push @platform, ("PowerPC", "Macintosh");};
        #AMD64, Intel x86_64
            /\(.*amd64.*\)/ && do {push @platform, ("AMD64", "x86_64", "PC");};
            /\(.*x86_64.*\)/ && do {push @platform, ("AMD64", "x86_64", "PC");};
        #Intel Itanium
            /\(.*IA64.*\)/ && do {push @platform, "IA64";};
        #Intel x86
            /\(.*Intel.*\)/ && do {push @platform, ("IA32", "x86", "PC");};
            /\(.*[ix0-9]86.*\)/ && do {push @platform, ("IA32", "x86", "PC");};
        #Versions of Windows that only run on Intel x86
            /\(.*Win(?:dows |)[39M].*\)/ && do {push @platform, ("IA32", "x86", "PC");};
            /\(.*Win(?:dows |)16.*\)/ && do {push @platform, ("IA32", "x86", "PC");};
        #Sparc
            /\(.*sparc.*\)/ && do {push @platform, ("Sparc", "Sun");};
            /\(.*sun4.*\)/ && do {push @platform, ("Sparc", "Sun");};
        #Alpha
            /\(.*AXP.*\)/i && do {push @platform, ("Alpha", "DEC");};
            /\(.*[ _]Alpha.\D/i && do {push @platform, ("Alpha", "DEC");};
            /\(.*[ _]Alpha\)/i && do {push @platform, ("Alpha", "DEC");};
        #MIPS
            /\(.*IRIX.*\)/i && do {push @platform, ("MIPS", "SGI");};
            /\(.*MIPS.*\)/i && do {push @platform, ("MIPS", "SGI");};
        #68k
            /\(.*68K.*\)/ && do {push @platform, ("68k", "Macintosh");};
            /\(.*680[x0]0.*\)/ && do {push @platform, ("68k", "Macintosh");};
        #HP
            /\(.*9000.*\)/ && do {push @platform, ("PA-RISC", "HP");};
        #ARM
            /\(.*ARM.*\)/ && do {push @platform, ("ARM", "PocketPC");};
        #PocketPC intentionally before PowerPC
            /\(.*Windows CE.*PPC.*\)/ && do {push @platform, ("ARM", "PocketPC");};
        #PowerPC
            /\(.*PPC.*\)/ && do {push @platform, ("PowerPC", "Macintosh");};
            /\(.*AIX.*\)/ && do {push @platform, ("PowerPC", "Macintosh");};
        #Stereotypical and broken
            /\(.*Windows CE.*\)/ && do {push @platform, ("ARM", "PocketPC");};
            /\(.*Macintosh.*\)/ && do {push @platform, ("68k", "Macintosh");};
            /\(.*Mac OS [89].*\)/ && do {push @platform, ("68k", "Macintosh");};
            /\(.*Win64.*\)/ && do {push @platform, "IA64";};
            /\(Win.*\)/ && do {push @platform, ("IA32", "x86", "PC");};
            /\(.*Win(?:dows[ -])NT.*\)/ && do {push @platform, ("IA32", "x86", "PC");};
            /\(.*OSF.*\)/ && do {push @platform, ("Alpha", "DEC");};
            /\(.*HP-?UX.*\)/i && do {push @platform, ("PA-RISC", "HP");};
            /\(.*IRIX.*\)/i && do {push @platform, ("MIPS", "SGI");};
            /\(.*(SunOS|Solaris).*\)/ && do {push @platform, ("Sparc", "Sun");};
        #Braindead old browsers who didn't follow convention:
            /Amiga/ && do {push @platform, ("68k", "Macintosh");};
            /WinMosaic/ && do {push @platform, ("IA32", "x86", "PC");};
        }
    }

    return pick_valid_field_value('rep_platform', @platform) || "Other";
}

sub pickos {
    if (formvalue('op_sys') ne "") {
        return formvalue('op_sys');
    }

    my @os = ();

    if (Bugzilla->params->{'defaultopsys'}) {
        @os = Bugzilla->params->{'defaultopsys'};
    } else {
        # This function will return the first
        # item in @os that is a valid platform choice. If
        # no choice is valid, we return "Other".
        for ($ENV{'HTTP_USER_AGENT'}) {
            /\(.*IRIX.*\)/ && do {push @os, "IRIX";};
            /\(.*OSF.*\)/ && do {push @os, "OSF/1";};
            /\(.*Linux.*\)/ && do {push @os, "Linux";};
            /\(.*Solaris.*\)/ && do {push @os, "Solaris";};
            /\(.*SunOS.*\)/ && do {
              /\(.*SunOS 5.11.*\)/ && do {push @os, ("OpenSolaris", "Opensolaris", "Solaris 11");};
              /\(.*SunOS 5.10.*\)/ && do {push @os, "Solaris 10";};
              /\(.*SunOS 5.9.*\)/ && do {push @os, "Solaris 9";};
              /\(.*SunOS 5.8.*\)/ && do {push @os, "Solaris 8";};
              /\(.*SunOS 5.7.*\)/ && do {push @os, "Solaris 7";};
              /\(.*SunOS 5.6.*\)/ && do {push @os, "Solaris 6";};
              /\(.*SunOS 5.5.*\)/ && do {push @os, "Solaris 5";};
              /\(.*SunOS 5.*\)/ && do {push @os, "Solaris";};
              /\(.*SunOS.*sun4u.*\)/ && do {push @os, "Solaris";};
              /\(.*SunOS.*i86pc.*\)/ && do {push @os, "Solaris";};
              /\(.*SunOS.*\)/ && do {push @os, "SunOS";};
            };
            /\(.*HP-?UX.*\)/ && do {push @os, "HP-UX";};
            /\(.*BSD.*\)/ && do {
              /\(.*BSD\/(?:OS|386).*\)/ && do {push @os, "BSDI";};
              /\(.*FreeBSD.*\)/ && do {push @os, "FreeBSD";};
              /\(.*OpenBSD.*\)/ && do {push @os, "OpenBSD";};
              /\(.*NetBSD.*\)/ && do {push @os, "NetBSD";};
            };
            /\(.*BeOS.*\)/ && do {push @os, "BeOS";};
            /\(.*AIX.*\)/ && do {push @os, "AIX";};
            /\(.*OS\/2.*\)/ && do {push @os, "OS/2";};
            /\(.*QNX.*\)/ && do {push @os, "Neutrino";};
            /\(.*VMS.*\)/ && do {push @os, "OpenVMS";};
            /\(.*Win.*\)/ && do {
              /\(.*Windows XP.*\)/ && do {push @os, "Windows XP";};
              /\(.*Windows NT 6\.1.*\)/ && do {push @os, "Windows 7";};
              /\(.*Windows NT 6\.0.*\)/ && do {push @os, "Windows Vista";};
              /\(.*Windows NT 5\.2.*\)/ && do {push @os, "Windows Server 2003";};
              /\(.*Windows NT 5\.1.*\)/ && do {push @os, "Windows XP";};
              /\(.*Windows 2000.*\)/ && do {push @os, "Windows 2000";};
              /\(.*Windows NT 5.*\)/ && do {push @os, "Windows 2000";};
              /\(.*Win.*9[8x].*4\.9.*\)/ && do {push @os, "Windows ME";};
              /\(.*Win(?:dows |)M[Ee].*\)/ && do {push @os, "Windows ME";};
              /\(.*Win(?:dows |)98.*\)/ && do {push @os, "Windows 98";};
              /\(.*Win(?:dows |)95.*\)/ && do {push @os, "Windows 95";};
              /\(.*Win(?:dows |)16.*\)/ && do {push @os, "Windows 3.1";};
              /\(.*Win(?:dows[ -]|)NT.*\)/ && do {push @os, "Windows NT";};
              /\(.*Windows.*NT.*\)/ && do {push @os, "Windows NT";};
            };
            /\(.*Mac OS X.*\)/ && do {
              /\(.*Mac OS X (?:|Mach-O |\()10.6.*\)/ && do {push @os, "Mac OS X 10.6";};
              /\(.*Mac OS X (?:|Mach-O |\()10.5.*\)/ && do {push @os, "Mac OS X 10.5";};
              /\(.*Mac OS X (?:|Mach-O |\()10.4.*\)/ && do {push @os, "Mac OS X 10.4";};
              /\(.*Mac OS X (?:|Mach-O |\()10.3.*\)/ && do {push @os, "Mac OS X 10.3";};
              /\(.*Mac OS X (?:|Mach-O |\()10.2.*\)/ && do {push @os, "Mac OS X 10.2";};
              /\(.*Mac OS X (?:|Mach-O |\()10.1.*\)/ && do {push @os, "Mac OS X 10.1";};
        # Unfortunately, OS X 10.4 was the first to support Intel. This is
        # fallback support because some browsers refused to include the OS
        # Version.
              /\(.*Intel.*Mac OS X.*\)/ && do {push @os, "Mac OS X 10.4";};
        # OS X 10.3 is the most likely default version of PowerPC Macs
        # OS X 10.0 is more for configurations which didn't setup 10.x versions
              /\(.*Mac OS X.*\)/ && do {push @os, ("Mac OS X 10.3", "Mac OS X 10.0", "Mac OS X");};
            };
            /\(.*32bit.*\)/ && do {push @os, "Windows 95";};
            /\(.*16bit.*\)/ && do {push @os, "Windows 3.1";};
            /\(.*Mac OS \d.*\)/ && do {
              /\(.*Mac OS 9.*\)/ && do {push @os, ("Mac System 9.x", "Mac System 9.0");};
              /\(.*Mac OS 8\.6.*\)/ && do {push @os, ("Mac System 8.6", "Mac System 8.5");};
              /\(.*Mac OS 8\.5.*\)/ && do {push @os, "Mac System 8.5";};
              /\(.*Mac OS 8\.1.*\)/ && do {push @os, ("Mac System 8.1", "Mac System 8.0");};
              /\(.*Mac OS 8\.0.*\)/ && do {push @os, "Mac System 8.0";};
              /\(.*Mac OS 8[^.].*\)/ && do {push @os, "Mac System 8.0";};
              /\(.*Mac OS 8.*\)/ && do {push @os, "Mac System 8.6";};
            };
            /\(.*Darwin.*\)/ && do {push @os, ("Mac OS X 10.0", "Mac OS X");};
        # Silly
            /\(.*Mac.*\)/ && do {
              /\(.*Mac.*PowerPC.*\)/ && do {push @os, "Mac System 9.x";};
              /\(.*Mac.*PPC.*\)/ && do {push @os, "Mac System 9.x";};
              /\(.*Mac.*68k.*\)/ && do {push @os, "Mac System 8.0";};
            };
        # Evil
            /Amiga/i && do {push @os, "Other";};
            /WinMosaic/ && do {push @os, "Windows 95";};
            /\(.*PowerPC.*\)/ && do {push @os, "Mac System 9.x";};
            /\(.*PPC.*\)/ && do {push @os, "Mac System 9.x";};
            /\(.*68K.*\)/ && do {push @os, "Mac System 8.0";};
        }
    }

    push(@os, "Windows") if grep(/^Windows /, @os);
    push(@os, "Mac OS") if grep(/^Mac /, @os);

    return pick_valid_field_value('op_sys', @os) || "Other";
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

$vars->{'product'} = $product;

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

$vars->{'priority'}              = Bugzilla->get_field('priority')->legal_value_names;
$vars->{'bug_severity'}          = Bugzilla->get_field('bug_severity')->legal_value_names;
$vars->{'rep_platform'}          = Bugzilla->get_field('rep_platform')->legal_value_names if Bugzilla->params->{useplatform};
$vars->{'op_sys'}                = Bugzilla->get_field('op_sys')->legal_value_names if Bugzilla->params->{useopsys};

$vars->{'assigned_to'}           = formvalue('assigned_to');
$vars->{'assigned_to_disabled'}  = !$has_editbugs;
$vars->{'cc_disabled'}           = 0;

$vars->{'qa_contact'}           = formvalue('qa_contact');
$vars->{'qa_contact_disabled'}  = !$has_editbugs;

$vars->{'cloned_bug_id'}         = $cloned_bug_id;

$vars->{'token'}             = issue_session_token('createbug:');

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
# Product field as a parent.
$default{'product'} = $product->name;
$default{'product_obj'} = $product;

if ($cloned_bug_id) {

    $default{'component_'}    = $cloned_bug->component;
    $default{'priority'}      = $cloned_bug->priority;
    $default{'bug_severity'}  = $cloned_bug->bug_severity;
    $default{'rep_platform'}  = $cloned_bug->rep_platform if Bugzilla->params->{useplatform};
    $default{'op_sys'}        = $cloned_bug->op_sys if Bugzilla->params->{useopsys};

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

    $vars->{'comment'}        = "";
    $vars->{'commentprivacy'} = 0;

    if (!$isprivate || Bugzilla->user->is_insider) {
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
        $vars->{'commentprivacy'} = $isprivate;
    }

    Bugzilla::Hook::process('enter_bug_cloned_bug', { vars => $vars, product => $product, cloned_bug => $cloned_bug });
} # end of cloned bug entry form

else {

    $default{'component_'}    = formvalue('component');
    $default{'priority'}      = formvalue('priority', Bugzilla->params->{'defaultpriority'});
    $default{'bug_severity'}  = formvalue('bug_severity', Bugzilla->params->{'defaultseverity'});
    $default{'rep_platform'}  = pickplatform() if Bugzilla->params->{useplatform};
    $default{'op_sys'}        = pickos() if Bugzilla->params->{useopsys};

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
    $vars->{'commentprivacy'} = formvalue('commentprivacy');

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
$vars->{version} = [ map($_->name, @{$product->versions}) ];

my $vercookie = $cgi->cookie("VERSION-" . $product->name);
if ($cloned_bug_id && $product->name eq $cloned_bug->product)
{
    $vars->{overridedefaultversion} = 1;
    $default{version} = $cloned_bug->version;
}
elsif (formvalue('version'))
{
    $vars->{overridedefaultversion} = 1;
    $default{version} = formvalue('version');
}
elsif (defined $vercookie && grep { $_ eq $vercookie } @{$vars->{version}})
{
    $default{version} = $vercookie;
}
else
{
    $default{version} = $vars->{version}->[$#{$vars->{'version'}}];
}

# Get list of milestones.
if ( Bugzilla->params->{'usetargetmilestone'} ) {
    $vars->{'target_milestone'} = [map($_->name, @{$product->milestones})];
    if (formvalue('target_milestone')) {
       $default{'target_milestone'} = formvalue('target_milestone');
    } else {
       $default{'target_milestone'} = $product->default_milestone;
    }
}

# Construct the list of allowable statuses.
my $initial_statuses = Bugzilla::Status->can_change_to();
# Exclude closed states from the UI, even if the workflow allows them.
# The back-end code will still accept them, though.
@$initial_statuses = grep { $_->name eq 'RESOLVED' || $_->is_open } @$initial_statuses;

my @status = map { $_->name } @$initial_statuses;
# UNCONFIRMED is illegal if allows_unconfirmed is false.
if (!$product->allows_unconfirmed) {
    @status = grep {$_ ne 'UNCONFIRMED'} @status;
}
scalar(@status) || ThrowUserError('no_initial_bug_status');

# If the user has no privs...
unless ($has_editbugs || $has_canconfirm) {
    # ... use UNCONFIRMED if available, else use the first status of the list.
    my $bug_status = (grep {$_ eq 'UNCONFIRMED'} @status) ? 'UNCONFIRMED' : $status[0];
    @status = ($bug_status);
}

$vars->{bug_status} = \@status;
$vars->{resolution} = [ grep ($_, @{Bugzilla->get_field('resolution')->legal_value_names}) ];

# Get the default from a template value if it is legitimate.
# Otherwise, and only if the user has privs, set the default
# to the first confirmed bug status on the list, if available.

$default{bug_status} = formvalue('bug_status');
if (!grep { $_ eq $default{bug_status} } @status)
{
    $default{bug_status} = $status[0];
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

$vars->{'group'} = \@groups;

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
