# Bugzilla Classification class, based on GenericObject
# License: MPL 1.1
# Author(s): Vitaliy Filippov <vitalif@mail.ru>
#   still contains some original code from:
#   Tiago R. Mello <timello@async.com.br>
#   Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::Classification;

use base qw(Bugzilla::GenericObject);

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;

use constant DB_TABLE => 'classifications';
use constant NAME_FIELD => 'name';
use constant LIST_ORDER => 'sortkey, name';
use constant CLASS_NAME => 'classification';

use constant OVERRIDE_SETTERS => {
    name => \&_set_name,
    description => \&_set_description,
    sortkey => \&_set_sortkey,
};

use constant is_active => 1;
use constant is_default => 0;
use constant bug_count => 0;

sub _set_name
{
    my ($self, $name) = @_;

    $name = trim($name);
    $name || ThrowUserError('classification_not_specified');
    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError('classification_name_too_long', { name => $name });
    }

    my $classification = new Bugzilla::Classification({ name => $name });
    if ($classification && ($classification->id != $self->id))
    {
        ThrowUserError("classification_already_exists", { name => $classification->name });
    }
    return $name;
}

sub _set_description
{
    my ($self, $description) = @_;
    $description = trim($description || '');
    return $description;
}

sub _set_sortkey
{
    my ($self, $sortkey) = @_;
    $sortkey ||= 0;
    if (!detaint_natural($sortkey))
    {
        ThrowUserError('classification_invalid_sortkey', { sortkey => $sortkey });
    }
    return $sortkey;
}

sub product_count
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!defined $self->{product_count})
    {
        $self->{product_count} = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM products WHERE classification_id=?', undef, $self->id
        ) || 0;
    }
    return $self->{product_count};
}

sub products
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!$self->{products})
    {
        $self->{products} = Bugzilla::Product->_do_list_select('classification_id=?', [ $self->id ]);
    }
    return $self->{products};
}

# Return all visible classifications.
sub get_all { @{ Bugzilla->user->get_selectable_classifications } }

1;

__END__

=head1 NAME

Bugzilla::Classification - Bugzilla classification class.

=head1 SYNOPSIS

    use Bugzilla::Classification;

    my $classification = new Bugzilla::Classification(1);
    my $classification = new Bugzilla::Classification({name => 'Acme'});

    my $id = $classification->id;
    my $name = $classification->name;
    my $description = $classification->description;
    my $sortkey = $classification->sortkey;
    my $product_count = $classification->product_count;
    my $products = $classification->products;

=head1 DESCRIPTION

Classification.pm represents a classification object. It is an
implementation of L<Bugzilla::Object>, and thus provides all methods
that L<Bugzilla::Object> provides.

The methods that are specific to C<Bugzilla::Classification> are listed
below.

A Classification is a higher-level grouping of Products.

=head1 METHODS

=over

=item B<product_count()>

 Description: Returns the total number of products that belong to
              the classification.

 Params:      none.

 Returns:     Integer - The total of products inside the classification.

=item B<products>

 Description: Returns all products of the classification.

 Params:      none.

 Returns:     A reference to an array of Bugzilla::Product objects.

=back

=cut
