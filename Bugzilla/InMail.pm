# Incoming mail handler for Bugzilla
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>, Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::InMail;

use strict;
use warnings;

use Email::Address;
use Email::Reply qw(reply);
use Email::MIME;
use Email::MIME::Attachment::Stripper;
use HTML::Strip;
use Getopt::Long qw(:config bundling);
use Pod::Usage;
use Encode;
use Scalar::Util qw(blessed);

use Bugzilla;
use Bugzilla::Attachment;
use Bugzilla::Bug;
use Bugzilla::Hook;
use Bugzilla::BugMail;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Mailer;
use Bugzilla::Token;
use Bugzilla::User;
use Bugzilla::Util;

#############
# Constants #
#############

# This is the USENET standard line for beginning a signature block
# in a message. RFC-compliant mailers use this.
use constant SIGNATURE_DELIMITER => '-- ';

sub process_inmail
{
    my ($mail_text) = @_;

    my $input_email = Email::MIME->new($mail_text);

    my $status = eval
    {
        my $mail_fields = parse_mail($input_email);
        if (!$mail_fields)
        {
            return 0;
        }

        Bugzilla::Hook::process('email_in_after_parse', { fields => $mail_fields });

        my $attachments = delete $mail_fields->{attachments};
        select_user($mail_fields->{reporter}, $mail_fields->{_reporter_name});

        my ($bug, $comment);
        if ($mail_fields->{bug_id})
        {
            $bug = Bugzilla::Bug::create_or_update($mail_fields);
            $comment = $bug->comments->[-1] if trim($mail_fields->{comment});
        }
        else
        {
            ($bug, $comment) = post_bug($mail_fields);
        }

        handle_attachments($bug, $attachments, $comment);

        Bugzilla->send_mail;

        return 1;
    };

    if ($@)
    {
        # Report error to the sender of original message
        my $msg = $@;
        if (ref $msg eq 'Bugzilla::Error')
        {
            $msg = $msg->{message};
        }
        if ($input_email)
        {
            my $from = Bugzilla->params->{mailfrom};
            my $reply = reply(to => $input_email, from => $from, top_post => 1, body => "$msg\n");
            MessageToMTA($reply->as_string);
        }
        return -1;
    }

    return $status;
}

sub select_user
{
    my ($reporter, $reporter_name) = @_;

    my $username = $reporter;
    # If emailsuffix is in use, we have to remove it from the email address.
    if (my $suffix = Bugzilla->params->{emailsuffix})
    {
        $username =~ s/\Q$suffix\E$//i;
    }

    # First try to select user with name $username
    my $user = Bugzilla::User->new({ name => $username });

    # Then try to find alias $username for some user
    unless ($user)
    {
        my $dbh = Bugzilla->dbh;
        ($user) = $dbh->selectrow_array("SELECT userid FROM emailin_aliases WHERE address=?", undef, trim($reporter));
        $user = Bugzilla::User->new({ id => $user }) if $user;
        # Then check if autoregistration is enabled
        unless ($user)
        {
            unless (Bugzilla->params->{emailin_autoregister})
            {
                ThrowUserError('invalid_username', { name => $username });
            }
            # Then try to autoregister unknown user
            $user = Bugzilla::User->create({
                login_name      => $username,
                realname        => $reporter_name,
                cryptpassword   => 'a3#',
                disabledtext    => '',
            });
        }
    }

    if (!$user->is_enabled)
    {
        ThrowUserError('account_disabled', { disabled_reason => $user->disabledtext });
    }

    Bugzilla->set_user($user);
}

sub parse_mail
{
    my ($input_email) = @_;

    my %fields;
    Bugzilla::Hook::process('email_in_before_parse', { mail => $input_email, fields => \%fields });
    # RFC 3834 - Recommendations for Automatic Responses to Electronic Mail
    # Automatic responses SHOULD NOT be issued in response to any
    # message which contains an Auto-Submitted header field (see below),
    # where that field has any value other than "no".
    # F*cking MS Exchange sometimes does not append Auto-Submitted header
    # to delivery status reports, so also check content-type.
    my $autosubmitted;
    if (lc($input_email->header('Auto-Submitted') || 'no') ne 'no' ||
        ($input_email->header('X-Auto-Response-Suppress') || '') =~ /all/iso ||
        ($input_email->header('Content-Type') || '') =~ /delivery-status/iso)
    {
        return undef;
    }

    my $dbh = Bugzilla->dbh;

    # Fetch field => value from emailin_fields table
    my ($toemail) = Email::Address->parse($input_email->header('To'));
    %fields = (%fields, map { @$_ } @{ $dbh->selectall_arrayref(
        "SELECT field, value FROM emailin_fields WHERE address=?",
        undef, $toemail) || [] });

    my $summary = $input_email->header('Subject');
    if ($summary =~ /\[\s*Bug\s*(\d+)\s*\](.*)/i)
    {
        $fields{bug_id} = $1;
        $summary = trim($2);
    }
    $fields{_subject} = $summary;

    # Add CC's from email Cc: header
    $fields{newcc} = $input_email->header('Cc');
    $fields{newcc} = $fields{newcc} && (join ', ', map { [ Email::Address->parse($_) ] -> [0] }
        split /\s*,\s*/, $fields{newcc}) || undef;

    my ($body, $attachments) = get_body_and_attachments($input_email);
    if (@$attachments)
    {
        $fields{attachments} = $attachments;
    }

    $body = remove_leading_blank_lines($body);

    Bugzilla::Hook::process("emailin-filter_body", { body => \$body });

    my @body_lines = split(/\r?\n/s, $body);
    my $fields_by_name = { map { (lc($_->description) => $_->name, lc($_->name) => $_->name) } Bugzilla->get_fields({ obsolete => 0 }) };

    # If there are fields specified.
    if ($body =~ /^\s*@/s)
    {
        my $current_field;
        while (my $line = shift @body_lines)
        {
            # If the sig is starting, we want to keep this in the
            # @body_lines so that we don't keep the sig as part of the
            # comment down below.
            if ($line eq SIGNATURE_DELIMITER)
            {
                unshift(@body_lines, $line);
                last;
            }
            # Otherwise, we stop parsing fields on the first blank line.
            $line = trim($line);
            last if !$line;
            if ($line =~ /^\@\s*(.+?)\s*=\s*(.*)\s*/)
            {
                $current_field = $fields_by_name->{lc($1)} || lc($1);
                $fields{$current_field} = $2;
            }
            else
            {
                $fields{$current_field} .= " $line";
            }
        }
    }

    %fields = %{ Bugzilla::Bug::map_fields(\%fields) };

    my ($reporter) = Email::Address->parse($input_email->header('From'));
    $fields{reporter} = $reporter->address;

    {
        my $r;
        if ($r = $reporter->phrase)
        {
            $r .= ' ' . $reporter->comment if $reporter->comment;
        }
        else
        {
            $r = $reporter->address;
        }
        $fields{_reporter_name} = $r;
    }

    # The summary line only affects us if we're doing a post_bug.
    # We have to check it down here because there might have been
    # a bug_id specified in the body of the email.
    if (!$fields{bug_id} && !$fields{short_desc})
    {
        $fields{short_desc} = $summary;
    }

    my $comment = '';
    # Get the description, except the signature.
    foreach my $line (@body_lines)
    {
        last if $line eq SIGNATURE_DELIMITER;
        $comment .= "$line\n";
    }
    $fields{comment} = $comment;

    return \%fields;
}

sub post_bug
{
    my ($fields) = @_;
    my $bug;
    $Bugzilla::Error::IN_EVAL++;
    eval
    {
        my ($retval, $non_conclusive_fields) =
            Bugzilla::User::match_field({
                assigned_to => { type => 'single' },
                qa_contact  => { type => 'single' },
                cc          => { type => 'multi'  }
            }, $fields, MATCH_SKIP_CONFIRM);
        if ($retval != USER_MATCH_SUCCESS)
        {
            ThrowUserError('user_match_too_many', { fields => $non_conclusive_fields });
        }
        $bug = Bugzilla::Bug::create_or_update($fields);
    };
    $Bugzilla::Error::IN_EVAL--;
    if (my $err = $@)
    {
        my $format = "\n\nIncoming mail format for entering bugs:\n\n\@field = value\n\@field = value\n...\n\n<Bug description...>\n";
        if (blessed $err && $err->{message})
        {
            $err->{message} .= $format;
        }
        else
        {
            $err .= $format;
        }
        die $err;
    }
    if ($bug)
    {
        return ($bug, $bug->comments->[0]);
    }
    return undef;
}

sub handle_attachments
{
    my ($bug, $attachments, $comment) = @_;
    return if !$attachments;
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    my ($update_comment, $update_bug);
    foreach my $attachment (@$attachments)
    {
        my $data = delete $attachment->{payload};
        $attachment->{content_type} ||= 'application/octet-stream';
        my $obj = Bugzilla::Attachment->create({
            bug         => $bug,
            description => $attachment->{filename},
            filename    => $attachment->{filename},
            mimetype    => $attachment->{content_type},
            data        => $data,
        });
        # If we added a comment, and our comment does not already have a type,
        # and this is our first attachment, then we make the comment an
        # "attachment created" comment.
        if ($comment and !$comment->type and !$update_comment)
        {
            $comment->set_type(CMT_ATTACHMENT_CREATED, $obj->id);
            $update_comment = 1;
        }
        else
        {
            $bug->add_comment('', { type => CMT_ATTACHMENT_CREATED, extra_data => $obj->id });
            $update_bug = 1;
        }
    }
    # We only update the comments and bugs at the end of the transaction,
    # because doing so modifies bugs_fulltext, which is a non-transactional
    # table.
    $bug->update() if $update_bug;
    $comment->update() if $update_comment;
    $dbh->bz_commit_transaction();
}

######################
# Helper Subroutines #
######################

sub get_body_and_attachments
{
    my ($email) = @_;

    my $ct = $email->content_type || 'text/plain';

    my $body;
    my $attachments = [];
    if ($ct =~ /^multipart\/(alternative|signed)/i)
    {
        $body = get_text_alternative($email);
    }
    else
    {
        my $stripper = new Email::MIME::Attachment::Stripper($email, force_filename => 1);
        my $message = $stripper->message;
        $body = get_text_alternative($message);
        $attachments = [$stripper->attachments];
    }
    $email->charset_set('utf8');
    $email->body_str_set($body);

    return ($body, $attachments);
}

sub rm_line_feeds
{
    my ($t) = @_;
    $t =~ s/[\n\r]+/ /giso;
    return $t;
}

sub get_text_alternative
{
    my ($email) = @_;

    my @parts = $email->parts;
    my $body;
    foreach my $part (@parts)
    {
        my $ct = $part->content_type || 'text/plain';
        my $charset = 'iso-8859-1';
        # The charset may be quoted.
        if ($ct =~ /charset="?([^;"]+)/)
        {
            $charset = $1;
        }
        if (!$ct || $ct =~ /^text\/plain/i)
        {
            $body = $part->body;
        }
        elsif ($ct =~ /^text\/html/i)
        {
            $body = $part->body;
            $body =~ s/<table[^<>]*class=[\"\']?difft[^<>]*>.*?<\/table\s*>//giso;
            $body =~ s/(<a[^<>]*>.*?<\/a\s*>)/rm_line_feeds($1)/gieso;
            Bugzilla::Hook::process("emailin-filter_html", { body => \$body });
            $body = HTML::Strip->new->parse($body);
        }
        if (defined $body)
        {
            if (Bugzilla->params->{utf8} && !utf8::is_utf8($body))
            {
                $body = Encode::decode($charset, $body);
            }
            last;
        }
    }

    if (!defined $body)
    {
        # Note that this only happens if the email does not contain any
        # text/plain parts. If the email has an empty text/plain part,
        # you're fine, and this message does NOT get thrown.
        ThrowUserError('email_no_text_plain');
    }

    return $body;
}

sub remove_leading_blank_lines
{
    my ($text) = @_;
    $text =~ s/^(\s*\n)+//s;
    return $text;
}

# Use UTF-8 in Email::Reply to correctly quote the body
my $crlf = "\x0d\x0a";
my $CRLF = $crlf;
undef *Email::Reply::_quote_body;
*Email::Reply::_quote_body = sub
{
    my ($self, $part) = @_;
    return if length $self->{quoted};
    return map $self->_quote_body($_), $part->parts if $part->parts > 1;
    return if $part->content_type && $part->content_type !~ m[\btext/plain\b];

    my $body = $part->body;
    Encode::_utf8_on($body);

    $body = ($self->_strip_sig($body) || $body)
        if !$self->{keep_sig} && $body =~ /$crlf--\s*$crlf/o;

    my ($end) = $body =~ /($crlf)/;
    $end ||= $CRLF;
    $body =~ s/[\r\n\s]+$//;
    $body = $self->_quote_orig_body($body);
    $body = "$self->{attrib}$end$body$end";

    $self->{crlf}   = $end;
    $self->{quoted} = $body;
};

1;
__END__
