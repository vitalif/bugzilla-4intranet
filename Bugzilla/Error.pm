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
# Contributor(s): Bradley Baetz <bbaetz@acm.org>
#                 Marc Schumann <wurblzap@gmail.com>
#                 Frédéric Buclin <LpSolit@gmail.com>

package Bugzilla::Error;

use strict;
use base qw(Exporter);

@Bugzilla::Error::EXPORT = qw(ThrowCodeError ThrowTemplateError ThrowUserError);

use Bugzilla::Constants;
use Bugzilla::WebService::Constants;
use Bugzilla::Util;
use Bugzilla::Mailer;
use Date::Format;
use JSON;
use Data::Dumper;

use overload '""' => sub { $_[0]->{message} };

my $HAVE_DEVEL_STACKTRACE = eval { require Devel::StackTrace };

our $IN_EVAL = 0;

# We cannot use $^S to detect if we are in an eval(), because mod_perl
# already eval'uates everything, so $^S = 1 in all cases under mod_perl!
sub _in_eval
{
    my $in = -$IN_EVAL;
    for (my $stack = 1; my $sub = (caller($stack))[3]; $stack++)
    {
        $in--, last if $sub =~ /^Bugzilla::HTTPServerSimple/;
        last if $sub =~ /^ModPerl/;
        if ($sub =~ /^\(eval\)/)
        {
            $in++;
        }
    }
    return $in > 0;
}

# build error message for printing into error log or sending to maintainer e-mail
sub _error_message
{
    my ($type, $error, $vars) = @_;
    my $mesg = '';
    $mesg .= "[$$] " . time2str("%D %H:%M:%S ", time());
    $mesg .= uc($type)." $error ";
    $mesg .= remote_ip();
    if (Bugzilla->user)
    {
        $mesg .= ' ' . Bugzilla->user->login;
        $mesg .= (' actually ' . Bugzilla->sudoer->login) if Bugzilla->sudoer;
    }
    $mesg .= "\n";
    $Data::Dumper::Indent = 1;
    # Don't try to dump upload data, dump upload info instead
    my $cgi = Bugzilla->cgi;
    my $cgivars = { $cgi->Vars };
    for (keys %$cgivars)
    {
        $cgivars->{$_} = $cgi->uploadInfo($cgivars->{$_}) if $cgi->upload($_);
    }
    $mesg .= Data::Dumper->Dump([$vars, $cgivars, { %ENV }], ['error_vars', 'cgi_params', 'env']);
    # ugly workaround for Data::Dumper's \x{425} unicode characters
    $mesg =~ s/((?:\\x\{(?:[\dA-Z]+)\})+)/eval("\"$1\"")/egiso;
    return $mesg;
}

sub throw
{
    my $self = shift;
    ref $self and _throw_error($self->{type}, $self->{error}, $self->{vars});
}

my $frame_filter_finished = 0;
sub _frame_filter
{
    my ($caller) = @_;
    $caller = $caller->{caller};
    # exclude several subs and all mod_perl stuff from stack trace
    return 0 if
        $caller->[3] eq 'Devel::StackTrace::new' ||
        $caller->[3] eq 'Bugzilla::Error::ThrowCodeError' && $caller->[0] eq 'Bugzilla' && $caller->[2] == 82 ||
        $caller->[3] eq 'Bugzilla::Error::_throw_error' && $caller->[0] eq 'Bugzilla::Error' ||
        $frame_filter_finished;
    if ($caller->[3] =~ /^ModPerl::ROOT::Bugzilla/)
    {
        $frame_filter_finished = 1;
        return 0;
    }
    return 1;
}

# Object method: log the Bugzilla::Error object to [data/]errorlog if it is configured
sub log
{
    my $self = shift;
    # Report error into [$datadir/] params.error_log if requested
    if (my $logfile = Bugzilla->params->{error_log})
    {
        $logfile = bz_locations()->{datadir} . '/' . $logfile if substr($logfile, 0, 1) ne '/';
        my $fd;
        # If we can write into error log, log error details there
        if (open $fd, ">>", $logfile)
        {
            print $fd (("-" x 75) . "\n" . ($self->{message} ||= _error_message($self->{type}, $self->{error}, $self->{vars})) . "\n");
            close $fd;
        }
    }
}

sub _throw_error
{
    my ($type, $error, $vars) = @_;

    my $msg;
    $vars ||= {};
    $vars->{error} = $error;
    if (!$vars->{stack_trace} && $HAVE_DEVEL_STACKTRACE)
    {
        # Append stack trace if Devel::StackTrace is available
        $frame_filter_finished = 0;
        $vars->{stack_trace} = Devel::StackTrace->new(frame_filter => \&_frame_filter)->as_string;
    }
    my $mode = Bugzilla->error_mode;

    my $do_die = $mode == ERROR_MODE_DIE ||
        $mode != ERROR_MODE_DIE_SOAP_FAULT && $mode != ERROR_MODE_JSON_RPC && _in_eval();

    # Report error into [$datadir/] params.error_log if requested
    if (($mode == ERROR_MODE_DIE || !$do_die) &&
        (my $logfile = Bugzilla->params->{error_log}))
    {
        $logfile = bz_locations()->{datadir} . '/' . $logfile if substr($logfile, 0, 1) ne '/';
        my $fd;
        # If we can write into error log, log error details there
        if (open $fd, ">>", $logfile)
        {
            print $fd (("-" x 75) . "\n" . ($msg ||= _error_message($type, $error, $vars)) . "\n");
            close $fd;
        }
    }

    # If we are within an eval(), do not do anything more
    # as we are eval'uating some test on purpose.
    if ($do_die)
    {
        die bless { message => ($msg ||= _error_message($type, $error, $vars)), type => $type, error => $error, vars => $vars };
    }

    # Make sure any transaction is rolled back (if supported).
    my $dbh = Bugzilla->dbh;
    $dbh->bz_rollback_transaction() if $dbh->bz_in_transaction();

    my $message;
    unless (Bugzilla->template->process("global/$type-error.html.tmpl", $vars, \$message))
    {
        # A template error occurred during reporting the error...
        $message = Bugzilla->template->error() . ' during reporting ' . uc($type) . ' error ' . $error;
        $vars = {
            nested_error       => $vars,
            error              => 'template_error',
            template_error_msg => $message,
        };
        if ($type ne 'code' || $error ne 'template_error')
        {
            _throw_error('code', 'template_error', $vars);
        }
        # If we failed processing template error, just die
        die bless { message => ($msg ||= _error_message($type, $error, $vars)), type => $type, error => $error, vars => $vars };
    }

    # Report error to maintainer email if requested
    if (Bugzilla->params->{"report_${type}_errors_to_maintainer"})
    {
        # Don't call _error_message twice
        $msg ||= _error_message($type, $error, $vars);
        my $t =
            "From: ".Bugzilla->params->{mailfrom}."\n".
            "To: ".Bugzilla->params->{maintainer}."\n".
            "Subject: ".uc($type)." error $error\n".
            "X-Bugzilla-Type: ${type}error\n\n".
            $msg;
        MessageToMTA($t, 1);
    }

    if ($mode == ERROR_MODE_WEBPAGE)
    {
        if (Bugzilla->cgi->{_multipart_initialized})
        {
            Bugzilla->cgi->send_multipart_end();
            Bugzilla->cgi->send_multipart_start(
                -type => 'text/html',
                -content_disposition => 'inline',
            );
        }
        else
        {
            Bugzilla->cgi->send_header;
        }
        print $message;
    }
    elsif ($mode == ERROR_MODE_DIE_SOAP_FAULT || $mode == ERROR_MODE_JSON_RPC)
    {
        # FIXME FIXME FIXME: Numeric error codes are UGLY!!!
        # But we can't change them without breaking the compatibility...
        # So we'll just use REST-XML for our APIs and screw SOAP and JSON-RPC.

        # Clone the hash so we aren't modifying the constant.
        my %error_map = %{ WS_ERROR_CODE() };
        eval
        {
            require Bugzilla::Hook;
            Bugzilla::Hook::process('webservice_error_codes',
                                    { error_map => \%error_map });
            my $code = $error_map{$error};
            if (!$code) {
                $code = ERROR_UNKNOWN_FATAL if $name =~ /code/i;
                $code = ERROR_UNKNOWN_TRANSIENT if $name =~ /user/i;
            }

            if (Bugzilla->error_mode == ERROR_MODE_DIE_SOAP_FAULT) {
                die SOAP::Fault->faultcode($code)->faultstring($message);
            }
            else {
                my $server = Bugzilla->_json_server;
                # Technically JSON-RPC isn't allowed to have error numbers
                # higher than 999, but we do this to avoid conflicts with
                # the internal JSON::RPC error codes.
                $server->raise_error(code    => 100000 + $code,
                                     message => $message);
                # We die with no message. JSON::RPC checks raise_error before
                # it checks $@, so it returns the proper error.
                die;
            }
        }
        else {
            my $server = Bugzilla->_json_server;
            # Technically JSON-RPC isn't allowed to have error numbers
            # higher than 999, but we do this to avoid conflicts with
            # the internal JSON::RPC error codes.
            $server->raise_error(code    => 100000 + $code,
                                 message => $message,
                                 id      => $server->{_bz_request_id},
                                 version => $server->version);
            # Most JSON-RPC Throw*Error calls happen within an eval inside
            # of JSON::RPC. So, in that circumstance, instead of exiting,
            # we die with no message. JSON::RPC checks raise_error before
            # it checks $@, so it returns the proper error.
            die if _in_eval();
            $server->response($server->error_response_header);
        }
    }
    elsif ($mode == ERROR_MODE_AJAX)
    {
        # JSON can't handle strings across lines.
        $message =~ s/\n/ /gm;
        my $err;
        $err->{'success'} = JSON::false;
        $err->{'error'} = $error;
        $err->{'message'} = $message;
        my $json = new JSON;
        Bugzilla->send_header;
        print $json->encode($err);
    }
    else
    {
        die "Fatal error: '$mode' is an unknown error reporting mode!";
    }
    exit;
}

sub ThrowUserError
{
    _throw_error('user', @_);
}

sub ThrowCodeError
{
    _throw_error('code', @_);
}

sub ThrowTemplateError
{
    my ($template_err) = @_;
    _throw_error('code', 'template_error', { template_error_msg => "$template_err" });
}

1;

__END__

=head1 NAME

Bugzilla::Error - Error handling utilities for Bugzilla

=head1 SYNOPSIS

  use Bugzilla::Error;

  ThrowUserError("error_tag",
                 { foo => 'bar' });

=head1 DESCRIPTION

Various places throughout the Bugzilla codebase need to report errors to the
user. The C<Throw*Error> family of functions allow this to be done in a
generic and localizable manner.

These functions automatically unlock the database tables, if there were any
locked. They will also roll back the transaction, if it is supported by
the underlying DB.

=head1 FUNCTIONS

=over 4

=item C<ThrowUserError>

This function takes an error tag as the first argument, and an optional hashref
of variables as a second argument. These are used by the
I<global/user-error.html.tmpl> template to format the error, using the passed
in variables as required.

=item C<ThrowCodeError>

This function is used when an internal check detects an error of some sort.
This usually indicates a bug in Bugzilla, although it can occur if the user
manually constructs urls without correct parameters.

This function's behaviour is similar to C<ThrowUserError>, except that the
template used to display errors is I<global/code-error.html.tmpl>. In addition
if the hashref used as the optional second argument contains a key I<variables>
then the contents of the hashref (which is expected to be another hashref) will
be displayed after the error message, as a debugging aid.

=item C<ThrowTemplateError>

This function should only be called if a C<template-<gt>process()> fails.
It tries another template first, because often one template being
broken or missing doesn't mean that they all are. But it falls back to
a print statement as a last-ditch error.

=back

=head1 SEE ALSO

L<Bugzilla|Bugzilla>
