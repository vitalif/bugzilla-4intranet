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
# Contributor(s): Owen Taylor <otaylor@redhat.com>
#                 Gervase Markham <gerv@gerv.net>
#                 David Fallon <davef@tetsubo.com>
#                 Tobias Burnus <burnus@net-b.de>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Token;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $ARGS = Bugzilla->input_params;
my $vars = {};

my $action = $ARGS->{action} || "";
my $token = $ARGS->{token};

if ($action eq "show")
{
    # Read in the entire quip list
    my $quips = $dbh->selectall_hashref(
        "SELECT q.quipid, q.userid, q.quip, q.approved, p.login_name".
        " FROM quips q LEFT JOIN profiles p ON p.userid=q.userid", 'quipid'
    );
    $vars->{quips} = $quips;
    $vars->{show_quips} = 1;
}

if ($action eq "add")
{
    if (Bugzilla->params->{quip_list_entry_control} eq "closed")
    {
        ThrowUserError("no_new_quips");
    }

    check_hash_token($token, [ 'create-quips' ]);

    # Add the quip
    my $approved = (Bugzilla->params->{quip_list_entry_control} eq "open")
        || Bugzilla->user->in_group('admin') || 0;
    my $comment = $ARGS->{quip};
    $comment || ThrowUserError("need_quip");
    trick_taint($comment); # Used in a placeholder below

    $dbh->do(
        "INSERT INTO quips (userid, quip, approved) VALUES (?, ?, ?)",
        undef, $user->id, $comment, $approved
    );

    $vars->{added_quip} = $comment;
}

if ($action eq 'approve')
{
    $user->in_group('admin') || ThrowUserError("auth_failure", {
        group  => "admin",
        action => "approve",
        object => "quips",
    });

    check_hash_token($token, [ 'approve-quips' ]);

    # Read in the entire quip list
    my $quipsref = $dbh->selectall_arrayref("SELECT quipid, approved FROM quips");
    my %quips;
    foreach my $quipref (@$quipsref)
    {
        my ($quipid, $approved) = @$quipref;
        $quips{$quipid} = $approved;
    }

    my @approved;
    my @unapproved;
    foreach my $quipid (keys %quips)
    {
        # Must check for each quipid being defined for concurrency and
        # automated usage where only one quipid might be defined.
        my $quip = $ARGS->{"quipid_$quipid"} ? 1 : 0;
        if (defined $ARGS->{"defined_quipid_$quipid"})
        {
            if ($quips{$quipid} != $quip)
            {
                if ($quip)
                {
                    push @approved, $quipid;
                }
                else
                {
                    push @unapproved, $quipid;
                }
            }
        }
    }
    $dbh->do("UPDATE quips SET approved = 1 WHERE quipid IN (" . join(",", @approved) . ")") if @approved;
    $dbh->do("UPDATE quips SET approved = 0 WHERE quipid IN (" . join(",", @unapproved) . ")") if @unapproved;
    $vars->{approved} = \@approved;
    $vars->{unapproved} = \@unapproved;
}

if ($action eq "delete")
{
    Bugzilla->user->in_group("admin") || ThrowUserError("auth_failure", {
        group  => "admin",
        action => "delete",
        object => "quips",
    });

    my $quipid = $ARGS->{quipid};
    ThrowCodeError("need_quipid") unless $quipid =~ /(\d+)/;
    $quipid = $1;
    check_hash_token($token, [ 'quips', $quipid ]);

    ($vars->{deleted_quip}) = $dbh->selectrow_array(
        "SELECT quip FROM quips WHERE quipid = ?", undef, $quipid
    );
    $dbh->do("DELETE FROM quips WHERE quipid = ?", undef, $quipid);
}

$template->process("list/quips.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
