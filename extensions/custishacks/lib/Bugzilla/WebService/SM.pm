#!/usr/bin/perl
# Bugzilla web-service for integration with SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::SM;

use utf8;
use strict;
use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::SmMapping;

# DIRTY hack for disabling bug status validation... :-X
sub _hack_bug_status
{
    my ($invocant, $new_status) = @_;
    my $new_status = Bugzilla::Status->check($new_status) unless ref $new_status;
    return $new_status->name if ref $invocant;
    return ($new_status->name, $new_status->name eq 'UNCONFIRMED' ? 0 : 1);
}

# Another dirty hack allowing to set any reporter
sub _hack_reporter
{
    my ($invocant, $reporter) = @_;
    return $reporter;
}

# Create bug as a "Task C" (SM terms). Arguments:
#  TaskBUID: TN-ERP's ID of bug WBS.
#  ComponentUID: Bug component ID.
#  Name: Bug title.
#  Description: Bug description.
#  Owner: Reporter email.
#  State: One of 'In progress', 'Draft', 'Postponed', 'Cancelled', 'Complete'. Maps to bug status+resolution.
# Returns:
#  TaskСUID = Bug ID
sub CreateTaskC
{
    my ($self, $params) = @_;
    local *Bugzilla::Bug::_check_bug_status = *_hack_bug_status;
    local *Bugzilla::Bug::_check_reporter = *_hack_reporter;
    local $Bugzilla::SmMapping::InWS = 1;
    my $component = Bugzilla::Component->match({ id => $params->{ComponentUID} });
    $component = $component->[0] || ThrowUserError('unknown_component');
    my $wbs = get_wbs($params->{TaskBUID});
    my $version = $component->default_version;
    $version ||= $component->product->versions->[0];
    my ($st, $res) = map_state_to_bz($params->{State}, 1);
    my $rep = Bugzilla::User->new({ name => lc $params->{Owner} });
    return { status => 'unknown_owner' } unless $rep;
    my $bug = Bugzilla::Bug->create({
        product     => $component->product->name,
        component   => $component->name,
        reporter    => $rep->id,
        short_desc  => $params->{Name},
        comment     => $params->{Description},
        CF_WBS()    => $wbs->name,
        version     => $version,
        bug_status  => $st,
        resolution  => $res,
    });
    return { status => 'ok', TaskCUID => $bug->id };
}

# Update bug as a "Task C" (SM terms). Arguments:
#  TaskCUID: Bug id.
#  TaskBUID: TN-ERP's ID of bug WBS.
#  ComponentUID: Bug component ID.
#  Name: Bug title.
#  State: dotProject's status.
# Returns nothing.
sub UpdateTaskC
{
    my ($self, $params) = @_;
    local *Bugzilla::Bug::_check_bug_status = *_hack_bug_status;
    local $Bugzilla::SmMapping::InWS = 1;
    my $bug = Bugzilla::Bug->new({ id => $params->{TaskCUID}, for_update => 1 });
    $bug || return { status => 'task_c_not_found' };
    Bugzilla->user->can_edit_bug($bug, THROW_ERROR);
    if (defined $params->{ComponentUID})
    {
        my $component = Bugzilla::Component->match({ id => $params->{ComponentUID} });
        $component = $component->[0] || ThrowUserError('unknown_component');
        if ($component->id ne $bug->component_id)
        {
            $bug->set_product($component->product->name);
            $bug->set_component($component->name);
        }
    }
    if (defined $params->{TaskBUID})
    {
        my $wbs = get_wbs($params->{TaskBUID});
        $bug->set_custom_field(Bugzilla->get_field(CF_WBS), $wbs->name);
    }
    if (defined $params->{Name})
    {
        $bug->set_summary($params->{Name});
    }
    if (defined $params->{State})
    {
        my ($st, $res) = map_state_to_bz($params->{State}, 1);
        if ($st ne $bug->bug_status || $res ne $bug->resolution)
        {
            $bug->set_status($st, { resolution => $res });
        }
    }
    $bug->update;
    return { status => 'ok' };
}

# Get values for a bug as a "Task C" (SM terms). Arguments:
#  TaskCUID: Bug id.
# Returns:
#  task: see Bugzilla::SmMapping::get_formatted_bugs
sub ReadTaskC
{
    my ($self, $params) = @_;
    my $r = get_formatted_bugs({ bug_id => $params->{TaskCUID} });
    @$r || return { status => 'task_c_not_found' };
    return { status => 'ok', task => $r->[0] };
}

# Get bug list by their WBS (task B in SM terms). Arguments:
#  TaskBUID: TN-ERP's ID of bug WBS.
# Returns:
#  tasks: [ bug_hash, ... ]
# bug_hash: see Bugzilla::SmMapping::get_formatted_bugs
sub FetchTaskC
{
    my ($self, $params) = @_;
    my $wbs = get_wbs($params->{TaskBUID});
    return { status => 'ok', tasks => get_formatted_bugs({ cf_wbs => $wbs->name }) };
}

1;
__END__
