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
# The Original Code is the Bugzilla Inbound Email System.
#
# The Initial Developer of the Original Code is Akamai Technologies, Inc.
# Portions created by Akamai are Copyright (C) 2006 Akamai Technologies,
# Inc. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;
use warnings;

# MTAs may call this script from any directory, but it should always
# run from this one so that it can find its modules.
use Cwd qw(abs_path);
use File::Basename qw(dirname);
BEGIN
{
    # Untaint the abs_path.
    my ($a) = abs_path($0) =~ /^(.*)$/;
    chdir dirname($a);
}
use lib qw(. lib);
use Bugzilla::InMail;

my $switch = {};

GetOptions($switch, 'help|h', 'verbose|v+');
$switch->{verbose} ||= 0;

# Print the help message if that switch was selected.
pod2usage({-verbose => 0, -exitval => 1}) if $switch->{help};

# Get a next-in-pipe command from commandline
my ($pipe) = join(' ', @ARGV) =~ /^(.*)$/iso;
@ARGV = ();

Bugzilla->usage_mode(USAGE_MODE_EMAIL);
Bugzilla->error_mode(ERROR_MODE_CONSOLE);

my @mail_lines = <STDIN>;
my ($mail_text) = join("", @mail_lines) =~ /^(.*)$/iso;

if ($pipe && open PIPE, "| $pipe")
{
    # Also pipe mail to passed command
    print PIPE $mail_text;
    close PIPE;
}

Bugzilla::InMail::process_inmail($mail_text);
exit;

__END__

=head1 NAME

email_in.pl - The Bugzilla Inbound Email Interface

=head1 SYNOPSIS

 ./email_in.pl [-vvv] [--] [pipe_to_command] < email.txt

 Reads an email on STDIN (the standard input)

  Options:
    --verbose (-v) - Make the script print more to STDERR.
                     Specify multiple times to print even more.

 If <pipe_to_command> is specified, then email is piped to that program
 after reading and I<before> any processing. For example, you can use the
 following syntax:

 ./email_in.pl -- maildrop -d bugzilla@domain.com

 to both save emails in some maildir/mailbox and process it via Bugzilla.

=head1 DESCRIPTION

This script processes inbound email and creates a bug, or appends data
to an existing bug.

=head2 Creating a New Bug

The script expects to read an email with the following format:

 From: account@domain.com
 Subject: Bug Summary
 Cc: user1@domain.com, user2@domain.com

 @product ProductName
 @component ComponentName
 @version 1.0

 This is a bug description. It will be entered into the bug exactly as
 written here.

 It can be multiple paragraphs.

 --
 This is a signature line, and will be removed automatically, It will not
 be included in the bug description.

For the list of valid field names for the C<@> fields, including
a list of which ones are required, see L<Bugzilla::WebService::Bug/create>.
(Note, however, that you cannot specify C<@description> as a field--
you just add a comment by adding text after the C<@> fields.)

The values for the fields can be split across multiple lines, but
note that a newline will be parsed as a single space, for the value.
So, for example:

 @summary This is a very long
 description

Will be parsed as "This is a very long description".

If you specify C<@summary>, it will override the summary you specify
in the Subject header.

C<account@domain.com> (the value of the C<From> header) must be a valid
Bugzilla account.

Note that signatures must start with '-- ', the standard signature
border.

=head2 Modifying an Existing Bug

Bugzilla determines what bug you want to modify in one of two ways:

=over

=item *

Your subject starts with [Bug 123456] -- then it modifies bug 123456.

=item *

You include C<@id 123456> in the first lines of the email.

=back

If you do both, C<@id> takes precedence.

You send your email in the same format as for creating a bug, except
that you only specify the fields you want to change. If the very
first non-blank line of the email doesn't begin with C<@>, then it
will be assumed that you are only adding a comment to the bug.

Note that when updating a bug, the C<Subject> header is ignored,
except for getting the bug ID. If you want to change the bug's summary,
you have to specify C<@summary> as one of the fields to change.

Please remember not to include any extra text in your emails, as that
text will also be added as a comment. This includes any text that your
email client automatically quoted and included, if this is a reply to
another email.

=head3 Adding/Removing CCs

To add CCs, you can either add them to C<Cc:> mail header or specify
them in a comma-separated list in C<@cc>. For backward compatibility,
C<@newcc> can also be used. If both are present, C<@cc> takes precedence,
and if C<Cc:> header is also present, both C<@cc> and C<@newcc> take
precedence over it.

To remove CCs, specify them as a comma-separated list in C<@removecc>.

=head2 Errors

If your request cannot be completed for any reason, Bugzilla will
send an email back to you. If your request succeeds, Bugzilla will
not send you anything.

If any part of your request fails, all of it will fail. No partial
changes will happen.

=head1 CAUTION

The script does not do any validation that the user is who they say
they are. That is, it accepts I<any> 'From' address, as long as it's
a valid Bugzilla account. So make sure that your MTA validates that
the message is actually coming from who it says it's coming from,
and only allow access to the inbound email system from people you trust.

=head1 LIMITATIONS

The email interface only accepts emails that are correctly formatted
per RFC2822. If you send it an incorrectly formatted message, it
may behave in an unpredictable fashion.

You cannot send an HTML mail along with attachments. If you do, Bugzilla
will reject your email, saying that it doesn't contain any text. This
is a bug in L<Email::MIME::Attachment::Stripper> that we can't work
around.

You cannot modify Flags through the email interface.
