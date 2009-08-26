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
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Christopher Aillon <christopher@aillon.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Marc Schumann <wurblzap@gmail.com>

package Bugzilla::Util;

use strict;

use base qw(Exporter);
@Bugzilla::Util::EXPORT = qw(trick_taint detaint_natural
                             detaint_signed
                             html_quote url_quote xml_quote
                             css_class_quote html_light_quote url_decode
                             i_am_cgi get_netaddr correct_urlbase
                             lsearch ssl_require_redirect use_attachbase
                             diff_arrays
                             trim wrap_hard wrap_comment find_wrap_point
                             format_time format_time_decimal validate_date
                             validate_time
                             file_mod_time is_7bit_clean
                             bz_crypt generate_random_password
                             validate_email_syntax clean_text
                             get_term get_text disable_utf8 stem_text);

use Bugzilla::Constants;

use Date::Parse;
use Date::Format;
use DateTime;
use DateTime::TimeZone;
use Digest;
use Email::Address;
use Scalar::Util qw(tainted);
use Text::Wrap;
use Lingua::Stem::RuUTF8;

sub trick_taint {
    require Carp;
    Carp::confess("Undef to trick_taint") unless defined $_[0];
    my $match = $_[0] =~ /^(.*)$/s;
    $_[0] = $match ? $1 : undef;
    return (defined($_[0]));
}

sub detaint_natural {
    my $match = $_[0] =~ /^(\d+)$/;
    $_[0] = $match ? $1 : undef;
    return (defined($_[0]));
}

sub detaint_signed {
    my $match = $_[0] =~ /^([-+]?\d+)$/;
    $_[0] = $match ? $1 : undef;
    # Remove any leading plus sign.
    if (defined($_[0]) && $_[0] =~ /^\+(\d+)$/) {
        $_[0] = $1;
    }
    return (defined($_[0]));
}

sub html_quote {
    my ($var) = (@_);
    $var =~ s/\&/\&amp;/g;
    $var =~ s/</\&lt;/g;
    $var =~ s/>/\&gt;/g;
    $var =~ s/\"/\&quot;/g;
    return $var;
}

sub html_light_quote {
    my ($text) = @_;

    # List of allowed HTML elements having no attributes.
    my @allow = qw(b strong em i u p br abbr acronym ins del cite code var
                   dfn samp kbd big small sub sup tt dd dt dl ul li ol
                   fieldset legend);

    # Are HTML::Scrubber and HTML::Parser installed?
    eval { require HTML::Scrubber;
           require HTML::Parser;
    };

    if ($@) { # Package(s) not installed.
        my $safe = join('|', @allow);
        my $chr = chr(1);

        # First, escape safe elements.
        $text =~ s#<($safe)>#$chr$1$chr#go;
        $text =~ s#</($safe)>#$chr/$1$chr#go;
        # Now filter < and >.
        $text =~ s#<#&lt;#g;
        $text =~ s#>#&gt;#g;
        # Restore safe elements.
        $text =~ s#$chr/($safe)$chr#</$1>#go;
        $text =~ s#$chr($safe)$chr#<$1>#go;
        return $text;
    }
    else { # Packages installed.
        # We can be less restrictive. We can accept elements with attributes.
        push(@allow, qw(a blockquote q span));

        # Allowed protocols.
        my $safe_protocols = join('|', SAFE_PROTOCOLS);
        my $protocol_regexp = qr{(^(?:$safe_protocols):|^[^:]+$)}i;

        # Deny all elements and attributes unless explicitly authorized.
        my @default = (0 => {
                             id    => 1,
                             name  => 1,
                             class => 1,
                             '*'   => 0, # Reject all other attributes.
                            }
                       );

        # Specific rules for allowed elements. If no specific rule is set
        # for a given element, then the default is used.
        my @rules = (a => {
                           href  => $protocol_regexp,
                           title => 1,
                           id    => 1,
                           name  => 1,
                           class => 1,
                           '*'   => 0, # Reject all other attributes.
                          },
                     blockquote => {
                                    cite => $protocol_regexp,
                                    id    => 1,
                                    name  => 1,
                                    class => 1,
                                    '*'  => 0, # Reject all other attributes.
                                   },
                     'q' => {
                             cite => $protocol_regexp,
                             id    => 1,
                             name  => 1,
                             class => 1,
                             '*'  => 0, # Reject all other attributes.
                          },
                    );

        my $scrubber = HTML::Scrubber->new(default => \@default,
                                           allow   => \@allow,
                                           rules   => \@rules,
                                           comment => 0,
                                           process => 0);

        return $scrubber->scrub($text);
    }
}

sub email_filter {
    my ($toencode) = @_;
    if (!Bugzilla->user->id) {
        my @emails = Email::Address->parse($toencode);
        if (scalar @emails) {
            my @hosts = map { quotemeta($_->host) } @emails;
            my $hosts_re = join('|', @hosts);
            $toencode =~ s/\@(?:$hosts_re)//g;
            return $toencode;
        }
    }
    return $toencode;
}

# This originally came from CGI.pm, by Lincoln D. Stein
sub url_quote {
    my ($toencode) = (@_);
    utf8::encode($toencode) # The below regex works only on bytes
        if Bugzilla->params->{'utf8'} && utf8::is_utf8($toencode);
    $toencode =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

sub css_class_quote {
    my ($toencode) = (@_);
    $toencode =~ s/ /_/g;
    $toencode =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("&#x%x;",ord($1))/eg;
    return $toencode;
}

sub xml_quote {
    my ($var) = (@_);
    $var =~ s/\&/\&amp;/g;
    $var =~ s/</\&lt;/g;
    $var =~ s/>/\&gt;/g;
    $var =~ s/\"/\&quot;/g;
    $var =~ s/\'/\&apos;/g;
    
    # the following nukes characters disallowed by the XML 1.0
    # spec, Production 2.2. 1.0 declares that only the following 
    # are valid:
    # (#x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF])
    $var =~ s/([\x{0001}-\x{0008}]|
               [\x{000B}-\x{000C}]|
               [\x{000E}-\x{001F}]|
               [\x{D800}-\x{DFFF}]|
               [\x{FFFE}-\x{FFFF}])//gx;
    return $var;
}

# This function must not be relied upon to return a valid string to pass to
# the DB or the user in UTF-8 situations. The only thing you  can rely upon
# it for is that if you url_decode a string, it will url_encode back to the 
# exact same thing.
sub url_decode {
    my ($todecode) = (@_);
    $todecode =~ tr/+/ /;       # pluses become spaces
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}

sub i_am_cgi {
    # I use SERVER_SOFTWARE because it's required to be
    # defined for all requests in the CGI spec.
    return exists $ENV{'SERVER_SOFTWARE'} ? 1 : 0;
}

sub ssl_require_redirect {
    my $method = shift;

    # If currently not in a protected SSL 
    # connection, determine if a redirection is 
    # needed based on value in Bugzilla->params->{ssl}.
    # If we are already in a protected connection or
    # sslbase is not set then no action is required.
    if (uc($ENV{'HTTPS'}) ne 'ON' 
        && $ENV{'SERVER_PORT'} != 443 
        && Bugzilla->params->{'sslbase'} ne '')
    {
        # System is configured to never require SSL 
        # so no redirection is needed.
        return 0 
            if Bugzilla->params->{'ssl'} eq 'never';
            
        # System is configured to always require a SSL
        # connection so we need to redirect.
        return 1
            if Bugzilla->params->{'ssl'} eq 'always';

        # System is configured such that if we are inside
        # of an authenticated session, then we need to make
        # sure that all of the connections are over SSL. Non
        # authenticated sessions SSL is not mandatory.
        # For XMLRPC requests, if the method is User.login
        # then we always want the connection to be over SSL
        # if the system is configured for authenticated
        # sessions since the user's username and password
        # will be passed before the user is logged in.
        return 1 
            if Bugzilla->params->{'ssl'} eq 'authenticated sessions'
                && (Bugzilla->user->id 
                    || (defined $method && $method eq 'User.login'));
    }

    return 0;
}

sub correct_urlbase {
    my $ssl = Bugzilla->params->{'ssl'};
    return Bugzilla->params->{'urlbase'} if $ssl eq 'never';

    my $sslbase = Bugzilla->params->{'sslbase'};
    if ($sslbase) {
        return $sslbase if $ssl eq 'always';
        # Authenticated Sessions
        return $sslbase if Bugzilla->user->id;
    }

    # Set to "authenticated sessions" but nobody's logged in, or
    # sslbase isn't set.
    return Bugzilla->params->{'urlbase'};
}

sub use_attachbase {
    my $attachbase = Bugzilla->params->{'attachment_base'};
    return ($attachbase ne ''
            && $attachbase ne Bugzilla->params->{'urlbase'}
            && $attachbase ne Bugzilla->params->{'sslbase'}) ? 1 : 0;
}

sub lsearch {
    my ($list,$item) = (@_);
    my $count = 0;
    foreach my $i (@$list) {
        if ($i eq $item) {
            return $count;
        }
        $count++;
    }
    return -1;
}

sub diff_arrays {
    my ($old_ref, $new_ref) = @_;

    my @old = @$old_ref;
    my @new = @$new_ref;

    # For each pair of (old, new) entries:
    # If they're equal, set them to empty. When done, @old contains entries
    # that were removed; @new contains ones that got added.
    foreach my $oldv (@old) {
        foreach my $newv (@new) {
            next if ($newv eq '');
            if ($oldv eq $newv) {
                $newv = $oldv = '';
            }
        }
    }

    my @removed = grep { $_ ne '' } @old;
    my @added = grep { $_ ne '' } @new;
    return (\@removed, \@added);
}

sub trim {
    my ($str) = @_;
    if ($str) {
      $str =~ s/^\s+//g;
      $str =~ s/\s+$//g;
    }
    return $str;
}

sub wrap_comment
{
    my ($comment, $cols) = @_;
    my $wrappedcomment = "";

    $cols ||= COMMENT_COLS;
    $cols-=2;
    my $re = qr/^(.{0,$cols}(\s(?=\S)|\S(?=\s)))\s*/s;
    $cols+=2;

    foreach my $line (split /\r\n?|\n/, $comment)
    {
        # If the line starts with ">", don't wrap it. Otherwise, wrap.
        if ($line !~ /^>/so)
        {
            $line =~ s/\t/    /gso;
            while (length($line) > $cols && $line =~ s/$re//)
            {
                $wrappedcomment .= $1 . "\n";
            }
        }
        $wrappedcomment .= $line . "\n" if $line;
    }

    chomp $wrappedcomment;
    return $wrappedcomment;
}

sub find_wrap_point {
    my ($string, $maxpos) = @_;
    if (!$string) { return 0 }
    if (length($string) < $maxpos) { return length($string) }
    my $wrappoint = rindex($string, ",", $maxpos); # look for comma
    if ($wrappoint < 0) {  # can't find comma
        $wrappoint = rindex($string, " ", $maxpos); # look for space
        if ($wrappoint < 0) {  # can't find space
            $wrappoint = rindex($string, "-", $maxpos); # look for hyphen
            if ($wrappoint < 0) {  # can't find hyphen
                $wrappoint = $maxpos;  # just truncate it
            } else {
                $wrappoint++; # leave hyphen on the left side
            }
        }
    }
    return $wrappoint;
}

sub wrap_hard {
    my ($string, $columns) = @_;
    local $Text::Wrap::columns = $columns;
    local $Text::Wrap::unexpand = 0;
    local $Text::Wrap::huge = 'wrap';
    
    my $wrapped = wrap('', '', $string);
    chomp($wrapped);
    return $wrapped;
}

sub format_time {
    my ($date, $format, $timezone) = @_;

    # If $format is undefined, try to guess the correct date format.    
    if (!defined($format)) {
        if ($date =~ m/^(\d{4})[-\.](\d{2})[-\.](\d{2}) (\d{2}):(\d{2})(:(\d{2}))?$/) {
            my $sec = $7;
            if (defined $sec) {
                $format = "%Y-%m-%d %T %Z";
            } else {
                $format = "%Y-%m-%d %R %Z";
            }
        } else {
            # Default date format. See DateTime for other formats available.
            $format = "%Y-%m-%d %R %Z";
        }
    }

    # strptime($date) returns an empty array if $date has an invalid date format.
    my @time = strptime($date);

    unless (scalar @time) {
        # If an unknown timezone is passed (such as MSK, for Moskow), strptime() is
        # unable to parse the date. We try again, but we first remove the timezone.
        $date =~ s/\s+\S+$//;
        @time = strptime($date);
    }

    if (scalar @time) {
        # Fix a bug in strptime() where seconds can be undefined in some cases.
        $time[0] ||= 0;

        # strptime() counts years from 1900, and months from 0 (January).
        # We have to fix both values.
        my $dt = DateTime->new({year   => 1900 + $time[5],
                                month  => ++$time[4],
                                day    => $time[3],
                                hour   => $time[2],
                                minute => $time[1],
                                # DateTime doesn't like fractional seconds.
                                second => int($time[0]),
                                # If importing, use the specified timezone, otherwise 
                                # use the timezone specified by the server.
                                time_zone => Bugzilla->local_timezone->offset_as_string($time[6]) 
                                          || Bugzilla->local_timezone});

        # Now display the date using the given timezone,
        # or the user's timezone if none is given.
        $dt->set_time_zone($timezone || Bugzilla->user->timezone);
        $date = $dt->strftime($format);
    }
    else {
        # Don't let invalid (time) strings to be passed to templates!
        $date = '';
    }
    return trim($date);
}

sub format_time_decimal {
    my ($time) = (@_);

    my $newtime = sprintf("%.2f", $time);

    if ($newtime =~ /0\Z/) {
        $newtime = sprintf("%.1f", $time);
    }

    return $newtime;
}

sub file_mod_time {
    my ($filename) = (@_);
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($filename);
    return $mtime;
}

sub bz_crypt {
    my ($password, $salt) = @_;

    my $algorithm;
    if (!defined $salt) {
        # If you don't use a salt, then people can create tables of
        # hashes that map to particular passwords, and then break your
        # hashing very easily if they have a large-enough table of common
        # (or even uncommon) passwords. So we generate a unique salt for
        # each password in the database, and then just prepend it to
        # the hash.
        $salt = generate_random_password(PASSWORD_SALT_LENGTH);
        $algorithm = PASSWORD_DIGEST_ALGORITHM;
    }

    # We append the algorithm used to the string. This is good because then
    # we can change the algorithm being used, in the future, without 
    # disrupting the validation of existing passwords. Also, this tells
    # us if a password is using the old "crypt" method of hashing passwords,
    # because the algorithm will be missing from the string.
    if ($salt =~ /{([^}]+)}$/) {
        $algorithm = $1;
    }

    my $crypted_password;
    if (!$algorithm) {
    # Wide characters cause crypt to die
    if (Bugzilla->params->{'utf8'}) {
        utf8::encode($password) if utf8::is_utf8($password);
    }
    
    # Crypt the password.
        $crypted_password = crypt($password, $salt);

        # HACK: Perl has bug where returned crypted password is considered
        # tainted. See http://rt.perl.org/rt3/Public/Bug/Display.html?id=59998
        unless(tainted($password) || tainted($salt)) {
            trick_taint($crypted_password);
        } 
    }
    else {
        my $hasher = Digest->new($algorithm);
        # We only want to use the first characters of the salt, no
        # matter how long of a salt we may have been passed.
        $salt = substr($salt, 0, PASSWORD_SALT_LENGTH);
        $hasher->add($password, $salt);
        $crypted_password = $salt . $hasher->b64digest . "{$algorithm}";
    }

    # Return the crypted password.
    return $crypted_password;
}

sub generate_random_password {
    my $size = shift || 10; # default to 10 chars if nothing specified
    return join("", map{ ('0'..'9','a'..'z','A'..'Z')[rand 62] } (1..$size));
}

sub validate_email_syntax {
    my ($addr) = @_;
    my $match = Bugzilla->params->{'emailregexp'};
    my $ret = ($addr =~ /$match/ && $addr !~ /[\\\(\)<>&,;:\"\[\] \t\r\n]/);
    if ($ret) {
        # We assume these checks to suffice to consider the address untainted.
        trick_taint($_[0]);
    }
    return $ret ? 1 : 0;
}

sub validate_date {
    my ($date) = @_;
    my $date2;

    # $ts is undefined if the parser fails.
    my $ts = str2time($date);
    if ($ts) {
        $date2 = time2str("%Y-%m-%d", $ts);

        $date =~ s/(\d+)-0*(\d+?)-0*(\d+?)/$1-$2-$3/; 
        $date2 =~ s/(\d+)-0*(\d+?)-0*(\d+?)/$1-$2-$3/;
    }
    my $ret = ($ts && $date eq $date2);
    return $ret ? 1 : 0;
}

sub validate_time {
    my ($time) = @_;
    my $time2;

    # $ts is undefined if the parser fails.
    my $ts = str2time($time);
    if ($ts) {
        $time2 = time2str("%H:%M:%S", $ts);
        if ($time =~ /^(\d{1,2}):(\d\d)(?::(\d\d))?$/) {
            $time = sprintf("%02d:%02d:%02d", $1, $2, $3 || 0);
        }
    }
    my $ret = ($ts && $time eq $time2);
    return $ret ? 1 : 0;
}

sub is_7bit_clean {
    return $_[0] !~ /[^\x20-\x7E\x0A\x0D]/;
}

sub clean_text {
    my ($dtext) = shift;
    $dtext =~  s/[\x00-\x1F\x7F]+/ /g;   # change control characters into a space
    return trim($dtext);
}

# Довольно некрасивый хак для бага см.ниже - на багах с длинным числом комментов
# quoteUrls вызывает на каждый коммент get_text('term', { term => 'bug' }),
# что приводит к ужасной производительности. например, на баге с 703
# комментами в 10-15 раз ухудшение по сравнению с Bugzilla 2.x.
# Избавляемся от этого.
sub get_term
{
    my ($term) = @_;
    my $tt;
    unless ($tt = Bugzilla->request_cache->{_variables_none_tmpl})
    {
        # создаём отдельный шаблон
        $tt = Bugzilla::Template->create();
        # хакаемся внутрь контекста и делаем process без localise
        $tt = $tt->{SERVICE}->context;
        $tt->process('global/variables.none.tmpl');
        Bugzilla->request_cache->{_variables_none_tmpl} = $tt;
    }
    return $tt->stash->get(['terms', 0, $term, 0]);
}

# CustIS Bug 40933 ФАКМОЙМОЗГ! ВРОТМНЕНОГИ! КТО ТАК ПИШЕТ?!!!!
# ВОТ он, антипаттерн разработки на TT, ведущий к тормозам...
# ALSO CustIS Bug3 52322
sub get_text {
    my ($name, $vars) = @_;
    my $template = Bugzilla->template_inner;
    $vars ||= {};
    $vars->{'message'} = $name;
    my $message;
    $template->process('global/message.txt.tmpl', $vars, \$message)
        || ThrowTemplateError($template->error());
    # Remove the indenting that exists in messages.html.tmpl.
    $message =~ s/^    //gm;
    return $message;
}


sub get_netaddr {
    my $ipaddr = shift;

    # Check for a valid IPv4 addr which we know how to parse
    if (!$ipaddr || $ipaddr !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
        return undef;
    }

    my $addr = unpack("N", pack("CCCC", split(/\./, $ipaddr)));

    my $maskbits = Bugzilla->params->{'loginnetmask'};

    # Make Bugzilla ignore the IP address if loginnetmask is set to 0
    return "0.0.0.0" if ($maskbits == 0);

    $addr >>= (32-$maskbits);

    $addr <<= (32-$maskbits);
    return join(".", unpack("CCCC", pack("N", $addr)));
}

sub disable_utf8 {
    if (Bugzilla->params->{'utf8'}) {
        binmode STDOUT, ':bytes'; # Turn off UTF8 encoding.
    }
}

# Bug 46221 - Russian Stemming in Bugzilla fulltext search
sub stem_text
{
    my ($text, $allow_verbatim) = @_;
    $text = [ split /(?<=\w)(?=\W)|(?<=\W)(?=\w)/, $text ];
    my $q = 0;
    for (@$text)
    {
        unless (/\W/)
        {
            $_ = Lingua::Stem::RuUTF8::stem_word($_) unless $q;
        }
        elsif ($allow_verbatim)
        {
            # If $allow_verbatim is TRUE then text in "double quotes" doesn't stem
            $q = ($q + tr/\"/\"/) % 2;
        }
    }
    return join '', @$text;
}

1;

__END__

=head1 NAME

Bugzilla::Util - Generic utility functions for bugzilla

=head1 SYNOPSIS

  use Bugzilla::Util;

  # Functions for dealing with variable tainting
  trick_taint($var);
  detaint_natural($var);
  detaint_signed($var);

  # Functions for quoting
  html_quote($var);
  url_quote($var);
  xml_quote($var);
  email_filter($var);

  # Functions for decoding
  $rv = url_decode($var);

  # Functions that tell you about your environment
  my $is_cgi   = i_am_cgi();
  my $net_addr = get_netaddr($ip_addr);
  my $urlbase  = correct_urlbase();

  # Functions for searching
  $loc = lsearch(\@arr, $val);

  # Data manipulation
  ($removed, $added) = diff_arrays(\@old, \@new);

  # Functions for manipulating strings
  $val = trim(" abc ");
  $wrapped = wrap_comment($comment);

  # Functions for formatting time
  format_time($time);

  # Functions for dealing with files
  $time = file_mod_time($filename);

  # Cryptographic Functions
  $crypted_password = bz_crypt($password);
  $new_password = generate_random_password($password_length);

  # Validation Functions
  validate_email_syntax($email);
  validate_date($date);

=head1 DESCRIPTION

This package contains various utility functions which do not belong anywhere
else.

B<It is not intended as a general dumping group for something which
people feel might be useful somewhere, someday>. Do not add methods to this
package unless it is intended to be used for a significant number of files,
and it does not belong anywhere else.

=head1 FUNCTIONS

This package provides several types of routines:

=head2 Tainting

Several functions are available to deal with tainted variables. B<Use these
with care> to avoid security holes.

=over 4

=item C<trick_taint($val)>

Tricks perl into untainting a particular variable.

Use trick_taint() when you know that there is no way that the data
in a scalar can be tainted, but taint mode still bails on it.

B<WARNING!! Using this routine on data that really could be tainted defeats
the purpose of taint mode.  It should only be used on variables that have been
sanity checked in some way and have been determined to be OK.>

=item C<detaint_natural($num)>

This routine detaints a natural number. It returns a true value if the
value passed in was a valid natural number, else it returns false. You
B<MUST> check the result of this routine to avoid security holes.

=item C<detaint_signed($num)>

This routine detaints a signed integer. It returns a true value if the
value passed in was a valid signed integer, else it returns false. You
B<MUST> check the result of this routine to avoid security holes.

=back

=head2 Quoting

Some values may need to be quoted from perl. However, this should in general
be done in the template where possible.

=over 4

=item C<html_quote($val)>

Returns a value quoted for use in HTML, with &, E<lt>, E<gt>, and E<34> being
replaced with their appropriate HTML entities.

=item C<html_light_quote($val)>

Returns a string where only explicitly allowed HTML elements and attributes
are kept. All HTML elements and attributes not being in the whitelist are either
escaped (if HTML::Scrubber is not installed) or removed.

=item C<url_quote($val)>

Quotes characters so that they may be included as part of a url.

=item C<css_class_quote($val)>

Quotes characters so that they may be used as CSS class names. Spaces
are replaced by underscores.

=item C<xml_quote($val)>

This is similar to C<html_quote>, except that ' is escaped to &apos;. This
is kept separate from html_quote partly for compatibility with previous code
(for &apos;) and partly for future handling of non-ASCII characters.

=item C<url_decode($val)>

Converts the %xx encoding from the given URL back to its original form.

=item C<email_filter>

Removes the hostname from email addresses in the string, if the user
currently viewing Bugzilla is logged out. If the user is logged-in,
this filter just returns the input string.

=back

=head2 Environment and Location

Functions returning information about your environment or location.

=over 4

=item C<i_am_cgi()>

Tells you whether or not you are being run as a CGI script in a web
server. For example, it would return false if the caller is running
in a command-line script.

=item C<get_netaddr($ipaddr)>

Given an IP address, this returns the associated network address, using
C<Bugzilla->params->{'loginnetmask'}> as the netmask. This can be used
to obtain data in order to restrict weak authentication methods (such as
cookies) to only some addresses.

=item C<correct_urlbase()>

Returns either the C<sslbase> or C<urlbase> parameter, depending on the
current setting for the C<ssl> parameter.

=item C<use_attachbase()>

Returns true if an alternate host is used to display attachments; false
otherwise.

=back

=head2 Searching

Functions for searching within a set of values.

=over 4

=item C<lsearch($list, $item)>

Returns the position of C<$item> in C<$list>. C<$list> must be a list
reference.

If the item is not in the list, returns -1.

=back

=head2 Data Manipulation

=over 4

=item C<diff_arrays(\@old, \@new)>

 Description: Takes two arrayrefs, and will tell you what it takes to 
              get from @old to @new.
 Params:      @old = array that you are changing from
              @new = array that you are changing to
 Returns:     A list of two arrayrefs. The first is a reference to an 
              array containing items that were removed from @old. The
              second is a reference to an array containing items
              that were added to @old. If both returned arrays are 
              empty, @old and @new contain the same values.

=back

=head2 String Manipulation

=over 4

=item C<trim($str)>

Removes any leading or trailing whitespace from a string. This routine does not
modify the existing string.

=item C<wrap_hard($string, $size)>

Wraps a string, so that a line is I<never> longer than C<$size>.
Returns the string, wrapped.

=item C<wrap_comment($comment)>

Takes a bug comment, and wraps it to the appropriate length. The length is
currently specified in C<Bugzilla::Constants::COMMENT_COLS>. Lines beginning
with ">" are assumed to be quotes, and they will not be wrapped.

The intended use of this function is to wrap comments that are about to be
displayed or emailed. Generally, wrapped text should not be stored in the
database.

=item C<find_wrap_point($string, $maxpos)>

Search for a comma, a whitespace or a hyphen to split $string, within the first
$maxpos characters. If none of them is found, just split $string at $maxpos.
The search starts at $maxpos and goes back to the beginning of the string.

=item C<is_7bit_clean($str)>

Returns true is the string contains only 7-bit characters (ASCII 32 through 126,
ASCII 10 (LineFeed) and ASCII 13 (Carrage Return).

=item C<disable_utf8()>

Disable utf8 on STDOUT (and display raw data instead).

=item C<clean_text($str)>
Returns the parameter "cleaned" by exchanging non-printable characters with spaces.
Specifically characters (ASCII 0 through 31) and (ASCII 127) will become ASCII 32 (Space).

=item C<get_text>

=over

=item B<Description>

This is a method of getting localized strings within Bugzilla code.
Use this when you don't want to display a whole template, you just
want a particular string.

It uses the F<global/message.txt.tmpl> template to return a string.

=item B<Params>

=over

=item C<$message> - The identifier for the message.

=item C<$vars> - A hashref. Any variables you want to pass to the template.

=back

=item B<Returns>

A string.

=back

=back

=head2 Formatting Time

=over 4

=item C<format_time($time)>

Takes a time and converts it to the desired format and timezone.
If no format is given, the routine guesses the correct one and returns
an empty array if it cannot. If no timezone is given, the user's timezone
is used, as defined in his preferences.

This routine is mainly called from templates to filter dates, see
"FILTER time" in L<Bugzilla::Template>.

=item C<format_time_decimal($time)>

Returns a number with 2 digit precision, unless the last digit is a 0. Then it 
returns only 1 digit precision.

=back


=head2 Files

=over 4

=item C<file_mod_time($filename)>

Takes a filename and returns the modification time. It returns it in the format
of the "mtime" parameter of the perl "stat" function.

=back

=head2 Cryptography

=over 4

=item C<bz_crypt($password, $salt)>

Takes a string and returns a hashed (encrypted) value for it, using a
random salt. An optional salt string may also be passed in.

Please always use this function instead of the built-in perl C<crypt>
function, when checking or setting a password. Bugzilla does not use
C<crypt>.

=begin undocumented

Random salts are generated because the alternative is usually
to use the first two characters of the password itself, and since
the salt appears in plaintext at the beginning of the encrypted
password string this has the effect of revealing the first two
characters of the password to anyone who views the encrypted version.

=end undocumented

=item C<generate_random_password($password_length)>

Returns an alphanumeric string with the specified length
(10 characters by default). Use this function to generate passwords
and tokens.

=back

=head2 Validation

=over 4

=item C<validate_email_syntax($email)>

Do a syntax checking for a legal email address and returns 1 if
the check is successful, else returns 0.
Untaints C<$email> if successful.

=item C<validate_date($date)>

Make sure the date has the correct format and returns 1 if
the check is successful, else returns 0.

=back
