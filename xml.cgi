#!/usr/bin/perl -wT
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
# Contributor(s): Dawn Endico    <endico@mozilla.org>
#                 Terry Weissman <terry@mozilla.org>
#                 Gervase Markham <gerv@gerv.net>

use strict;

use lib qw(. lib);
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::WebService::Server::XMLSimple;

my $cgi = Bugzilla->cgi;

my $args = $cgi->Vars;
my $method = $args->{method};

sub addmsg
{
    my ($result, $message) = @_;
    if (ref $message && $message->isa('Bugzilla::Error'))
    {
        $result->{status} = $message->{error};
        $result->{error_data} = $message->{vars};
        delete $message->{vars}->{error};
    }
    else
    {
        $result->{message} = "$message";
    }
}

if (!$method)
{
    # Backward compatibility: redirect to show_bug.cgi?ctype=xml
    # Convert comma/space separated elements into separate params
    my @ids = ();

    if (defined $cgi->param('id')) {
        @ids = split (/[, ]+/, $cgi->param('id'));
    }

    my $ids = join('', map { $_ = "&id=" . $_ } @ids);

    print $cgi->redirect("show_bug.cgi?ctype=xml$ids");
}
else
{
    # Very simple "REST/XML-RPC" server:
    # Takes arguments from GET and POST parameters, returns XML.
    Bugzilla->error_mode(ERROR_MODE_DIE);
    Bugzilla->login;
    my ($service, $result);
    ($service, $method) = split /\./, $method;
    $service =~ s/[^a-z0-9]+//giso;
    if (!$Bugzilla::WebService::{$service.'::'} ||
        !$Bugzilla::WebService::{$service.'::'}->{'XMLSimple::'})
    {
        eval { require "Bugzilla/WebService/$service.pm" };
        if ($@)
        {
            $result = {
                status  => 'bad_service',
                service => $service,
                method  => $method,
            };
            addmsg($result, $@);
        }
        else
        {
            # This perversion is needed to override Bugzilla::WebService->type() method
            eval "\@Bugzilla::WebService::$service\::XMLSimple::ISA = qw(Bugzilla::WebService::Server::XMLSimple Bugzilla::WebService::$service)";
        }
    }
    if ($Bugzilla::WebService::{$service.'::'} &&
        $Bugzilla::WebService::{$service.'::'}->{'XMLSimple::'})
    {
        my $func_args = { %$args };
        delete $func_args->{method};
        my $pkg = 'Bugzilla::WebService::'.$service.'::XMLSimple';
        eval { $result = $pkg->$method($func_args) };
        if ($@)
        {
            $result = {
                status  => 'error',
                service => $service,
                method  => $method,
            };
            addmsg($result, $@);
        }
        else
        {
            $result->{status} ||= 'ok';
        }
    }
    # Send response
    Bugzilla->send_header(-type => 'text/xml'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : ''));
    print '<?xml version="1.0"'.(Bugzilla->params->{utf8} ? ' encoding="UTF-8"' : '').' ?>';
    print '<response>';
    print xml_dump_simple($result);
    print '</response>';
}
