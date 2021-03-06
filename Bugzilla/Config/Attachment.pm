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
#                 Dawn Endico <endico@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Joe Robins <jmrobins@tgix.com>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 J. Paul Reed <preed@sigkill.com>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Joseph Heenan <joseph@heenan.me.uk>
#                 Erik Stambaugh <erik@dasbistro.com>
#                 Frédéric Buclin <LpSolit@gmail.com>
#

package Bugzilla::Config::Attachment;

use strict;

use Bugzilla;
use Bugzilla::Config::Common;

our $sortkey = 400;

sub check_maxattachmentsize
{
    my $check = check_numeric(@_);
    return $check if $check;
    my $size = shift;
    my $dbh = Bugzilla->dbh;
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        my (undef, $max_packet) = $dbh->selectrow_array("SHOW VARIABLES LIKE 'max\\_allowed\\_packet'");
        my $byte_size = $size * 1024;
        if ($max_packet < $byte_size)
        {
            return "You asked for a maxattachmentsize of $byte_size bytes," .
                " but the max_allowed_packet setting in MySQL currently" .
                " only allows packets up to $max_packet bytes";
        }
    }
    return "";
}

sub get_param_list
{
    my $class = shift;
    my @param_list = (
    {
        name => 'allow_attachment_display',
        type => 'b',
        default => 0
    },

    {
        name => 'attachment_base',
        type => 't',
        default => '',
        checker => \&check_urlbase
    },

    {
        name => 'allow_attachment_deletion',
        type => 'b',
        default => 0
    },

    {
        name => 'use_supa_applet',
        type => 'b',
        default => 0,
    },

    {
        name => 'supa_jar_url',
        type => 't',
        default => '',
    },

    # The maximum size (in bytes) for attachments STORED IN THE DATABASE (!!!)
    # By default Bugzilla4Intranet DOES NOT store ANY attachments in the DB,
    # because force_attach_bigfile=1 by default.
    #
    # The default limit is 1000KB, which is 24KB less than mysql's default
    # maximum packet size (which determines how much data can be sent in a
    # single mysql packet and thus how much data can be inserted into the
    # database) to provide breathing space for the data in other fields of
    # the attachment record as well as any mysql packet overhead (I don't
    # know of any, but I suspect there may be some.)
    {
        name => 'maxattachmentsize',
        type => 't',
        default => '1000',
        checker => \&check_maxattachmentsize
    },

    {
        name    => 'force_attach_bigfile',
        type    => 'b',
        default => 1,
    },

    {
        name    => 'maxlocalattachment',
        type    => 't',
        default => '5000',
        checker => \&check_numeric
    },

    {
        name    => 'inline_attachment_mime',
        type    => 't',
        default => '^text/|^image/',
    },

    {
        name    => 'mime_types_file',
        type    => 't',
        default => '',
    },
    );
    return @param_list;
}

1;
