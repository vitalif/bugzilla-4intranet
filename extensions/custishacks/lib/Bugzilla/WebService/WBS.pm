#!/usr/bin/perl
# Bugzilla::WebService::WBS - API for managing WBS values and ID mapping from TN-ERP
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::WBS;

use strict;
use Bugzilla::Error;
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::WebService::Util qw(validate);
use base qw(Bugzilla::WebService::Field Exporter);

use Bugzilla::SmMapping;

# No arguments. Returns all WBS along with their TNERP_IDs.
sub get_values
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    my $r = $self->SUPER::get_values($params);
    my $mappings = { map { ($_->{our_id} => $_->{tnerp_id}) } @{ get_wbs_mappings() } };
    for (@{$r->{values}})
    {
        $_->{tnerp_id} = $mappings->{$_->{id}};
    }
    return $r;
}

# Add a WBS with mapping TNERP_ID => OUR_ID.
#
# Arguments:
#   tnerp_id  => <TN-ERP's ID for this WBS>
#   value     => <WBS name>
#   sortkey   => <number for sorting>
#   isactive  => <is active? 1|0>
#   syncing   => <should be synced with dotProject? 1|0>
# Errors:
#   different_value_has_this_id
#     WE'VE LOST SYNC, there is a different value with this ID
#   value_already_exists
#     SYNC IS OK, same id has same value, but different parameters, please update_value
sub add_value
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    my $tnerp_id = delete $params->{tnerp_id};
    if (my $map = get_wbs_mapping($tnerp_id))
    {
        my $field = Bugzilla->get_field(CF_WBS);
        my $class = Bugzilla::Field::Choice->type($field);
        my $wbs = $class->new({ id => $map->{our_id} });
        if ($params->{value} ne $wbs->name)
        {
            ThrowUserError('different_value_has_this_id', {
                value => $wbs->name,
                sortkey => $wbs->sortkey,
                isactive => $wbs->is_active,
                tnerp_id => $tnerp_id,
                syncing => $map->{syncing},
            });
        }
        elsif ($params->{sortkey} != $wbs->sortkey ||
            $params->{isactive} != $wbs->is_active ||
            $params->{syncing} != $map->{syncing})
        {
            ThrowUserError('value_already_exists');
        }
        else
        {
            return {
                status => 'ok',
                id => $wbs->id,
            };
        }
    }
    my $r = $self->SUPER::add_value($params);
    if ($r->{id})
    {
        add_wbs_mapping({
            tnerp_id => $tnerp_id,
            our_id   => $r->{id},
            syncing  => $params->{syncing} ? 1 : 0,
        });
    }
    return $r;
}

# Decorate parameters for adding/updating/deleting WBS
sub _tnerp_id_param
{
    my ($params) = @_;
    $params->{field} = CF_WBS;
    if ($params->{tnerp_id})
    {
        $params->{id} = get_wbs_mapping($params->{tnerp_id});
        if ($params->{id})
        {
            if ($params->{syncing} eq $params->{id}->{syncing})
            {
                $params->{syncing} = undef;
            }
            $params->{id} = $params->{id}->{our_id};
        }
        else
        {
            return 0;
        }
    }
    return 1;
}

# Update a WBS identified by its TNERP_ID. Arguments:
# tnerp_id  => <TN-ERP's ID for this WBS>
#   (or old_value => <old value>)
# value     => <new value>
# sortkey   => <new sortkey>
# isactive  => <new isactive>
# syncing   => <new syncing flag>
sub update_value
{
    my ($self, $params) = @_;
    _tnerp_id_param($params) || return { status => 'value_not_found' };
    my $r = $self->SUPER::update_value($params);
    if ($r->{id} && defined $params->{syncing})
    {
        set_wbs_syncing($r->{id}, $params->{syncing});
    }
    return $r;
}

# Delete a WBS identified by its TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
sub delete_value
{
    my ($self, $params) = @_;
    _tnerp_id_param($params) || return { status => 'value_not_found' };
    my $r = $self->SUPER::delete_value($params);
    delete_wbs_mapping($params->{tnerp_id});
    return $r;
}

# Set visibility values (products in which WBS should be visible) by TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
# ids => [ visibility_ID, visibility_ID, ... ]
sub set_visibility_values
{
    my ($self, $params) = @_;
    _tnerp_id_param($params) || return { status => 'value_not_found' };
    return $self->SUPER::set_visibility_values($params);
}

# Update values massively (only sortkeys by now)
sub update_sortkeys
{
    my ($self, $params) = @_;
    my $updated = 0;
    my $ok = 0;
    my $failed = [];
    for (keys %$params)
    {
        if (/^sortkey(\d+)$/so)
        {
            my $tnerp_id = $1;
            trick_taint($params->{$_});
            $ok = Bugzilla->dbh->do(
                "UPDATE cf_wbs w, tnerp_wbs_mapping m SET w.sortkey=?".
                " WHERE m.tnerp_id=? AND m.our_id=w.id", undef,
                $params->{$_}, $tnerp_id
            );
            $updated += $ok;
            if (!$ok)
            {
                push @$failed, $tnerp_id;
            }
        }
    }
    return { status => 'ok', updated_rows => $updated, failed_ids => $failed };
}

1;
__END__
