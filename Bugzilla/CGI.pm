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
# Contributor(s): Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Byron Jones <bugzilla@glob.com.au>
#                 Marc Schumann <wurblzap@gmail.com>

use strict;

package Bugzilla::CGI;

BEGIN {
    if ($^O =~ /MSWin32/i) {
        # Help CGI find the correct temp directory as the default list
        # isn't Windows friendly (Bug 248988)
        $ENV{'TMPDIR'} = $ENV{'TEMP'} || $ENV{'TMP'} || "$ENV{'WINDIR'}\\TEMP";
    }
}

use CGI qw(-no_xhtml -oldstyle_urls :private_tempfiles :unique_headers SERVER_PUSH);

use base qw(CGI);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;

# We need to disable output buffering - see bug 179174
$| = 1;

# Ignore SIGTERM and SIGPIPE - this prevents DB corruption. If the user closes
# their browser window while a script is running, the web server sends these
# signals, and we don't want to die half way through a write.
$::SIG{TERM} = 'IGNORE';
$::SIG{PIPE} = 'IGNORE';

# CGI.pm uses AUTOLOAD, but explicitly defines a DESTROY sub.
# We need to do so, too, otherwise perl dies when the object is destroyed
# and we don't have a DESTROY method (because CGI.pm's AUTOLOAD will |die|
# on getting an unknown sub to try to call)
sub DESTROY {
    my $self = shift;
    $self->SUPER::DESTROY(@_);
};

sub new {
    my ($invocant, @args) = @_;
    my $class = ref($invocant) || $invocant;

    my $self = $class->SUPER::new(@args);

    # Make sure our outgoing cookie list is empty on each invocation
    $self->{Bugzilla_cookie_list} = [];

    # Send appropriate charset
    $self->charset(Bugzilla->params->{'utf8'} ? 'UTF-8' : '');

    # Redirect to urlbase/sslbase if we are not viewing an attachment.
    if (use_attachbase() && i_am_cgi()) {
        my $cgi_file = $self->url('-path_info' => 0, '-query' => 0, '-relative' => 1);
        $cgi_file =~ s/\?$//;
        my $urlbase = Bugzilla->params->{'urlbase'};
        my $sslbase = Bugzilla->params->{'sslbase'};
        my $path_regexp = $sslbase ? qr/^(\Q$urlbase\E|\Q$sslbase\E)/ : qr/^\Q$urlbase\E/;
        if ($cgi_file ne 'attachment.cgi' && $self->self_url !~ /$path_regexp/) {
            $self->redirect_to_urlbase;
        }
    }

    # Check for errors
    # All of the Bugzilla code wants to do this, so do it here instead of
    # in each script

    my $err = $self->cgi_error;

    if ($err) {
        # Note that this error block is only triggered by CGI.pm for malformed
        # multipart requests, and so should never happen unless there is a
        # browser bug.

        print $self->header(-status => $err);

        # ThrowCodeError wants to print the header, so it grabs Bugzilla->cgi
        # which creates a new Bugzilla::CGI object, which fails again, which
        # ends up here, and calls ThrowCodeError, and then recurses forever.
        # So don't use it.
        # In fact, we can't use templates at all, because we need a CGI object
        # to determine the template lang as well as the current url (from the
        # template)
        # Since this is an internal error which indicates a severe browser bug,
        # just die.
        die "CGI parsing error: $err";
    }

    return $self;
}

# DAMN CGI.pm AUTHORS for their newstyle_urls O_O O_O
sub parse_params {
    my $self = shift;
    $CGI::USE_PARAM_SEMICOLONS = 0;
    $self->SUPER::parse_params(@_);
}

# We want this sorted plus the ability to exclude certain params
sub canonicalise_query {
    my ($self, @exclude) = @_;

    # Reconstruct the URL by concatenating the sorted param=value pairs
    my @parameters;
    foreach my $key (sort($self->param())) {
        # Leave this key out if it's in the exclude list
        next if lsearch(\@exclude, $key) != -1;

        # Remove the Boolean Charts for standard query.cgi fields
        # They are listed in the query URL already
        next if $key =~ /^(field|type|value)(-\d+){3}$/;

        my $esc_key = url_quote($key);

        foreach my $value ($self->param($key)) {
            if (defined($value)) {
                my $esc_value = url_quote($value);

                push(@parameters, "$esc_key=$esc_value");
            }
        }
    }

    return join("&", @parameters);
}

sub clean_search_url {
    my $self = shift;
    # Delete any empty URL parameter.
    my @cgi_params = $self->param;

    foreach my $param (@cgi_params) {
        if (defined $self->param($param) && $self->param($param) eq '') {
            $self->delete($param);
            $self->delete("${param}_type");
        }

        # Boolean Chart stuff is empty if it's "noop"
        if ($param =~ /\d-\d-\d/ && defined $self->param($param)
            && $self->param($param) eq 'noop')
        {
            $self->delete($param);
        }
    }

    # Delete certain parameters if the associated parameter is empty.
    $self->delete('bugidtype')  if !$self->param('bug_id');

    # Delete leftovers from the login form
    $self->delete('Bugzilla_remember', 'GoAheadAndLogIn');

    foreach my $num (1,2) {
        # If there's no value in the email field, delete the related fields.
        if (!$self->param("email$num")) {
            foreach my $field qw(type assigned_to reporter qa_contact
                                 cc longdesc) 
            {
                $self->delete("email$field$num");
            }
        }
    }

    # chfieldto is set to "Now" by default in query.cgi.
    if ($self->param('chfieldto') eq 'Now')
    {
        $self->delete('chfieldto');
    }

    # cmdtype "doit" is the default from query.cgi, but it's only meaningful
    # if there's a remtype parameter.
    if (defined $self->param('cmdtype') && $self->param('cmdtype') eq 'doit'
        && !defined $self->param('remtype'))
    {
        $self->delete('cmdtype');
    }

    # "Reuse same sort as last time" is actually the default, so we don't
    # need it in the URL.
    if ($self->param('order') 
        && $self->param('order') eq 'Reuse same sort as last time')
    {
        $self->delete('order');
    }

    # And now finally, if query_format is our only parameter, that
    # really means we have no parameters, so we should delete query_format.
    if ($self->param('query_format') && scalar($self->param()) == 1) {
        $self->delete('query_format');
    }
}

# Overwrite to ensure nph doesn't get set, and unset HEADERS_ONCE
sub multipart_init {
    my $self = shift;

    # Keys are case-insensitive, map to lowercase
    my %args = @_;
    my %param;
    foreach my $key (keys %args) {
        $param{lc $key} = $args{$key};
    }

    # Set the MIME boundary and content-type
    my $boundary = $param{'-boundary'} || '------- =_aaaaaaaaaa0';
    delete $param{'-boundary'};
    $self->{'separator'} = "\r\n--$boundary\r\n";
    $self->{'final_separator'} = "\r\n--$boundary--\r\n";
    $param{'-type'} = SERVER_PUSH($boundary);

    # Note: CGI.pm::multipart_init up to v3.04 explicitly set nph to 0
    # CGI.pm::multipart_init v3.05 explicitly sets nph to 1
    # CGI.pm's header() sets nph according to a param or $CGI::NPH, which
    # is the desired behaviour.

    return $self->header(
        %param,
    ) . "WARNING: YOUR BROWSER DOESN'T SUPPORT THIS SERVER-PUSH TECHNOLOGY." . $self->multipart_end;
}

# Have to add the cookies in.
sub multipart_start {
    my $self = shift;
    
    my %args = @_;

    # CGI.pm::multipart_start doesn't honour its own charset information, so
    # we do it ourselves here
    if (defined $self->charset() && defined $args{-type}) {
        # Remove any existing charset specifier
        $args{-type} =~ s/;.*$//;
        # and add the specified one
        $args{-type} .= '; charset=' . $self->charset();
    }
        
    my $headers = $self->SUPER::multipart_start(%args);
    # Eliminate the one extra CRLF at the end.
    $headers =~ s/$CGI::CRLF$//;
    # Add the cookies. We have to do it this way instead of
    # passing them to multpart_start, because CGI.pm's multipart_start
    # doesn't understand a '-cookie' argument pointing to an arrayref.
    foreach my $cookie (@{$self->{Bugzilla_cookie_list}}) {
        $headers .= "Set-Cookie: ${cookie}${CGI::CRLF}";
    }
    $headers .= $CGI::CRLF;
    return $headers;
}

# Override header so we can add the cookies in
sub header {
    my $self = shift;

    # Add the cookies in if we have any
    if (scalar(@{$self->{Bugzilla_cookie_list}})) {
        if (scalar(@_) == 1) {
            # if there's only one parameter, then it's a Content-Type.
            # Since we're adding parameters we have to name it.
            unshift(@_, '-type' => shift(@_));
        }
        unshift(@_, '-cookie' => $self->{Bugzilla_cookie_list});
    }

    return $self->SUPER::header(@_) || "";
}

sub param {
    my $self = shift;

    # When we are just requesting the value of a parameter...
    if (scalar(@_) == 1) {
        my @result = $self->SUPER::param(@_); 

        # Also look at the URL parameters, after we look at the POST 
        # parameters. This is to allow things like login-form submissions
        # with URL parameters in the form's "target" attribute.
        if (!scalar(@result)
            && $self->request_method && $self->request_method eq 'POST')
        {
            @result = $self->SUPER::url_param(@_);
        }

        # Fix UTF-8-ness of input parameters.
        if (Bugzilla->params->{'utf8'}) {
            @result = map { _fix_utf8($_) } @result;
        }

        return wantarray ? @result : $result[0];
        }
    # And for various other functions in CGI.pm, we need to correctly
    # return the URL parameters in addition to the POST parameters when
    # asked for the list of parameters.
    elsif (!scalar(@_) && $self->request_method 
           && $self->request_method eq 'POST') 
    {
        my @post_params = $self->SUPER::param;
        my @url_params  = $self->url_param;
        my %params = map { $_ => 1 } (@post_params, @url_params);
        return keys %params;
    }

    return $self->SUPER::param(@_);
}

sub _fix_utf8 {
    my $input = shift;
    # The is_utf8 is here in case CGI gets smart about utf8 someday.
    utf8::decode($input) if defined $input && !utf8::is_utf8($input);
    return $input;
}

# The various parts of Bugzilla which create cookies don't want to have to
# pass them around to all of the callers. Instead, store them locally here,
# and then output as required from |header|.
sub send_cookie {
    my $self = shift;

    # Move the param list into a hash for easier handling.
    my %paramhash;
    my @paramlist;
    my ($key, $value);
    while ($key = shift) {
        $value = shift;
        $paramhash{$key} = $value;
    }

    # Complain if -value is not given or empty (bug 268146).
    if (!exists($paramhash{'-value'}) || !$paramhash{'-value'}) {
        ThrowCodeError('cookies_need_value');
    }

    # Add the default path and the domain in.
    $paramhash{'-path'} = Bugzilla->params->{'cookiepath'};
    $paramhash{'-domain'} = Bugzilla->params->{'cookiedomain'}
        if Bugzilla->params->{'cookiedomain'};

    # Move the param list back into an array for the call to cookie().
    foreach (keys(%paramhash)) {
        unshift(@paramlist, $_ => $paramhash{$_});
    }

    push(@{$self->{'Bugzilla_cookie_list'}}, $self->cookie(@paramlist));
}

# Cookies are removed by setting an expiry date in the past.
# This method is a send_cookie wrapper doing exactly this.
sub remove_cookie {
    my $self = shift;
    my ($cookiename) = (@_);

    # Expire the cookie, giving a non-empty dummy value (bug 268146).
    $self->send_cookie('-name'    => $cookiename,
                       '-expires' => 'Tue, 15-Sep-1998 21:49:00 GMT',
                       '-value'   => 'X');
}

# Redirect to https if required
sub require_https {
     my ($self, $url) = @_;
     # Do not create query string if data submitted via XMLRPC
     # since we want the data to be resubmitted over POST method.
     my $query = Bugzilla->usage_mode == USAGE_MODE_WEBSERVICE ? 0 : 1;
     # XMLRPC clients (SOAP::Lite at least) requires 301 to redirect properly
     # and do not work with 302.
     my $status = Bugzilla->usage_mode == USAGE_MODE_WEBSERVICE ? 301 : 302;
     if (defined $url) {
         $url .= $self->url('-path_info' => 1, '-query' => $query, '-relative' => 1);
     } else {
         $url = $self->self_url;
         $url =~ s/^http:/https:/i;
     }
     print $self->redirect(-location => $url, -status => $status);
     # When using XML-RPC with mod_perl, we need the headers sent immediately.
     $self->r->rflush if $ENV{MOD_PERL};
     exit;
}

# Redirect to the urlbase version of the current URL.
sub redirect_to_urlbase {
    my $self = shift;
    my $path = $self->url('-path_info' => 1, '-query' => 1, '-relative' => 1);
    print $self->redirect('-location' => correct_urlbase() . $path);
    exit;
}

# cookie() with UTF-8 support...
sub cookie
{
    my($self,@p) = CGI::self_or_default(@_);
    my($name,$value,$path,$domain,$secure,$expires,$httponly) =
        CGI::rearrange(['NAME',['VALUE','VALUES'],'PATH','DOMAIN','SECURE','EXPIRES','HTTPONLY'],@p);

    require CGI::Cookie;

    # if no value is supplied, then we retrieve the
    # value of the cookie, if any.  For efficiency, we cache the parsed
    # cookies in our state variables.
    unless ( defined($value) ) {
        unless ($self->{'.cookies'})
        {
            $self->{'.cookies'} = CGI::Cookie->fetch;
            if (Bugzilla->params->{utf8})
            {
                my $v;
                my @a;
                for (keys %{$self->{'.cookies'}})
                {
                    $v = $self->{'.cookies'}->{$_}->value;
                    Encode::_utf8_on($_);
                    Encode::_utf8_on($v);
                    push @a, $_, $v;
                }
                $self->{'.cookies'} = { @a };
            }
        }

        # If no name is supplied, then retrieve the names of all our cookies.
        return () unless $self->{'.cookies'};
        return keys %{$self->{'.cookies'}} unless $name;
        return () unless $self->{'.cookies'}->{$name};
        return $self->{'.cookies'}->{$name} if defined($name) && $name ne '';
    }

    # If we get here, we're creating a new cookie
    return undef unless defined($name) && $name ne ''; # this is an error

    my @param;
    push(@param,'-name'=>$name);
    push(@param,'-value'=>$value);
    push(@param,'-domain'=>$domain) if $domain;
    push(@param,'-path'=>$path) if $path;
    push(@param,'-expires'=>$expires) if $expires;
    push(@param,'-secure'=>$secure) if $secure;
    push(@param,'-httponly'=>$httponly) if $httponly;

    return new CGI::Cookie(@param);
}

1;

__END__

=head1 NAME

Bugzilla::CGI - CGI handling for Bugzilla

=head1 SYNOPSIS

  use Bugzilla::CGI;

  my $cgi = new Bugzilla::CGI();

=head1 DESCRIPTION

This package inherits from the standard CGI module, to provide additional
Bugzilla-specific functionality. In general, see L<the CGI.pm docs|CGI> for
documention.

=head1 CHANGES FROM L<CGI.PM|CGI>

Bugzilla::CGI has some differences from L<CGI.pm|CGI>.

=over 4

=item C<cgi_error> is automatically checked

After creating the CGI object, C<Bugzilla::CGI> automatically checks
I<cgi_error>, and throws a CodeError if a problem is detected.

=back

=head1 ADDITIONAL FUNCTIONS

I<Bugzilla::CGI> also includes additional functions.

=over 4

=item C<canonicalise_query(@exclude)>

This returns a sorted string of the parameters, suitable for use in a url.
Values in C<@exclude> are not included in the result.

=item C<send_cookie>

This routine is identical to the cookie generation part of CGI.pm's C<cookie>
routine, except that it knows about Bugzilla's cookie_path and cookie_domain
parameters and takes them into account if necessary.
This should be used by all Bugzilla code (instead of C<cookie> or the C<-cookie>
argument to C<header>), so that under mod_perl the headers can be sent
correctly, using C<print> or the mod_perl APIs as appropriate.

To remove (expire) a cookie, use C<remove_cookie>.

=item C<remove_cookie>

This is a wrapper around send_cookie, setting an expiry date in the past,
effectively removing the cookie.

As its only argument, it takes the name of the cookie to expire.

=item C<require_https($baseurl)>

This routine redirects the client to a different location using the https protocol. 
If the client is using XMLRPC, it will not retain the QUERY_STRING since XMLRPC uses POST.

It takes an optional argument which will be used as the base URL.  If $baseurl
is not provided, the current URL is used.

=item C<redirect_to_urlbase>

Redirects from the current URL to one prefixed by the urlbase parameter.

=back

=head1 SEE ALSO

L<CGI|CGI>, L<CGI::Cookie|CGI::Cookie>
