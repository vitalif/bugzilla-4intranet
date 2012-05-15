#!/usr/bin/perl
# SOAP client wrapper class for SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

# FIXME :-X there is no usable WSDL client in perl for RPC
# encoded WS which takes named parameters... O_o
# SOAP::Lite only takes positional parameters
# SOAP::WSDL doesn't work with WSDL definitions like attributeGroup
# XML::Compile::SOAP 2.26 doesn't work with rpc/encoded
# XML::Compile::SOAP 0.78 wants rpcin/rpcout and requires older XML::Compile

# Soooooo... We use positional parameters...

package Bugzilla::SmClient;

use utf8;
use strict;
use Bugzilla::Util;
use Bugzilla::Error;
use SOAP::Lite;

# Construct an SM/dotProject WS client
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my $cli = SOAP::Lite->service(Bugzilla->params->{sm_dotproject_wsdl_url});
    my $r = $cli->OpenSession(
        Bugzilla->params->{sm_dotproject_login},
        Bugzilla->params->{sm_dotproject_password},
    );
    check_ws_error($r);
    my $data = xml_simple($r->{Data});
    if (!$data->{eSessionID})
    {
        ThrowUserError('sm_ws_invalid_data', { data => $r->{Data} });
    }
    return bless {
        sid => $data->{eSessionID}->[0]->{char},
        client => $cli,
    }, $class;
}

# Destructor, closes the session
sub DESTROY
{
    my $self = shift;
    $self->{client}->CloseSession($self->{sid});
}

# Check for SM WS error and throw 'sm_ws_error' if there is one
sub check_ws_error
{
    my ($r) = @_;
    if ($r->{Status}->{ErrorCode})
    {
        ThrowUserError('sm_ws_error', {
            code => $r->{Status}->{ErrorCode},
            message => $r->{Status}->{Message},
        });
    }
}

# Create a task (if it doesn't exist) or update it (if it already exists). Arguments:
#  TaskCUID: task id (prefix + bug id)
#  TaskBUID: TN-ERP's WBS id
#  ComponentUID: component id
#  Name: bug title
#  Description: bug description
#  Owner: bug assignee
#  Status: translated bug status+resolution
#  Release: bug target milestone
# ProjectUID will be fetched from parent task's ProjectUID.
sub create_or_update
{
    my ($self, $params) = @_;
    # First try to update task
    my $req = {
        SessionID    => $self->{sid},
        TaskUID      => $params->{TaskCUID},
        ParentUID    => $params->{TaskBUID},
        ComponentUID => $params->{ComponentUID},
        FieldList    => SOAP::Data->name('FieldList' =>
            \SOAP::Data->value(
                SOAP::Data->name('Field' =>
                    map { \SOAP::Data->value(
                        SOAP::Data->name(Name => $_),
                        SOAP::Data->name(Value => $params->{$_})
                    ) } qw(Name Description Owner Status Release)
                )
            )
        ),
    };
    my $r = $self->{client}->call('UpdateTask',
        @$req{qw(SessionID TaskUID ParentUID ComponentUID FieldList)}
    )->result;
    # If the task does not exist, create it
    if ($r->{Status}->{ErrorCode} &&
        $r->{Status}->{Message} =~ /Неверный идентификатор задачи/s)
    {
        # Fetch ProjectUID from the parent task
        $r = $self->{client}->ReadTask(
            $self->{sid},
            $params->{TaskBUID},
            [],
        );
        check_ws_error($r);
        my $data = xml_simple($r->{Data});
        my $project;
        foreach (@{$data->{eRecord}->[0]->{eField}})
        {
            if ($_->{eName}->[0]->{char} eq 'ProjectUID')
            {
                $project = $_->{eValue}->[0]->{char};
            }
        }
        if (!defined $project)
        {
            ThrowUserError('sm_ws_invalid_data', { data => $r->{Data} });
        }
        $req->{ProjectUID} = $project;
        # Create task
        $r = $self->{client}->CreateTask(
            @$req{qw(SessionID ProjectUID TaskUID ParentUID ComponentUID FieldList)}
        )->result;
    }
    check_ws_error($r);
}

1;
__END__
