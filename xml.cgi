#!/usr/bin/perl -wT
# REST-(XML/JSON) RPC interface (input as query parameters, output as xml or json)
# Catches all errors and reports them correctly in output!
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

# USAGE: xml.cgi?method={{method}}&output=(xml|json)&<param>=<value>&...
# FIXME: rename to rest.cgi

use strict;

use lib qw(. lib);
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::WebService::Server::XMLSimple;

my $args = Bugzilla->input_params;
my $method = $args->{method};

sub addmsg
{
    my ($result, $message) = @_;
    if (ref $message && $message->isa('Bugzilla::Error'))
    {
        $message->log;
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

    if (defined $args->{id}) {
        @ids = ref $args->{id} ? @{$args->{id}} : split(/[, ]+/, $args->{id});
    }

    my $ids = join('', map { $_ = "&id=" . $_ } @ids);

    print Bugzilla->cgi->redirect("show_bug.cgi?ctype=xml$ids");
}
else
{
    my ($service, $result);
    # Very simple "REST/XML-RPC" server:
    # Takes arguments from GET and POST parameters, returns XML.
    Bugzilla->usage_mode(USAGE_MODE_XMLRPC); # needed to catch login_required error
    Bugzilla->error_mode(ERROR_MODE_DIE);
    eval { Bugzilla->login(~LOGIN_REQUIRED); };
    if ($@)
    {
        # catch login_required error
        $result = {
            status  => 'error',
            service => $service,
            method  => $method,
        };
        addmsg($result, $@);
    }
    Bugzilla->usage_mode(USAGE_MODE_BROWSER);
    Bugzilla->error_mode(ERROR_MODE_DIE);
    ($service, $method) = split /\./, $method;
    $service =~ s/[^a-z0-9]+//giso;
    trick_taint($service);
    if (!$Bugzilla::WebService::{$service.'::'} ||
        !$Bugzilla::WebService::{$service.'::'}->{'XMLSimple::'})
    {
        $Bugzilla::Error::IN_EVAL++;
        eval { require "Bugzilla/WebService/$service.pm" };
        $Bugzilla::Error::IN_EVAL--;
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
    if (!$result && $Bugzilla::WebService::{$service.'::'} &&
        $Bugzilla::WebService::{$service.'::'}->{'XMLSimple::'})
    {
        my $func_args = { %$args };
        delete $func_args->{method};
        my $pkg = 'Bugzilla::WebService::'.$service.'::XMLSimple';
        $Bugzilla::Error::IN_EVAL++;
        # FIXME exported methods need prefix or other protection type!
        eval { $result = $pkg->$method($func_args) };
        $Bugzilla::Error::IN_EVAL--;
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
    if (!$args->{output} || lc $args->{output} ne 'json')
    {
        # XML output format
        Bugzilla->send_header(-type => 'text/xml'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : ''));
        print '<?xml version="1.0"'.(Bugzilla->params->{utf8} ? ' encoding="UTF-8"' : '').' ?>';
        print '<response>';
        print xml_dump_simple($result);
        print '</response>';
    }
    else
    {
        # JSON output format
        Bugzilla->send_header(-type => 'application/json'.(Bugzilla->params->{utf8} ? '; charset=utf-8' : ''));
        print bz_encode_json($result);
    }
}
