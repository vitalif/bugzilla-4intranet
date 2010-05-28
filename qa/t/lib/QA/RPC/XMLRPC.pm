# -*- Mode: perl; indent-tabs-mode: nil -*-

package QA::RPC::XMLRPC;
use strict;
use base qw(QA::RPC XMLRPC::Lite);

use constant TYPE => 'XML-RPC';
use constant DATETIME_REGEX => qr/^\d{8}T\d\d:\d\d:\d\d$/;

1;

__END__
