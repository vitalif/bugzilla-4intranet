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

# No arguments. Returns all WBS, but without their TNERP_IDs.
sub get_values
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    return $self->SUPER::get_values($params);
}

# Add a WBS and a mapping TNERP_ID => OUR_ID. Arguments:
# tnerp_id  => <TN-ERP's ID for this WBS>
# value     => <WBS name>
# sortkey   => <number for sorting>
# isactive  => <is active? 1|0>
sub add_value
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    my $tnerp_id = delete $params->{tnerp_id};
    if (my $other_id = get_wbs_mapping($tnerp_id))
    {
        my $field = Bugzilla->get_field(CF_WBS);
        my $class = Bugzilla::Field::Choice->type($field);
        my $wbs = $class->new({ id => $other_id });
        if ($params->{value} ne $wbs->value ||
            $params->{sortkey} != $wbs->sortkey ||
            $params->{isactive} != $wbs->isactive)
        {
            ThrowUserError('value_mapping_already_exists', {
                value => $wbs->value,
                sortkey => $wbs->sortkey,
                isactive => $wbs->isactive,
                tnerp_id => $tnerp_id,
            });
        }
        else
        {
            ThrowUserError('value_already_exists');
        }
    }
    my $r = $self->SUPER::add_value($params);
    set_wbs_mapping($r->{id}, $tnerp_id) if $r->{id};
    return $r;
}

# Update a WBS identified by its TNERP_ID. Arguments:
# tnerp_id  => <TN-ERP's ID for this WBS>
#   (or old_value => <old value>)
# value     => <new value>
# sortkey   => <new sortkey>
# isactive  => <new isactive>
sub update_value
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    if ($params->{tnerp_id})
    {
        $params->{id} = get_wbs_mapping($params->{tnerp_id});
        $params->{id} || return { status => 'value_not_found' };
    }
    return $self->SUPER::update_value($params);
}

# Delete a WBS identified by its TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
sub delete_value
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    $params->{id} = get_wbs_mapping($params->{tnerp_id});
    delete_wbs_mapping($params->{tnerp_id});
    my $r = $self->SUPER::delete_value($params);
    return $r;
}

# Set visibility values (products in which WBS should be visible) by TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
# ids => [ visibility_ID, visibility_ID, ... ]
sub set_visibility_values
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    $params->{id} = get_wbs_mapping($params->{tnerp_id});
    return $self->SUPER::set_visibility_values($params);
}

# Update values massively (only sortkeys by now)
sub update_sortkeys
{
    my ($self, $params) = @_;
    my $updated = 0;
    for (keys %$params)
    {
        if (/^sortkey(\d+)$/so)
        {
            my $tnerp_id = $1;
            trick_taint($params->{$_});
            $updated += Bugzilla->dbh->do(
                "UPDATE cf_wbs w, tnerp_wbs_mapping m SET w.sortkey=?".
                " WHERE m.tnerp_id=? AND m.our_id=w.id", undef,
                $params->{$_}, $tnerp_id
            );
        }
    }
    return { status => 'ok', updated_rows => $updated };
}

1;
__END__
