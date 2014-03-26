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
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Keyword;
use Bugzilla::Bug;

use Checkers;

my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->cgi->VarHash({ id => 1, excludefield => 1, field => 1, includefield => 1 });
my $user = Bugzilla->login;

# Editable, 'single' HTML bugs are treated slightly specially in a few places
my $single = !$ARGS->{format} && (!$ARGS->{ctype} || $ARGS->{ctype} eq 'html');
$vars->{multiple} = !$single;

# If we don't have an ID, _AND_ we're only doing a single bug, then prompt
if (!$ARGS->{id} && $single)
{
    $template->process('bug/choose.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

my $format = $template->get_format('bug/show', $ARGS->{format}, $ARGS->{ctype});

my @bugs = ();
my %marks;

# If the user isn't logged in, we use data from the shadow DB. If he plans
# to edit the bug(s), he will have to log in first, meaning that the data
# will be reloaded anyway, from the main DB.
Bugzilla->switch_to_shadow_db unless $user->id;

if ($single)
{
    my ($id) = @{$ARGS->{id}};
    push @bugs, Bugzilla::Bug->check($id);
    if (defined $ARGS->{mark})
    {
        foreach my $range (split ',', $ARGS->{mark})
        {
            if ($range =~ /^(\d+)-(\d+)$/)
            {
                foreach my $i ($1..$2)
                {
                    $marks{$i} = 1;
                }
            }
            elsif ($range =~ /^(\d+)$/)
            {
                $marks{$1} = 1;
            }
        }
    }
}
else
{
    foreach my $id (@{$ARGS->{id}})
    {
        # Be kind enough and accept URLs of the form: id=1,2,3.
        my @ids = split /,/, $id;
        foreach (@ids)
        {
            my $bug = new Bugzilla::Bug($_);
            # This is basically a backwards-compatibility hack from when
            # Bugzilla::Bug->new used to set 'NotPermitted' if you couldn't
            # see the bug.
            if (!$bug->{error} && !$user->can_see_bug($bug->bug_id))
            {
                $bug->{error} = 'NotPermitted';
            }
            push @bugs, $bug;
        }
    }
}

$vars->{bugs} = \@bugs;
$vars->{marks} = \%marks;

my @bugids = map { $_->bug_id } grep { !$_->error } @bugs;
$vars->{bugids} = join(', ', @bugids);

# Work out which fields we are displaying (currently XML only)
# If no explicit list is defined, we show all fields. We then exclude any
# on the exclusion list. This is so you can say e.g. "Everything except 
# attachments" without listing almost all the fields.
my @fieldlist = (
    Bugzilla::Bug->fields, 'flag', 'group', 'long_desc',
    'attachment', 'attachmentdata', 'token'
);
my %displayfields;

unless (Bugzilla->user->is_timetracker)
{
    @fieldlist = grep { $_ !~ /(^deadline|_time)$/ } @fieldlist;
}

foreach (@fieldlist)
{
    $displayfields{$_} = 1;
}

foreach (@{$ARGS->{excludefield} || []})
{
    $displayfields{$_} = undef;
}

# CustIS Bug 70168
if ($ARGS->{includefield} || $ARGS->{field})
{
    %displayfields = map { $_ => 1 } grep { $displayfields{$_} } @{$ARGS->{includefield} || $ARGS->{field}};
}

$vars->{displayfields} = \%displayfields;

# Custis Bug 66910
my @keyword_list = Bugzilla::Keyword->get_all();
my @keyword_list_out = map { { name => $_->{name} } } @keyword_list;
$vars->{keyword_list} = \@keyword_list_out;
# END Custis Bug 66910

my $sd;
if (Bugzilla->session && ($sd = Bugzilla->session_data) && $sd->{sent})
{
    Bugzilla->save_session_data({
        sent => undef,
        title => undef,
        header => undef,
        sent_attrs => undef,
        failed_checkers => undef,
        message => undef,
        message_vars => undef,
    });
    $vars->{last_title} = $sd->{title};
    $vars->{last_header} = $sd->{header};
    $vars->{sentmail} = $sd->{sent};
    $vars->{failed_checkers} = Checkers::unfreeze_failed_checkers($sd->{failed_checkers});
    if ($sd->{message})
    {
        $vars->{message} = $sd->{message};
        $vars->{$_} = $sd->{message_vars}->{$_} for keys %{$sd->{message_vars} || {}};
    }
    $vars->{$_} = $sd->{sent_attrs}->{$_} for keys %{$sd->{sent_attrs} || {}};
}

Bugzilla->cgi->send_header($format->{ctype});
$template->process($format->{template}, $vars)
    || ThrowTemplateError($template->error());
exit;
