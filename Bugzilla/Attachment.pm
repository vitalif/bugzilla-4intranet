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
#                 Marc Schumann <wurblzap@gmail.com>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::Attachment;

=head1 NAME

Bugzilla::Attachment - Bugzilla attachment class.

=head1 SYNOPSIS

  use Bugzilla::Attachment;

  # Get the attachment with the given ID.
  my $attachment = new Bugzilla::Attachment($attach_id);

  # Get the attachments with the given IDs.
  my $attachments = Bugzilla::Attachment->new_from_list($attach_ids);

=head1 DESCRIPTION

Attachment.pm represents an attachment object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

The methods that are specific to B<Bugzilla::Attachment> are listed
below.

=cut

use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Flag;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Hook;

use LWP::MediaTypes;
use MIME::Base64;

use base qw(Bugzilla::Object);

###############################
####    Initialization     ####
###############################

use constant DB_TABLE   => 'attachments';
use constant ID_FIELD   => 'attach_id';
use constant LIST_ORDER => ID_FIELD;

sub DB_COLUMNS
{
    my $dbh = Bugzilla->dbh;
    return qw(
        attach_id
        bug_id
        description
        filename
        isobsolete
        ispatch
        isprivate
        mimetype
        modification_time
        submitter_id),
        $dbh->sql_date_format('attachments.creation_ts') . ' AS creation_ts',
        'creation_ts AS creation_ts_orig';
}

use constant REQUIRED_CREATE_FIELDS => qw(
    bug
    data
    description
    filename
    mimetype
);

use constant UPDATE_COLUMNS => qw(
    description
    filename
    isobsolete
    ispatch
    isprivate
    mimetype
);

use constant VALIDATORS => {
    bug           => \&_check_bug,
    description   => \&_check_description,
    ispatch       => \&Bugzilla::Object::check_boolean,
    isprivate     => \&_check_is_private,
    mimetype      => \&_check_content_type,
    store_in_file => \&_check_store_in_file,
};

use constant UPDATE_VALIDATORS => {
    filename   => \&_check_filename,
    isobsolete => \&Bugzilla::Object::check_boolean,
};

=pod

=head2 Instance Properties

=over

=item B<bug_id>

the ID of the bug to which the attachment is attached

=item B<description>

user-provided text describing the attachment

=item B<contenttype>

the attachment's MIME media type

=item B<attached>

the date and time on which the attacher attached the attachment

=item B<modification_time>

the date and time on which the attachment was last modified.

=item B<filename>

the name of the file the attacher attached

=item B<ispatch>

whether or not the attachment is a patch

=item B<isobsolete>

whether or not the attachment is obsolete

=item B<isprivate>

whether or not the attachment is private

=item B<bug>

the bug object to which the attachment is attached

=item B<attacher>

the user who attached the attachment

=item B<is_viewable>

Returns 1 if the attachment has a content-type viewable in this browser.
Note that we don't use $cgi->Accept()'s ability to check if a content-type
matches, because this will return a value even if it's matched by the generic
*/* which most browsers add to the end of their Accept: headers.

=item B<data>

the content of the attachment

=item B<isOfficeDocument>

check if the attachment has office document content type

=item B<convert_to>

return converted html or pdf from the content of the attachment

=item B<datasize>

the length (in characters) of the attachment content

=item B<flags>

flags that have been set on the attachment

=item B<flag_types>

Return all flag types available for this attachment as well as flags
already set, grouped by flag type.

=back

=cut

sub bug_id { $_[0]->{bug_id} }
sub description { $_[0]->{description} }
sub contenttype { $_[0]->{mimetype} }
sub attached { $_[0]->{creation_ts} }
sub modification_time { $_[0]->{modification_time} }
sub filename { $_[0]->{filename} }
sub ispatch { $_[0]->{ispatch} }
sub isobsolete { $_[0]->{isobsolete} }
sub isprivate { $_[0]->{isprivate} }

sub bug
{
    my $self = shift;
    $self->{bug} ||= Bugzilla::Bug->new($self->bug_id);
    return $self->{bug};
}

sub attacher
{
    my $self = shift;
    return $self->{attacher} if exists $self->{attacher};
    $self->{attacher} = new Bugzilla::User($self->{submitter_id});
    return $self->{attacher};
}

sub is_viewable
{
    my $self = shift;
    my $contenttype = $self->contenttype;
    my $cgi = Bugzilla->cgi;

    # We assume we can view all text and image types.
    return 1 if ($contenttype =~ /^(text|image)\//);

    # Mozilla can view XUL. Note the trailing slash on the Gecko detection to
    # avoid sending XUL to Safari.
    return 1 if (($contenttype =~ /^application\/vnd\.mozilla\./) && ($cgi->user_agent() =~ /Gecko\//));

    # If it's not one of the above types, we check the Accept: header for any
    # types mentioned explicitly.
    my $accept = join(",", $cgi->Accept());
    return 1 if ($accept =~ /^(.*,)?\Q$contenttype\E(,.*)?$/);

    return 0;
}

sub data
{
    my $self = shift;
    return $self->{data} if exists $self->{data};

    # First try to get the attachment data from the database.
    ($self->{data}) = Bugzilla->dbh->selectrow_array(
        "SELECT thedata FROM attach_data WHERE id = ?", undef, $self->id
    );

    # If there's no attachment data in the database, the attachment is stored
    # in a local file, so retrieve it from there.
    if (length($self->{data}) == 0)
    {
        if (open(AH, $self->_get_local_filename()))
        {
            local $/;
            binmode AH;
            $self->{data} = <AH>;
            close(AH);
        }
    }

    return $self->{data};
}

sub isOfficeDocument
{
    my $self = shift;
    return 1 && $self->{mimetype} =~ m/(officedocument|msword|excel|html|opendocument)/;
}

sub convert_to
{
    my $self = shift;
    my ($format) = @_;
    $format = $format eq 'pdf' ? 'pdf' : 'html';
    my $file_path = $self->_get_local_filename();
    my $file_cache_path = $self->_get_local_cache_filename().'.'.$format;
    my $dir_cache_path = $self->_get_local_cache_dir();
    my $converted_html;

    if (!-e $file_cache_path)
    {
        # Work with existing files
        if (-e $file_path)
        {
            $ENV{HOME} = '/tmp/';
            system("/usr/bin/libreoffice --invisible --convert-to $format --outdir $dir_cache_path $file_path 1>&2");
            if (-e "$dir_cache_path/attachment.$format")
            {
                rename "$dir_cache_path/attachment.$format", $file_cache_path;
            }
        }
        else
        {
            # Work with blob from the DB. Unused and unimplemented by now.
            # FIXME: save data from DB to file and convert it to HTML.
        }
    }

    # Read cached converted file
    if (-e $file_cache_path && open(AH, $file_cache_path))
    {
        local $/ = undef;
        $converted_html = <AH>;
        close AH;
        # Known bug of Perl: previously tainted scalar doesn't want to change its UTF-8 status
        trick_taint($converted_html);
        if ($format eq 'html')
        {
            $converted_html =~ s/\n([^\n]*List_\d+_Paragraph.*?\{.*?)margin:100%;(.*?\}[^\n]*?)\n/\n$1$2\n/;
        }
    }

    return $converted_html;
}

# datasize is a property of the data itself, and it's unclear whether we should
# expose it at all, since you can easily derive it from the data itself: in TT,
# attachment.data.size; in Perl, length($attachment->{data}).  But perhaps
# it makes sense for performance reasons, since accessing the data forces it
# to get retrieved from the database/filesystem and loaded into memory,
# while datasize avoids loading the attachment into memory, calling SQL's
# LENGTH() function or stat()ing the file instead.  I've left it in for now.

sub datasize
{
    my $self = shift;
    return $self->{datasize} if exists $self->{datasize};

    # If we have already retrieved the data, return its size.
    return length($self->{data}) if exists $self->{data};

    $self->{datasize} = Bugzilla->dbh->selectrow_array(
        "SELECT LENGTH(thedata) FROM attach_data WHERE id = ?", undef, $self->id
    ) || 0;

    # If there's no attachment data in the database, either the attachment
    # is stored in a local file, and so retrieve its size from the file,
    # or the attachment has been deleted.
    unless ($self->{datasize})
    {
        if (open(AH, $self->_get_local_filename()))
        {
            binmode AH;
            $self->{datasize} = (stat(AH))[7];
            close(AH);
        }
    }

    return $self->{datasize};
}

sub _get_local_filename
{
    my $self = shift;
    my $hash = ($self->id % 100) + 100;
    $hash =~ s/.*(\d\d)$/group.$1/;
    return bz_locations()->{attachdir} . "/$hash/attachment." . $self->id;
}

sub _get_local_cache_filename
{
    my $self = shift;
    my $hash = ($self->id % 100) + 100;
    $hash =~ s/.*(\d\d)$/group.$1/;
    return bz_locations()->{attachdir} . "_cache/$hash/attachment." . $self->id;
}

sub _get_local_cache_dir
{
    my $self = shift;
    my $hash = ($self->id % 100) + 100;
    $hash =~ s/.*(\d\d)$/group.$1/;
    return bz_locations()->{attachdir} . "_cache/$hash";
}

sub flags
{
    my $self = shift;

    # Don't cache it as it must be in sync with ->flag_types.
    $self->{flags} = [map { @{$_->{flags}} } @{$self->flag_types}];
    return $self->{flags};
}

sub flag_types
{
    my $self = shift;
    return $self->{flag_types} if exists $self->{flag_types};

    my $vars = {
        target_type  => 'attachment',
        product_id   => $self->bug->product_id,
        component_id => $self->bug->component_id,
        attach_id    => $self->id,
        bug_obj      => $self->bug,
    };

    $self->{flag_types} = Bugzilla::Flag->_flag_types($vars);
    return $self->{flag_types};
}

###############################
####      Validators     ######
###############################

sub set_content_type { $_[0]->set('mimetype', $_[1]); }
sub set_description  { $_[0]->set('description', $_[1]); }
sub set_filename     { $_[0]->set('filename', $_[1]); }
sub set_is_patch     { $_[0]->set('ispatch', $_[1]); }
sub set_is_private   { $_[0]->set('isprivate', $_[1]); }

sub set_is_obsolete 
{
    my ($self, $obsolete) = @_;

    my $old = $self->isobsolete;
    $self->set('isobsolete', $obsolete);
    my $new = $self->isobsolete;

    # If the attachment is being marked as obsolete, cancel pending requests.
    if ($new && $old != $new)
    {
        my @requests = grep { $_->status eq '?' } @{$self->flags};
        return unless scalar @requests;

        my %flag_ids = map { $_->id => 1 } @requests;
        foreach my $flagtype (@{$self->flag_types})
        {
            @{$flagtype->{flags}} = grep { !$flag_ids{$_->id} } @{$flagtype->{flags}};
        }
    }
}

sub set_flags
{
    my ($self, $flags, $new_flags, $comment) = @_;
    Bugzilla::Flag->set_flag($self, $_) foreach (@$flags, @$new_flags);
    $self->{flag_notify_comment} = $comment;
}

sub _check_bug
{
    my ($invocant, $bug) = @_;
    my $user = Bugzilla->user;

    $bug = ref $invocant ? $invocant->bug : $bug;
    $user->can_edit_bug($bug->id) || ThrowUserError("illegal_attachment_edit_bug", { bug_id => $bug->id });

    return $bug;
}

sub _legal_content_type
{
    my ($content_type) = @_;
    my $legal_types = join('|', LEGAL_CONTENT_TYPES);
    return $content_type =~ /^($legal_types)\/.+$/;
}

sub _check_content_type
{
    my ($invocant, $content_type) = @_;

    $content_type = 'text/plain' if ref $invocant && $invocant->ispatch;
    $content_type = trim($content_type);
    if (!$content_type || !_legal_content_type($content_type))
    {
        ThrowUserError("invalid_content_type", { contenttype => $content_type });
    }
    trick_taint($content_type);

    return $content_type;
}

sub _check_data
{
    my ($invocant, $params) = @_;

    my $data;
    if ($params->{base64_content})
    {
        $data = decode_base64($params->{base64_content});
    }
    else
    {
        if ($params->{store_in_file} || !ref $params->{data})
        {
            # If it's a filehandle, just store it, not the content of the file
            # itself as the file may be quite large. If it's not a filehandle,
            # it already contains the content of the file.
            $data = $params->{data};
        }
        else
        {
            # The file will be stored in the DB. We need the content of the file.
            local $/;
            my $fh = $params->{data};
            $data = <$fh>;
            close $fh;
        }
    }
    Bugzilla::Hook::process('attachment_process_data', { data => \$data, attributes => $params });

    # Do not validate the size if we have a filehandle. It will be checked later.
    return $data if ref $data;

    $data || ThrowUserError('zero_length_file');
    # Make sure the attachment does not exceed the maximum permitted size.
    my $len = length($data);
    my $max_size = $params->{store_in_file} || Bugzilla->params->{force_attach_bigfile}
        ? Bugzilla->params->{maxlocalattachment} * 1048576
        : Bugzilla->params->{maxattachmentsize} * 1024;
    if ($len > $max_size)
    {
        my $vars = { filesize => sprintf("%.0f", $len/1024) };
        if ($params->{ispatch})
        {
            ThrowUserError('patch_too_large', $vars);
        }
        elsif ($params->{store_in_file})
        {
            ThrowUserError('local_file_too_large');
        }
        else
        {
            ThrowUserError('file_too_large', $vars);
        }
    }
    return $data;
}

sub _check_description
{
    my ($invocant, $description) = @_;

    $description = trim($description);
    $description || ThrowUserError('missing_attachment_description');
    return $description;
}

sub _check_filename
{
    my ($invocant, $filename, undef, $params) = @_;

    if ($params && $params->{base64_content})
    {
        $filename = $params->{description};
    }

    $filename = trim($filename);
    $filename || ThrowUserError('file_not_specified');

    # Remove path info (if any) from the file name.  The browser should do this
    # for us, but some are buggy.  This may not work on Mac file names and could
    # mess up file names with slashes in them, but them's the breaks.  We only
    # use this as a hint to users downloading attachments anyway, so it's not
    # a big deal if it munges incorrectly occasionally.
    $filename =~ s/^.*[\/\\]//;

    # Truncate the filename to 100 characters, counting from the end of the
    # string to make sure we keep the filename extension.
    $filename = substr($filename, -100, 100);
    trick_taint($filename);

    return $filename;
}

sub _check_is_private
{
    my ($invocant, $is_private) = @_;

    $is_private = $is_private ? 1 : 0;
    if ((ref $invocant ? ($invocant->isprivate != $is_private) : $is_private) && !Bugzilla->user->is_insider)
    {
        ThrowUserError('user_not_insider');
    }
    return $is_private;
}

sub _check_store_in_file
{
    my ($invocant, $store_in_file) = @_;
    if (($store_in_file || Bugzilla->params->{force_attach_bigfile}) &&
        !Bugzilla->params->{maxlocalattachment})
    {
        ThrowCodeError('attachment_local_storage_disabled');
    }
    return $store_in_file ? 1 : 0;
}

=pod

=head2 Class Methods

=over

=item B<get_attachments_by_bug($bug_id)>

Description: retrieves and returns the attachments the currently logged in
             user can view for the given bug.

Params:     B<$bug_id> - integer - the ID of the bug for which
            to retrieve and return attachments.

Returns:    a reference to an array of attachment objects.

=cut

sub get_attachments_by_bug
{
    my ($class, $bug_id, $vars) = @_;
    my $user = Bugzilla->user;
    my $dbh = Bugzilla->dbh;

    # By default, private attachments are not accessible, unless the user
    # is in the insider group or submitted the attachment.
    my $and_restriction = '';
    my @values = ($bug_id);

    unless ($user->is_insider)
    {
        $and_restriction = 'AND (isprivate = 0 OR submitter_id = ?)';
        push(@values, $user->id);
    }

    my $attach_ids = $dbh->selectcol_arrayref(
        "SELECT attach_id FROM attachments WHERE bug_id = ? $and_restriction",
        undef, @values
    );

    my $attachments = Bugzilla::Attachment->new_from_list($attach_ids);

    # To avoid $attachment->flags to run SQL queries itself for each
    # attachment listed here, we collect all the data at once and
    # populate $attachment->{flags} ourselves.
    if ($vars->{preload})
    {
        $_->{flags} = [] foreach @$attachments;
        my %att = map { $_->id => $_ } @$attachments;

        my $flags = Bugzilla::Flag->match({ bug_id => $bug_id, target_type => 'attachment' });

        # Exclude flags for private attachments you cannot see.
        @$flags = grep {exists $att{$_->attach_id}} @$flags;

        push(@{$att{$_->attach_id}->{flags}}, $_) foreach @$flags;
        $attachments = [sort {$a->id <=> $b->id} values %att];
    }
    return $attachments;
}

=pod

=item B<validate_can_edit($attachment, $product_id)>

Description: validates if the user is allowed to view and edit the attachment.
             Only the submitter or someone with editbugs privs can edit it.
             Only the submitter and users in the insider group can view
             private attachments.

Params:      $attachment - the attachment object being edited.
             $product_id - the product ID the attachment belongs to.

Returns:     1 on success, 0 otherwise.

=cut

sub validate_can_edit {
    my ($attachment, $product_id) = @_;
    my $user = Bugzilla->user;

    # The submitter can edit their attachments.
    return ($attachment->attacher->id == $user->id ||
        ((!$attachment->isprivate || $user->is_insider) &&
        $user->in_group('editbugs', $product_id))) ? 1 : 0;
}

=item B<validate_obsolete($bug)>

Description: validates if attachments the user wants to mark as obsolete
             really belong to the given bug and are not already obsolete.
             Moreover, a user cannot mark an attachment as obsolete if
             he cannot view it (due to restrictions on it).

Params:      $bug - The bug object obsolete attachments should belong to.

Returns:     1 on success. Else an error is thrown.

=cut

sub validate_obsolete
{
    my ($class, $bug, $list) = @_;

    # Make sure the attachment id is valid and the user has permissions to view
    # the bug to which it is attached. Make sure also that the user can view
    # the attachment itself.
    my @obsolete_attachments;
    foreach my $attachid (@$list)
    {
        my $vars = {};
        $vars->{attach_id} = $attachid;

        detaint_natural($attachid)
            || ThrowCodeError('invalid_attach_id_to_obsolete', $vars);

        # Make sure the attachment exists in the database.
        my $attachment = new Bugzilla::Attachment($attachid)
            || ThrowUserError('invalid_attach_id', $vars);

        # Check that the user can view and edit this attachment.
        $attachment->validate_can_edit($bug->product_id)
            || ThrowUserError('illegal_attachment_edit', { attach_id => $attachment->id });

        $vars->{description} = $attachment->description;

        if ($attachment->bug_id != $bug->bug_id)
        {
            $vars->{my_bug_id} = $bug->bug_id;
            $vars->{attach_bug_id} = $attachment->bug_id;
            ThrowCodeError('mismatched_bug_ids_on_obsolete', $vars);
        }

        push(@obsolete_attachments, $attachment);
    }
    return @obsolete_attachments;
}

###############################
####     Constructors     #####
###############################

=pod

=item B<create>

Description: inserts an attachment into the given bug.

Params:     takes a hashref with the following keys:
            B<bug> - Bugzilla::Bug object - the bug for which to insert
            the attachment.
            B<data> - Either a filehandle pointing to the content of the
            attachment, or the content of the attachment itself.
            B<description> - string - describe what the attachment is about.
            B<filename> - string - the name of the attachment (used by the
            browser when downloading it). If the attachment is a URL, this
            parameter has no effect.
            B<mimetype> - string - a valid MIME type.
            B<creation_ts> - string (optional) - timestamp of the insert
            as returned by SELECT LOCALTIMESTAMP(0).
            B<ispatch> - boolean (optional, default false) - true if the
            attachment is a patch.
            B<isprivate> - boolean (optional, default false) - true if
            the attachment is private.
            B<store_in_file> - boolean (optional, default false) - true
            if the attachment must be stored in data/attachments/ instead
            of in the DB.

Returns:    The new attachment object.

=cut

sub create
{
    my $class = shift;
    my $dbh = Bugzilla->dbh;

    $class->check_required_create_fields(@_);
    my $params = $class->run_create_validators(@_);

    # Extract everything which is not a valid column name.
    my $bug = delete $params->{bug};
    $params->{bug_id} = $bug->id;
    my $fh = delete $params->{data};
    my $store_in_file = delete $params->{store_in_file};

    if (Bugzilla->params->{force_attach_bigfile})
    {
        # Force uploading into files instead of DB when force_attach_bigfile = On
        $store_in_file = 1;
    }

    my $attachment = $class->insert_create_data($params);
    my $attachid = $attachment->id;

    # If the file is to be stored locally, stream the file from the web server
    # to the local file without reading it into a local variable.
    if ($store_in_file)
    {
        my $attachdir = bz_locations()->{attachdir};
        my $hash = ($attachid % 100) + 100;
        $hash =~ s/.*(\d\d)$/group.$1/;
        mkdir "$attachdir/$hash", 0770;
        chmod 0770, "$attachdir/$hash";
        open(AH, '>', "$attachdir/$hash/attachment.$attachid") or die "Could not write into $attachdir/$hash/attachment.$attachid: $!";
        binmode AH;
        if (ref $fh)
        {
            my $limit = Bugzilla->params->{maxlocalattachment} * 1048576;
            my $sizecount = 0;
            while (<$fh>)
            {
                print AH $_;
                $sizecount += length($_);
                if ($sizecount > $limit)
                {
                    close AH;
                    close $fh;
                    unlink "$attachdir/$hash/attachment.$attachid";
                    ThrowUserError("local_file_too_large");
                }
            }
            close $fh;
        }
        else
        {
            print AH $fh;
        }
        close AH;
    }
    else
    {
        # We only use $fh here in this INSERT with a placeholder, so it's safe.
        my $sth = $dbh->prepare("INSERT INTO attach_data (id, thedata) VALUES ($attachid, ?)");
        trick_taint($fh);
        $sth->bind_param(1, $fh, $dbh->BLOB_TYPE);
        $sth->execute();
    }

    Bugzilla::Hook::process('attachment_post_create', { attachment => $attachment });

    # Return the new attachment object.
    return $attachment;
}

sub run_create_validators
{
    my ($class, $params) = @_;

    # Let's validate the attachment content first as it may
    # alter some other attachment attributes.
    $params->{data} = $class->_check_data($params);
    $params = $class->SUPER::run_create_validators($params);

    $params->{filename} = $class->_check_filename($params->{filename}, 'filename', $params);
    $params->{creation_ts} ||= Bugzilla->dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');
    $params->{modification_time} = $params->{creation_ts};
    $params->{submitter_id} = Bugzilla->user->id || ThrowCodeError('invalid_user');

    delete $params->{base64_content};
    return $params;
}

sub update
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;
    my $timestamp = shift || $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');

    my ($changes, $old_self) = $self->SUPER::update(@_);

    my ($removed, $added) = Bugzilla::Flag->update_flags($self, $old_self, $timestamp, $self->{flag_notify_comment});
    if ($removed || $added)
    {
        $changes->{'flagtypes.name'} = [$removed, $added];
    }
    delete $self->{flag_notify_comment};

    # Log activity
    my $c;
    foreach my $field (keys %$changes)
    {
        $c = $changes->{$field};
        $field = "attachments.$field" unless $field eq 'flagtypes.name';
        Bugzilla::Bug::LogActivityEntry(
            $self->bug_id, $field, $c->[0], $c->[1],
            $user->id, $timestamp, $self->id
        );
    }

    if (scalar keys %$changes)
    {
        $dbh->do(
            'UPDATE attachments SET modification_time = ? WHERE attach_id = ?',
            undef, $timestamp, $self->id
        );
        $dbh->do(
            'UPDATE bugs SET delta_ts = ? WHERE bug_id = ?',
            undef, $timestamp, $self->bug_id
        );
    }

    return $changes;
}

=pod

=item B<remove_from_db()>

Description: removes an attachment from the DB.

Params:     none

Returns:    nothing

=back

=cut

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    $dbh->do('DELETE FROM flags WHERE attach_id = ?', undef, $self->id);
    $dbh->do('DELETE FROM attach_data WHERE id = ?', undef, $self->id);
    $dbh->do(
        'UPDATE attachments SET mimetype = ?, ispatch = ?, isobsolete = ? WHERE attach_id = ?',
        undef, ('text/plain', 0, 1, $self->id)
    );
    $dbh->bz_commit_transaction();
}

###############################
####       Helpers        #####
###############################

my $lwp_read_mime_types;
sub guess_content_type
{
    my ($filename) = @_;
    if (Bugzilla->params->{mime_types_file})
    {
        if (!$lwp_read_mime_types)
        {
            LWP::MediaTypes::read_media_types(Bugzilla->params->{mime_types_file});
            $lwp_read_mime_types = 1;
        }
        return LWP::MediaTypes::guess_media_type("$filename");
    }
    return '';
}

# Extract the content type from the attachment form.
# FIXME this is not the logic of Attachment, this is the form logic,
# so it must be inside form implementation, not Attachment implementation
sub get_content_type
{
    my $cgi = Bugzilla->cgi;
    my $ARGS = Bugzilla->input_params;

    my $ispatch = $ARGS->{ispatch};
    if ($ispatch || $ARGS->{text_attachment} !~ /^\s*$/so)
    {
        return ('text/plain', $ispatch);
    }

    my $content_type;
    if (!defined $ARGS->{contenttypemethod})
    {
        ThrowUserError('missing_content_type_method');
    }
    elsif ($ARGS->{contenttypemethod} eq 'autodetect')
    {
        defined $cgi->upload('data') || ThrowUserError('file_not_specified');
        # The user asked us to auto-detect the content type, so use the type
        # specified in the HTTP request headers.
        $content_type = $cgi->uploadInfo($cgi->param('data'))->{'Content-Type'};
        if (!_legal_content_type($content_type))
        {
            $content_type = guess_content_type($cgi->param('data'));
        }
        if (!_legal_content_type($content_type))
        {
            $content_type = 'application/octet-stream';
        }
        $content_type || ThrowUserError("missing_content_type");

        # Set the ispatch flag to 1 if the content type
        # is text/x-diff or text/x-patch
        if ($content_type =~ m{text/x-(?:diff|patch)})
        {
            $ispatch = 1;
            $content_type = 'text/plain';
        }
        # Internet Explorer sends image/x-png for PNG images,
        # so convert that to image/png to match other browsers.
        elsif ($content_type eq 'image/x-png')
        {
            $content_type = 'image/png';
        }
    }
    elsif ($ARGS->{contenttypemethod} eq 'list')
    {
        # The user selected a content type from the list, so use their selection.
        $content_type = $ARGS->{contenttypeselection};
    }
    elsif ($ARGS->{contenttypemethod} eq 'manual')
    {
        # The user entered a content type manually, so use their entry.
        $content_type = $ARGS->{contenttypeentry};
    }
    else
    {
        ThrowCodeError('illegal_content_type_method', {
            contenttypemethod => $ARGS->{contenttypemethod},
        });
    }
    return ($content_type, $ispatch);
}

# CustIS Bug 68919 - Create multiple attachments to bug
sub add_multiple
{
    my ($bug) = @_;
    my $multiple = {};
    my $params = Bugzilla->input_params;
    my $cgi = Bugzilla->cgi;
    my ($multi, $key);
    for (keys %$params)
    {
        if (/^attachmulti_(.*)_([^_]*)$/so)
        {
            ($key, $multi) = ($1, $2);
            if ($key eq 'data')
            {
                my $up = $cgi->upload($_);
                if ($up)
                {
                    my $fn = $params->{$_};
                    $fn = "$fn";
                    if (Bugzilla->params->{utf8})
                    {
                        # CGI::upload() will probably return non-UTF8 string, so set UTF8 flag on
                        # utf8::decode() and Encode::_utf8_on() do not work on tainted scalars...
                        $fn = trick_taint_copy($fn);
                        Encode::_utf8_on($fn);
                    }
                    $multiple->{$multi}->{$key} = {
                        filename    => $fn,
                        upload      => $up,
                        uploadInfo  => $cgi->uploadInfo($params->{$_}),
                    };
                }
            }
            else
            {
                $multiple->{$multi}->{$key} = $params->{$_};
            }
        }
    }
    # Create attachments in the same order as on the form
    for (sort { $a <=> $b } keys %$multiple)
    {
        if ($multiple->{$_}->{data})
        {
            add_attachment($bug, $multiple->{$_});
        }
    }
}

# Insert a new attachment into the database.
sub add_attachment
{
    my ($bug, $params) = @_;

    my $dbh = Bugzilla->dbh;
    my $user = Bugzilla->user;

    $dbh->bz_start_transaction;

    my $content_type = $params->{ctype};
    my $ctype_auto = 0;
    if (!$content_type)
    {
        $ctype_auto = 1;
        $content_type = $params->{data}->{uploadInfo}->{'Content-Type'};
        if (!_legal_content_type($content_type))
        {
            $content_type = guess_content_type($params->{data}->{filename});
        }
        if (!_legal_content_type($content_type))
        {
            $content_type = 'application/octet-stream';
        }
        # Set the ispatch flag to 1 if the content type
        # is text/x-diff or text/x-patch
        if ($content_type =~ m{text/x-(?:diff|patch)})
        {
            $params->{ispatch} = 1;
            $content_type = 'text/x-diff';
        }
        # Internet Explorer sends image/x-png for PNG images,
        # so convert that to image/png to match other browsers.
        if ($content_type eq 'image/x-png')
        {
            $content_type = 'image/png';
        }
    }

    my $attachment = Bugzilla::Attachment->create({
        bug           => $bug,
        data          => $params->{data}->{upload},
        description   => $params->{description},
        filename      => $params->{data}->{filename},
        ispatch       => $params->{ispatch},
        isprivate     => $params->{isprivate},
        mimetype      => $content_type,
    });

    # Insert a comment about the new attachment into the database.
    # FIXME move comment adding into Bugzilla::Attachment
    my $comment = defined $params->{comment} ? $params->{comment} : '';
    $bug->add_comment($comment, {
        isprivate => $attachment->isprivate,
        type => CMT_ATTACHMENT_CREATED,
        work_time => $params->{work_time},
        extra_data => $attachment->id
    });
    $bug->update($attachment->{creation_ts_orig});

    $dbh->bz_commit_transaction;

    # Operation result to save into session (CustIS Bug 64562)
    Bugzilla->add_result_message({
        message => 'added_attachment',
        id => $attachment->id,
        bug_id => $attachment->bug_id,
        description => $attachment->description,
        contenttype => $attachment->contenttype,
        ctype_auto => $ctype_auto,
    });
}

1;
__END__
