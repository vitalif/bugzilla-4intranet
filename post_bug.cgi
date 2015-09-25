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
#                 Dan Mosedale <dmose@mozilla.org>
#                 Joe Robins <jmrobins@tgix.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Marc Schumann <wurblzap@gmail.com>
#
# Deep refactoring by Vitaliy Filippov <vitalif@mail.ru> -- see http://wiki.4intra.net

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

my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->input_params;

$ARGS->{cc} = join(', ', list $ARGS->{cc}) if $ARGS->{cc};

######################################################################
# Main Script
######################################################################

# redirect to enter_bug if no field is passed.
unless (keys %$ARGS)
{
    print Bugzilla->cgi->redirect(correct_urlbase() . 'enter_bug.cgi');
    exit;
}

# Detect if the user already used the same form to submit a bug
my $token = trim($ARGS->{token});
check_token_data($token, qr/^createbug:/s, 'enter_bug.cgi');

my (undef, undef, $old_bug_id) = Bugzilla::Token::GetTokenData($token);
$old_bug_id =~ s/^createbug://;
if ($old_bug_id)
{
    $vars->{bugid} = $old_bug_id;
    $vars->{allow_override} = defined $ARGS->{ignore_token} ? 0 : 1;
    $vars->{new_token} = issue_session_token('createbug:');

    $template->process('bug/create/confirm-create-dupe.html.tmpl', $vars)
        || ThrowTemplateError($template->error);
    exit;
}

# do a match on the fields if applicable
Bugzilla::User::match_field({
    cc          => { type => 'multi'  },
    assigned_to => { type => 'single' },
    qa_contact  => { type => 'single' },
});

if (defined $ARGS->{maketemplate})
{
    delete $ARGS->{$_} for qw(token cloned_bug_id cloned_comment);
    for (keys %$ARGS)
    {
        delete $ARGS->{$_} if $ARGS->{$_} eq '';
    }
    $vars->{url} = http_build_query($ARGS);
    $vars->{short_desc} = $ARGS->{short_desc};

    $template->process("bug/create/make-template.html.tmpl", $vars)
        || ThrowTemplateError($template->error);
    exit;
}

# Group Validation
my @selected_groups;
for (keys %$ARGS)
{
    if (/^bit-(\d+)$/)
    {
        push @selected_groups, $1;
    }
}

# The format of the initial comment can be structured by adding fields to the
# enter_bug template and then referencing them in the comment template.
my $comment;
my $format = $template->get_format('bug/create/comment', $ARGS->{format}, 'txt');
$template->process($format->{template}, $vars, \$comment)
    || ThrowTemplateError($template->error);

# Product must be set first
my @bug_fields = qw(
    product
    component
    assigned_to
    qa_contact
    alias
    bug_file_loc
    bug_status
    resolution
    short_desc
    bug_severity
    priority
    version
    target_milestone
    status_whiteboard
    estimated_time
    deadline
    cc
);
# FIXME kill op_sys and rep_platform completely, make them custom fields
push @bug_fields, 'op_sys' if Bugzilla->get_field('op_sys')->enabled;
push @bug_fields, 'rep_platform' if Bugzilla->get_field('rep_platform')->enabled;
# Include custom fields.
push @bug_fields, map { $_->name } Bugzilla->active_custom_fields;

# Wrap bug creation in a transaction, so attachment create errors
# don't lead to duplicated bugs. Also it allows many ugly hacks
# to be removed from Bugzilla::Bug. (CustIS Bug 63152)
Bugzilla->dbh->bz_start_transaction;

my $bug = new Bugzilla::Bug;

for my $f (@bug_fields)
{
    $bug->set($f, $ARGS->{$f}) if exists $ARGS->{$f};
}

$bug->add_comment($comment, {
    isprivate => $ARGS->{commentprivacy},
    work_time => $user->is_timetracker && $ARGS->{work_time} || 0,
});
$bug->set('keywords', {
    keywords => $ARGS->{keywords},
    descriptions => http_decode_query($ARGS->{keywords_description}),
});
$bug->set_dependencies({
    blocked => $ARGS->{blocked},
    dependson => $ARGS->{dependson},
});
$bug->set('groups', \@selected_groups);

# Set bug flags
my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi($bug, undef, $vars);
$bug->set_flags($flags, $new_flags);

# Save bug
$bug->update;

if ($ARGS->{cloned_bug_id})
{
    # Add a comment to cloned bug
    my $cmt = "Bug ".$bug->id." (".$bug->short_desc.") was cloned from ".
        ($ARGS->{cloned_comment} =~ /(\d+)/ && $1 ? "comment $1" : 'this bug');
    my $cloned_bug = Bugzilla::Bug->check($ARGS->{cloned_bug_id});
    $cloned_bug->add_comment($cmt);
    Bugzilla::Hook::process('post_bug_cloned_bug', { bug => $bug, cloned_bug => $cloned_bug });
    $cloned_bug->update($bug->creation_ts);
}

# Get the bug ID back
my $id = $bug->bug_id;

my $timestamp = $bug->creation_ts;

# Set Version cookie, but only if the user actually selected
# a version on the page.
if (defined $ARGS->{version} && $ARGS->{version} ne '' && $bug->version)
{
    Bugzilla->cgi->send_cookie(
        -name => "VERSION-" . $bug->product,
        -value => $bug->version_obj->name,
        -expires => "Fri, 01-Jan-2038 00:00:00 GMT"
    );
}

# We don't have to check if the user can see the bug, because a user filing
# a bug can always see it. You can't change reporter_accessible until
# after the bug is filed.

# Add an attachment if requested.
my $is_multiple = 0;
for (keys %$ARGS)
{
    if (/^attachmulti_(.*)_([^_]*)$/so)
    {
        if ($1 eq 'data' && Bugzilla->cgi->upload($_))
        {
            $is_multiple = 1;
        }
    }
}

if ($is_multiple)
{
    Bugzilla::Attachment::add_multiple($bug);
}
elsif (defined(Bugzilla->cgi->upload('data')) || $ARGS->{attachurl} ||
    $ARGS->{text_attachment} || $ARGS->{base64_content})
{
    $ARGS->{isprivate} = $ARGS->{commentprivacy};

    # Must be called before create() as it may alter $ARGS->{ispatch}.
    my ($content_type, $ispatch) = Bugzilla::Attachment::get_content_type();
    my $attachment;

    # If the attachment cannot be successfully added to the bug,
    # we notify the user, but we don't interrupt the bug creation process.
    my $error_mode_cache = Bugzilla->error_mode;
    Bugzilla->error_mode(ERROR_MODE_DIE);
    eval
    {
        my $data = $ARGS->{data};
        my $filename = '';
        $filename = scalar(Bugzilla->cgi->upload('data')) || $ARGS->{filename};
        if ($ARGS->{text_attachment} !~ /^\s*$/so)
        {
            $data = $ARGS->{text_attachment};
            $filename = $ARGS->{description};
        }
        $attachment = Bugzilla::Attachment->create({
            bug             => $bug,
            creation_ts     => $timestamp,
            data            => $data,
            description     => $ARGS->{description},
            filename        => $filename,
            ispatch         => $ispatch,
            isprivate       => $ARGS->{isprivate},
            mimetype        => $content_type,
            store_in_file   => $ARGS->{bigfile},
            base64_content  => $ARGS->{base64_content},
        });
    };
    Bugzilla->error_mode($error_mode_cache);

    if ($attachment)
    {
        # Set attachment flags.
        my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi(
            $bug, $attachment, $vars
        );
        $attachment->set_flags($flags, $new_flags);
        $attachment->update($timestamp);
        my $comment = $bug->comments->[0];
        $comment->set('type', CMT_ATTACHMENT_CREATED);
        $comment->set('extra_data', $attachment->id);
        $comment->update();
    }
    else
    {
        Bugzilla->add_result_message({ message => 'attachment_creation_failed' });
    }
}

$vars->{id} = $id;
$vars->{bug} = $bug;

Bugzilla->dbh->bz_commit_transaction;

Bugzilla::Hook::process('post_bug_after_creation', { vars => $vars });

if ($token)
{
    trick_taint($token);
    $dbh->do('UPDATE tokens SET eventdata = ? WHERE token = ?', undef, "createbug:$id", $token);
}

Bugzilla->send_mail;

if (Bugzilla->usage_mode != USAGE_MODE_EMAIL)
{
    # FIXME title/header hardcode
    Bugzilla->save_session_data({
        title => Bugzilla->messages->{terms}->{Bug}.' '.$bug->id.' Submitted – '.$bug->short_desc,
        header => Bugzilla->messages->{terms}->{Bug}.' '.$bug->id.' Submitted',
    });
    print Bugzilla->cgi->redirect(-location => 'show_bug.cgi?id='.$bug->id);
}

$vars;
__END__
