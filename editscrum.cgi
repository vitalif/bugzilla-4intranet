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
# Contributor(s): Vitaliy Filippov <vfilippov@custis.ru>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Product;
use Bugzilla::User;
use Bugzilla::Token;

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

my $user = Bugzilla->login(LOGIN_REQUIRED);

my @bug_objects = map { Bugzilla::Bug->check($_) } ($cgi->param('id') =~ /(\d+)/gso);

# Make sure there are bugs
scalar(@bug_objects) || ThrowUserError("no_bugs_chosen", {action => 'scrum'});

my $sprint = $cgi->param('save') || $cgi->param('sprint_select') ? $cgi->param('sprint') || '' : undef;
my $type = $cgi->param('save') || $cgi->param('type_select') ? $cgi->param('type') || '' : undef;
defined $sprint and trick_taint($sprint);
defined $type and trick_taint($type);

my $sql = 'SELECT * FROM scrum_cards WHERE estimate!="" AND bug_id IN ('.join(',', ('?') x @bug_objects).')';
my @bind = map { $_->id } @bug_objects;

if (defined $sprint)
{
    $sql .= ' AND sprint=?';
    push @bind, $sprint;
}

if (defined $type)
{
    $sql .= ' AND type=?';
    push @bind, $type;
}

$sql .= ' ORDER BY bug_id, sprint, type';

$vars->{ids} = join ',', map { $_->id } @bug_objects;
$vars->{bugs} = \@bug_objects;
$vars->{sprint} = $sprint;
$vars->{type} = $type;
$vars->{sprint_select} = $cgi->param('sprint_select');
$vars->{type_select} = $cgi->param('type_select');
$vars->{cards} = [ grep { $_->{bug} = Bugzilla::Bug->new($_->{bug_id}) } @{ $dbh->selectall_arrayref($sql, {Slice=>{}}, @bind) || [] } ];

if (defined $sprint && defined $type)
{
    if ($cgi->param('save'))
    {
        my $estimate = {};
        my $del = {};
        foreach ($cgi->param)
        {
            if (/^estimate_(\d+)$/s)
            {
                if ($cgi->param($_))
                {
                    $estimate->{$1} = $cgi->param($_);
                    trick_taint($estimate->{$1});
                }
                else
                {
                    $del->{$1} = 1;
                }
            }
        }
        if (%$del)
        {
            $sql = 'DELETE FROM scrum_cards WHERE sprint=? AND type=? AND bug_id IN ('.join(',', ('?') x keys %$del).')';
            @bind = ($sprint, $type, keys %$del);
            $dbh->do($sql, undef, @bind);
        }
        if (%$estimate)
        {
            $sql = 'REPLACE INTO scrum_cards (bug_id, sprint, type, estimate) VALUES '.
                join(',', ('(?, ?, ?, ?)') x keys %$estimate);
            @bind = map { ($_, $sprint, $type, $estimate->{$_}) } keys %$estimate;
            $dbh->do($sql, undef, @bind);
        }
        print $cgi->redirect(-location => 'editscrum.cgi?sprint_select=1&type_select=1&sprint='.url_quote($sprint).'&type='.url_quote($type).'&id='.join(',', map { $_->id } @bug_objects));
        exit;
    }
    $vars->{estimates} = { map { $_->{bug_id} => $_->{estimate} } @{$vars->{cards}} };
}

$template->process('list/edit-scrum.html.tmpl', $vars)
    || ThrowTemplateError($template->error());
exit;
