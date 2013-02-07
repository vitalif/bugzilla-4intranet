#!/usr/bin/perl
# Various mappings (bug fields, statuses, WBS IDs, etc) for integration with SM/dotProject
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::SmMapping;

use utf8;
use strict;
use base qw(Exporter);
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Search;

use constant CF_WBS => 'cf_wbs';

# 1 when we are inside SM webservice
our $InWS = 0;

our @EXPORT = qw(
    CF_WBS
    get_wbs_mapping
    get_wbs_mappings
    add_wbs_mapping
    set_wbs_syncing
    delete_wbs_mapping
    get_wbs
    map_state_to_bz
    map_bz_to_state
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

# Get mapping by tnerp_id or by our_id
# returns { tnerp_id => ?, our_id => ?, syncing => ? }
sub get_wbs_mapping
{
    my ($tnerp_id, $our_id) = @_;
    if (defined $tnerp_id && ($tnerp_id > 0x7fffffff || $tnerp_id !~ /^\d+$/s))
    {
        ThrowUserError('tnerp_mapping_id_invalid');
    }
    $tnerp_id ? trick_taint($tnerp_id) : trick_taint($our_id);
    my ($set, $other) = $tnerp_id ? ('tnerp_id', 'our_id') : ('our_id', 'tnerp_id');
    my $r = Bugzilla->dbh->selectall_arrayref(
        "SELECT * FROM tnerp_wbs_mapping WHERE $set=?",
        {Slice=>{}}, $tnerp_id||$our_id
    );
    return $r && $r->[0];
}

# Get all WBS mappings
sub get_wbs_mappings
{
    return Bugzilla->dbh->selectall_arrayref(
        "SELECT tnerp_id, our_id FROM tnerp_wbs_mapping", {Slice=>{}}
    ) || [];
}

# Add new WBS mapping
sub add_wbs_mapping
{
    my ($row) = @_;
    if ($row->{tnerp_id} > 0x7fffffff ||
        $row->{tnerp_id} < 1 ||
        $row->{tnerp_id} !~ /^\d+$/s)
    {
        ThrowUserError('tnerp_mapping_id_invalid');
    }
    trick_taint($row->{$_}) for keys %$row;
    Bugzilla->dbh->do(
        "INSERT INTO tnerp_wbs_mapping (our_id, tnerp_id, syncing) VALUES (?, ?, ?)",
        undef, @$row{qw(our_id tnerp_id syncing)}
    );
}

# Set syncing flag on a WBS by our_id
sub set_wbs_syncing
{
    my ($our_id, $syncing) = @_;
    Bugzilla->dbh->do(
        "UPDATE tnerp_wbs_mapping SET syncing=? WHERE our_id=?",
        undef, $syncing, $our_id
    );
}

# Remove mapping by tnerp_id
sub delete_wbs_mapping
{
    my ($tnerp_id) = @_;
    trick_taint($tnerp_id);
    Bugzilla->dbh->do("DELETE FROM tnerp_wbs_mapping WHERE tnerp_id=?", undef, $tnerp_id);
}

# Map SM state to Bugzilla (status, resolution)
sub map_state_to_bz
{
    my ($st, $create) = @_;
    if ($st eq 'In progress')
    {
        return ($create ? 'NEW' : 'REOPENED', '');
    }
    return ('CLOSED', $resolution{$st});
}

# Map Bugzilla (status, resolution) to SM state
sub map_bz_to_state
{
    my ($status, $resolution) = @_;
    if (!$resolution)
    {
        return 'In progress';
    }
    return $smstatus{$resolution};
}

# Get WBS object by TN-ERP ID or by name
sub get_wbs
{
    my ($tnerp_id, $value) = @_;
    my $field = Bugzilla->get_field(CF_WBS);
    my $class = Bugzilla::Field::Choice->type($field);
    my $map = $tnerp_id && get_wbs_mapping($tnerp_id);
    my $wbs = $map ? $class->new({ id => $map->{our_id} }) :
        ($value ? $class->new({ name => $value }) : undef);
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
        'fields' => [ qw(bug_id cf_wbs component_id short_desc comment0 reporter bug_status resolution target_milestone) ],
        'params' => Bugzilla::CGI->new($params),
        'order' => [ 'bug_id' ],
    );
    my $sql = $search->getSQL();
    my $bugs = Bugzilla->dbh->selectall_arrayref($sql, {Slice=>{}});
    # Format bugs
    my $wbs_id_cache = {};
    my $r = [];
    my $tnerp_id;
    foreach my $bug (@$bugs)
    {
        $tnerp_id = $wbs_id_cache->{$bug->{cf_wbs}};
        if (!$tnerp_id)
        {
            $tnerp_id = get_wbs_mapping(undef, get_wbs(undef, $bug->{cf_wbs})->id);
            if ($tnerp_id)
            {
                $tnerp_id = $tnerp_id->{tnerp_id};
                $wbs_id_cache->{$bug->{cf_wbs}} = $tnerp_id;
            }
        }
        my $state = map_bz_to_state($bug->{bug_status}, $bug->{resolution});
        push @$r, {
            TaskCUID     => $bug->{bug_id}, # FIXME append prefix to ID
            TaskBUID     => $tnerp_id, # FIXME will be undef when wbs is not found
            ComponentUID => $bug->{component_id},
            Name         => $bug->{short_desc},
            Description  => $bug->{comment0},
            Owner        => $bug->{reporter},
            State        => $state,
            Release      => $bug->{target_milestone},
        };
    }
    return $r;
}

1;
__END__
