# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# Contributor(s): Tiago R. Mello <timello@async.com.br>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::Version;

use base qw(Bugzilla::Field::Choice);

use Bugzilla::Install::Util qw(vers_cmp);
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Error;

################################
#####   Initialization     #####
################################

use constant DB_TABLE => 'versions';
use constant FIELD_NAME => 'version';

use constant NAME_FIELD => 'value';
# This is "id" because it has to be filled in and id is probably the fastest.
# We do a custom sort in _do_list_select below.
use constant LIST_ORDER => 'id';
use constant CUSTOM_SORT => 1;

use constant DB_COLUMNS => qw(
    id
    value
    product_id
    isactive
);

use constant REQUIRED_CREATE_FIELDS => qw(
    name
    product
);

use constant UPDATE_COLUMNS => qw(
    value
    isactive
);

use constant VALIDATORS => {
    product => \&_check_product,
    isactive => \&Bugzilla::Object::check_boolean,
};

use constant UPDATE_VALIDATORS => {
    value => \&_check_value,
};

################################
# Methods
################################

sub new {
    my $class = shift;
    my $param = shift;
    my $dbh = Bugzilla->dbh;

    my $product;
    if (ref $param) {
        $product = $param->{product};
        my $name = $param->{name};
        if (!defined $product) {
            ThrowCodeError('bad_arg',
                {argument => 'product',
                 function => "${class}::new"});
        }
        if (!defined $name) {
            ThrowCodeError('bad_arg',
                {argument => 'name',
                 function => "${class}::new"});
        }

        my $condition = 'product_id = ? AND value = ?';
        my @values = ($product->id, $name);
        $param = { condition => $condition, values => \@values };
    }

    unshift @_, $param;
    return $class->SUPER::new(@_);
}

sub _do_list_select {
    my $self = shift;
    my $list = $self->SUPER::_do_list_select(@_);
    return [sort { vers_cmp(lc($a->{value}), lc($b->{value})) } @$list];
}

sub run_create_validators {
    my $class  = shift;
    my $params = $class->SUPER::run_create_validators(@_);

    my $product = delete $params->{product};
    $params->{product_id} = $product->id;
    $params->{value} = $class->_check_value($params->{name}, $product);
    delete $params->{name};

    return $params;
}

sub bug_count
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!defined $self->{bug_count})
    {
        $self->{bug_count} = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM bugs WHERE product_id = ? AND version = ?",
            undef, ($self->product_id, $self->id)
        ) || 0;
    }
    return $self->{bug_count};
}

sub create
{
    my $class = shift;
    my ($params) = @_;
    my $self = $class->SUPER::create($params);
    if ($self)
    {
        # Fill visibility values
        $self->set_visibility_values([ $self->product_id ]);
        Bugzilla->get_field(FIELD_NAME)->touch;
    }
    return $self;
}

sub update
{
    my $self = shift;

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    my ($changes, $old_self) = Bugzilla::Object::update($self, @_);

    # Fill visibility values
    $self->set_visibility_values([ $self->product_id ]);

    Bugzilla->get_field(FIELD_NAME)->touch;

    $dbh->bz_commit_transaction();

    return $changes;
}

###############################
#####     Accessors        ####
###############################

sub product_id { return $_[0]->{product_id}; }
sub is_active  { return $_[0]->{isactive};   }

sub product {
    my $self = shift;

    require Bugzilla::Product;
    $self->{'product'} ||= new Bugzilla::Product($self->product_id);
    return $self->{'product'};
}

################################
# Validators
################################

sub set_name { $_[0]->set('value', $_[1]); }
sub set_is_active { $_[0]->set('isactive', $_[1]); }

sub _check_value {
    my ($invocant, $name, $product) = @_;

    $name = trim($name);
    $name || ThrowUserError('version_blank_name');
    # Remove unprintable characters
    $name = clean_text($name);

    ThrowUserError('fieldvalue_name_too_long', { value => $name })
        if length($name) > MAX_FIELD_VALUE_SIZE;

    $product = $invocant->product if (ref $invocant);
    my $version = new Bugzilla::Version({ product => $product, name => $name });
    if ($version && (!ref $invocant || $version->id != $invocant->id)) {
        ThrowUserError('version_already_exists', { name    => $version->name,
                                                   product => $product->name });
    }
    return $name;
}

sub _check_product {
    my ($invocant, $product) = @_;
    return Bugzilla->user->check_can_admin_product($product->name);
}

1;

__END__

=head1 NAME

Bugzilla::Version - Bugzilla product version class.

=head1 SYNOPSIS

    use Bugzilla::Version;

    my $version = new Bugzilla::Version({ name => $name, product => $product });

    my $value = $version->name;
    my $product_id = $version->product_id;
    my $product = $version->product;

    my $version = Bugzilla::Version->create(
        { name => $name, product => $product });

    $version->set_name($new_name);
    $version->update();

    $version->remove_from_db;

=head1 DESCRIPTION

Version.pm represents a Product Version object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

The methods that are specific to C<Bugzilla::Version> are listed
below.

=head1 METHODS

=over

=item C<bug_count()>

 Description: Returns the total of bugs that belong to the version.

 Params:      none.

 Returns:     Integer with the number of bugs.

=back

=cut
