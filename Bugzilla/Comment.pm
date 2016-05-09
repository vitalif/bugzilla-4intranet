#!/usr/bin/perl
# Bug comment class (based on GenericObject)
# License: MPL 1.1
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
#   James Robson <arbingersys@gmail.com>

package Bugzilla::Comment;

use strict;
use base qw(Bugzilla::GenericObject);

use Bugzilla::Attachment;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Template;

use constant DB_TABLE => 'longdescs';
use constant ID_FIELD => 'comment_id';
use constant LIST_ORDER => 'bug_when';
use constant NAME_FIELD => 'comment_id';
use constant CLASS_NAME => 'comment';

use constant OVERRIDE_SETTERS => {
    type => \&_check_type,
    extra_data => \&_check_extra_data,
};

#########################
# Database Manipulation #
#########################

sub update
{
    my $self = shift;
    my $changes = $self->SUPER::update(@_);
    $self->bug->_sync_fulltext();
    return $changes;
}

# Speeds up displays of comment lists by loading all ->author objects at once for a whole list.
sub preload
{
    my ($class, $comments) = @_;
    my %user_ids = map { $_->{who} => 1 } @$comments;
    my $users = Bugzilla::User->new_from_list([keys %user_ids]);
    my %user_map = map { $_->id => $_ } @$users;
    foreach my $comment (@$comments)
    {
        $comment->{who_obj} = $user_map{$comment->{who}};
    }
}

###############################
####      Accessors      ######
###############################

sub count       { $_[0]->{count} }
sub creation_ts { $_[0]->{bug_when} }
sub is_private  { $_[0]->{isprivate} }
sub bug         { $_[0]->get_object('bug_id') }
sub author      { $_[0]->get_object('who') }

sub body
{
    my ($self, $preview) = @_;
    $preview = 0 if !$preview;
    if ($preview && !$self->check_length)
    {
        my $max_lines = Bugzilla->params->{preview_comment_lines} - 1;
        my $line_length = Bugzilla->params->{comment_line_length} - 1;
        my $result = $self->{thetext};
        $result =~ s/(>[^\n]*?\n)+/>...\n/g;
        $result =~ s/^((?>[^\n]{0,$line_length}.){0,$max_lines}(?>[^\n]{0,$line_length}\s)).*$/$1.../s if !$self->check_length($result);
        return $result;
    }
    return $_[0]->{thetext};
}

sub is_about_attachment
{
    my ($self) = @_;
    return 1 if ($self->type == CMT_ATTACHMENT_CREATED || $self->type == CMT_ATTACHMENT_UPDATED);
    return 0;
}

sub attachment
{
    my ($self) = @_;
    return undef if not $self->is_about_attachment;
    $self->{attachment} ||= new Bugzilla::Attachment($self->extra_data);
    return $self->{attachment};
}

# %$params:
# is_bugmail => format as plaintext (TODO rename to 'plaintext')
# wrap => wrap or not
sub body_full
{
    my ($self, $params) = @_;
    $params ||= {};
    my $preview = $params->{preview} ? $params->{preview} : 0;
    my $wo_preview = $params->{wo_preview} ? $params->{wo_preview} : 0;
    $preview = 0 if $wo_preview;
    my $template = Bugzilla->template_inner;
    my $body;
    my $t = $self->type;
    if ($t && $t != CMT_BACKDATED_WORKTIME && $t != CMT_WORKTIME)
    {
        $template->process("bug/format_comment.txt.tmpl", { comment => $self, %$params }, \$body)
            || ThrowTemplateError($template->error());
        $body =~ s/^X//;
    }
    else
    {
        $body = $self->body($preview);
    }
    if (!$params->{is_bugmail})
    {
        $body = Bugzilla::Template::quoteUrls($body, $self->bug_id, $self);
    }
    if ($params->{wrap})
    {
        $body = wrap_comment($body);
        if (!$preview && !($self->check_length) && !$wo_preview)
        {
            $params->{preview} = 1;
            my $new_body;
            my $vars = {
                preview => $self->body_full($params),
                body => $body,
                id => $self->id,
            };
            $template->process("bug/comment-preview-text.html.tmpl", $vars, \$new_body)
                || ThrowTemplateError($template->error());
            $body = $new_body;
        }
    }
    return $body;
}

sub check_length
{
    my ($self, $test) = @_;
    $test ||= $self->{thetext};
    my $line_length = Bugzilla->params->{comment_line_length};
    my $length = $test =~ s/([^\n]{$line_length}|\n)/$1/g;
    $length = 0 if !$length;
    return $length <= Bugzilla->params->{preview_comment_lines};
}

##############
# Validators #
##############

sub _check_extra_data
{
    my ($invocant, $extra_data, $type) = @_;
    $type = $invocant->type if ref $invocant;
    if ($type == CMT_NORMAL or $type == CMT_POPULAR_VOTES)
    {
        if (defined $extra_data)
        {
            ThrowCodeError('comment_extra_data_not_allowed', { type => $type, extra_data => $extra_data });
        }
    }
    else
    {
        if (!defined $extra_data)
        {
            ThrowCodeError('comment_extra_data_required', { type => $type });
        }
        if ($type == CMT_MOVED_TO)
        {
            $extra_data = Bugzilla::User->check($extra_data)->login;
        }
        elsif ($type == CMT_ATTACHMENT_CREATED || $type == CMT_ATTACHMENT_UPDATED)
        {
             my $attachment = Bugzilla::Attachment->check({ id => $extra_data });
             $extra_data = $attachment->id;
        }
        else
        {
            my $original = $extra_data;
            detaint_natural($extra_data) || ThrowCodeError('comment_extra_data_not_numeric',
                { type => $type, extra_data => $original });
        }
    }

    return $extra_data;
}

sub _check_type
{
    my ($invocant, $type) = @_;
    $type ||= CMT_NORMAL;
    my $original = $type;
    detaint_natural($type) || ThrowCodeError('comment_type_invalid', { type => $original });
    return $type;
}

1;
__END__

=head1 NAME

Bugzilla::Comment - A Comment for a given bug 

=head1 SYNOPSIS

 use Bugzilla::Comment;

 my $comment = Bugzilla::Comment->new($comment_id);
 my $comments = Bugzilla::Comment->new_from_list($comment_ids);

=head1 DESCRIPTION

Bugzilla::Comment represents a comment attached to a bug.

This implements all standard C<Bugzilla::Object> methods. See 
L<Bugzilla::Object> for more details.

=head2 Accessors

=over

=item C<bug_id>

C<int> The ID of the bug to which the comment belongs.

=item C<creation_ts>

C<string> The comment creation timestamp.

=item C<body>

C<string> The body without any special additional text.

=item C<work_time>

C<string> Time spent as related to this comment.

=item C<is_private>

C<boolean> Comment is marked as private

=item C<already_wrapped>

If this comment is stored in the database word-wrapped, this will be C<1>.
C<0> otherwise.

=item C<author>

L<Bugzilla::User> who created the comment.

=item C<body_full>

=over

=item B<Description>

C<string> Body of the comment, including any special text (such as
"this bug was marked as a duplicate of...").

=item B<Params>

=over

=item C<is_bugmail>

C<boolean>. C<1> if this comment should be formatted specifically for
bugmail.

=item C<wrap>

C<boolean>. C<1> if the comment should be returned word-wrapped.

=back

=item B<Returns>

A string, the full text of the comment as it would be displayed to an end-user.

=back

=back

=cut
