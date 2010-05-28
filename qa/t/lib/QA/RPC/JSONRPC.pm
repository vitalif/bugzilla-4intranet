# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::RPC::JSONRPC;
use strict;
use base qw(QA::RPC JSON::RPC::Client);

use constant TYPE => 'JSON-RPC';
use constant DATETIME_REGEX => qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;

#################################
# Consistency with XMLRPC::Lite #
#################################

sub ua {
    my $self = shift;
    if ($self->{ua} and not $self->{ua}->isa('QA::RPC::UserAgent')) {
        bless $self->{ua}, 'QA::RPC::UserAgent';
    }
    return $self->SUPER::ua(@_);
}
sub transport { $_[0]->ua }

sub call {
    my $self = shift;
    my ($method, $args) = @_;
    my %params = ( method => $method, params => [$args] );
    my $config = $self->bz_config;
    my $url = $config->{browser_url} . "/"
              . $config->{bugzilla_installation} . "/jsonrpc.cgi";
    my $result = $self->SUPER::call($url, \%params);
    if ($result) {
        bless $result, 'QA::RPC::JSONRPC::ReturnObject';
    }
    return $result;
}

1;

package QA::RPC::JSONRPC::ReturnObject;
use strict;
use JSON::RPC::Client;
use base qw(JSON::RPC::ReturnObject);

#################################
# Consistency with XMLRPC::Lite #
#################################

sub faultstring { $_[0]->{content}->{error}->{message} }
sub faultcode   { $_[0]->{content}->{error}->{code}    }
sub fault { $_[0]->is_error }

1;

package QA::RPC::UserAgent;
use strict;
use base qw(LWP::UserAgent);

########################################
# Consistency with XMLRPC::Lite's ->ua #
########################################

sub send_request {
    my $self = shift;
    my $response = $self->SUPER::send_request(@_);
    $self->http_response($response);
    return $response;
}

# Copied directly from SOAP::Lite::Transport::HTTP.
sub http_response {
    my $self = shift;
    if (@_) { $self->{'_http_response'} = shift; return $self }
    return $self->{'_http_response'};
}
