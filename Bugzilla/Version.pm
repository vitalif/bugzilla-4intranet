# License: MPL 1.1
# Author(s): Vitaliy Filippov <vitalif@mail.ru>
#   Tiago R. Mello <timello@async.com.br>
#   Max Kanat-Alexander <mkanat@bugzilla.org>
#   Frédéric Buclin <LpSolit@gmail.com>

package Bugzilla::Version;

use strict;
use base qw(Bugzilla::GenericObject);

use Bugzilla::Install::Util qw(vers_cmp);
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Constants;
use Bugzilla::Error;

use constant DB_TABLE => 'versions';
use constant CLASS_NAME => 'version';
use constant NAME_FIELD => 'value';
# This is "id" because it has to be filled in and id is probably the fastest.
# We do a custom sort in _do_list_select below.
use constant LIST_ORDER => 'id';
use constant CUSTOM_SORT => 1;

use constant OVERRIDE_SETTERS => {
    value => \&_set_name,
    product_id => \&_set_product_id,
    sortkey => \&_set_sortkey,
};

sub DEPENDENCIES
{
    my ($deps) = @_;
    $deps->{value}->{product_id} = 1;
}

################################
# Methods
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

sub _do_list_select
{
    my $self = shift;
    my $list = $self->SUPER::_do_list_select(@_);
    return [ sort { ($a->{sortkey} <=> $b->{sortkey}) || vers_cmp(lc $a->{value}, lc $b->{value}) } @$list ];
}

sub update
{
    my $self = shift;
    my $changes = $self->SUPER::update(@_);
    # Fill visibility values
    Bugzilla->get_field('version')->update_visibility_values($self->id, [ $self->product_id ]);
    return $changes;
}

sub bug_count
{
    my $self = shift;
    return Bugzilla->get_field('version')->count_value_objects($self->id);
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
        ThrowUserError('version_already_exists', {
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

sub _set_sortkey
{
    my ($self, $sortkey) = @_;
    return int($sortkey || 0);
}

1;
__END__

=head1 NAME

Bugzilla::Version - Bugzilla product version class.

=head1 SYNOPSIS

    use Bugzilla::Version;
    my $version = new Bugzilla::Version({ name => $name, product => $product });
    my $product = $version->product;

=head1 DESCRIPTION

Version.pm represents a Product Version object. It is a subclass of GenericObject,
so all DB interaction is done exactly as with any other GenericObject.

=head1 FIELDS

=over

=item B<product_id>: Bugzilla::Product

Parent product

=item B<value>: string

Version name, unique in the product

=item B<isactive>: boolean

=back

=cut
