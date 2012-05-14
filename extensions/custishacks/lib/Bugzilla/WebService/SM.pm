#!/usr/bin/perl
# Bugzilla web-service for integration with SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::SM;

use utf8;
use strict;
use base qw(Bugzilla::WebService);

use Bugzilla::SmMapping;

# DIRTY hack for disabling bug status validation... :-X
sub _hack_bug_status
{
    my ($invocant, $new_status) = @_;
    my $new_status = Bugzilla::Status->check($new_status) unless ref $new_status;
    return $new_status->name if ref $invocant;
    return ($new_status->name, $new_status->name eq 'UNCONFIRMED' ? 0 : 1);
}

# Create bug as a "Task C" (SM terms). Arguments:
#  TaskBUID: TN-ERP's ID of bug WBS.
#  ComponentUID: Bug component ID.
#  Name: Bug title.
#  Description: Bug description.
#  Owner: Assignee email.
#  Status: One of 'In progress', 'Draft', 'Postponed', 'Cancelled', 'Complete'. Maps to bug status+resolution.
# Returns:
#  TaskСUID = Bug ID
sub CreateTaskC
{
    my ($self, $params) = @_;
    local *Bugzilla::Bug::_check_bug_status = *_hack_bug_status;
    local $Bugzilla::SmMapping::InWS = 1;
    my $component = Bugzilla::Component->match({ id => $params->{ComponentUID} });
    $component = $component->[0] || ThrowUserError('unknown_component');
    my $wbs = get_wbs($params->{TaskBUID});
    my $version = $component->default_version;
    $version ||= $component->product->versions->[0];
    my ($st, $res) = map_status_to_bz($params, 1);
    my $bug = Bugzilla::Bug->create({
        product     => $component->product->name,
        component   => $component->name,
        assigned_to => $params->{Owner},
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
#  Status: dotProject's status.
# Returns nothing.
sub UpdateTaskC
{
    my ($self, $params) = @_;
    local *Bugzilla::Bug::_check_bug_status = *_hack_bug_status;
    local $Bugzilla::SmMapping::InWS = 1;
    my $bug = Bugzilla::Bug->new({ id => $params->{TaskCUID}, for_update => 1 });
    $bug || return { status => 'task_c_not_found' };
    Bugzilla->user->can_edit_bug($bug, THROW_ERROR);
    my $component = Bugzilla::Component->match({ id => $params->{ComponentUID} });
    $component = $component->[0] || ThrowUserError('unknown_component');
    my $wbs = get_wbs($params->{TaskBUID});
    $bug->set_summary($params->{Name});
    $bug->comments;
    $bug->set_custom_field(Bugzilla->get_field(CF_WBS), $wbs->name);
    if ($component->id ne $bug->component_id)
    {
        $bug->set_product($component->product->name);
        $bug->set_component($component->name);
    }
    my ($st, $res) = map_status_to_bz($params, 1);
    if ($st ne $bug->bug_status || $res ne $bug->resolution)
    {
        $bug->set_status($st, { resolution => $res });
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
