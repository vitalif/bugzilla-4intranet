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

use utf8;
use strict;

use base qw(Exporter);
@Bugzilla::Util::EXPORT = qw(
    trick_taint is_tainted detaint_natural trick_taint_copy detaint_signed
    html_strip html_quote url_quote url_quote_noslash xml_quote css_class_quote html_light_quote url_decode
    i_am_cgi correct_urlbase remote_ip lsearch
    do_ssl_redirect_if_required use_attachbase
    diff_arrays list
    trim wrap_hard wrap_comment makeCitations
    format_time format_time_decimal validate_date validate_time datetime_from
    file_mod_time is_7bit_clean
    bz_crypt generate_random_password
    validate_email_syntax clean_text
    stem_text intersect union
    get_text disable_utf8 bz_encode_json
    xml_element xml_element_quote xml_dump_simple xml_simple
    Dumper http_build_query http_decode_query join_escaped split_escaped
    get_subclasses
);

use Bugzilla::Constants;

use Date::Parse;
use Date::Format;
use DateTime;
use DateTime::TimeZone;
use Digest;
use Email::Address;
use List::Util qw(first);
use Scalar::Util qw(tainted blessed);
use Template::Filters;
use Text::Wrap;
use Text::TabularDisplay::Utf8;
use JSON;

use Data::Dumper qw(Dumper);
$Data::Dumper::Useperl = 1;
$Data::Dumper::Indent = 1;
no warnings 'redefine';
*Data::Dumper::qquote = sub
{
    my $s = $_[0];
    $s = '' unless defined $s;
    $s =~ s/\"/\\"/gs;
    return '"'.$s.'"';
};

eval { require 'Lingua/Stem/Snowball.pm' };

sub is_tainted
{
    no warnings;
    return !eval { join('', @_), kill 0; 1; };
}

sub trick_taint
{
    return undef unless defined $_[0];
    my $match = $_[0] =~ /^(.*)$/s;
    $_[0] = $match ? $1 : undef;
    return (defined($_[0]));
}

sub trick_taint_copy
{
    $_[0] =~ /^(.*)$/s;
    return $1;
}

sub detaint_natural
{
    my $match = $_[0] =~ /^(\d+)$/;
    $_[0] = $match ? int($1) : undef;
    return (defined($_[0]));
}

sub detaint_signed
{
    my $match = $_[0] =~ /^([-+]?\d+)$/;
    # The "int()" call removes any leading plus sign.
    $_[0] = $match ? int($1) : undef;
    return (defined($_[0]));
}

sub html_strip
{
    my ($var) = @_;
    # Trivial HTML tag remover (this is just for error messages, really.)
    $var =~ s/<[^>]*>//g;
    # And this basically reverses the Template-Toolkit html filter.
    $var =~ s/\&amp;/\&/g;
    $var =~ s/\&lt;/</g;
    $var =~ s/\&gt;/>/g;
    $var =~ s/\&quot;/\"/g;
    $var =~ s/&#64;/@/g;
    # Also remove undesired newlines and consecutive spaces.
    $var =~ s/[\n\s]+/ /gms;
    return $var;
}

# Bug 120030: Override html filter to obscure the '@' in user
#             visible strings.
# Bug 319331: Handle BiDi disruptions.
sub html_quote
{
    my ($var) = Template::Filters::html_filter(@_);
    # Obscure '@'.
    $var =~ s/\@/\&#64;/g;
    if (Bugzilla->params->{utf8})
    {
        # Remove the following characters because they're
        # influencing BiDi:
        # --------------------------------------------------------
        # |Code  |Name                      |UTF-8 representation|
        # |------|--------------------------|--------------------|
        # |U+202a|Left-To-Right Embedding   |0xe2 0x80 0xaa      |
        # |U+202b|Right-To-Left Embedding   |0xe2 0x80 0xab      |
        # |U+202c|Pop Directional Formatting|0xe2 0x80 0xac      |
        # |U+202d|Left-To-Right Override    |0xe2 0x80 0xad      |
        # |U+202e|Right-To-Left Override    |0xe2 0x80 0xae      |
        # --------------------------------------------------------
        #
        # The following are characters influencing BiDi, too, but
        # they can be spared from filtering because they don't
        # influence more than one character right or left:
        # --------------------------------------------------------
        # |Code  |Name                      |UTF-8 representation|
        # |------|--------------------------|--------------------|
        # |U+200e|Left-To-Right Mark        |0xe2 0x80 0x8e      |
        # |U+200f|Right-To-Left Mark        |0xe2 0x80 0x8f      |
        # --------------------------------------------------------
        $var =~ s/[\x{202a}-\x{202e}]//g;
    }
    return $var;
}

sub _skip_attrs
{
    my ($tag, $attrs) = @_;
    $tag = lc $tag;
    return "<$tag>" if $tag =~ m!^/!so;
    my ($enclosed) = $attrs =~ m!/$!so ? ' /' : '';
    $attrs = { $attrs =~ /([^\s=]+)=([^\s=\'\"]+|\"[^\"]*\"|\'[^\']*\')/gso };
    my $new = {};
    for (qw(name id class style title))
    {
        $new->{$_} = $attrs->{$_} if $attrs->{$_};
    }
    my %l = (a => 'href', blockquote => 'cite', q => 'cite');
    if ($attrs->{$l{$tag}} && $attrs->{$l{$tag}} !~ /^[\"\']?javascript/iso)
    {
        $new->{$l{$tag}} = $attrs->{$l{$tag}};
    }
    return "<$tag".join("", map { " $_=".$new->{$_} } keys %$new).$enclosed.">";
}

sub html_light_quote
{
    my ($text) = @_;
    # List of allowed HTML elements having no attributes.
    my @allow = qw(
        a abbr acronym b big blockquote br cite code dd del dfn dl dt em fieldset hr i ins
        kbd legend li ol p q samp small span strong sub sup tt u ul var
    );
    my $safe = join('|', @allow);
    $text =~ s{(<(/?(?:$safe))(\s+(?:[^>"']+|"[^"]*"|'[^']*')*)?>)|(<)|(>)}{($1 ? _skip_attrs($2, $3) : ($4 ? '&lt;' : '&gt;'))}egiso;
    return $text;
}

sub email_filter
{
    my ($toencode) = @_;
    if (!Bugzilla->user->id)
    {
        my @emails = Email::Address->parse($toencode);
        if (scalar @emails)
        {
            my @hosts = map { quotemeta($_->host) } @emails;
            my $hosts_re = join('|', @hosts);
            $toencode =~ s/\@(?:$hosts_re)//g;
            return $toencode;
        }
    }
    return $toencode;
}

# This originally came from CGI.pm, by Lincoln D. Stein
sub url_quote
{
    my ($toencode) = (@_);
    utf8::encode($toencode) # The below regex works only on bytes
        if Bugzilla->params->{utf8} && utf8::is_utf8($toencode);
    $toencode =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

# Same, but doesn't quote the forward slash "/"
sub url_quote_noslash
{
    my ($toencode) = (@_);
    utf8::encode($toencode) # The below regex works only on bytes
        if Bugzilla->params->{utf8} && utf8::is_utf8($toencode);
    $toencode =~ s!([^a-zA-Z0-9_\-\./])!uc sprintf("%%%02x",ord($1))!ego;
    return $toencode;
}

# http_build_query($hashref) - transforms a parameter hash into URL-encoded query string
sub http_build_query($)
{
    my ($query) = @_;
    return join('&', map {
        url_quote($_).'='.(ref $query->{$_}
            ? join('&'.url_quote($_).'=', map { url_quote($_) } @{$query->{$_}})
            : url_quote($query->{$_}))
    } sort keys %$query);
}

# Decode query string to a hashref
sub http_decode_query($)
{
    my ($query) = @_;
    my $h = {};
    foreach my $part (split /&/, $query)
    {
        my ($k, $v) = map { url_decode($_); } split /=/, $part, 2;
        utf8::decode($_) for $k, $v;
        if (exists $h->{$k})
        {
            $h->{$k} = [ $h->{$k} ] if !ref $h->{$k};
            push @{$h->{$k}}, $v;
        }
        else
        {
            $h->{$k} = $v;
        }
    }
    return $h;
}

sub css_class_quote
{
    my ($toencode) = (@_);
    $toencode =~ s#[ /]#_#g;
    $toencode =~ s/([^a-zA-Z0-9_\-.])/sprintf("&#x%x;",ord($1))/eg;
    return $toencode;
}

sub xml_quote
{
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
sub url_decode
{
    my ($todecode) = (@_);
    $todecode =~ tr/+/ /;       # pluses become spaces
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
    return $todecode;
}

sub i_am_cgi
{
    # I use SERVER_SOFTWARE because it's required to be
    # defined for all requests in the CGI spec.
    return exists $ENV{SERVER_SOFTWARE} ? 1 : 0;
}

# This exists as a separate function from Bugzilla::CGI::redirect_to_https
# because we don't want to create a CGI object during XML-RPC calls
# (doing so can mess up XML-RPC).
sub do_ssl_redirect_if_required
{
    return if !i_am_cgi();
    return if !Bugzilla->params->{ssl_redirect};

    my $sslbase = Bugzilla->params->{sslbase};

    # If we're already running under SSL, never redirect.
    return if uc($ENV{HTTPS} || '') eq 'ON';
    # Never redirect if there isn't an sslbase.
    return if !$sslbase;
    Bugzilla->cgi->redirect_to_https();
}

sub correct_urlbase
{
    my $ssl = Bugzilla->params->{ssl_redirect};
    my $urlbase = Bugzilla->params->{urlbase};
    my $sslbase = Bugzilla->params->{sslbase};
    if (!$sslbase)
    {
        return $urlbase;
    }
    elsif ($ssl)
    {
        return $sslbase;
    }
    else
    {
        # Return what the user currently uses.
        return (uc($ENV{HTTPS} || '') eq 'ON') ? $sslbase : $urlbase;
    }
}

sub remote_ip
{
    my $ip = $ENV{REMOTE_ADDR} || '127.0.0.1';
    my @proxies = ('127.0.0.1', split /[\s,]+/, Bugzilla->params->{inbound_proxies});
    if (grep { $_ eq $ip } @proxies)
    {
        $ip = $ENV{HTTP_X_FORWARDED_FOR} if $ENV{HTTP_X_FORWARDED_FOR};
    }
    return $ip;
}

sub use_attachbase
{
    my $attachbase = Bugzilla->params->{attachment_base};
    return ($attachbase ne '' &&
        $attachbase ne Bugzilla->params->{urlbase} &&
        $attachbase ne Bugzilla->params->{sslbase}) ? 1 : 0;
}

sub lsearch
{
    my ($list,$item) = (@_);
    my $count = 0;
    foreach my $i (@$list)
    {
        if ($i eq $item)
        {
            return $count;
        }
        $count++;
    }
    return -1;
}

sub diff_arrays
{
    my ($old_ref, $new_ref) = @_;

    my @old = @$old_ref;
    my @new = @$new_ref;

    # For each pair of (old, new) entries:
    # If they're equal, set them to empty. When done, @old contains entries
    # that were removed; @new contains ones that got added.
    foreach my $oldv (@old)
    {
        foreach my $newv (@new)
        {
            next if $newv eq '';
            if ($oldv eq $newv)
            {
                $newv = $oldv = '';
            }
        }
    }

    my @removed = grep { $_ ne '' } @old;
    my @added = grep { $_ ne '' } @new;
    return (\@removed, \@added);
}

sub trim
{
    my ($str) = @_;
    if ($str)
    {
        $str =~ s/^\s+//g;
        $str =~ s/\s+$//g;
    }
    return $str;
}

sub makeCitations
{
    my ($input) = @_;
    my $last = 0;
    my $text = '';
    my ($re, $pre);
    for (split /\n/, $input)
    {
        s/^((?:\s*&gt;)+ ?)?//s;
        if ($_ ne '')
        {
            $re = (($1 || '') =~ tr/&/&/);
            $text .= ("<div class=\"quote\">\n" x ($re-$last)) .
                ("</div>\n" x ($last-$re)) . $_ . "\n";
            $last = $re;
        }
        else
        {
            $text .= "\n";
        }
    }
    $text .= ("</div>\n" x $last);
    return $text;
}

sub wrap_comment # makeParagraphs
{
    my ($input) = @_;
    my @m;
    my $p;
    my $tmp;
    my $text = '';
    my $block_tags = '(?:div|h[1-6]|center|ol|ul|li)';
    while ($input ne '')
    {
        # Convert double line breaks to new paragraphs
        if ($input =~ m!\n\s*\n|(</?$block_tags[^<>]*>)!so)
        {
            @m = (substr($input, 0, $-[0]), $1);
            $input = substr($input, $+[0]);
        }
        else
        {
            @m = ($input, '');
            $input = '';
        }
        if ($m[0] ne '')
        {
            # FIXME Opera Presto has a bug with ul > li > p > br...
            $m[0] =~ s/^\s*\n//s;
            $m[0] =~ s/^([ \t]+)/$tmp = $1; s!\t!    !g; $tmp/emog;
            $m[0] =~ s/(<[^<>]*>)|(  +)/$1 || ' '.('&nbsp;' x (length($2)-1))/ge;
            if (!$p && $m[0] ne '')
            {
                $text .= '<p>';
                $p = 1;
            }
            # But preserve single line breaks!
            $m[0] =~ s/\s+$//so;
            $m[0] =~ s/\n/<br \/>/giso;
            $text .= $m[0];
        }
        if ($p)
        {
            $text .= '</p>';
            $p = 0;
        }
        $text .= $m[1];
    }
    return $text;
}

sub wrap_hard
{
    my ($string, $columns) = @_;
    local $Text::Wrap::columns = $columns;
    local $Text::Wrap::unexpand = 0;
    local $Text::Wrap::huge = 'wrap';

    my $wrapped = wrap('', '', $string);
    chomp($wrapped);
    return $wrapped;
}

sub format_time
{
    my ($date, $format, $timezone) = @_;
    # If $format is not set, try to guess the correct date format.
    if (!$format)
    {
        if (!ref $date && $date =~ /^(\d{4})[-\.](\d{2})[-\.](\d{2}) (\d{2}):(\d{2})(:(\d{2}))?$/)
        {
            my $sec = $7;
            if (defined $sec)
            {
                $format = "%Y-%m-%d %T %Z";
            }
            else
            {
                $format = "%Y-%m-%d %R %Z";
            }
        }
        else
        {
            # Default date format. See DateTime for other formats available.
            $format = "%Y-%m-%d %R %Z";
        }
    }
    my $dt = ref $date ? $date : datetime_from($date, $timezone);
    $date = defined $dt ? $dt->strftime($format) : '';
    return trim($date);
}

sub datetime_from
{
    my ($date, $timezone) = @_;

    # In the database, this is the "0" date.
    return undef if $date =~ /^0000/;

    # strptime($date) returns an empty array if $date has an invalid
    # date format.
    my @time = strptime($date);

    unless (scalar @time)
    {
        # If an unknown timezone is passed (such as MSK, for Moskow),
        # strptime() is unable to parse the date. We try again, but we first
        # remove the timezone.
        $date =~ s/\s+\S+$//;
        @time = strptime($date);
    }

    return undef if !@time;

    # strptime() counts years from 1900, and months from 0 (January).
    # We have to fix both values.
    my $dt = DateTime->new({
        year   => $time[5] + 1900,
        month  => $time[4] + 1,
        day    => $time[3],
        hour   => $time[2],
        minute => $time[1],
        # DateTime doesn't like fractional seconds.
        # Also, sometimes seconds are undef.
        second => int($time[0] || 0),
        # If a timezone was specified, use it. Otherwise, use the
        # local timezone.
        time_zone => Bugzilla->local_timezone->offset_as_string($time[6]) || Bugzilla->local_timezone,
    });

    # Now display the date using the given timezone,
    # or the user's timezone if none is given.
    $dt->set_time_zone($timezone || Bugzilla->user->timezone);
    return $dt;
}

sub format_time_decimal
{
    my ($time) = (@_);
    my $newtime = sprintf("%.2f", $time);
    if ($newtime =~ /0\Z/)
    {
        $newtime = sprintf("%.1f", $time);
    }
    return $newtime;
}

sub file_mod_time
{
    my ($filename) = (@_);
    return [ stat $filename ]->[9];
}

sub bz_crypt
{
    my ($password, $salt) = @_;

    my $algorithm;
    if (!defined $salt)
    {
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
    if ($salt =~ /{([^}]+)}$/)
    {
        $algorithm = $1;
    }

    # Wide characters cause crypt to die
    if (Bugzilla->params->{utf8})
    {
        utf8::encode($password) if utf8::is_utf8($password);
    }

    my $crypted_password;
    if (!$algorithm)
    {
        # Crypt the password.
        $crypted_password = crypt($password, $salt);

        # HACK: Perl has bug where returned crypted password is considered
        # tainted. See http://rt.perl.org/rt3/Public/Bug/Display.html?id=59998
        unless (tainted($password) || tainted($salt))
        {
            trick_taint($crypted_password);
        }
    }
    else
    {
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

# If you want to understand the security of strings generated by this
# function, here's a quick formula that will help you estimate:
# We pick from 62 characters, which is close to 64, which is 2^6.
# So 8 characters is (2^6)^8 == 2^48 combinations. Just multiply 6
# by the number of characters you generate, and that gets you the equivalent
# strength of the string in bits.
sub generate_random_password
{
    my $size = shift || 10; # default to 10 chars if nothing specified
    my $rand;
    if (Bugzilla->feature('rand_security'))
    {
        $rand = \&Math::Random::Secure::irand;
    }
    else
    {
        # For details on why this block works the way it does, see bug 619594.
        # (Note that we don't do this if Math::Random::Secure is installed,
        # because we don't need to.)
        my $counter = 0;
        $rand = sub
        {
            # If we regenerate the seed every 5 characters, our seed is roughly
            # as strong (in terms of bit size) as our randomly-generated
            # string itself.
            _do_srand() if ($counter % 5) == 0;
            $counter++;
            return int(rand $_[0]);
        };
    }
    my @chars = ('0'..'9', 'a'..'z', 'A'..'Z');
    return join("", map { $chars[$rand->(62)] } (1..$size));
}

sub _do_srand
{
    # On Windows, calling srand over and over in the same process produces
    # very bad results. We need a stronger seed.
    if (ON_WINDOWS)
    {
        require Win32;
        # GuidGen generates random data via Windows's CryptGenRandom
        # interface, which is documented as being cryptographically secure.
        my $guid = Win32::GuidGen();
        # GUIDs look like:
        # {09531CF1-D0C7-4860-840C-1C8C8735E2AD}
        $guid =~ s/[-{}]+//g;
        # Get a 32-bit integer using the first eight hex digits.
        my $seed = hex(substr($guid, 0, 8));
        srand($seed);
        return;
    }
    # On *nix-like platforms, this uses /dev/urandom, so the seed changes
    # enough on every invocation.
    srand();
}

sub validate_email_syntax
{
    my ($addr) = @_;
    my $match = Bugzilla->params->{emailregexp};
    my $ret = ($addr =~ /$match/ && $addr !~ /[\\\(\)<>&,;:\"\[\] \t\r\n]/ && length $addr <= 255);
    if ($ret)
    {
        # We assume these checks to suffice to consider the address untainted.
        trick_taint($_[0]);
    }
    return $ret ? 1 : 0;
}

sub validate_date
{
    my ($date) = @_;
    my $date2;
    # $ts is undefined if the parser fails.
    my $ts = str2time($date);
    if ($ts)
    {
        $date2 = time2str("%Y-%m-%d", $ts);
        $date =~ s/(\d+)-0*(\d+?)-0*(\d+?)/$1-$2-$3/;
        $date2 =~ s/(\d+)-0*(\d+?)-0*(\d+?)/$1-$2-$3/;
    }
    my $ret = ($ts && $date eq $date2);
    return $ret ? 1 : 0;
}

sub validate_time
{
    my ($time) = @_;
    my $time2;
    # $ts is undefined if the parser fails.
    my $ts = str2time($time);
    if ($ts)
    {
        $time2 = time2str("%H:%M:%S", $ts);
        if ($time =~ /^(\d{1,2}):(\d\d)(?::(\d\d))?$/)
        {
            $time = sprintf("%02d:%02d:%02d", $1, $2, $3 || 0);
        }
    }
    my $ret = ($ts && $time eq $time2);
    return $ret ? 1 : 0;
}

sub is_7bit_clean
{
    return $_[0] !~ /[^\x20-\x7E\x0A\x0D]/;
}

sub clean_text
{
    my ($dtext) = shift;
    $dtext =~ s/[\x00-\x1F\x7F]+/ /g; # change control characters into a space
    return trim($dtext);
}

# FUCKMYBRAIN! CustIS Bugs 40933, 52322.
# Here is the Template Toolkit development anti-pattern!
# Originally, Bugzilla used to call get_text('term', { term => 'bug' })
# from quoteUrls() for each comment. This leaded to TERRIBLE performance
# on "long" bugs compared to Bugzilla 2.x!

sub get_text
{
    my ($name, $vars) = @_;
    my $template = Bugzilla->template_inner;
    $vars ||= {};
    $vars->{message} = $name;
    my $message;
    if (!$template->process('global/message.txt.tmpl', $vars, \$message))
    {
        require Bugzilla::Error;
        Bugzilla::Error::ThrowTemplateError($template->error());
    }
    # Remove the indenting that exists in messages.html.tmpl.
    $message =~ s/^    //gm;
    return $message;
}

sub disable_utf8
{
    if (Bugzilla->params->{utf8})
    {
        binmode STDOUT, ':bytes'; # Turn off UTF8 encoding.
    }
}

# CustIS Bug 46221 - Snowball Stemmers in MySQL fulltext search
my $snowballs = {};
sub stem_text
{
    my ($text, $lang, $allow_verbatim) = @_;
    return '' if !defined $text || $text =~ /^\s*$/so;
    return $text if !$INC{'Lingua/Stem/Snowball.pm'};
    $lang = lc($lang || 'en');
    $lang = LANG_FULL_ISO->{$lang} || 'en' if !LANG_ISO_FULL->{$lang};
    Encode::_utf8_on($text) if Bugzilla->params->{utf8};
    # CustIS Bug 66033 - _ is wanted to also be a delimiter
    $text = [ split /(\PL+)/, $text ];
    my $word = 1;
    if ($text->[0] eq '')
    {
        $word = 0;
        shift @$text;
    }
    my $q = 0;
    my $cache = (Bugzilla->request_cache->{stem_cache} ||= {});
    %$cache = () if keys(%$cache) > 65536;
    my $stem = ($snowballs->{$lang} ||= Lingua::Stem::Snowball->new(lang => $lang, encoding => 'UTF-8'));
    my $r = '';
    for (@$text)
    {
        if ($word)
        {
            # $q = 1 means we're inside quotes
            $r .= ($cache->{$_} ||= $stem->stem($_)) unless $q;
        }
        else
        {
            if ($allow_verbatim)
            {
                # If $allow_verbatim is TRUE then text in "double quotes" doesn't stem
                $q = ($q + tr/\"/\"/) % 2;
            }
            $r .= $_;
            $r .= ' ' if !/\s$/o;
        }
        $word = !$word;
    }
    return $r;
}

sub intersect
{
    my $values = shift;
    my %chk;
    while (my $next = shift)
    {
        %chk = map { $_ => 1 } @$next;
        @$values = grep { $chk{$_} } @$values;
    }
    return $values;
}

sub union
{
    return [] if !@_;
    my @values = @{shift()};
    my %chk = map { $_ => 1 } @values;
    while (my $next = shift)
    {
        for (@$next)
        {
            if (!$chk{$_})
            {
                push @values, $_;
                $chk{$_} = 1;
            }
        }
    }
    return \@values;
}

sub xml_element_quote
{
    my ($name, $args, $content) = @_;
    xml_element($name, $args, xml_quote($content));
}

sub xml_element
{
    my ($name, $args, $content) = @_;
    if (ref $args)
    {
        $args = join '', map { ' '.xml_quote($_).'="'.xml_quote($args->{$_}).'"' } keys %$args;
    }
    $name = xml_quote($name);
    $args = '<'.$name.$args;
    if (defined $content && $content eq '')
    {
        return $args.' />';
    }
    return $args.'>'.$content.'</'.$name.'>';
}

sub xml_dump_type
{
    if (ref $_[0])
    {
        ref($_[0]) =~ /^(?:([^=]*)=)?([^=\(]*)\(/;
        my $r = { type => $2 };
        $r->{class} = $1 if $1;
        return $r;
    }
    return '';
}

sub xml_dump_simple
{
    my ($data) = @_;
    if (blessed $data)
    {
        return $data->name if $data->can('name');
        return "$data";
    }
    elsif (ref $data)
    {
        my $r;
        if ($data =~ 'ARRAY')
        {
            $r = join '', map { xml_element('i', '', xml_dump_simple($_)) } @$data;
        }
        elsif ($data =~ 'HASH')
        {
            $r = join '', map { xml_element((/^[a-z:_][a-z:_\.0-9]*$/is ? ($_, '') : ('i', { key => $_ })), xml_dump_simple($data->{$_})) } keys %$data;
        }
        elsif ($data =~ 'SCALAR')
        {
            # FIXME maybe save references?
            $r = xml_dump_simple($$data);
        }
        else
        {
            $r = xml_quote("$data");
        }
        return $r;
    }
    return xml_quote("$data");
}

sub bz_encode_json
{
    my ($var) = @_;
    $var = encode_json($var);
    Encode::_utf8_on($var) if Bugzilla->params->{utf8};
    return $var;
}

# Return empty list for undef or expand an arrayref
sub list($)
{
    # If you write "list Package->method->{something}", for example "list Bugzilla->input_params->{arg}",
    # Perl parses it as "(list Package)->method->{something}". But most Bugzilla modules use Bugzilla::Util
    # and thus have list() imported in their namespace, so (list Package) gets happily executed and you
    # just get "Package->method->{something}" without list().
    # Trry to fight it by checking if the calling context wants a list.
    wantarray or die "Possible bug: Bugzilla::Util::list() called without wantarray. Do not write 'list Package->method->...'";
    my ($array) = @_;
    return () unless defined $array;
    return ($array) if ref $array ne 'ARRAY';
    return @$array;
}

sub xml_simple
{
    my ($text) = @_;
    require XML::Parser;
    my $parser = XML::Parser->new(Handlers => {
        Start => \&xml_simple_start,
        End   => \&xml_simple_end,
        Char  => \&xml_simple_char,
    });
    $parser->{_simple_data} = {};
    $parser->{_simple_stack} = [ $parser->{_simple_data} ];
    $parser->parse($text);
    return $parser->{_simple_data};
}

sub xml_simple_start
{
    my ($parser, $tag, %attr) = @_;
    my $stack = $parser->{_simple_stack};
    my $frame = $stack->[$#$stack];
    my $e = { char => '', map { ( "a$_" => $attr{$_} ) } keys %attr };
    push @$stack, $e;
    push @{$frame->{"e$tag"}}, $e;
}

sub xml_simple_end
{
    my ($parser, $tag) = @_;
    pop @{$parser->{_simple_stack}};
}

sub xml_simple_char
{
    my ($parser, $text) = @_;
    my $stack = $parser->{_simple_stack};
    my $frame = $stack->[$#$stack];
    $frame->{char} .= $text;
}

sub join_escaped
{
    my ($str, $re, @array) = @_;
    s/($re|\\)/\\$1/gs for @array;
    return join $str, @array;
}

sub split_escaped
{
    my ($re, $s, $limit) = @_;
    my @r;
    while ($s =~ s/^(.*(?:^|[^\\])(?:\\\\)*)$re//gs)
    {
        push @r, $1;
    }
    push @r, $s if length $s;
    s/\\(.)/$1/gso for @r;
    return @r;
}

sub get_subclasses
{
    my ($pkg) = @_;
    $pkg =~ s/::/\//gso;
    my $seen = {};
    foreach my $path (@INC)
    {
        foreach my $file (glob("$path/$pkg/*.pm"))
        {
            $file = substr($file, 2 + length($pkg) + length($path), -3);
            $file =~ s!/!::!gs;
            $seen->{$file} = 1;
        }
    }
    return [ sort keys %$seen ];
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
  datetime_from($time, $timezone);

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

Returns a value quoted for use in HTML, with &, E<lt>, E<gt>, E<34> and @ being
replaced with their appropriate HTML entities.  Also, Unicode BiDi controls are
deleted.

=item C<html_light_quote($val)>

Returns a string where only explicitly allowed HTML elements and attributes
are kept. All HTML elements not being in the whitelist are escaped; all HTML
attributes no being in the whitelist are removed.

=item C<url_quote($val)>

Quotes characters so that they may be included as part of a url.

=item C<css_class_quote($val)>

Quotes characters so that they may be used as CSS class names. Spaces
and forward slashes are replaced by underscores.

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

=item C<correct_urlbase()>

Returns either the C<sslbase> or C<urlbase> parameter, depending on the
current setting for the C<ssl_redirect> parameter.

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

=item C<datetime_from($time, $timezone)>

Returns a DateTime object given a date string. If the string is not in some
valid date format that C<strptime> understands, we return C<undef>.

You can optionally specify a timezone for the returned date. If not
specified, defaults to the currently-logged-in user's timezone, or
the Bugzilla server's local timezone if there isn't a logged-in user.

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
