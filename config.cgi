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
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Myk Melez <myk@mozilla.org>
#                 Frank Becker <Frank@Frank-Becker.de>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Keyword;
use Bugzilla::Product;
use Bugzilla::Status;
use Bugzilla::Field;
use Bugzilla::Util qw(list);

use Digest::MD5 qw(md5_base64);

my $ARGS = Bugzilla->input_params;
my $user = Bugzilla->login(LOGIN_OPTIONAL);

# If the 'requirelogin' parameter is on and the user is not
# authenticated, return empty fields.
if (Bugzilla->params->{requirelogin} && !$user->id)
{
    display_data();
}

# Get data from the shadow DB as they don't change very often.
Bugzilla->switch_to_shadow_db;

# Pass a bunch of Bugzilla configuration to the templates.
my $vars = {};
$vars->{priority}   = Bugzilla->get_field('priority')->legal_value_names;
$vars->{severity}   = Bugzilla->get_field('bug_severity')->legal_value_names;
$vars->{platform}   = Bugzilla->get_field('rep_platform')->legal_value_names if Bugzilla->get_field('rep_platform')->enabled;
$vars->{op_sys}     = Bugzilla->get_field('op_sys')->legal_value_names if Bugzilla->get_field('op_sys')->enabled;
$vars->{keyword}    = [ map($_->name, Bugzilla::Keyword->get_all) ];
$vars->{resolution} = Bugzilla->get_field('resolution')->legal_value_names;
$vars->{status}     = Bugzilla->get_field('bug_status')->legal_value_names;
$vars->{custom_fields} = [ grep { $_->is_select } Bugzilla->active_custom_fields ];

# Include a list of product objects.
if ($ARGS->{product})
{
    foreach my $product_name (list $ARGS->{product})
    {
        # We don't use check_product because config.cgi outputs mostly
        # in XML and JS and we don't want to display an HTML error
        # instead of that.
        my $product = new Bugzilla::Product({ name => $product_name });
        if ($product && $user->can_see_product($product->name))
        {
            push @{$vars->{products}}, $product;
        }
    }
}
else
{
    $vars->{products} = $user->get_selectable_products;
}

Bugzilla::Product::preload($vars->{products});

# Allow consumers to specify whether or not they want flag data.
if (defined $ARGS->{flags})
{
    $vars->{show_flags} = $ARGS->{flags} && 1;
}
else
{
    # We default to sending flag data.
    $vars->{show_flags} = 1;
}

# Create separate lists of open versus resolved statuses.
my @open_status;
my @closed_status;
foreach my $status (@{ Bugzilla->get_field('bug_status')->legal_values })
{
    $status->is_open ? push(@open_status, $status->name) : push(@closed_status, $status->name);
}
$vars->{open_status} = \@open_status;
$vars->{closed_status} = \@closed_status;

# Generate a list of fields that can be queried.
my @fields = Bugzilla->get_fields({obsolete => 0});
# Exclude fields the user cannot query.
if (!Bugzilla->user->is_timetracker)
{
    @fields = grep { !TIMETRACKING_FIELDS->{$_->name} } @fields;
}
$vars->{field} = \@fields;

display_data($vars);
exit;

sub display_data
{
    my $vars = shift;

    my $ARGS = Bugzilla->input_params;
    my $template = Bugzilla->template;

    # Determine how the user would like to receive the output; 
    # default is JavaScript.
    my $format = $template->get_format("config", $ARGS->{format}, $ARGS->{ctype} || 'js');

    # Generate the configuration data.
    my $output;
    $template->process($format->{template}, $vars, \$output)
        || ThrowTemplateError($template->error());

    # Wide characters cause md5_base64() to die.
    my $digest_data = $output;
    utf8::encode($digest_data) if utf8::is_utf8($digest_data);
    my $digest = md5_base64($digest_data);

    # ETag support.
    my $if_none_match = Bugzilla->cgi->http('If-None-Match') || "";
    my $found304;
    my @if_none = split /[\s,]+/, $if_none_match;
    foreach my $if_none (@if_none)
    {
        # remove quotes from begin and end of the string
        $if_none =~ s/^\"//g;
        $if_none =~ s/\"$//g;
        if ($if_none eq $digest || $if_none eq '*')
        {
            # leave the loop after the first match
            $found304 = $if_none;
            last;
        }
    }

    if ($found304)
    {
        Bugzilla->cgi->send_header(
            -type => 'text/html',
            -ETag => $found304,
            -status => '304 Not Modified',
        );
    }
    else
    {
        # Return HTTP headers.
        Bugzilla->cgi->send_header(
            -ETag => $digest,
            -type => $format->{ctype},
        );
        print $output;
    }
}
