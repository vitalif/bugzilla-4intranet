#!/usr/bin/perl
# Bugzilla::WebService::WBS - API for managing WBS values and ID mapping from TN-ERP
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::WebService::WBS;

use strict;
use Bugzilla::Field::Choice;
use Bugzilla::User;
use Bugzilla::WebService::Util qw(validate);
use base qw(Bugzilla::WebService::Field);

use constant CF_WBS => 'cf_wbs';

# Get mapping tnerp_id -> ?
sub _get_mapping
{
    my ($tnerp_id) = @_;
    my ($our_id) = Bugzilla->dbh->selectrow_array(
        "SELECT our_id FROM tnerp_wbs_mapping WHERE tnerp_id=?",
        undef, $tnerp_id
    );
    return $our_id;
}

# Set mapping tnerp_id -> our_id
sub _set_mapping
{
    my ($our_id, $tnerp_id) = @_;
    Bugzilla->dbh->do(
        "INSERT INTO tnerp_wbs_mapping (our_id, tnerp_id) VALUES (?, ?)",
        undef, $our_id, $tnerp_id
    );
}

# Remove mapping tnerp_id -> ?
sub _delete_mapping
{
    my ($tnerp_id) = @_;
    Bugzilla->dbh->do("DELETE FROM tnerp_wbs_mapping WHERE tnerp_id=?", undef, $tnerp_id);
}

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
    my $r = $self->SUPER::add_value($params);
    _set_mapping($r->{id}, $tnerp_id) if $r->{id};
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
    $params->{id} = _get_mapping($params->{tnerp_id}) if $params->{tnerp_id};
    return $self->SUPER::update_value($params);
}

# Delete a WBS identified by its TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
sub delete_value
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    $params->{id} = _get_mapping($params->{tnerp_id});
    my $r = $self->SUPER::delete_value($params);
    _delete_mapping($params->{tnerp_id}) if $r->{status} eq 'ok';
    return $r;
}

# Set visibility values (products in which WBS should be visible) by TNERP_ID. Arguments:
# tnerp_id => <TN-ERP's ID for this WBS>
# ids => [ visibility_ID, visibility_ID, ... ]
sub set_visibility_values
{
    my ($self, $params) = @_;
    $params->{field} = CF_WBS;
    $params->{id} = _get_mapping($params->{tnerp_id});
    return $self->SUPER::set_visibility_values($params);
}

1;
__END__
