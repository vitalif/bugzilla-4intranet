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
use Carp;
use Data::Dumper;

# Construct an SM/dotProject WS client
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my $cli = SOAP::Lite->service(Bugzilla->params->{sm_dotproject_wsdl_url});
    my $self = bless { client => $cli }, $class;
    my $r = $self->call(1, 'OpenSession',
        Bugzilla->params->{sm_dotproject_login},
        Bugzilla->params->{sm_dotproject_password},
    );
    my $data = xml_simple($r->{Data});
    if (!$data->{eSessionID})
    {
        die "No <SessionID> in SM WS answer data: $r->{Data}";
    }
    $self->{sid} = $data->{eSessionID}->[0]->{char};
    return $self;
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
    my ($self, $r, $skipFrames) = @_;
    if ($r->{Status}->{ErrorCode})
    {
        local $Carp::CarpLevel = $skipFrames || 1;
        local $Data::Dumper::Indent = 0;
        Carp::confess(
            "SM WS returned error #$r->{Status}->{ErrorCode}: $r->{Status}->{Message}\n".
            "(in response to $self->{lastFn}(".substr(Dumper($self->{lastParams}), 8, -1)."))\n"
        );
    }
}

# Wrapper for $self->{client}->call
sub call
{
    my ($self, $check_err, $fn, @params) = @_;
    $self->{lastFn} = $fn;
    $self->{lastParams} = \@params;
    my $r = $self->{client}->call($fn, @params);
    if ($check_err)
    {
        $self->check_ws_error($r, 2);
    }
    return $r;
}

# Read task with all attributes
sub read_task
{
    my ($self, $taskUID) = @_;
    my $r = $self->call(0, 'ReadTask', $self->{sid}, $taskUID, [])->result;
    if ($r->{Status}->{ErrorCode} &&
        $r->{Status}->{Message} =~ /Неверный идентификатор задачи/s)
    {
        # The task does not exist
        return undef;
    }
    $self->check_ws_error($r);
    my $data = xml_simple($r->{Data});
    my $task = {};
    foreach (@{$data->{eFieldList}->[0]->{eField}})
    {
        $task->{$_->{eName}->[0]->{char}} = $_->{eValue}->[0]->{char};
    }
    return $task;
}

# Convert hash to SOAP::Data with associative array named $soapname
# If $keys is an arrayref, select only that keys from the hash
# Default $soapname is FieldList
sub hash_to_soapdata
{
    my ($hash, $keys, $soapname) = @_;
    $soapname ||= 'FieldList';
    $keys ||= [ sort keys %$hash ];
    return SOAP::Data->name($soapname =>
        map { \SOAP::Data->value(
            SOAP::Data->name(Name => $_),
            SOAP::Data->name(Value => $hash->{$_})
        ) } @$keys
    );
}

# Create a task (if it doesn't exist) or update it (if it already exists). Arguments:
#  TaskCUID: task id (prefix + bug id)
#  TaskBUID: TN-ERP's WBS id
#  ComponentUID: component id
#  Name: bug title
#  Description: bug description
#  Owner: bug assignee
#  State: translated bug status+resolution
#  Release: bug target milestone
# ProjectUID will be fetched from parent task's ProjectUID.
sub create_or_update
{
    my ($self, $params) = @_;
    $params->{ZISTaskClass} = 'class_3';
    my $fieldNames = [ qw(Name Description State Release ZISTaskClass) ];
    my $req = {
        SessionID    => $self->{sid},
        TaskUID      => $params->{TaskCUID},
        ParentUID    => $params->{TaskBUID},
        ComponentUID => $params->{ComponentUID},
        FieldList    => hash_to_soapdata($params, $fieldNames),
    };
    # First check if the task does exist
    my $taskC = $self->read_task($req->{TaskUID});
    my $r;
    if (!$taskC)
    {
        # The task does not exist, create it
        my $taskB = $self->read_task($params->{TaskBUID});
        if (!defined $taskB)
        {
            die("Task B with UID=$params->{TaskBUID} does not exist");
        }
        if (!defined $taskB->{ProjectUID})
        {
            die("No <ProjectUID> field in SM WS ReadTask() answer data:\n" .
                join "\n", map { "$_ => $taskB->{$_}" } keys %$taskB);
        }
        # Add Owner field from the parent task
        $req->{FieldList}->value($req->{FieldList}->value, \SOAP::Data->value(
            SOAP::Data->name(Name => 'Owner'),
            SOAP::Data->name(Value => $taskB->{Owner})
        ));
        $req->{ProjectUID} = $taskB->{ProjectUID};
        # Create task
        $r = $self->call(1, 'CreateTask',
            @$req{qw(SessionID ProjectUID TaskUID ParentUID ComponentUID FieldList)}
        )->result;
    }
    else
    {
        # Check if we need to change any updatable fields
        if (grep { $params->{$_} ne $taskC->{$_} } @$fieldNames)
        {
            $r = $self->call(1, 'UpdateTask',
                @$req{qw(SessionID TaskUID ComponentUID FieldList)}
            )->result;
        }
        # Check if we need to change ParentUID via a separate call to ChangeTaskB
        if ($params->{TaskBUID} ne $taskC->{ParentUID})
        {
            $r = $self->call(1, 'ChangeTaskB',
                @$req{qw(SessionID TaskUID ParentUID)}
            )->result;
        }
    }
}

1;
__END__
