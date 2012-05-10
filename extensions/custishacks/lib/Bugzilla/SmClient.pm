#!/usr/bin/perl
# SOAP client wrapper class for SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::SmClient;

use utf8;
use strict;
use Bugzilla::Util;
use SOAP::WSDL;

# Construct an SM/dotProject WS client
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my $client = SOAP::WSDL->new(
        wsdl => Bugzilla->params->{sm_dotproject_wsdl_url},
    );
    my $r = $client->call('OpenSession', {
        Login => Bugzilla->params->{sm_dotproject_login},
        Password => Bugzilla->params->{sm_dotproject_password},
    });
    check_ws_error($r);
    my $data = xml_simple($r->{Data});
    if (!$data->{eSessionID})
    {
        ThrowUserError('sm_ws_invalid_data', { data => $r->{Data} });
    }
    return bless {
        sid => $data->{eSessionID},
        client => $client,
    }, $class;
}

# Destructor, closes the session
sub DESTROY
{
    my $self = shift;
    $self->{client}->call('CloseSession', { SessionID => $self->{sid} });
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
        FieldList    => {
            Field => [
                map { { Name => $_, Value => $params->{$_} } }
                qw(Name Description Owner Status Release)
            ],
        },
    };
    my $r = $self->{client}->call('UpdateTask', $req);
    # If the task does not exist, create it
    if ($r->{Status}->{ErrorCode} == 1) # FIXME what number?
    {
        # Fetch ProjectUID from the parent task
        $r = $self->{client}->call('ReadTask', {
            SessionID => $self->{sid},
            TaskUID   => $params->{TaskBUID},
            FieldList => [],
        });
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
        $r = $self->{client}->call('CreateTask', $req);
    }
    check_ws_error($r);
}

1;
__END__
