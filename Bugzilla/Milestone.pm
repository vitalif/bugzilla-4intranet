# Bugzilla Milestone class based on GenericObject
# License: MPL 1.1
# Author(s): Vitaliy Filippov <vitalif@mail.ru>
#   Tiago R. Mello <timello@async.com.br>
#   Max Kanat-Alexander <mkanat@bugzilla.org>
#   Frédéric Buclin <LpSolit@gmail.com>

package Bugzilla::Milestone;

use strict;
use base qw(Bugzilla::GenericObject);

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Error;

use constant DB_TABLE => 'milestones';
use constant CLASS_NAME => 'milestone';
use constant NAME_FIELD => 'value';
use constant LIST_ORDER => 'product_id, sortkey, value';

use constant OVERRIDE_SETTERS => {
    value => \&_set_name,
    product_id => \&_set_product_id,
};

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

sub update
{
    my $self = shift;
    my $changes = $self->SUPER::update(@_);
    # Fill visibility values
    Bugzilla->get_field('target_milestone')->update_visibility_values($self->id, [ $self->product_id ]);
    return $changes;
}

sub bug_count
{
    my $self = shift;
    return Bugzilla->get_field('target_milestone')->count_value_objects($self->id);
}

################################
# Accessors
################################

sub is_active { $_[0]->isactive }
sub product { $_[0]->product_id_obj }

################################
# Validators
################################

sub _set_name
{
    my ($self, $name) = @_;
    $name = clean_text(trim($name)) || ThrowUserError('version_blank_name');
    ThrowUserError('fieldvalue_name_too_long', { value => $name })
        if length($name) > MAX_FIELD_VALUE_SIZE;
    my $version = Bugzilla::Version->new({ product => $self->product, name => $name });
    if ($version && $version->id != $self->id)
    {
        ThrowUserError('milestone_already_exists', {
            name    => $version->name,
            product => $self->product->name,
        });
    }
    return $name;
}

sub _set_product
{
    my ($self, $product) = @_;
    $self->{product_id_obj} = Bugzilla->user->check_can_admin_product($product->name);
    return $self->{product_id_obj}->id;
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

=item B<bug_count()>

 Returns the total number of bugs that belong to the milestone.

=back
