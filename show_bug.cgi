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

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Keyword;
use Bugzilla::Bug;

my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->input_params;
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
    my ($id) = list $ARGS->{id};
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
    my @errors;
    foreach my $id (list $ARGS->{id})
    {
        # Be kind enough and accept URLs of the form: id=1,2,3.
        my @ids = split /,/, $id;
        foreach (@ids)
        {
            my $bug = new Bugzilla::Bug($_, RETURN_ERROR);
            # This is basically a backwards-compatibility hack from when
            # Bugzilla::Bug->new used to set 'NotPermitted' if you couldn't
            # see the bug.
            if (!$bug->{error} && !$user->can_see_bug($bug->bug_id))
            {
                $bug = { bug_id => $bug->bug_id, error => 'NotPermitted' };
            }
            if ($bug->{error})
            {
                push @errors, $bug;
            }
            else
            {
                push @bugs, $bug;
            }
        }
    }
    $vars->{error_bugs} = \@errors;
}

$vars->{bugs} = \@bugs;
$vars->{marks} = \%marks;
$vars->{last_bug_list} = [ split /:/, Bugzilla->cookies->{BUGLIST} ];

my @bugids = map { $_->bug_id } grep { ref $_ } @bugs;
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

foreach (list $ARGS->{excludefield})
{
    $displayfields{$_} = undef;
}

# CustIS Bug 70168
if ($ARGS->{includefield} || $ARGS->{field})
{
    %displayfields = map { $_ => 1 } grep { $displayfields{$_} } list($ARGS->{includefield} || $ARGS->{field});
}

$vars->{displayfields} = \%displayfields;

Bugzilla->cgi->send_header($format->{ctype});
$template->process($format->{template}, $vars)
    || ThrowTemplateError($template->error());
exit;
