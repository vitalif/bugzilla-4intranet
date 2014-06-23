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

my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = $cgi->VarHash({
    cc => 1,
    (map { ($_->name => 1) } Bugzilla->get_fields({ type => FIELD_TYPE_MULTI_SELECT })),
});
$ARGS->{cc} = join(', ', @{$ARGS->{cc}}) if $ARGS->{cc};

######################################################################
# Main Script
######################################################################

# redirect to enter_bug if no field is passed.
print $cgi->redirect(correct_urlbase() . 'enter_bug.cgi') unless $cgi->param;

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
    $vars->{url} = $cgi->canonicalise_query('token', 'cloned_bug_id', 'cloned_comment');
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
push @bug_fields, 'op_sys' if Bugzilla->params->{useopsys};
push @bug_fields, 'rep_platform' if Bugzilla->params->{useplatform};
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

# Get the bug ID back
my $id = $bug->bug_id;

my $timestamp = $bug->creation_ts;

# Set Version cookie, but only if the user actually selected
# a version on the page.
if (defined $ARGS->{version} && $ARGS->{version} ne '' && $bug->version)
{
    $cgi->send_cookie(
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
        if ($1 eq 'data' && $cgi->upload($_))
        {
            $is_multiple = 1;
        }
    }
}

if ($is_multiple)
{
    my $send_attrs = {};
    Bugzilla::Attachment::add_multiple($bug, $cgi, $send_attrs);
}
elsif (defined($cgi->upload('data')) || $ARGS->{attachurl} ||
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
        $filename = scalar($cgi->upload('data')) || $ARGS->{filename};
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
        $comment->set_type(CMT_ATTACHMENT_CREATED, $attachment->id);
        $comment->update();
    }
    else
    {
        $vars->{message} = 'attachment_creation_failed';
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

my $bug_sent = { bug_id => $id, type => 'created', mailrecipients => { changer => $user->login } };
send_results($bug_sent);
my @all_mail_results = ($bug_sent);

# Add flag notify to send_result
my $notify = Bugzilla->get_mail_result();
send_results($_) for @$notify;
push @all_mail_results, @$notify;

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
            cc_restrict_group => $bug->product_obj->cc_group,
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
