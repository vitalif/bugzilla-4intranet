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
#                 Dan Mosedale <dmose@mozilla.org>
#                 Joe Robins <jmrobins@tgix.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Marc Schumann <wurblzap@gmail.com>

use utf8;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Attachment;
use Bugzilla::BugMail;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::User;
use Bugzilla::Field;
use Bugzilla::Hook;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Keyword;
use Bugzilla::Token;
use Bugzilla::Flag;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

######################################################################
# Main Script
######################################################################

# redirect to enter_bug if no field is passed.
print $cgi->redirect(correct_urlbase() . 'enter_bug.cgi') unless $cgi->param();

# Detect if the user already used the same form to submit a bug
my $token = trim($cgi->param('token'));
if ($token) {
    my ($creator_id, $date, $old_bug_id) = Bugzilla::Token::GetTokenData($token);
    unless ($creator_id
              && ($creator_id == $user->id)
              && ($old_bug_id =~ "^createbug:"))
    {
        # The token is invalid.
        ThrowUserError('token_does_not_exist');
    }

    $old_bug_id =~ s/^createbug://;

    if ($old_bug_id && (!$cgi->param('ignore_token')
                        || ($cgi->param('ignore_token') != $old_bug_id)))
    {
        $vars->{'bugid'} = $old_bug_id;
        $vars->{'allow_override'} = defined $cgi->param('ignore_token') ? 0 : 1;

        $template->process("bug/create/confirm-create-dupe.html.tmpl", $vars)
           || ThrowTemplateError($template->error());
        exit;
    }
}

# do a match on the fields if applicable
Bugzilla::User::match_field ({
    'cc'            => { 'type' => 'multi'  },
    'assigned_to'   => { 'type' => 'single' },
    'qa_contact'    => { 'type' => 'single' },
});

if (defined $cgi->param('maketemplate')) {
    $vars->{'url'} = $cgi->canonicalise_query('token');
    $vars->{'short_desc'} = $cgi->param('short_desc');

    $template->process("bug/create/make-template.html.tmpl", $vars)
      || ThrowTemplateError($template->error());
    exit;
}

umask 0;

# Group Validation
my @selected_groups;
foreach my $group (grep(/^bit-\d+$/, $cgi->param())) {
    $group =~ /^bit-(\d+)$/;
    push(@selected_groups, $1);
}

# The format of the initial comment can be structured by adding fields to the
# enter_bug template and then referencing them in the comment template.
my $comment;
my $format = $template->get_format("bug/create/comment",
                                   scalar($cgi->param('format')), "txt");
$template->process($format->{'template'}, $vars, \$comment)
    || ThrowTemplateError($template->error());

# Include custom fields editable on bug creation.
my @custom_bug_fields = grep {$_->type != FIELD_TYPE_MULTI_SELECT && $_->enter_bug}
                             Bugzilla->active_custom_fields;

# Undefined custom fields are ignored to ensure they will get their default
# value (e.g. "---" for custom single select fields).
my @bug_fields = grep { defined $cgi->param($_->name) } @custom_bug_fields;
@bug_fields = map { $_->name } @bug_fields;

push(@bug_fields, qw(
    product
    component

    assigned_to
    qa_contact

    alias
    blocked
    commentprivacy
    bug_file_loc
    bug_severity
    bug_status
    resolution
    dependson
    keywords
    short_desc
    priority
    version
    target_milestone
    status_whiteboard

    estimated_time
    deadline
));
# FIXME kill op_sys and rep_platform completely, make them custom fields
push @bug_fields, 'op_sys' if Bugzilla->params->{useopsys};
push @bug_fields, 'rep_platform' if Bugzilla->params->{useplatform};
my %bug_params;
foreach my $field (@bug_fields) {
    $bug_params{$field} = $cgi->param($field);
}
$bug_params{'cc'}          = [$cgi->param('cc')];
$bug_params{'groups'}      = \@selected_groups;
$bug_params{'comment'}     = $comment;

if ($user->is_timetracker)
{
    $bug_params{'work_time'} = $cgi->param('work_time') || 0;
}
else
{
    $bug_params{'work_time'} = 0;
}

my @multi_selects = grep {$_->type == FIELD_TYPE_MULTI_SELECT && $_->enter_bug}
                         Bugzilla->active_custom_fields;

foreach my $field (@multi_selects) {
    $bug_params{$field->name} = [$cgi->param($field->name)];
}

# CustIS Bug 63152 - Duplicated bugs on attachment create errors
Bugzilla->dbh->bz_start_transaction;

my $bug = Bugzilla::Bug->create(\%bug_params);

# Run hooks
Bugzilla::Hook::process('post_bug-post_create', { bug => $bug });

# Get the bug ID back.
my $id = $bug->bug_id;

# We do this directly from the DB because $bug->creation_ts has the seconds
# formatted out of it (which should be fixed some day).
my $timestamp = $dbh->selectrow_array(
    'SELECT creation_ts FROM bugs WHERE bug_id = ?', undef, $id);

# Set Version cookie, but only if the user actually selected
# a version on the page.
if (defined $cgi->param('version') && length $cgi->param('version'))
{
    $cgi->send_cookie(-name => "VERSION-" . $bug->product,
                      -value => $bug->version,
                      -expires => "Fri, 01-Jan-2038 00:00:00 GMT");
}

# We don't have to check if the user can see the bug, because a user filing
# a bug can always see it. You can't change reporter_accessible until
# after the bug is filed.

# Add an attachment if requested.
if (defined($cgi->upload('data')) || $cgi->param('attachurl') ||
    $cgi->param('text_attachment') || $cgi->param('base64_content'))
{
    $cgi->param('isprivate', $cgi->param('commentprivacy'));

    # Must be called before create() as it may alter $cgi->param('ispatch').
    my $content_type = Bugzilla::Attachment::get_content_type();
    my $attachment;

    # If the attachment cannot be successfully added to the bug,
    # we notify the user, but we don't interrupt the bug creation process.
    my $error_mode_cache = Bugzilla->error_mode;
    Bugzilla->error_mode(ERROR_MODE_DIE);
    eval {
        my $data = scalar $cgi->param('attachurl') || $cgi->upload('data');
        my $filename = '';
        $filename = scalar $cgi->upload('data') || $cgi->param('filename') unless $cgi->param('attachurl');
        if (scalar $cgi->param('text_attachment') !~ /^\s*$/so)
        {
            $data = $cgi->param('text_attachment');
            $filename = $cgi->param('description');
        }
        $attachment = Bugzilla::Attachment->create(
            {bug           => $bug,
             creation_ts   => $timestamp,
             data          => $data,
             description   => scalar $cgi->param('description'),
             filename      => $filename,
             ispatch       => scalar $cgi->param('ispatch'),
             isprivate     => scalar $cgi->param('isprivate'),
             isurl         => scalar $cgi->param('attachurl'),
             mimetype      => $content_type,
             store_in_file => scalar $cgi->param('bigfile'),
             base64_content => scalar $cgi->param('base64_content'),
            });
    };
    Bugzilla->error_mode($error_mode_cache);

    if ($attachment) {
        # Set attachment flags.
        my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi(
            $bug, $attachment, $vars
        );
        $attachment->set_flags($flags, $new_flags);
        $attachment->update($timestamp);
        my $comment = $bug->comments->[0];
        $comment->set_type(CMT_ATTACHMENT_CREATED, $attachment->id);
        $comment->update();
    }
    else {
        $vars->{'message'} = 'attachment_creation_failed';
    }
}

# Set bug flags.
my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi($bug, undef, $vars);
$bug->set_flags($flags, $new_flags);
$bug->update($timestamp);

$vars->{'id'} = $id;
$vars->{'bug'} = $bug;

# CustIS Bug 63152 - Duplicated bugs on attachment create errors
Bugzilla->dbh->bz_commit_transaction;

Bugzilla::Hook::process('post_bug_after_creation', { vars => $vars });

ThrowCodeError("bug_error", { bug => $bug }) if $bug->error;

if ($token)
{
    trick_taint($token);
    $dbh->do('UPDATE tokens SET eventdata = ? WHERE token = ?', undef, 
             ("createbug:$id", $token));
}

my $bug_sent = { bug_id => $id, type => 'created', mailrecipients => { changer => $user->login } };
send_results($bug_sent);
my @all_mail_results = ($bug_sent);
foreach my $dep (@{$bug->dependson || []}, @{$bug->blocked || []})
{
    my $dep_sent = {
        type       => 'dep',
        bug_id     => $dep,
        recipients => $bug_sent->{recipients},
    };
    send_results($dep_sent);
    push @all_mail_results, $dep_sent;
}
$vars->{sentmail} = \@all_mail_results;

if (Bugzilla->usage_mode != USAGE_MODE_EMAIL)
{
    my $title = Bugzilla->messages->{terms}->{Bug}.' '.$bug->id.' Submitted – '.$bug->short_desc;
    my $header = Bugzilla->messages->{terms}->{Bug}.' '.$bug->id.' Submitted';
    my $ses = {
        sent => \@all_mail_results,
        title => $title,
        header => $header,
        message => $vars->{message},
    };
    # CustIS Bug 38616 - CC list restriction
    if (!$ses->{message} && $bug->{restricted_cc})
    {
        $ses->{message_vars} = {
            restricted_cc     => [ map { $_->login } @{ $bug->{restricted_cc} } ],
            cc_restrict_group => $bug->product_obj->cc_restrict_group,
        };
        $ses->{message} = 'cc_list_restricted';
    }
    if (Bugzilla->save_session_data($ses))
    {
        print $cgi->redirect(-location => 'show_bug.cgi?id='.$bug->id);
    }
    else
    {
        $template->process("bug/create/created.html.tmpl", $vars)
            || ThrowTemplateError($template->error());
    }
}

$vars;
__END__
