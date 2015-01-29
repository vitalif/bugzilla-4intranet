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

package Bugzilla::Milestone;

use base qw(Bugzilla::Field::Choice);

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Error;

################################
#####    Initialization    #####
################################

use constant DEFAULT_SORTKEY => 0;

use constant DB_TABLE => 'milestones';
use constant FIELD_NAME => 'target_milestone';

use constant NAME_FIELD => 'value';
use constant LIST_ORDER => 'product_id, sortkey, value';

use constant DB_COLUMNS => qw(
    id
    value
    product_id
    sortkey
    isactive
);

use constant REQUIRED_CREATE_FIELDS => qw(
    name
    product
);

use constant UPDATE_COLUMNS => qw(
    value
    sortkey
    isactive
);

use constant VALIDATORS => {
    product => \&_check_product,
    sortkey => \&_check_sortkey,
    isactive => \&Bugzilla::Object::check_boolean,
};

use constant UPDATE_VALIDATORS => {
    value => \&_check_value,
};

################################

sub new
{
    my $class = shift;
    my $param = shift;
    my $dbh = Bugzilla->dbh;

    my $product;
    if (ref $param)
    {
        $product = $param->{product};
        my $name = $param->{name};
        if (!defined $product)
        {
            ThrowCodeError('bad_arg', {
                argument => 'product',
                function => "${class}::new",
            });
        }
        if (!defined $name)
        {
            ThrowCodeError('bad_arg', {
                argument => 'name',
                function => "${class}::new",
            });
        }
        my $condition = 'product_id = ? AND value = ?';
        my @values = ($product->id, $name);
        $param = { condition => $condition, values => \@values };
    }

    unshift @_, $param;
    return $class->SUPER::new(@_);
}

sub run_create_validators
{
    my $class  = shift;
    my $params = $class->SUPER::run_create_validators(@_);

    my $product = delete $params->{product};
    $params->{product_id} = $product->id;
    $params->{value} = $class->_check_value($params->{name}, $product);
    delete $params->{name};

    return $params;
}

sub create
{
    my $class = shift;
    my ($params) = @_;
    if ($params->{name} =~ /^-*$/s)
    {
        ThrowUserError('milestone_blank_name', $params);
    }
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

################################
# Validators
################################

sub _check_value
{
    my ($invocant, $name, $product) = @_;
    $name = trim($name);
    $name || ThrowUserError('milestone_blank_name');
    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError('milestone_name_too_long', {name => $name});
    }
    $product = $invocant->product if (ref $invocant);
    my $milestone = new Bugzilla::Milestone({product => $product, name => $name});
    if ($milestone && (!ref $invocant || $milestone->id != $invocant->id))
    {
        ThrowUserError('milestone_already_exists', {
            name    => $milestone->name,
            product => $product->name,
        });
    }
    return $name;
}

sub _check_sortkey
{
    my ($invocant, $sortkey) = @_;
    # Keep a copy in case detaint_signed() clears the sortkey
    my $stored_sortkey = $sortkey;
    if (!detaint_signed($sortkey) || $sortkey < MIN_SMALLINT || $sortkey > MAX_SMALLINT)
    {
        ThrowUserError('milestone_sortkey_invalid', {sortkey => $stored_sortkey});
    }
    return $sortkey;
}

sub _check_product
{
    my ($invocant, $product) = @_;
    return Bugzilla->user->check_can_admin_product($product->name);
}

################################
# Methods
################################

sub set_name { $_[0]->set('value', $_[1]); }
sub set_sortkey { $_[0]->set('sortkey', $_[1]); }
sub set_is_active { $_[0]->set('isactive', $_[1]); }

sub bug_count
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!defined $self->{bug_count})
    {
        $self->{bug_count} = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM bugs WHERE product_id = ? AND target_milestone = ?",
            undef, $self->product_id, $self->id
        ) || 0;
    }
    return $self->{bug_count};
}

################################
#####      Accessors      ######
################################

sub name       { return $_[0]->{value};      }
sub product_id { return $_[0]->{product_id}; }
sub sortkey    { return $_[0]->{sortkey};    }
sub is_active  { return $_[0]->{isactive};   }

sub product
{
    my $self = shift;
    require Bugzilla::Product;
    $self->{product} ||= new Bugzilla::Product($self->product_id);
    return $self->{product};
}

1;

__END__

=head1 NAME

Bugzilla::Milestone - Bugzilla product milestone class.

=head1 SYNOPSIS

    use Bugzilla::Milestone;

    my $milestone = new Bugzilla::Milestone({ name => $name, product => $product });

    my $name       = $milestone->name;
    my $product_id = $milestone->product_id;
    my $product    = $milestone->product;
    my $sortkey    = $milestone->sortkey;

    my $milestone = Bugzilla::Milestone->create(
        { name => $name, product => $product, sortkey => $sortkey });

    $milestone->set_name($new_name);
    $milestone->set_sortkey($new_sortkey);
    $milestone->update();

    $milestone->remove_from_db;

=head1 DESCRIPTION

Milestone.pm represents a Product Milestone object.

=head1 METHODS

=over

=item C<new({name => $name, product => $product})>

 Description: The constructor is used to load an existing milestone
              by passing a product object and a milestone name.

 Params:      $product - a Bugzilla::Product object.
              $name - the name of a milestone (string).

 Returns:     A Bugzilla::Milestone object.

=item C<name()>

 Description: Name (value) of the milestone.

 Params:      none.

 Returns:     The name of the milestone.

=item C<product_id()>

 Description: ID of the product the milestone belongs to.

 Params:      none.

 Returns:     The ID of a product.

=item C<product()>

 Description: The product object of the product the milestone belongs to.

 Params:      none.

 Returns:     A Bugzilla::Product object.

=item C<sortkey()>

 Description: Sortkey of the milestone.

 Params:      none.

 Returns:     The sortkey of the milestone.

=item C<bug_count()>

 Description: Returns the total of bugs that belong to the milestone.

 Params:      none.

 Returns:     Integer with the number of bugs.

=item C<set_name($new_name)>

 Description: Changes the name of the milestone.

 Params:      $new_name - new name of the milestone (string). This name
                          must be unique within the product.

 Returns:     Nothing.

=item C<set_sortkey($new_sortkey)>

 Description: Changes the sortkey of the milestone.

 Params:      $new_sortkey - new sortkey of the milestone (signed integer).

 Returns:     Nothing.

=item C<update()>

 Description: Writes the new name and/or the new sortkey into the DB.

 Params:      none.

 Returns:     A hashref with changes made to the milestone object.

=item C<remove_from_db()>

 Description: Deletes the current milestone from the DB. The object itself
              is not destroyed.

 Params:      none.

 Returns:     Nothing.

=back

=head1 CLASS METHODS

=over

=item C<create({name => $name, product => $product, sortkey => $sortkey})>

 Description: Create a new milestone for the given product.

 Params:      $name    - name of the new milestone (string). This name
                         must be unique within the product.
              $product - a Bugzilla::Product object.
              $sortkey - the sortkey of the new milestone (signed integer)

 Returns:     A Bugzilla::Milestone object.

=back
