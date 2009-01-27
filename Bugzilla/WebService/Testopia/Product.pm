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
# The Original Code is the Bugzilla Testopia System.
#
# The Initial Developer of the Original Code is Greg Hendricks.
# Portions created by Greg Hendricks are Copyright (C) 2006
# Novell. All Rights Reserved.
#
# Contributor(s): Dallas Harken <dharken@novell.com>
#                 Greg Hendricks <ghendricks@novell.com>

package Bugzilla::WebService::Testopia::Product;

use strict;

use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Testopia::Product;

sub _validate {
    my ($product) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    
    if ($product =~ /^\d+$/){
        $product = Bugzilla::Testopia::Product->new($product);
    }
    else {
        $product = Bugzilla::Product::check_product($product);
        $product = Bugzilla::Testopia::Product->new($product->id);
    }
    
    ThrowUserError('invalid-test-id-non-existent', {type => 'Product', id => $product}) unless $product;
    ThrowUserError('testopia-permission-denied', {'object' => $product}) if $product && !$product->canedit;

    return $product;
}

sub get {
    my $self = shift;
    my ($id) = @_;
    
    Bugzilla->login(LOGIN_REQUIRED);
    
    # Result is a product object hash
    my $product = new Bugzilla::Testopia::Product($id);

    ThrowUserError('invalid-test-id-non-existent', {type => 'Product', id => $id}) unless $product;
    ThrowUserError('testopia-permission-denied', {'object' => $product}) unless $product->canedit;

    return $product;
}

sub check_product {
    my $self = shift;
    my ($name) = @_;
 
    my $product = _validate($name);
    
    return $product;
}

sub check_category {
    my $self = shift;
    my ($name, $product) = @_;
    
    Bugzilla->login(LOGIN_REQUIRED);
    
    $product = _validate($product);
    
    ThrowUserError('testopia-read-only', {'object' => $product}) unless $product->canedit;
    require Bugzilla::Testopia::Category;
    return Bugzilla::Testopia::Category->new(Bugzilla::Testopia::Category::check_case_category($name, $product));
}

sub check_component {
    my $self = shift;
    my ($name, $product) = @_;
    
    Bugzilla->login(LOGIN_REQUIRED);
    
    $product = _validate($product);
    
    ThrowUserError('testopia-read-only', {'object' => $product}) unless $product->canedit;
    require Bugzilla::Component;
    return Bugzilla::Component->check({product => $product, name => $name});
}

sub get_builds {
    my $self = shift;
    my ($product, $active) = @_;
    
    $product = _validate($product);
    
    return $product->builds($active);
    
}

sub get_category {
    my $self = shift;
    my ($id) = @_;
    
    Bugzilla->login(LOGIN_REQUIRED);
    
    require Bugzilla::Testopia::Category;
    
    my $category = Bugzilla::Testopia::Category->new($id); 
    
    ThrowUserError('invalid-test-id-non-existent', {type => 'Category', id => $id}) unless $category;
    ThrowUserError('testopia-permission-denied', {'object' => $category->product}) unless $category->product->canedit;
    
    delete $category->{'product'};
    
    return  $category;
}

sub get_component {
    my $self = shift;
    my ($id) = @_;
    
    Bugzilla->login(LOGIN_REQUIRED);
    
    require Bugzilla::Component;
    my $component = Bugzilla::Component->new($id); 
    
    ThrowUserError('invalid-test-id-non-existent', {type => 'Component', id => $id}) unless $component;
    
    my $product = Bugzilla::Testopia::Product->new($component->product_id);
    
    ThrowUserError('testopia-permission-denied', {'object' => $product}) unless $product->canedit;
    
    return  $component;
}

sub get_cases {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->cases;
}

sub get_categories {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->categories;
}

sub get_components {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->components;
}

sub get_environments {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->environments;
}

sub get_milestones {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->milestones;
}

sub get_plans {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->plans;
}

sub get_runs {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->runs;
}

sub get_tags {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->tags;
}

sub get_versions {
    my $self = shift;
    my ($product) = @_;
    
    $product = _validate($product);
    
    return $product->versions;

}

sub lookup_name_by_id {
    return {ERROR=> 'This method id deprecated. Use Product::get instead.'};
}
sub lookup_id_by_name {
    return {ERROR=> 'This method id deprecated. Use Product::check_product instead.'};
}

1;

__END__

=head1 NAME

Bugzilla::Testopia::Webservice::Product

=head1 EXTENDS

Bugzilla::Webservice

=head1 DESCRIPTION

Provides methods for automated scripts to expose Testopia Product data.

=head1 METHODS

=over

=item C<check_category($name, $product)>

 Description: Looks up and returns a category by name.

 Params:      $name - String: name of the category.
              $product - Integer/String
                 Integer: product_id of the product in the Database
                 String: Product name

 Returns:     Hash: Matching Category object hash or error if not found.

=item C<check_component($name, $product)>

 Description: Looks up and returns a component by name.

 Params:      $name - String: name of the category.
              $product - Integer/String
                 Integer: product_id of the product in the Database
                 String: Product name

 Returns:     Hash: Matching component object hash or error if not found.

=item C<check_product($name, $product)>

 Description: Looks up and returns a validated product.

 Params:      $name - String: name of the product.

 Returns:     Hash: Matching Product object hash or error if not found.

=item C<get($id)>

 Description: Used to load an existing product from the database.

 Params:      $id - An integer representing the ID in the database

 Returns:     A blessed Bugzilla::Testopia::Product object hash

=item C<get_builds($product, $active)>

 Description: Get the list of builds associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name
              $active  - Boolean: True to only include builds where isactive is true. 

 Returns:     Array: Returns an array of Build objects.

=item C<get_cases($product)>

 Description: Get the list of cases associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of TestCase objects.

=item C<get_categories($product)>

 Description: Get the list of categories associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Case Category objects.

=item C<get_category($id)>

 Description: Get the category matching the given id.

 Params:      $id - Integer: ID of the category in the database.

 Returns:     Hash: Category object hash.

=item C<get_component($id)>

 Description: Get the component matching the given id.

 Params:      $id - Integer: ID of the component in the database.

 Returns:     Hash: Component object hash.

=item C<get_components($product)>

 Description: Get the list of components associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Component objects.

=item C<get_environments($product)>

 Description: Get the list of environments associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Environment objects.

=item C<get_milestones($product)>

 Description: Get the list of milestones associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Milestone objects.

=item C<get_plans($product)>

 Description: Get the list of plans associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Test Plan objects.

=item C<get_runs($product)>

 Description: Get the list of runs associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Test Run objects.

=item C<get_tags($product)>

 Description: Get the list of tags associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Tags objects.

=item C<get_versions($product)>

 Description: Get the list of versions associated with this product.

 Params:      $product - Integer/String
                         Integer: product_id of the product in the Database
                         String: Product name

 Returns:     Array: Returns an array of Version objects.

=item C<lookup_name_by_id> B<DEPRECATED> Use Product::get instead

=item C<lookup_id_by_name> B<DEPRECATED - CONSIDERED HARMFUL> Use Product::check_product instead

=back

=head1 SEE ALSO

L<Bugzilla::Testopia::Product>
L<Bugzilla::Webservice> 

=head1 AUTHOR

Greg Hendricks <ghendricks@novell.com>