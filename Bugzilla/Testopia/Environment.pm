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
# The Original Code is the Bugzilla Test Runner System.
#
# The Initial Developer of the Original Code is Maciej Maczynski.
# Portions created by Maciej Maczynski are Copyright (C) 2001
# Maciej Maczynski. All Rights Reserved.
#
# Contributor(s): Greg Hendricks <ghendricks@novell.com> 
#                 Michael Hight <mjhight@gmail.com>
#                 Garrett Braden <gbraden@novell.com>
#                 Andrew Nelson <anelson@novell.com>

=head1 NAME

Bugzilla::Testopia::Environment - A test environment

=head1 DESCRIPTION

Environments are a set of parameters dictating what conditions 
a test was conducted in. Each test run must have an environment. 
Environments can be very simple or very complex. 

Environments are comprised of Elemements, Properties, and Values.
Elements can be nested within other elements. Each element can have 
zero or more properties. Each property can only have one value selected
of the possible values.

=head1 SYNOPSIS

 $env = Bugzilla::Testopia::Environment->new($env_id);
 $env = Bugzilla::Testopia::Environment->new(\%env_hash);

=cut

package Bugzilla::Testopia::Environment;

use strict;

use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::Config;

use Bugzilla::Testopia::Environment::Category;
use Bugzilla::Testopia::Environment::Element;
use Bugzilla::Testopia::Environment::Property;

use JSON;

use base qw(Exporter Bugzilla::Object);
@Bugzilla::Bug::EXPORT = qw(check_environment);

###############################
####    Initialization     ####
###############################

=head1 FIELDS
    environment_id
    product_id
    name
    isactive

=cut
use constant DB_TABLE   => "test_environments";
use constant NAME_FIELD => "name";
use constant ID_FIELD   => "environment_id";
use constant DB_COLUMNS => qw(
    environment_id
    product_id
    name
    isactive
);

use constant REQUIRED_CREATE_FIELDS => qw(name product_id);
use constant UPDATE_COLUMNS         => qw(name isactive);

use constant VALIDATORS => {
    product_id => \&_check_product,
    isactive   => \&_check_isactive,
};

our constant $max_depth = 7;

###############################
####       Validators      ####
###############################
sub _check_product {
    my ($invocant, $product_id) = @_;

    $product_id = trim($product_id);
    
    require Bugzilla::Testopia::Product;
    
    my $product;
    if (trim($product_id) !~ /^\d+$/ ){
        $product = Bugzilla::Product::check_product($product_id);
        $product = Bugzilla::Testopia::Product->new($product->id);
    }
    else {
        $product = Bugzilla::Testopia::Product->new($product_id);
    }

    ThrowUserError("testopia-create-denied", {'object' => 'environment'}) unless $product->canedit;
    
    if (ref $invocant){
        $invocant->{'product'} = $product; 
        return $product->id;
    } 

    return $product;
}
sub _check_isactive {
    my ($invocant, $isactive) = @_;
    ThrowCodeError('bad_arg', {argument => 'isactive', function => 'set_isactive'}) unless ($isactive =~ /(1|0)/);
    return $isactive;
}
sub _check_name {
    my ($invocant, $name, $product_id) = @_;
    
    $name = clean_text($name) if $name;
    
    if (!defined $name || $name eq '') {
        ThrowUserError('testopia-missing-required-field', {'field' => 'name'});
    }
    
    trick_taint($name);
    
    # Check that we don't already have a environment with that name in this product.    
    my $orig_id = check_environment($name, $product_id);
    my $notunique;

    if (ref $invocant){
        # If updating, we have matched ourself at least
        $notunique = 1 if (($orig_id && $orig_id != $invocant->id))
    }
    else {
        # In new environment any match is one too many
        $notunique = 1 if $orig_id;
    }

    ThrowUserError('testopia-name-not-unique', 
                  {'object' => 'Environment', 
                   'name' => $name}) if $notunique;
               
    return $name;
}

###############################
####       Mutators        ####
###############################
sub set_isactive    { $_[0]->set('isactive', $_[1]); }
sub set_name { 
    my ($self, $value) = @_;
    $value = $self->_check_name($value, $self->product_id);
    $self->set('name', $value); 
}

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $param = shift;
    
    # We want to be able to supply an empty object to the templates for numerous
    # lists etc. This is much cleaner than exporting a bunch of subroutines and
    # adding them to $vars one by one. Probably just Laziness shining through.
    if (ref $param eq 'HASH'){
        if (!keys %$param || $param->{PREVALIDATED}){
            bless($param, $class);
            return $param;
        }
    }
    
    unshift @_, $param;
    my $self = $class->SUPER::new(@_);
    
    return $self; 
}

sub run_create_validators {
    my $class  = shift;
    my $params = $class->SUPER::run_create_validators(@_);
    my $product = $params->{product_id};
    
    $params->{name} = $class->_check_name($params->{name}, ref $product ? $product->id : $product);
    
    return $params;
}

sub create {
    my ($class, $params) = @_;

    $class->SUPER::check_required_create_fields($params);
    my $field_values = $class->run_create_validators($params);
    
    $field_values->{isactive}  = 1;
    $field_values->{product_id} = ref $field_values->{product_id} ? $field_values->{product_id}->id : $field_values->{product_id};
    my $self = $class->SUPER::insert_create_data($field_values);
    
    return $self;
}

# variables used for create_full() to _parseElementsRecursively() inter-subroutine communication:
my @environment_map;
my $modified_environment_structure = 0;

sub create_full {
	my $self = shift;
	my ($env_basename, $prod_id, $environment) = @_;

	# first, get ALL rows to add to test_environment_map table
	# and store them in @environment_map array
	foreach my $key (keys(%{$environment})){
		require Bugzilla::Testopia::Environment::Category;
		my $cat = Bugzilla::Testopia::Environment::Category->new({'product_id' => $prod_id});
		my $cat_id = $cat->check_category($key);
		if (!$cat_id) { warn "category: $key for id: $cat did not exist"; return 0; }
		_parseElementsRecursively($environment->{$key}, $cat_id, 'category');
	}

	# if we didn't touch the underlying element/property structure:
	# see if an existing environment matches
	if(!$modified_environment_structure){
	    # environment must begin with $env_basename
	    my $dbh = Bugzilla->dbh;
	    my @envmatch = @{$dbh->selectcol_arrayref(
	            	     "SELECT environment_id 
	               	      FROM test_environments
	               	      WHERE name LIKE '$env_basename:%' AND product_id = $prod_id")};
		
		if(scalar(@envmatch)){
			# ALL rows must be represented in that environment
			foreach my $hash (@environment_map) {
				my $env_id_conditions = "environment_id = " . pop @envmatch;
				foreach(@envmatch){$env_id_conditions .= " OR environment_id = $_";}
			
		   		@envmatch = @{$dbh->selectcol_arrayref(
		            				"SELECT environment_id 
		               		 		FROM test_environment_map
		               		 		WHERE ( $env_id_conditions ) AND
		               		 		property_id = $hash->{prop_id} AND
		               		 		element_id = $hash->{elem_id} AND
		               		 		value_selected = '$hash->{value_selected}'")};
				last if (!scalar(@envmatch));
			}

			# if we got at least one match..
			if(scalar(@envmatch)){
				# choose the highest valued one (most recent) and return it
				my $max = pop @envmatch;
				foreach(@envmatch){
					$max = $_ if $_ > $max;}
				return $max;
			} 
		}
	}

	# else, create a new environment
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	$year += 1900;
	$hour = sprintf("%02d", $hour); $min = sprintf("%02d", $min); $yday = sprintf("%03d", $yday);
	my $environment_name = $env_basename . ':' . $year . $yday . ':' . $hour . $min;

    my $env = $self->create({
        name => $environment_name,
        product_id => $prod_id
    });
    
	my $env_id = $env->id;
	ThrowUserError('could-not-create-environment', {'environment_name' => $environment_name}) unless $env_id;

	# and create all rows in test_environment_map table for this environment_id
	foreach my $hash (@environment_map) {
		$env->store_property_value($hash->{prop_id}, $hash->{elem_id}, $hash->{value_selected});	
	}

	# return the environment id
	return $env_id;
}

sub _parseElementsRecursively {
# internal function used by create_full()
	my ($hash, $callerid, $callertype, $categoryid) = @_;
	$categoryid = $callerid if !defined($categoryid);

	foreach my $key (keys(%{$hash})) {
		if(ref($hash->{$key})){ # must be element, since property contains value instead of another hash
			require Bugzilla::Testopia::Environment::Element;
			my $elem = Bugzilla::Testopia::Environment::Element->new({});
			# get exising element OR create new one
			my ($elem_id) = $elem->check_element($key, $callerid);
			if(!$elem_id){
				$elem->{'env_category_id'} = ($callertype eq 'category') ? $callerid : $categoryid;
				$elem->{'name'} = $key;
				$elem->{'parent_id'} = ($callertype eq 'element') ? $callerid : 0;
				$elem->{'isprivate'} = 0;
				($elem_id) = $elem->store();
				ThrowUserError('could-not-create-element', {'element_name' => $key}) unless $elem_id;
				$modified_environment_structure = 1;
			}
			_parseElementsRecursively($hash->{$key}, $elem_id, 'element', $categoryid);
		} else {
			require Bugzilla::Testopia::Environment::Property;
			my $prop = Bugzilla::Testopia::Environment::Property->new({});
			my ($prop_id) = $prop->check_property($key, $callerid);
			# get existing property OR create new one
			if(!$prop_id){
				$prop->{'element_id'} = $callerid;
				$prop->{'name'} = $key;
				$prop->{'validexp'} = $hash->{$key};
				($prop_id) = $prop->store();
				ThrowUserError('could-not-create-property', {'property_name' => $key}) unless $prop_id;
				$modified_environment_structure = 1;
			} else {
				# if property exists, still update validexp if needed
				$prop = Bugzilla::Testopia::Environment::Property->new($prop_id);
				my $validexp = $prop->validexp;
				if ($validexp !~ m/\Q$hash->{$key}/){
					my $newexp = $validexp . ((!length($validexp)) ? "" : "|") . $hash->{$key}; 
					$prop->update_property_validexp($newexp);
					$modified_environment_structure = 1;
				}
			}
			# push to array which will be used later
			push @environment_map, {prop_id => $prop_id, elem_id => $callerid, value_selected => $hash->{$key}};
		}
	}
}

###############################
####       Methods         ####
###############################

=head1 METHODS

=head2 get element list for environment

Returns an array of element objects for an environment

=cut

sub get_environment_elements{
    my $dbh = Bugzilla->dbh;
    my $self = shift;
    
    return $self->{'elements'} if exists $self->{'elements'};
    
    my $id = $self->{'environment_id'};
    
    my $ref = $dbh->selectcol_arrayref("
            SELECT DISTINCT tee.element_id 
              FROM test_environment_map as tem
              JOIN test_environment_element as tee
                ON tem.element_id = tee.element_id
             WHERE tem.environment_id = ?",undef,$id);
    
    my @elements;

    foreach my $val  (@$ref){
        push @elements, Bugzilla::Testopia::Environment::Element->new($val);
    }   
    $self->{'elements'} = \@elements;
     
   return \@elements;             
}

sub element_count {
    my $self = shift;
    
    return scalar(@{$self->get_environment_elements});   
}

sub element_categories {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT env_category_id 
           FROM test_environment_element tee 
     INNER JOIN test_environment_map tem 
       		 ON tem.element_id = tee.element_id 
          WHERE tem.environment_id = ?", undef, $self->id); 
    
    my @elements;
    foreach my $val  (@$ref){
        push @elements, Bugzilla::Testopia::Environment::Category->new($val);
    }   
    $self->{'categories'} = \@elements;
     
    return \@elements; 
}

sub categories_to_json {
    my $self = shift;

    my @elements_array; 
    foreach my $category (@{$self->element_categories}){
        push @elements_array, {
            text => $category->{'name'}, 
            id   => $category->id, 
            type => 'category', 
            leaf => JSON::false, 
            cls  => 'category',
            draggable => JSON::false,
        };
    }
    
    my $json = new JSON; 
    print $json->encode(\@elements_array);
    return undef;
}

sub mapped_category_elements_to_json {
    my $self = shift;
    my ($cat_id) = @_;
    
    my $dbh = Bugzilla->dbh;
    
    trick_taint($cat_id);
    my $ref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT tem.element_id 
           FROM test_environment_map tem
     INNER JOIN test_environment_element tee 
             ON tee.element_id = tem.element_id
           WHERE tee.env_category_id = ?
           AND tee.element_id IN (SELECT element_id 
                                    FROM test_environment_map 
                                   WHERE environment_id = ?)", 
           undef, ($cat_id, $self->id));
    
    my @elements;
    foreach my $id (@$ref){
        my $element = Bugzilla::Testopia::Environment::Element->new($id);
        push @elements, {
            text => $element->{'name'}, 
            id   => $element->id, 
            type => 'element', 
            leaf => $element->check_for_children ? JSON::false : JSON::true, 
            cls  => 'element',
            draggable => JSON::false,
        }; 
    }
    
    my $json = new JSON; 
    print $json->encode(\@elements);
    return undef;
    
}

sub get_value_selected{
    my $dbh = Bugzilla->dbh;
    my $self = shift;
    
    my ($environment,$element,$property) = (@_);
    
    my ($var) = $dbh->selectrow_array(
            "SELECT value_selected 
              FROM test_environment_map
             WHERE environment_id = ?
               AND element_id = ?
               AND property_id = ?",
               undef,($environment,$element,$property));
    
    return $var;
}

sub get_environments{
    my $dbh = Bugzilla->dbh;
    my $self = shift;
   
    my $ref = $dbh->selectall_arrayref(
            "SELECT environment_id, name 
               FROM test_environments");
             
   return $ref;             
}

sub get_all_env_categories {
    my $self = shift;
    my ($byid) = @_;
    my $dbh = Bugzilla->dbh;
    my $idstr = $byid ? 'env_category_id' : 'DISTINCT name';
    my $ref = $dbh->selectall_arrayref(
            "SELECT $idstr AS id, name
               FROM test_environment_category",
               {'Slice' => {}});
    
    return $ref;
}

sub get_all_visible_elements {
    my $self = shift;
    my ($byid) = @_;
    my $dbh = Bugzilla->dbh;
    my $idstr = $byid ? 'element_id' : 'DISTINCT name';
    my $ref = $dbh->selectall_arrayref(
            "SELECT $idstr AS id, name
               FROM test_environment_element",
               {'Slice' => {}});
    
    return $ref;
}

sub get_all_element_properties {
    my $self = shift;
    my ($byid) = @_;
    my $dbh = Bugzilla->dbh;
    my $idstr = $byid ? 'property_id' : 'DISTINCT name';
    my $ref = $dbh->selectall_arrayref(
            "SELECT $idstr AS id, name, validexp
               FROM test_environment_property",
               {'Slice' => {}});
    
    return $ref;
}

sub get_distinct_property_values {
    my $self = shift;
    my @exps;
    foreach my $prop (@{$self->get_all_element_properties}){
        push @exps, split(/\|/, $prop->{'validexp'})
    }
    my %seen;
    foreach my $v (@exps){
        $seen{$v} = $v;
    }
    my @values;
    foreach my $v (keys %seen){
        my %p;
        $p{'id'} = $v;
        $p{'name'} = $v;
        push @values, \%p;
    }
    return \@values;
}

=head2 get all elements

Returns the list of element names, ids and category names

=cut

sub get_all_elements{
    
    my $dbh = Bugzilla->dbh;
    my $self = shift;
    
    my $ref = $dbh->selectcol_arrayref(
            "SELECT tee.element_id 
               FROM test_environment_map as tem
               JOIN test_environment_element as tee
                 ON tem.element_id = tee.element_id",
                 undef);
    
    my @elements;

    foreach my $val  (@$ref){
        push @elements, Bugzilla::Testopia::Environment::Element->new($val);
    }   
             
       return \@elements;             
}

sub check_environment{
    my ($name, $product, $throw) = (@_);
    my $pid = ref $product ? $product->id : $product;
    my $dbh = Bugzilla->dbh;

    my ($used) = $dbh->selectrow_array(
        "SELECT environment_id 
           FROM test_environments
          WHERE name = ? AND product_id = ?",
          undef, ($name, $pid));
    if ($throw){
        ThrowUserError('invalid-test-id-non-existent', {type => 'Environment', id => $name}) unless $used;
        return Bugzilla::Testopia::Environment->new($used);
    }
    
    return $used;             
}

sub check_value_selected {
    my $self = shift;
    my ($prop_id, $elem_id) = @_;
    my $dbh = Bugzilla->dbh;
          
    my ($used) = $dbh->selectrow_array(
        "SELECT environment_id
           FROM test_environment_map
          WHERE environment_id = ? 
            AND property_id = ? 
            AND element_id = ?", 
            undef, ($self->{'environment_id'}, $prop_id, $elem_id));
        
    return $used;
}

=head2 store property values

Serializes the property values to the database

=cut

sub store_property_value {
    my $self = shift;
 
    my ($prop_id,$elem_id,$value_selected) = @_;
    
    return 0 if ($self->check_value_selected($prop_id, $elem_id, $value_selected));
        
    my $dbh = Bugzilla->dbh;
    $dbh->do("INSERT INTO test_environment_map (environment_id,property_id,element_id,value_selected)
             VALUES (?,?,?,?)",undef, ($self->{'environment_id'}, $prop_id, $elem_id,$value_selected));          
    return 1;
}

sub TO_JSON {
    my $self = shift;
    my $obj;
    my $json = new JSON;
    
    foreach my $field ($self->DB_COLUMNS){
        $obj->{$field} = $self->{$field};
    }
    
    $obj->{'product_name'}   = $self->product->name if $self->product;
    $obj->{'case_run_count'}   = $self->case_run_count;
    $obj->{'run_count'}  = $self->get_run_count;
    
    return $json->encode($obj); 
}
=head2 update

Updates this environment object in the database.
Takes a reference to a hash whose keys match the fields of 
an environment.

=cut

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    
    $self->SUPER::update();
    
    $dbh->bz_commit_transaction();

    my $elements = $self->{'elements'};
    
    foreach my $element (@$elements)
    {
        $self->persist_environment_element_and_children(1, $element, "update");
    }
    
    return 1;
}


=head2 persist_environment_element_and_children 

Persists Environment Element and Children Recursively.

=cut

sub persist_environment_element_and_children {
    my $self = shift;
    my ($depth, $element, $method) = @_;
    if ($depth > $max_depth) {
        return;
    }
    $depth++;
    my $elem_id = $element->{'element_id'};
    my $properties = $element->{'properties'};
    foreach my $property (@$properties)
    {
        my $prop_id = $property->{'property_id'};
        my $value_selected = $property->{'value_selected'};
        my ($value_stored) = $self->get_value_selected($self->{'environment_id'},$prop_id,$elem_id);
        if ($method eq "store" || $value_stored eq undef) {
            $self->store_property_value($prop_id,$elem_id,$value_selected);
        }
        else {
            $self->update_property_value($prop_id,$elem_id,$value_selected);
        }
    }
    my $children = $element->{'children'};
    foreach my $child_element (@$children) {
        $self->persist_environment_element_and_children($depth, $child_element, $method);
    }
}


=head2 update property value

Updates the property of the element in the database

=cut

sub update_property_value {
    my $self = shift;
    my ($propID, $elemID, $valueSelected) = (@_);
    
    my $dbh = Bugzilla->dbh;
    $dbh->do("UPDATE test_environment_map 
              SET value_selected = ? WHERE environment_id = ? AND property_id = ? AND element_id = ?"
              ,undef, ($valueSelected,$self->{'environment_id'},$propID,$elemID));          
    return 1;
}

=head2 toggle_hidden

Toggles the archive bit on the build.

=cut

sub toggle_archive {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $dbh->do("UPDATE test_environments SET isactive = ? 
               WHERE environment_id = ?", undef, $self->isactive ? 0 : 1, $self->id);
    
}

sub delete_element {
    my $self = shift;
    my ($element_id) = @_;
    my $dbh = Bugzilla->dbh;
    
    $dbh->do("DELETE FROM test_environment_map
              WHERE environment_id = ? AND element_id = ?",
              undef,($self->id, $element_id));
              
}

sub element_is_mapped{
    my $self = shift;
    my ($element_id) = @_;
    my $dbh = Bugzilla->dbh;
    
    $dbh->selectcol_arrayref("SELECT * FROM test_environment_map
              WHERE environment_id = ? AND element_id = ?",
              undef,($self->id, $element_id));
              
     if($dbh)
     {
         return 1;
     }
     
     return 0;
   
}

=head2 obliterate

Completely removes this environment from the database.

=cut

sub obliterate {
    my $self = shift;
    return 0 unless $self->candelete;
    my $dbh = Bugzilla->dbh;

    foreach my $obj (@{$self->runs}){
        $obj->obliterate;
    }
    foreach my $obj (@{$self->caseruns}){
        $obj->obliterate;
    }

    $dbh->do("DELETE FROM test_environment_map WHERE environment_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_environments WHERE environment_id = ?", undef, $self->id);
    return 1;
}

sub clone {
    my $self = shift;
    my ($name, $product) = @_;
    my $dbh = Bugzilla->dbh;
    
    my $new = $self->create({
        name => $name,
        product_id => $product
    });  
    
    my $ref = $dbh->selectall_arrayref(
        "SELECT * FROM test_environment_map
          WHERE environment_id = ?",{'Slice' => {}}, $self->id);
    
    my $sth = $dbh->prepare_cached(
        "INSERT INTO test_environment_map 
         (environment_id, property_id, element_id, value_selected)
         VALUES (?,?,?,?)");
    
    foreach my $row (@$ref){
        $sth->execute($new->id, $row->{'property_id'}, $row->{'element_id'}, $row->{'value_selected'})
    }
    
    return $new->id;
}

=head2 get_run_list

Returns a list of run ids associated with this environment.

=cut

sub get_run_list {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectcol_arrayref("SELECT run_id FROM test_runs 
                                         WHERE environment_id = ?",
                                        undef, $self->{'environment_id'});
    return join(",", @{$ref});
}

=head2 get_run_count

Returns a count of the runs associated with this environment

=cut

sub get_run_count {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my ($count) = $dbh->selectrow_array("SELECT COUNT(run_id) FROM test_runs 
                                          WHERE environment_id = ?",
                                        undef, $self->{'environment_id'});
    return $count;
}

=head2 canedit

Returns true if the logged in user has rights to edit this environment.

=cut

sub canedit {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('Testers') && Bugzilla->user->can_see_product($self->product->name);
    return 0;
}

=head2 canview

Returns true if the logged in user has rights to view this environment.

=cut

sub canview {
    my $self = shift;
    return 1 if Bugzilla->user->can_see_product($self->product->name);
    return 0;
}

=head2 candelete

Returns true if the logged in user has rights to delete this environment.

=cut

sub candelete {
    my $self = shift;
    return 1 if Bugzilla->user->in_group("admin");
    return 0 unless Bugzilla->params->{"allow-test-deletion"};
    return 0 unless Bugzilla->user->can_see_product($self->product->name);
    return 1 if Bugzilla->user->in_group("Testers") && Bugzilla->params->{"testopia-allow-group-member-deletes"}; 
    return 0;
}

###############################
####      Accessors        ####
###############################
=head2 id

Returns the ID of this object

=head2 name

Returns the name of this object

=cut

sub id              { return $_[0]->{'environment_id'};  }
sub product_id      { return $_[0]->{'product_id'};  }
sub isactive        { return $_[0]->{'isactive'};  }
sub name            { return $_[0]->{'name'};            }

=head2 product

Returns the bugzilla product 

=cut

sub product {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'product'} if exists $self->{'product'};
    require Bugzilla::Testopia::Product;
    $self->{'product'} = Bugzilla::Product->new($self->{'product_id'});
    return $self->{'product'};
}

=head2 runs

Returns a reference to a list of test runs useing this environment

=cut

sub runs {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'runs'} if exists $self->{'runs'};
    
    require Bugzilla::Testopia::TestRun;
    
    my $runids = $dbh->selectcol_arrayref("SELECT run_id FROM test_runs
                                          WHERE environment_id = ?", 
                                          undef, $self->id);
    my @runs;
    foreach my $id (@{$runids}){
        push @runs, Bugzilla::Testopia::TestRun->new($id);
    }
    
    $self->{'runs'} = \@runs;
    return $self->{'runs'};
}

=head2 caseruns

Returns a reference to a list of test caseruns useing this environment

=cut

sub caseruns {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'caseruns'} if exists $self->{'caseruns'};
    
    require Bugzilla::Testopia::TestCaseRun;

    my $ids = $dbh->selectcol_arrayref("SELECT case_run_id FROM test_case_runs
                                          WHERE environment_id = ?", 
                                          undef, $self->id);
    my @caseruns;
    foreach my $id (@{$ids}){
        push @caseruns, Bugzilla::Testopia::TestCaseRun->new($id);
    }
    
    $self->{'caseruns'} = \@caseruns;
    return $self->{'caseruns'};
}

sub case_run_count {
    my ($self,$status_id) = @_;
    my $dbh = Bugzilla->dbh;
    
    my $query = "SELECT COUNT(case_run_id) FROM test_case_runs 
           WHERE environment_id = ?";
    $query .= " AND case_run_status_id = ?" if $status_id;
    
    my $count;
    if ($status_id){
        $count = $dbh->selectrow_array($query, undef, ($self->id,$status_id));
    }
    else {
        $count = $dbh->selectrow_array($query, undef, $self->id);
    }
          
    return $count;
}

sub type {
    my $self = shift;
    $self->{'type'} = 'environment';
    return $self->{'type'};
}

=head1 TODO


=head1 SEE ALSO

TestRun

=head1 AUTHOR

Greg Hendricks <ghendricks@novell.com>

=cut

1;
