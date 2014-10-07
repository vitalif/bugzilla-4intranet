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
#                 Myk Melez <myk@mozilla.org>
#                 Daniel Raichle <draichle@gmx.net>
#                 Dave Miller <justdave@syndicomm.com>
#                 Alexander J. Vincent <ajvincent@juno.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Greg Hendricks <ghendricks@novell.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Marc Schumann <wurblzap@gmail.com>
#                 Byron Jones <bugzilla@glob.com.au>

################################################################################
# Script Initialization
################################################################################

# Make it harder for us to do dangerous things in Perl.
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::BugMail;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Flag;
use Bugzilla::FlagType;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Bug;
use Bugzilla::Field;
use Bugzilla::Attachment;
use Bugzilla::Attachment::PatchReader;
use Bugzilla::Token;
use Bugzilla::Keyword;

use Lingua::Translit;
use Archive::Zip qw ( :ERROR_CODES :CONSTANTS );
use Encode;

################################################################################
# Main Body Execution
################################################################################

# All calls to this script should contain an "action" variable whose
# value determines what the user wants to do.  The code below checks
# the value of that variable and runs the appropriate code. If none is
# supplied, we default to 'view'.

# Determine whether to use the action specified by the user or the default.
my $action = Bugzilla->input_params->{action} || 'view';

# You must use the appropriate urlbase/sslbase param when doing anything
# but viewing an attachment.
if ($action ne 'view') {
    do_ssl_redirect_if_required();
    if (Bugzilla->cgi->url_is_attachment_base) {
        Bugzilla->cgi->redirect_to_urlbase;
    }
    Bugzilla->login();
}

# When viewing an attachment, do not request credentials if we are on
# the alternate host. Let view() decide when to call Bugzilla->login.
if ($action eq "view")
{
    view();
}
elsif ($action eq "interdiff")
{
    interdiff();
}
elsif ($action eq "diff")
{
    diff();
}
elsif ($action eq "viewall")
{
    viewall();
}
elsif ($action eq "enter")
{
    Bugzilla->login(LOGIN_REQUIRED);
    enter();
}
elsif ($action eq "insert")
{
    Bugzilla->login(LOGIN_REQUIRED);
    insert();
}
elsif ($action eq "edit")
{
    edit();
}
elsif ($action eq "update")
{
    Bugzilla->login(LOGIN_REQUIRED);
    update();
}
elsif ($action eq "delete")
{
    delete_attachment();
}
# Bug 129399
elsif ($action eq "zip")
{
    all_attachments_in_zip();
}
# Bug 129398
elsif ($action eq "online_view")
{
    view($action);
}
else
{
    ThrowCodeError("unknown_action", { action => $action });
}

exit;

################################################################################
# Data Validation / Security Authorization
################################################################################

# Validates an attachment ID. Optionally takes a parameter of a form
# variable name that contains the ID to be validated. If not specified,
# uses 'id'.
# If the second parameter is true, the attachment ID will be validated,
# however the current user's access to the attachment will not be checked.
# Will throw an error if 1) attachment ID is not a valid number,
# 2) attachment does not exist, or 3) user isn't allowed to access the
# attachment.
#
# Returns an attachment object.

sub validateID {
    my ($param, $dont_validate_access) = @_;
    my $ARGS = Bugzilla->input_params;
    my $vars = {};
    $param ||= 'id';

    # If we're not doing interdiffs, check if id wasn't specified and
    # prompt them with a page that allows them to choose an attachment.
    # Happens when calling plain attachment.cgi from the urlbar directly
    if ($param eq 'id' && !$ARGS->{id}) {
        Bugzilla->template->process("attachment/choose.html.tmpl", $vars) ||
            ThrowTemplateError(Bugzilla->template->error());
        exit;
    }

    my $attach_id = $ARGS->{$param};

    # Validate the specified attachment id. detaint kills $attach_id if
    # non-natural, so use the original value in our exception message here.
    detaint_natural($attach_id) || ThrowUserError("invalid_attach_id", { attach_id => $ARGS->{$param} });

    # Make sure the attachment exists in the database.
    my $attachment = new Bugzilla::Attachment($attach_id)
      || ThrowUserError("invalid_attach_id", { attach_id => $attach_id });

    return $attachment if ($dont_validate_access || check_can_access($attachment));
}

# Make sure the current user has access to the specified attachment.
sub check_can_access {
    my $attachment = shift;
    my $user = Bugzilla->user;

    # Make sure the user is authorized to access this attachment's bug.
    Bugzilla::Bug->check($attachment->bug_id);
    if ($attachment->isprivate && $user->id != $attachment->attacher->id
        && !$user->is_insider)
    {
        ThrowUserError('auth_failure', {action => 'access',
                                        object => 'attachment'});
    }
    return 1;
}

# Determines if the attachment is public -- that is, if users who are
# not logged in have access to the attachment
sub attachmentIsPublic {
    my $attachment = shift;

    return 0 if Bugzilla->params->{'requirelogin'};
    return 0 if $attachment->isprivate;

    my $anon_user = new Bugzilla::User;
    return $anon_user->can_see_bug($attachment->bug_id);
}

# Validates format of a diff/interdiff. Takes a list as an parameter, which
# defines the valid format values. Will throw an error if the format is not
# in the list. Returns either the user selected or default format.
sub validateFormat
{
    # receives a list of legal formats; first item is a default
    my $format = Bugzilla->input_params->{format} || $_[0];
    if (!grep { $_ eq $format } @_)
    {
        ThrowUserError("invalid_format", { format => $format, formats => \@_ });
    }
    return $format;
}

# Validates context of a diff/interdiff. Will throw an error if the context
# is not number, "file" or "patch". Returns the validated, detainted context.
sub validateContext
{
  my $context = Bugzilla->input_params->{context} || "patch";
  if ($context ne "file" && $context ne "patch") {
    detaint_natural($context)
      || ThrowUserError("invalid_context", { context => Bugzilla->input_params->{context} });
  }

  return $context;
}

################################################################################
# Functions
################################################################################

# Display an attachment.
sub view {
    my $action = shift;
    my $ARGS = Bugzilla->input_params;
    my $cgi = Bugzilla->cgi;
    my $attachment;

    if (use_attachbase()) {
        $attachment = validateID(undef, 1);
        my $path = 'attachment.cgi?id=' . $attachment->id;
        # The user is allowed to override the content type of the attachment.
        if ($ARGS->{content_type}) {
            $path .= '&content_type=' . url_quote($ARGS->{content_type});
        }

        # Make sure the attachment is served from the correct server.
        my $bug_id = $attachment->bug_id;
        if ($cgi->url_is_attachment_base($bug_id)) {
            # No need to validate the token for public attachments. We cannot request
            # credentials as we are on the alternate host.
            if (!attachmentIsPublic($attachment)) {
                my $token = $ARGS->{t};
                my ($userid, undef, $token_attach_id) = Bugzilla::Token::GetTokenData($token);
                unless ($userid
                        && detaint_natural($token_attach_id)
                        && ($token_attach_id == $attachment->id))
                {
                    # Not a valid token.
                    print Bugzilla->cgi->redirect('-location' => correct_urlbase() . $path);
                    exit;
                }
                # Change current user without creating cookies.
                Bugzilla->set_user(new Bugzilla::User($userid));
                # Tokens are single use only, delete it.
                delete_token($token);
            }
        }
        elsif ($cgi->url_is_attachment_base) {
            # If we come here, this means that each bug has its own host
            # for attachments, and that we are trying to view one attachment
            # using another bug's host. That's not desired.
            $cgi->redirect_to_urlbase;
        }
        else {
            # We couldn't call Bugzilla->login earlier as we first had to
            # make sure we were not going to request credentials on the
            # alternate host.
            Bugzilla->login();
            my $attachbase = Bugzilla->params->{'attachment_base'};
            # Replace %bugid% by the ID of the bug the attachment
            # belongs to, if present.
            $attachbase =~ s/\%bugid\%/$bug_id/;
            if (attachmentIsPublic($attachment)) {
                # No need for a token; redirect to attachment base.
                print Bugzilla->cgi->redirect(-location => $attachbase . $path);
                exit;
            } else {
                # Make sure the user can view the attachment.
                check_can_access($attachment);
                # Create a token and redirect.
                my $token = url_quote(issue_session_token($attachment->id));
                print Bugzilla->cgi->redirect(-location => $attachbase . "$path&t=$token");
                exit;
            }
        }
    } else {
        do_ssl_redirect_if_required();
        # No alternate host is used. Request credentials if required.
        Bugzilla->login();
        $attachment = validateID();
    }

    # At this point, Bugzilla->login has been called if it had to.
    my $contenttype = $attachment->contenttype;
    my $filename = $attachment->filename;

    # Bug 111522: allow overriding content-type manually in the posted form params.
    if ($ARGS->{content_type})
    {
        $contenttype = $attachment->_check_content_type($ARGS->{content_type});
    }

    # Return the appropriate HTTP response headers.
    $attachment->datasize || ThrowUserError("attachment_removed");

    $filename =~ s/^.*[\/\\]//;
    # escape quotes and backslashes in the filename, per RFCs 2045/822
    $filename =~ s/\\/\\\\/g; # escape backslashes
    $filename =~ s/"/\\"/g; # escape quotes

    # Bug 129398 - View office documents online
    if (defined $action && $action eq 'online_view' && $attachment->isOfficeDocument())
    {
        Bugzilla->send_header();
        my $html = $attachment->_get_converted_html();
        $html =~ s/\n([^\n]*List_20_Paragraph.*?\{.*?)margin:100%;(.*?\}[^\n]*?)\n/\n$1$2\n/;
        print $html;
    }
    else
    {
        my $disposition = Bugzilla->params->{inline_attachment_mime};
        $disposition = $disposition
            && Bugzilla->params->{allow_attachment_display}
            && $contenttype =~ /$disposition/is
            ? "inline" : "attachment";

        if ($cgi->user_agent() =~ /MSIE/ && $cgi->user_agent() !~ /Opera/)
        {
            # Bug 57108 - russian filenames for MSIE
            Encode::_utf8_off($filename);
            Encode::from_to($filename, 'utf-8', 'cp1251');
        }

        # Don't send a charset header with attachments--they might not be UTF-8.
        # However, we do allow people to explicitly specify a charset if they
        # want.
        my $data = $attachment->data;
        if ($contenttype !~ /\bcharset=/i)
        {
            # Detect UTF-8 encoding
            my $is_utf8 = 0;
            if ($contenttype =~ m!^text/!iso)
            {
                Encode::_utf8_on($data);
                $is_utf8 = utf8::decode($data);
                Encode::_utf8_off($data);
            }
            # In order to prevent Apache from adding a charset, we have to send a
            # charset that's a single space.
            $cgi->charset($is_utf8 ? 'utf-8' : ' ');
        }
        $cgi->send_header(-type=>"$contenttype; name=\"$filename\"",
                           -content_disposition=> "$disposition; filename=\"$filename\"",
                           -content_length => $attachment->datasize);
        disable_utf8();
        print $data;
    }
}

sub interdiff {
    # Retrieve and validate parameters
    my $old_attachment = validateID('oldid');
    my $new_attachment = validateID('newid');
    my $format = validateFormat('html', 'raw');
    my $context = validateContext();

    Bugzilla::Attachment::PatchReader::process_interdiff(
        $old_attachment, $new_attachment, $format, $context);
}

sub diff {
    # Retrieve and validate parameters
    my $attachment = validateID();
    my $format = validateFormat('html', 'raw');
    my $context = validateContext();

    # If it is not a patch, view normally.
    if (!$attachment->ispatch) {
        view();
        return;
    }

    Bugzilla::Attachment::PatchReader::process_diff($attachment, $format, $context);
}

# Display all attachments for a given bug in a series of IFRAMEs within one
# HTML page.
sub viewall {
    my $ARGS = Bugzilla->input_params;
    my $vars = {};
    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check($ARGS->{bugid});
    my $bugid = $bug->id;

    my $attachments = Bugzilla::Attachment->get_attachments_by_bug($bugid);
    # Ignore deleted attachments.
    @$attachments = grep { $_->datasize } @$attachments;

    # Define the variables and functions that will be passed to the UI template.
    $vars->{'bug'} = $bug;
    $vars->{'attachments'} = $attachments;

    my $format = "";
    if ($ARGS->{format}) {
        $format = "-".$ARGS->{format};
    }
    $vars->{'show_obsolete'} = $ARGS->{show_obsolete};

    # Generate and return the UI (HTML page) from the appropriate template.
    Bugzilla->template->process("attachment/show-multiple".$format.".html.tmpl", $vars)
      || ThrowTemplateError(Bugzilla->template->error());
}

# Display a form for entering a new attachment.
sub enter {
    my $ARGS = Bugzilla->input_params;
    my $vars = {};
    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check($ARGS->{bugid});
    my $bugid = $bug->id;
    Bugzilla::Attachment->_check_bug($bug);
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    # Retrieve the attachments the user can edit from the database and write
    # them into an array of hashes where each hash represents one attachment.
    my $canEdit = "";
    if (!$user->in_group('editbugs', $bug->product_id)) {
        $canEdit = "AND submitter_id = " . $user->id;
    }
    my $attach_ids = $dbh->selectcol_arrayref("SELECT attach_id FROM attachments
                                               WHERE bug_id = ? AND isobsolete = 0 $canEdit
                                               ORDER BY attach_id", undef, $bugid);

    # Define the variables and functions that will be passed to the UI template.
    $vars->{'bug'} = $bug;
    $vars->{'attachments'} = Bugzilla::Attachment->new_from_list($attach_ids);

    my $flag_types = Bugzilla::FlagType::match({'target_type'  => 'attachment',
                                                'product_id'   => $bug->product_id,
                                                'component_id' => $bug->component_id});
    $vars->{'flag_types'} = $flag_types;
    $vars->{'any_flags_requesteeble'} =
      grep { $_->is_requestable && $_->is_requesteeble } @$flag_types;
    $vars->{'token'} = issue_session_token('create_attachment:');

    my $comment = $ARGS->{comment};
    $comment = '' unless defined $comment;
    $vars->{'commenttext'} = $comment;

    # Generate and return the UI (HTML page) from the appropriate template.
    Bugzilla->template->process("attachment/create.html.tmpl", $vars)
      || ThrowTemplateError(Bugzilla->template->error());
}

# Insert a new attachment into the database.
sub insert
{
    my $ARGS = Bugzilla->input_params;
    my $vars = {};
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    $dbh->bz_start_transaction;

    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check($ARGS->{bugid});
    my $bugid = $bug->id;
    my ($timestamp) = $dbh->selectrow_array("SELECT NOW()");

    # Detect if the user already used the same form to submit an attachment
    my $token = trim($ARGS->{token});
    check_token_data($token, qr/^create_attachment:/s, "show_bug.cgi?id=$bugid");

    my (undef, undef, $old_attach_id) = Bugzilla::Token::GetTokenData($token);
    $old_attach_id =~ s/^create_attachment://;
    if ($old_attach_id) {
        $vars->{'bugid'} = $bugid;
        $vars->{'attachid'} = $old_attach_id;
        Bugzilla->template->process("attachment/cancel-create-dupe.html.tmpl", $vars)
            || ThrowTemplateError(Bugzilla->template->error());
        exit;
    }

    # Check attachments the user tries to mark as obsolete.
    my @obsolete_attachments;
    if ($ARGS->{obsolete}) {
        my @obsolete = $ARGS->{obsolete};
        @obsolete_attachments = Bugzilla::Attachment->validate_obsolete($bug, \@obsolete);
    }

    my ($content_type, $ispatch) = Bugzilla::Attachment::get_content_type();

    my $data = Bugzilla->cgi->upload('data');
    my $filename = '';
    $filename = scalar Bugzilla->cgi->upload('data') || $ARGS->{filename};
    if ($ARGS->{text_attachment} !~ /^\s*$/so)
    {
        $data = $ARGS->{text_attachment};
        $filename = $ARGS->{description};
    }

    if (Bugzilla->params->{utf8})
    {
        # CGI::upload() will probably return non-UTF8 string, so set UTF8 flag on it.
        # Trick taint as utf8::decode() and Encode::_utf8_on() don't work on scalars
        # which were once tainted...
        $filename = trick_taint_copy($filename);
        Encode::_utf8_on($filename);
    }

    my $attachment = Bugzilla::Attachment->create(
        {bug           => $bug,
         creation_ts   => $timestamp,
         data          => $data,
         description   => $ARGS->{description},
         filename      => $filename,
         ispatch       => $ispatch,
         isprivate     => $ARGS->{isprivate},
         mimetype      => $content_type,
         store_in_file => $ARGS->{bigfile},
         base64_content => $ARGS->{base64_content},
         });

    foreach my $obsolete_attachment (@obsolete_attachments) {
        $obsolete_attachment->set_is_obsolete(1);
        $obsolete_attachment->update($timestamp);
    }

    my $comment = $ARGS->{comment};
    $comment = '' unless defined $comment;

    my ($flags, $new_flags) = Bugzilla::Flag->extract_flags_from_cgi(
        $bug, $attachment, $vars
    );
    $attachment->set_flags($flags, $new_flags, $comment);
    $attachment->update($timestamp);

    # Insert a comment about the new attachment into the database.
    $bug->add_comment($comment, { isprivate => $attachment->isprivate,
                                  type => CMT_ATTACHMENT_CREATED,
                                  work_time => $ARGS->{work_time},
                                  extra_data => $attachment->id });

    # When changing the bug status, we have to follow the workflow.
    # Custis Bug 131574 - Update bug status, bug resolution, bug duplicate
    if ($ARGS->{bug_status}) {
        my $bug_status = $ARGS->{bug_status};
        ($bug_status) = grep { $_->name eq $bug_status } @{$bug->status->can_change_to};

        if ($bug_status->comment_required_on_change_from($bug->status) && !$comment)
        {
            ThrowUserError('comment_required', { old => $bug->status,
                                             new => $bug_status });
        }

        $bug->set(bug_status => $ARGS->{bug_status});
        $bug->set(resolution => $ARGS->{resolution});
        $bug->set(dup_id => $ARGS->{dup_id});
    }

    # Assign the bug to the user, if they are allowed to take it
    if ($ARGS->{takebug})
    {
        $bug->set('assigned_to', $user);
    }
    $bug->update($timestamp);

    if ($token) {
        trick_taint($token);
        $dbh->do('UPDATE tokens SET eventdata = ? WHERE token = ?', undef,
                 ("create_attachment:" . $attachment->id, $token));
    }

    $dbh->bz_commit_transaction;

    # Define the variables and functions that will be passed to the UI template.
    $vars->{'attachment'} = $attachment;
    # We cannot reuse the $bug object as delta_ts has eventually been updated
    # since the object was created.
    $vars->{'bugs'} = [new Bugzilla::Bug($bugid)];
    $vars->{'header_done'} = 1;
    $vars->{'contenttypemethod'} = $ARGS->{contenttypemethod};

    Bugzilla->send_mail;

    Bugzilla->add_result_message({
        message     => 'added_attachment',
        id          => $attachment->id,
        bug_id      => $attachment->bug_id,
        description => $attachment->description,
        contenttype => $attachment->contenttype,
        ctype_auto  => $vars->{contenttypemethod} eq 'autodetect',
    });

    Bugzilla::Hook::process('attachment_post_create_result', { vars => $vars });

    # Save operation result into session and redirect (CustIS Bug 64562)
    my $title = "Attachment ".$attachment->id." added to ".Bugzilla->messages->{terms}->{Bug}." ".$attachment->bug_id;
    Bugzilla->save_session_data({ title => $title });
    print Bugzilla->cgi->redirect(-location => 'show_bug.cgi?id='.$attachment->bug_id);
    exit;
}

# Displays a form for editing attachment properties.
# Any user is allowed to access this page, unless the attachment
# is private and the user does not belong to the insider group.
# Validations are done later when the user submits changes.
sub edit {
    my $vars = {};
    my $attachment = validateID();

    my $bugattachments =
        Bugzilla::Attachment->get_attachments_by_bug($attachment->bug_id);
    # We only want attachment IDs.
    @$bugattachments = map { $_->id } @$bugattachments;

    my $any_flags_requesteeble =
        grep { $_->is_requestable && $_->is_requesteeble } @{$attachment->flag_types};
    # Useful in case a flagtype is no longer requestable but a requestee
    # has been set before we turned off that bit.
    $any_flags_requesteeble ||= grep { $_->requestee_id } @{$attachment->flags};
    $vars->{'any_flags_requesteeble'} = $any_flags_requesteeble;
    $vars->{'attachment'} = $attachment;
    $vars->{'attachments'} = $bugattachments;

    # Generate and return the UI (HTML page) from the appropriate template.
    Bugzilla->template->process("attachment/edit.html.tmpl", $vars)
      || ThrowTemplateError(Bugzilla->template->error());
}

# Updates an attachment record. Only users with "editbugs" privileges,
# (or the original attachment's submitter) can edit the attachment.
# Users cannot edit the content of the attachment itself.
sub update {
    my $ARGS = Bugzilla->input_params;
    my $user = Bugzilla->user;
    my $dbh = Bugzilla->dbh;
    my $vars = {};

    # Start a transaction in preparation for updating the attachment.
    $dbh->bz_start_transaction();

    # Retrieve and validate parameters
    my $attachment = validateID();
    my $bug = $attachment->bug;
    $attachment->_check_bug;
    my $can_edit = $attachment->validate_can_edit($bug->product_id);

    if ($can_edit) {
        $attachment->set_description($ARGS->{description});
        $attachment->set_is_patch($ARGS->{ispatch});
        $attachment->set_content_type($ARGS->{contenttypeentry});
        $attachment->set_is_obsolete($ARGS->{isobsolete});
        $attachment->set_is_private($ARGS->{isprivate});
        $attachment->set_filename($ARGS->{filename});

        # Now make sure the attachment has not been edited since we loaded the page.
        if (defined $ARGS->{delta_ts}
            && $ARGS->{delta_ts} ne $attachment->modification_time)
        {
            ($vars->{'operations'}) =
                Bugzilla::Bug::GetBugActivity($bug->id, $attachment->id, $ARGS->{delta_ts});

            # The token contains the old modification_time. We need a new one for global/hidden-fields.html.tmpl
            $ARGS->{token} = issue_hash_token([$attachment->id, $attachment->modification_time]);

            # If the modification date changed but there is no entry in
            # the activity table, this means someone commented only.
            # In this case, there is no reason to midair.
            if (scalar(@{$vars->{'operations'}})) {
                $ARGS->{delta_ts} = $attachment->modification_time;
                $vars->{'attachment'} = $attachment;
                $vars->{comment} = $ARGS->{comment};

                # Warn the user about the mid-air collision and ask them what to do.
                Bugzilla->template->process("attachment/midair.html.tmpl", $vars)
                  || ThrowTemplateError(Bugzilla->template->error());
                exit;
            }
        }
    }

    # We couldn't do this check earlier as we first had to validate attachment ID
    # and display the mid-air collision page if modification_time changed.
    my $token = $ARGS->{token};
    check_hash_token($token, [$attachment->id, $attachment->modification_time]);

    # If the user submitted a comment while editing the attachment,
    # add the comment to the bug. Do this after having validated isprivate!
    my $comment = $ARGS->{comment};
    if (defined $comment && trim($comment) ne '') {
        $bug->add_comment($comment, { isprivate => $attachment->isprivate,
                                      type => CMT_ATTACHMENT_UPDATED,
                                      work_time => $ARGS->{work_time},
                                      extra_data => $attachment->id });
    }

    if ($can_edit) {
        my ($flags, $new_flags) =
          Bugzilla::Flag->extract_flags_from_cgi($bug, $attachment, $vars);
        $attachment->set_flags($flags, $new_flags, $comment);
    }

    # Figure out when the changes were made.
    my $timestamp = $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    if ($can_edit) {
        my $changes = $attachment->update($timestamp);
        # If there are changes, we updated delta_ts in the DB. We have to
        # reflect this change in the bug object.
        $bug->{delta_ts} = $timestamp if scalar(keys %$changes);
    }

    # Commit the comment, if any.
    $bug->update($timestamp);

    # Commit the transaction now that we are finished updating the database.
    $dbh->bz_commit_transaction();

    # Define the variables and functions that will be passed to the UI template.
    $vars->{'attachment'} = $attachment;
    $vars->{'bugs'} = [$bug];
    $vars->{'header_done'} = 1;

    Bugzilla->send_mail;

    Bugzilla->add_result_message({
        message     => 'changed_attachment',
        id          => $attachment->id,
        bug_id      => $attachment->bug_id,
        description => $attachment->description,
    });

    # Save operation result into session and redirect (CustIS Bug 64562)
    Bugzilla->save_session_data;
    print Bugzilla->cgi->redirect(-location => 'show_bug.cgi?id='.$attachment->bug_id);
    exit;
}

# Only administrators can delete attachments.
sub delete_attachment {
    my $ARGS = Bugzilla->input_params;
    my $vars = {};
    my $user = Bugzilla->login(LOGIN_REQUIRED);
    my $dbh = Bugzilla->dbh;

    $user->in_group('admin')
      || ThrowUserError('auth_failure', {group  => 'admin',
                                         action => 'delete',
                                         object => 'attachment'});

    Bugzilla->params->{'allow_attachment_deletion'}
      || ThrowUserError('attachment_deletion_disabled');

    # Make sure the administrator is allowed to edit this attachment.
    my $attachment = validateID();
    Bugzilla::Attachment->_check_bug($attachment->bug);

    $attachment->datasize || ThrowUserError('attachment_removed');

    # We don't want to let a malicious URL accidentally delete an attachment.
    my $token = trim($ARGS->{token});
    if ($token) {
        my ($creator_id, $date, $event) = Bugzilla::Token::GetTokenData($token);
        unless ($creator_id
                  && ($creator_id == $user->id)
                  && ($event eq 'delete_attachment' . $attachment->id))
        {
            # The token is invalid.
            ThrowUserError('token_does_not_exist');
        }

        my $bug = new Bugzilla::Bug($attachment->bug_id);

        # The token is valid. Delete the content of the attachment.
        my $msg;
        $vars->{'attachment'} = $attachment;
        $vars->{'date'} = $date;
        $vars->{'reason'} = clean_text($ARGS->{reason} || '');

        Bugzilla->template->process("attachment/delete_reason.txt.tmpl", $vars, \$msg)
          || ThrowTemplateError(Bugzilla->template->error());

        # Paste the reason provided by the admin into a comment.
        $bug->add_comment($msg);

        # If the attachment is stored locally, remove it.
        if (-e $attachment->_get_local_filename) {
            unlink $attachment->_get_local_filename;
        }
        $attachment->remove_from_db();

        # Now delete the token.
        delete_token($token);

        # Insert the comment.
        $bug->update();

        # Required to display the bug the deleted attachment belongs to.
        $vars->{'bugs'} = [$bug];
        $vars->{'header_done'} = 1;

        Bugzilla->send_mail;

        # Save operation result into session and redirect (CustIS Bug 64562)
        Bugzilla->add_result_message({
            message     => 'changed_attachment',
            id          => $attachment->id,
            bug_id      => $attachment->bug_id,
            description => $attachment->description,
        });
        Bugzilla->save_session_data;
        print Bugzilla->cgi->redirect(-location => 'show_bug.cgi?id='.$attachment->bug_id);
        exit;
    }
    else {
        # Create a token.
        $token = issue_session_token('delete_attachment' . $attachment->id);

        $vars->{'a'} = $attachment;
        $vars->{'token'} = $token;

        Bugzilla->template->process("attachment/confirm-delete.html.tmpl", $vars)
          || ThrowTemplateError(Bugzilla->template->error());
    }
}

# CustIS Bug 129399 - download all attachments in a single ZIP archive
sub all_attachments_in_zip
{
    my $ARGS = Bugzilla->input_params;
    my $user = Bugzilla->login(LOGIN_REQUIRED);

    # Retrieve and validate parameters
    my $bug = Bugzilla::Bug->check($ARGS->{bugid});
    my $bugid = $bug->id;

    my $attachments = Bugzilla::Attachment->get_attachments_by_bug($bugid);
    # Ignore deleted attachments.
    @$attachments = grep { $_->datasize } @$attachments;

    # Create ZIP file
    my $transliter = Lingua::Translit->new('GOST 7.79 RUS');
    my $archive = Archive::Zip->new();
    my $filename = "attachments_for_bug_$bugid.zip";
    foreach my $file (@$attachments)
    {
        my $fn = $file->{filename};
        Encode::_utf8_off($fn);
        $fn = $transliter->translit($fn);
        my $path = $file->_get_local_filename;
        my $member = $archive->addFile($path, $fn);
        $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
    }
    # FIXME We don't send Content-Length - is it always OK?
    # We could use IO::Scalar for it.
    Bugzilla->cgi->send_header(
        -type => "application/zip; name=\"$filename\"",
        -content_disposition => "attachment; filename=\"$filename\""
    );
    $archive->writeToFileHandle(*STDOUT);
}
