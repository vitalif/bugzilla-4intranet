#!/usr/bin/perl
# Various mappings (bug fields, statuses, WBS IDs, etc) for integration with SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::SmMapping;

use utf8;
use strict;
use base qw(Exporter);
use Bugzilla::Error;
use Bugzilla::Search;

use constant CF_WBS => 'cf_wbs';

our @EXPORT = qw(
    CF_WBS
    get_wbs_mapping
    set_wbs_mapping
    delete_wbs_mapping
    get_wbs
    map_status_to_bz
    map_bz_to_status
    get_formatted_bugs
);

my %resolution = (
    Postponed   => 'LATER',
    Cancelled   => 'WONTFIX',
    Complete    => 'FIXED',
);

my %smstatus = (
    LATER       => 'Postponed',
    WONTFIX     => 'Cancelled',
    INVALID     => 'Cancelled',
    REMIND      => 'Cancelled',
    DUPLICATE   => 'Cancelled',
    WORKSFORME  => 'Cancelled',
    FIXED       => 'Complete',
);

# Get mapping tnerp_id -> ? or our_id => ?
sub get_wbs_mapping
{
    my ($tnerp_id, $our_id) = @_;
    if (defined $tnerp_id && ($tnerp_id > 0x7fffffff || $tnerp_id !~ /^\d+$/s))
    {
        ThrowUserError('tnerp_mapping_id_invalid');
    }
    my ($set, $other) = $tnerp_id ? ('tnerp_id', 'our_id') : ('our_id', 'tnerp_id');
    my ($r) = Bugzilla->dbh->selectrow_array(
        "SELECT $other FROM tnerp_wbs_mapping WHERE $set=?",
        undef, $tnerp_id||$our_id
    );
    return $r;
}

# Set mapping tnerp_id -> our_id
sub set_wbs_mapping
{
    my ($our_id, $tnerp_id) = @_;
    if ($tnerp_id > 0x7fffffff || $tnerp_id !~ /^\d+$/s)
    {
        ThrowUserError('tnerp_mapping_id_invalid');
    }
    Bugzilla->dbh->do(
        "INSERT INTO tnerp_wbs_mapping (our_id, tnerp_id) VALUES (?, ?)",
        undef, $our_id, $tnerp_id
    );
}

# Remove mapping tnerp_id -> ?
sub delete_wbs_mapping
{
    my ($tnerp_id) = @_;
    Bugzilla->dbh->do("DELETE FROM tnerp_wbs_mapping WHERE tnerp_id=?", undef, $tnerp_id);
}

# Map SM (status, isclosed) to Bugzilla (status, resolution)
sub map_status_to_bz
{
    my ($params, $create) = @_;
    my $st = $params->{Status};
    if ($st eq 'In progress')
    {
        return ('ASSIGNED', '');
    }
    elsif ($st eq 'Draft')
    {
        return ($create ? 'NEW' : 'REOPENED', '');
    }
    return ($params->{Closed} ? 'CLOSED' : 'RESOLVED', $resolution{$st});
}

# Map Bugzilla (status, resolution) to SM (status, isclosed)
sub map_bz_to_status
{
    my ($status, $resolution) = @_;
    if ($status eq 'NEW' || $status eq 'REOPENED')
    {
        return ('Draft', 0);
    }
    elsif ($status eq 'ASSIGNED')
    {
        return ('In progress', 0);
    }
    return ($smstatus{$resolution}, $status eq 'CLOSED');
}

# Get WBS object by TN-ERP ID or by name
sub get_wbs
{
    my ($tnerp_id, $value) = @_;
    my $field = Bugzilla->get_field(CF_WBS);
    my $class = Bugzilla::Field::Choice->type($field);
    my $wbs_id = $tnerp_id && get_wbs_mapping($tnerp_id);
    my $wbs = $wbs_id ? $class->new({ id => $wbs_id }) : $class->new({ name => $value });
    if (!$wbs)
    {
        ThrowUserError('task_b_not_found');
    }
    return $wbs;
}

# Search for bugs based on $params and return them in SM format
sub get_formatted_bugs
{
    my ($params) = @_;
    # Trick Bugzilla::Search to include component_id column
    Bugzilla::Search::COLUMNS->{component_id} = {
        name => 'map_components.id',
        joins => [ "INNER JOIN components AS map_components ON bugs.component_id=map_components.id" ],
    };
    # Search for bugs
    my $search = Bugzilla::Search->new(
        'fields' => [ qw(bug_id cf_wbs component_id short_desc comment0 assigned_to bug_status resolution target_milestone) ],
        'params' => Bugzilla::CGI->new($params),
        'order' => [ 'bug_id' ],
    );
    my $sql = $search->getSQL();
    my $bugs = Bugzilla->dbh->selectall_arrayref($sql, {Slice=>{}});
    # Format bugs
    my $wbs_id_cache = {};
    my $r = [];
    foreach my $bug (@$bugs)
    {
        $wbs_id_cache->{$bug->{cf_wbs}} ||=
            get_wbs_mapping(undef, get_wbs(undef, $bug->{cf_wbs})->id);
        my ($status, $closed) = map_bz_to_status($bug->{bug_status}, $bug->{resolution});
        push @$r, {
            TaskCUID     => $bug->{bug_id}, # FIXME append prefix to ID
            TaskBUID     => $wbs_id_cache->{$bug->{cf_wbs}},
            ComponentUID => $bug->{component_id},
            Name         => $bug->{short_desc},
            Description  => $bug->{comment0},
            Owner        => $bug->{assigned_to},
            Status       => $status,
            Closed       => $closed,
            Release      => $bug->{target_milestone},
        };
    }
    return $r;
}

1;
__END__
