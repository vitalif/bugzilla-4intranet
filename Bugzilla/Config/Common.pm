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
#                 Marc Schumann <wurblzap@gmail.com>
#

package Bugzilla::Config::Common;

use strict;

use Email::Address;

use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Status;

use base qw(Exporter);
@Bugzilla::Config::Common::EXPORT = qw(
    check_multi check_numeric check_regexp check_url
    check_urlbase check_email
);

# Checking functions for the various values

sub check_multi
{
    my ($value, $param) = (@_);
    if ($param->{type} eq "s")
    {
        unless (grep { $_ eq $value } @{$param->{choices}})
        {
            return "Invalid choice '$value' for single-select list param '$param->{name}'";
        }
        return "";
    }
    elsif ($param->{type} eq 'm' || $param->{type} eq 'o')
    {
        foreach my $chkParam (split ',', $value)
        {
            unless (grep { $_ eq $chkParam } @{$param->{choices}})
            {
                return "Invalid choice '$chkParam' for multi-select list param '$param->{name}'";
            }
        }
        return "";
    }
    else
    {
        die "BUG: Invalid param type '$param->{type}' for check_multi()";
    }
}

sub check_numeric
{
    my ($value) = (@_);
    if ($value !~ /^[0-9]+$/)
    {
        return "must be a numeric value";
    }
    return "";
}

sub check_regexp
{
    my ($value) = (@_);
    eval { qr/$value/ };
    return $@;
}

sub check_email
{
    my ($value) = @_;
    if ($value !~ $Email::Address::mailbox)
    {
        return "must be a valid email address.";
    }
    return "";
}

sub check_urlbase
{
    my ($url) = (@_);
    if ($url && $url !~ m:^http.*/$:)
    {
        return 'must be a legal URL, that starts with http and ends with a slash.';
    }
    return "";
}

sub check_url
{
    my ($url) = (@_);
    return '' if $url eq ''; # Allow empty URLs
    if ($url !~ m:/$:)
    {
        return 'must be a legal URL, absolute or relative, ending with a slash.';
    }
    return '';
}

# OK, here are the parameter definitions themselves.
#
# Each definition is a hash with keys:
#
# name    - name of the param
# desc    - description of the param (for editparams.cgi)
# type    - see below
# choices - (optional) see below
# default - default value for the param
# checker - (optional) checking function for validating parameter entry
#           It is called with the value of the param as the first arg and a
#           reference to the param's hash as the second argument
#
# The type value can be one of the following:
#
# t -- A short text entry field (suitable for a single line)
# p -- A short text entry field (as with type = 't'), but the string is
#      replaced by asterisks (appropriate for passwords)
# l -- A long text field (suitable for many lines)
# b -- A boolean value (either 1 or 0)
# m -- A list of values, with many selectable (shows up as a select box)
#      To specify the list of values, make the 'choices' key be an array
#      reference of the valid choices. The 'default' key should be a string
#      with a list of selected values (as a comma-separated list), i.e.:
#       {
#         name => 'multiselect',
#         desc => 'A list of options, choose many',
#         type => 'm',
#         choices => [ 'a', 'b', 'c', 'd' ],
#         default => [ 'a', 'd' ],
#         checker => \&check_multi
#       }
#
#      Here, 'a' and 'd' are the default options, and the user may pick any
#      combination of a, b, c, and d as valid options.
#
#      &check_multi should always be used as the param verification function
#      for list (single and multiple) parameter types.
#
# o -- A list of values, orderable, and with many selectable (shows up as a
#      JavaScript-enhanced select box if JavaScript is enabled, and a text
#      entry field if not)
#      Set up in the same way as type m.
#
# s -- A list of values, with one selectable (shows up as a select box)
#      To specify the list of values, make the 'choices' key be an array
#      reference of the valid choices. The 'default' key should be one of
#      those values, i.e.:
#       {
#         name => 'singleselect',
#         desc => 'A list of options, choose one',
#         type => 's',
#         choices => [ 'a', 'b', 'c' ],
#         default => 'b',
#         checker => \&check_multi
#       }
#
#      Here, 'b' is the default option, and 'a' and 'c' are other possible
#      options, but only one at a time!
#
#      &check_multi should always be used as the param verification function
#      for list (single and multiple) parameter types.

sub get_param_list
{
    return;
}

1;

__END__

=head1 NAME

Bugzilla::Config::Common - Parameter checking functions

=head1 DESCRIPTION

All parameter checking functions are called with two parameters:

=head2 Functions

=over

=item C<check_multi>

Checks that a multi-valued parameter (ie types C<s>, C<o> or C<m>) satisfies
its contraints.

=item C<check_numeric>

Checks that the value is a valid number

=item C<check_regexp>

Checks that the value is a valid regexp

=back
