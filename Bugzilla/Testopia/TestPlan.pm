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

package Bugzilla::Testopia::TestPlan;

use strict;

use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Config;
use Bugzilla::Constants;
use Bugzilla::Version;
use Bugzilla::Bug;

use Bugzilla::Testopia::Constants;
use Bugzilla::Testopia::Util;
use Bugzilla::Testopia::TestTag;
use Bugzilla::Testopia::Product;
use Bugzilla::Testopia::Attachment;

use Text::Diff;
use JSON;

use base qw(Exporter Bugzilla::Object);
@Bugzilla::Testopia::TestPlan::EXPORT = qw(lookup_type_by_name lookup_type);

###############################
####    Initialization     ####
###############################

=head1 FIELDS

    plan_id
    product_id
    author_id
    type_id
    default_product_version
    name
    creation_date
    isactive

=cut

use constant DB_TABLE   => "test_plans";
use constant NAME_FIELD => "name";
use constant ID_FIELD   => "plan_id";
use constant DB_COLUMNS => qw(
    plan_id
    product_id
    author_id
    type_id
    default_product_version
    name
    creation_date
    isactive
);

use constant REQUIRED_CREATE_FIELDS => qw(product_id author_id type_id default_product_version name);
use constant UPDATE_COLUMNS         => qw(product_id type_id default_product_version name isactive);

use constant VALIDATORS => {
    product_id => \&_check_product,
    author_id  => \&_check_author,
    type_id    => \&_check_type,
    isactive   => \&_check_isactive,
};

use constant NAME_MAX_LENGTH => 255;

sub report_columns {
    my $self = shift;
    my %columns;
    # Changes here need to match Report.pm
    $columns{'Type'}          = "plan_type";        
    $columns{'Version'}       = "default_product_version";
    $columns{'Product'}       = "product";
    $columns{'Archived'}      = "archived";
    $columns{'Tags'}          = "tags";
    $columns{'Author'}        = "author";
    my @result;
    push @result, {'name' => $_, 'id' => $columns{$_}} foreach (sort(keys %columns));
    unshift @result, {'name' => '<none>', 'id'=> ''};
    return \@result;     
        
}

###############################
####       Validators      ####
###############################

sub _check_product {
    my ($invocant, $product_id) = @_;

    if (ref $invocant){
        ThrowUserError("plan-has-children") 
          if (($invocant->test_case_count || $invocant->test_run_count) && $invocant->product_id != $product_id);
    }
    
    $product_id = trim($product_id);
    my $product;
    if ($product_id !~ /^\d+$/ ){
        $product = Bugzilla::Product::check_product($product_id);
        $product = Bugzilla::Testopia::Product->new($product->id);
    }
    else {
        $product = Bugzilla::Testopia::Product->new($product_id);
    }

    ThrowUserError("invalid-test-id-non-existent", {'id' => $product_id, 'type' => 'product'}) unless $product;
    ThrowUserError("testopia-create-denied", {'object' => 'plan'}) unless $product->canedit;
    if (ref $invocant){
        $invocant->{'product'} = $product; 
        return $product->id;
    } 
    return $product;
}

sub _check_author {
    my ($invocant, $author) = @_;
    $author = trim($author);
    if ($author =~ /^\d+$/){
        $author = Bugzilla::User->new($author);
    }
    else {
        my $id = login_to_id($author, THROW_ERROR);
        return $id;
    }
    return $author->id;
}

sub _check_type {
    my ($invocant, $type_id) = @_;
    $type_id = trim($type_id);
    trick_taint($type_id);
    if ($type_id !~ /^\d+$/){
        $type_id = lookup_type_by_name($type_id) || $type_id;
    }
    Bugzilla::Testopia::Util::validate_selection($type_id, 'type_id', 'test_plan_types');
    return $type_id;
}

sub _check_product_version {
    my ($invocant, $version, $product) = @_;
    if (ref $invocant){
        $product = $invocant->product;
    }
    $version = trim($version);
    $version = Bugzilla::Version->check({product => $product, name => $version});
    return $version->name;
}

sub _check_isactive {
    my ($invocant, $isactive) = @_;
    ThrowCodeError('bad_arg', {argument => 'isactive', function => 'set_isactive'}) unless ($isactive =~ /(1|0)/);
    return $isactive;
}

###############################
####       Mutators        ####
###############################
sub set_name        { $_[0]->set('name', $_[1]); }
sub set_type        { $_[0]->set('type_id', $_[1]); }
sub set_isactive    { $_[0]->set('isactive', $_[1]); }
sub set_product_id  { $_[0]->set('product_id', $_[1]); }
sub set_default_product_version { 
    my ($self, $value) = @_;
    $value = $self->_check_product_version($value);
    $self->set('default_product_version', $value); 
}

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $param = shift;
    
    # We want to be able to supply an empty object to the templates for numerous
    # lists etc. This is much cleaner than exporting a bunch of subroutines and
    # adding them to $vars one by one. Probably just Laziness shining through.
    if (ref $param eq 'HASH'){
        if (keys %$param){
            bless($param, $class);
            return $param;
        }
        bless($param, $class);
        return $param;
    }
    
    unshift @_, $param;
    my $self = $class->SUPER::new(@_);
    
    return $self; 
}

sub run_create_validators {
    my $class  = shift;
    my $params = $class->SUPER::run_create_validators(@_);
    my $product = $params->{product_id};
    
    $params->{default_product_version} = $class->_check_product_version($params->{default_product_version}, $product);
    $params->{product_id} = $product->id;
    
    return $params;
}

sub create {
    my ($class, $params) = @_;

    $class->SUPER::check_required_create_fields($params);
    my $field_values = $class->run_create_validators($params);
    
    $field_values->{creation_date} = Bugzilla::Testopia::Util::get_time_stamp();
    $field_values->{isactive}  = 1;

    #We have to handle the plan document text a bit differently since it has its own table.
    my $plan_document = $field_values->{text};
    
    delete $field_values->{text};
    
    my $self = $class->SUPER::insert_create_data($field_values);

    $self->store_text($self->id, $field_values->{'author_id'}, $plan_document, $field_values->{creation_date});

    # Add permissions for the plan
    $self->add_tester($self->{'author_id'},15);
    if (Bugzilla->params->{'testopia-default-plan-testers-regexp'}) {
        $self->set_tester_regexp( Bugzilla->params->{"testopia-default-plan-testers-regexp"}, 3);
        $self->derive_regexp_testers(Bugzilla->params->{'testopia-default-plan-testers-regexp'});
    }
    
    # Create default category
    unless (scalar @{$self->product->categories}){
        require Bugzilla::Testopia::Category;
        my $category = Bugzilla::Testopia::Category->create(
            {'name' => '--default--',
             'description' => 'Default product category for test cases',
             'product_id' => $self->product->id });
    }
    delete $self->{'product'};
    return $self;
}

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $timestamp = Bugzilla::Testopia::Util::get_time_stamp();
    $dbh->bz_start_transaction();

    my $changed = $self->SUPER::update();
    
    foreach my $field (keys %$changed){
        Bugzilla::Testopia::Util::log_activity('plan', $self->id, $field, $timestamp, $changed->{$field}->[0], $changed->{$field}->[1]);
    }
    $dbh->bz_commit_transaction();
}

###############################
####       Methods         ####
###############################

=head2 store_text

Stores the test plan document in the test_plan_texts 
table. Used by both store and copy. Accepts the the test plan id,
author id, text, and a an optional timestamp. 

=cut

sub store_text {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my ($key, $author, $text, $timestamp) = @_;
    if (!defined $timestamp){
        ($timestamp) = Bugzilla::Testopia::Util::get_time_stamp();
    }
    $text ||= '';
    trick_taint($text);

    my $version = $self->version || 0;
    $dbh->do("INSERT INTO test_plan_texts 
              (plan_id, plan_text_version, who, creation_ts, plan_text)
              VALUES(?,?,?,?,?)",
              undef, $key, ++$version, $author, 
              $timestamp, $text);
    
    $self->{'version'} = $version;
}

=head2 clone

Creates a copy of this test plan. Accepts the name of the new plan
and a boolean representing whether to copy the plan document as well.

=cut

sub clone {
    my $self = shift;
    my ($name, $author, $product_id, $version, $store_doc) = @_;
    $store_doc = 1 unless defined($store_doc);
    my $dbh = Bugzilla->dbh;
    # Exclude the auto-incremented field from the column list.
    my $columns = join(", ", grep {$_ ne 'plan_id'} DB_COLUMNS);
    my ($timestamp) = Bugzilla::Testopia::Util::get_time_stamp();

    $dbh->do("INSERT INTO test_plans ($columns) VALUES (?,?,?,?,?,?,?)",
              undef, ($product_id, $author,
              $self->{'type_id'}, $version, $name,
              $timestamp, 1));
    my $key = $dbh->bz_last_key( 'test_plans', 'plan_id' );
    my $text = $store_doc ? $self->text->{'plan_text'} : ''; 
    $self->store_text($key, $self->{'author_id'}, $text, $timestamp);
    return $key;
    
}

=head2 toggle_archive

Toggles the archive bit on the plan.

=cut

sub toggle_archive {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my $oldvalue = $self->isactive;
    my $newvalue = $oldvalue == 1 ? 0 : 1;
    $self->set_isactive($newvalue);
    $self->update;
}

=head2 add_tag

Associates a tag with this test plan. Takes the tag_id of the tag
to link.

=cut

sub add_tag {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my @tags;
    foreach my $t (@_){
        if (ref $t eq 'ARRAY'){
            push @tags, $_ foreach @$t;
        }
        else{
            push @tags, split(',', $t);
        }
    }

    foreach my $name (@tags){
        my $tag = Bugzilla::Testopia::TestTag->create({'tag_name' => $name});
        $tag->attach($self);
    }
}

=head2 remove_tag

Removes a tag from this plan. Takes the tag_id of the tag to remove.

=cut

sub remove_tag {    
    my $self = shift;
    my ($tag_name) = @_;
    my $tag = Bugzilla::Testopia::TestTag->check_tag($tag_name);
    ThrowUserError('testopia-unknown-tag', {'name' => $tag}) unless $tag;
    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM test_plan_tags 
               WHERE tag_id=? AND plan_id=?",
              undef, ($tag->id, $self->{'plan_id'}));
}

sub get_used_categories {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectall_arrayref(
            "SELECT DISTINCT test_case_categories.category_id AS id, name 
               FROM test_case_categories
               JOIN test_cases ON test_cases.category_id = test_case_categories.category_id
               JOIN test_case_plans ON test_cases.case_id = test_case_plans.case_id 
              WHERE plan_id = ?
           ORDER BY name",
           {'Slice'=>{}}, $self->id);
           
    return $ref;
}

=head2 get_plan_types

Returns a list of types from the test_plan_types table

=cut

sub get_plan_types {
    my $self = shift;
    my $dbh = Bugzilla->dbh;    

    my $types = $dbh->selectall_arrayref(
            "SELECT type_id AS id, name 
               FROM test_plan_types
           ORDER BY name", 
            {"Slice"=>{}});
    return $types;

}

=head2 last_changed

Returns the date of the last change in the history table

=cut

sub last_changed {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my ($date) = $dbh->selectrow_array(
            "SELECT MAX(changed)
               FROM test_plan_activity 
              WHERE plan_id = ?",
              undef, $self->id);

    return $self->{'creation_date'} unless $date;
    return $date;
}

=head2 plan_type_ref

Returns a type name matching the given type id

=cut

sub plan_type_ref {
    my $self = shift;
    my $type_id = shift;
    my $dbh = Bugzilla->dbh;    

    my $type = $dbh->selectrow_hashref(
            "SELECT type_id AS id, name, description 
               FROM test_plan_types
              WHERE type_id = ?", 
            undef, $type_id);
    
    return $type;
}

=head2 check_plan_type

Returns true if a type with the given name exists

=cut

sub check_plan_type {
    my $self = shift;
    my $name = shift;
    my $dbh = Bugzilla->dbh;    

    my $type = $dbh->selectrow_hashref(
            "SELECT 1 
               FROM test_plan_types
              WHERE name = ?", 
            undef, $name);
    
    return $type;
}

sub check_tester {
    my $self = shift;
    my $userid = shift;
    my $dbh = Bugzilla->dbh;    

    my ($exists) = $dbh->selectrow_array(
            "SELECT 1 
               FROM test_plan_permissions
              WHERE userid = ? AND plan_id = ? AND grant_type = ?", 
            undef, ($userid, $self->id, GRANT_DIRECT));
    
    return $exists;
    
}

=head2 update_plan_type

Update the given type

=cut

sub update_plan_type {
    my $self = shift;
    my ($type_id, $name, $desc) = @_;
    my $dbh = Bugzilla->dbh;    

    my $type = $dbh->do(
            "UPDATE test_plan_types
                SET name = ?, description = ? 
              WHERE type_id = ?", 
            undef, ($name, $desc, $type_id));
    
}

=head2 add_plan_type

Add the given type

=cut

sub add_plan_type {
    my $self = shift;
    my ($name, $desc) = @_;
    my $dbh = Bugzilla->dbh;    

    my $type = $dbh->do(
            "INSERT INTO test_plan_types (name, description) VALUES(?, ?)",
             undef, ($name, $desc));
}

=head2 get_fields

Returns a list of fields from the fielddefs table associated with
a plan

=cut

sub get_fields {
    my $self = shift;
    my $dbh = Bugzilla->dbh;    

    my $types = $dbh->selectall_arrayref(
            "SELECT fieldid AS id, description AS name 
               FROM test_fielddefs 
              WHERE table_name=?", 
            {"Slice"=>{}}, "test_plans");
    unshift @$types, {id => 'text', name => 'Document'};
    unshift @$types, {id => '[Creation]', name => '[Created]'};            
    return $types;
}

=head2 get_text_versions

Returns the list of versions of the plan document.

=cut

sub get_text_versions {
    my $self = shift;
    my $dbh = Bugzilla->dbh;    

    my $versions = $dbh->selectall_arrayref(
            "SELECT plan_text_version AS id, plan_text_version AS name 
               FROM test_plan_texts
              WHERE plan_id = ?
              ORDER BY plan_text_version", 
            {'Slice' =>{}}, $self->id);
    return $versions;
}

=head2 diff_plan_doc

Returns either the diff of the latest version with a new text
or two numerical versions.

=cut

sub diff_plan_doc {
    my $self = shift;
    my ($new, $old) = @_;
    $old ||= $self->version;
    my $dbh = Bugzilla->dbh;
    my $newdoc;
    my $text = $new;
    if (detaint_natural($new)){
        # we are looking for a version 
        $newdoc = $dbh->selectrow_array(
            "SELECT plan_text FROM test_plan_texts
              WHERE plan_id = ? AND plan_text_version = ?",
            undef, ($self->{'plan_id'}, $new));
    }
    else {
        $newdoc = $text;
    }
    detaint_natural($old);
    my $olddoc = $dbh->selectrow_array(
            "SELECT plan_text FROM test_plan_texts
              WHERE plan_id = ? AND plan_text_version = ?",
            undef, ($self->{'plan_id'}, $old));
    my $diff = diff(\$newdoc, \$olddoc);
    return $diff
}

=head2 history

Returns a reference to a list of history entries from the 
test_plan_activity table.

=cut

sub history {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectall_arrayref(
            "SELECT defs.description AS what, 
                    p.login_name AS who, a.changed, a.oldvalue, a.newvalue
               FROM test_plan_activity AS a
               JOIN test_fielddefs AS defs ON a.fieldid = defs.fieldid
               JOIN profiles AS p ON a.who = p.userid
              WHERE a.plan_id = ?",
              {'Slice'=>{}}, $self->{'plan_id'});
    foreach my $row (@$ref){
        if ($row->{'what'} eq 'Product'){
            $row->{'oldvalue'} = $self->lookup_product($row->{'oldvalue'});
            $row->{'newvalue'} = $self->lookup_product($row->{'newvalue'});
        }
        elsif ($row->{'what'} eq 'Plan Type'){
            $row->{'oldvalue'} = lookup_type($row->{'oldvalue'});
            $row->{'newvalue'} = lookup_type($row->{'newvalue'});
        }
    }        
    return $ref;
}

sub copy_permissions {
    my $self = shift;
    my ($planid) = @_;
    my $dbh = Bugzilla->dbh;
    
    my ($regexp, $perms) = $dbh->selectrow_array(
        "SELECT user_regexp, permissions
           FROM test_plan_permissions_regexp
          WHERE plan_id = ?",undef, $self->id);

    $dbh->do("INSERT INTO test_plan_permissions_regexp (plan_id, user_regexp, permissions)
              VALUES(?,?,?)", undef,($planid, $regexp, $perms)) if $regexp;
              
    my $ref = $dbh->selectall_arrayref(
        "SELECT userid, permissions 
           FROM test_plan_permissions
          WHERE plan_id = ? AND grant_type = ?", 
          {'Slice' =>{}}, ($self->id, GRANT_DIRECT));
    foreach my $row (@$ref){
        $dbh->do("INSERT INTO test_plan_permissions (userid, plan_id, permissions, grant_type)
        VALUES(?,?,?,?)", undef, ($row->{'userid'}, $planid, $row->{'permissions'}, GRANT_DIRECT));
    }
}

=head2 lookup_type

Takes an ID of the type field and returns the value

=cut

sub lookup_type {
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT name 
               FROM test_plan_types
              WHERE type_id = ?",
              undef, $id);
    return $value;
}

=head2 lookup_type_by_name

Returns the id of the type name passed.

=cut

sub lookup_type_by_name {
    my ($name) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT type_id
             FROM test_plan_types
             WHERE name = ?",
             undef, $name);
    return $value;
}

=head2 lookup_product

Takes an ID of the status field and returns the value

=cut

sub lookup_product {
    my $self = shift;
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT name 
               FROM products
              WHERE id = ?",
              undef, $id);
    return $value;
}

=head2 lookup_product_by_name

Returns the id of the product name passed.

=cut

sub lookup_product_by_name {
    my ($name) = @_;
    my $dbh = Bugzilla->dbh;
    
    # TODO 2.22 use Product.pm
    my ($value) = $dbh->selectrow_array(
            "SELECT id
             FROM products
             WHERE name = ?",
             undef, $name);
    return $value;
}

sub set_tester_regexp {
    my $self = shift;
    my ($regexp, $permissions) = @_;
    my $dbh = Bugzilla->dbh;
    
    ThrowUserError("invalid_regexp") unless (eval {qr/$regexp/});
    
    return unless $regexp;
    my ($count) = $dbh->selectrow_array(
        "SELECT COUNT(*) 
           FROM profiles 
          WHERE login_name REGEXP(?)", 
          undef, $regexp);
    ThrowUserError("testopia-regexp-too-inclusive") if $count > Bugzilla->params->{'testopia-max-allowed-plan-testers'};
     
    my ($is, $oldreg, $oldperms) = $dbh->selectrow_array(
        "SELECT 1, user_regexp, permissions 
           FROM test_plan_permissions_regexp 
          WHERE plan_id = ?",undef, $self->id);
    
    return unless ($oldreg ne $regexp || $oldperms != $permissions);
    if ($is){
        $dbh->do("UPDATE test_plan_permissions_regexp
                     SET user_regexp = ?, permissions = ? 
                   WHERE plan_id = ?", undef, ($regexp, $permissions, $self->id));
    }
    else { 
        $dbh->do("INSERT INTO test_plan_permissions_regexp
                  (plan_id, user_regexp, permissions) 
                  VALUES(?,?,?)", 
                  undef, ($self->id, $regexp, $permissions));
    } 
    
    $self->derive_regexp_testers($regexp);
    
}

sub derive_regexp_testers {
    my $self = shift;
    my $regexp = shift;
    ThrowUserError("invalid_regexp") unless (eval {qr/$regexp/});
    my $dbh = Bugzilla->dbh;
    # Get the permissions of the regexp testers so we can set it later.
    my ($permissions) = $dbh->selectrow_array(
        "SELECT permissions 
           FROM test_plan_permissions_regexp 
         WHERE plan_id = ?", undef, $self->id);
               
    my $sth = $dbh->prepare("SELECT profiles.userid, profiles.login_name, plan_id
                               FROM profiles
                          LEFT JOIN test_plan_permissions
                                 ON test_plan_permissions.userid = profiles.userid
                                AND test_plan_permissions.plan_id = ?
                                AND grant_type = ?");
    my $plan_add = $dbh->prepare("INSERT INTO test_plan_permissions
                                 (userid, plan_id, permissions, grant_type)
                                 VALUES (?,?,?,?)");
    my $plan_update = $dbh->prepare("UPDATE test_plan_permissions
                                 SET permissions = ? 
                                 WHERE userid = ? AND plan_id = ? AND grant_type = ?");
    my $plan_del = $dbh->prepare("DELETE FROM test_plan_permissions
                                 WHERE userid = ? AND plan_id = ?
                                 AND grant_type = ?");
    $sth->execute($self->id, GRANT_REGEXP);
    while (my ($userid, $login, $present) = $sth->fetchrow_array()) {
        if (($regexp =~ /\S+/) && ($login =~ m/$regexp/i)){
            if ($present){
                $plan_update->execute($permissions, $userid, $self->id, GRANT_REGEXP)
            }
            else {
                $plan_add->execute($userid, $self->id, $permissions, GRANT_REGEXP)
            } 
        }
        else {
            $plan_del->execute($userid, $self->id, GRANT_REGEXP) if $present;
        }
    }

}

sub remove_tester {
    my $self = shift;
    my ($userid) = @_;
    my $dbh = Bugzilla->dbh;
    
    $dbh->do("DELETE FROM test_plan_permissions 
              WHERE userid = ? AND plan_id = ? AND grant_type = ?",
              undef, ($userid, $self->id, GRANT_DIRECT));
}

sub add_tester {
    my $self = shift;
    my ($userid, $perms) = @_;
    my $dbh = Bugzilla->dbh;
    my ($is) = $dbh->selectrow_array(
        "SELECT userid 
           FROM test_plan_permissions
           WHERE userid = ? AND plan_id = ? AND grant_type = ?", 
           undef, ($userid, $self->id, GRANT_DIRECT));
    return if $is;
    
    $dbh->do("INSERT INTO test_plan_permissions
              (userid, plan_id, permissions, grant_type) 
              VALUES(?,?,?,?)", 
              undef, ($userid, $self->id, $perms, GRANT_DIRECT));
}

sub update_tester {
    my $self = shift;
    my ($userid, $perms) = @_;
    my $dbh = Bugzilla->dbh;

    $dbh->do("UPDATE test_plan_permissions SET permissions = ? 
          WHERE userid = ? AND plan_id = ? AND grant_type = ?", 
          undef, ($perms, $userid, $self->id, GRANT_DIRECT)); 
}

=head2 obliterate

Removes this plan and all things that reference it.

=cut

sub obliterate {
    my $self = shift;
    my ($cgi, $template) = @_;
    my $vars;
    my $dbh = Bugzilla->dbh;

    my $progress_interval = 250;
    my $i = 0;
    my $total = scalar @{$self->test_cases} + scalar @{$self->test_runs};

    foreach my $obj (@{$self->attachments}){
        $obj->obliterate;
    }
    foreach my $obj (@{$self->test_runs}){
        $obj->obliterate($cgi, $template);
    }
    foreach my $obj (@{$self->test_cases}){
        $i++;
        if ($cgi && $i % $progress_interval == 0){
            print $cgi->multipart_end;
            print $cgi->multipart_start;
            $vars->{'complete'} = $i;
            $vars->{'total'} = $total;
            $vars->{'process'} = "Deleting test cases";
            
            $template->process("testopia/progress.html.tmpl", $vars)
              || ThrowTemplateError($template->error());
        }
        
        $obj->obliterate if (scalar @{$obj->plans} == 1);
    }

    $dbh->do("DELETE FROM test_plan_texts WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_plan_tags WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_plan_activity WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_plan_permissions WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_plan_permissions_regexp WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_case_plans WHERE plan_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_plans WHERE plan_id = ?", undef, $self->id);
    return 1;
}

=head2 canview

Returns true if the logged in user has rights to view this plan

=cut

sub canview {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('Testers');
    return 1 if $self->get_user_rights(Bugzilla->user->id) & TR_READ;
    return 0;
}

=head2 canedit

Returns true if the logged in user has rights to edit this plan

=cut

sub canedit {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('Testers');
    return 1 if $self->get_user_rights(Bugzilla->user->id) & TR_WRITE;
    return 0;

}

=head2 candelete

Returns true if the logged in user has rights to delete this plan

=cut

sub candelete {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('admin');
    return 0 unless Bugzilla->params->{"allow-test-deletion"};
    return 1 if Bugzilla->user->in_group('Testers') && Bugzilla->params->{"testopia-allow-group-member-deletes"};
    return 1 if $self->get_user_rights(Bugzilla->user->id) & TR_DELETE;
    return 0;
}

sub canadmin {
    my $self = shift;
    return 1 if Bugzilla->user->in_group("admin");
    return 1 if ($self->get_user_rights(Bugzilla->user->id) & TR_ADMIN);
    return 0;
}
  
sub get_user_rights {
    my $self = shift;
    my ($userid) = @_;
    
    my $dbh = Bugzilla->dbh;
    my ($perms) = $dbh->selectrow_array(
        "SELECT permissions FROM test_plan_permissions 
          WHERE userid = ? AND plan_id = ?", 
          undef, ($userid, $self->id));
    
    return $perms || 0;
}

sub TO_JSON {
    my $self = shift;
    my $obj;
    my $json = new JSON;
    
    foreach my $field ($self->DB_COLUMNS){
        $obj->{$field} = $self->{$field};
    }
    
    $obj->{'product_name'} = $self->product->name if $self->product;
    $obj->{'run_count'}    = $self->test_run_count;
    $obj->{'case_count'}   = $self->test_case_count;
    $obj->{'author_name'}  = $self->author->login;
    $obj->{'plan_type'}    = $self->plan_type;
    $obj->{'canedit'}      = $self->canedit;
    $obj->{'canview'}      = $self->canview;
    $obj->{'candelete'}    = $self->candelete;
    $obj->{'link_url'}     = 'tr_show_plan.cgi?plan_id=' . $self->id;
    $obj->{'type'}         = $self->type;
    $obj->{'id'}           = $self->id;
    
    return $json->encode($obj); 
}

###############################
####      Accessors        ####
###############################
=head1 ACCESSOR METHODS

=head2 id

Returns the ID for this object

=head2 creation_date

Returns the creation timestamp for this object

=head2 product_version

Returns the product version for this object

=head2 product_id

Returns the product id for this object

=head2 author

Returns a Bugzilla::User object representing the plan author

=head2 name

Returns the name of this plan

=head2 type_id

Returns the type id of this plan

=head2 isactive

Returns true if this plan is not archived

=cut

sub id              { return $_[0]->{'plan_id'};          }
sub creation_date   { return $_[0]->{'creation_date'};    }
sub product_version { return $_[0]->{'default_product_version'};  }
sub product_id      { return $_[0]->{'product_id'};       }
sub author          { return Bugzilla::User->new($_[0]->{'author_id'});  }
sub name            { return $_[0]->{'name'};    }
sub type_id         { return $_[0]->{'type_id'};    }
sub isactive        { return $_[0]->{'isactive'};  }

=head2 type

Returns 'case'

=cut

sub type {
    my $self = shift;
    $self->{'type'} = 'plan';
    return $self->{'type'};
}

sub tester_regexp { 
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    
    my ($regexp) = $dbh->selectrow_array(
        "SELECT user_regexp 
           FROM test_plan_permissions_regexp
          WHERE plan_id = ?", undef, $self->id);

    return $regexp;
}

sub tester_regexp_permissions { 
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    
    my ($perms) = $dbh->selectrow_array(
        "SELECT permissions 
           FROM test_plan_permissions_regexp
          WHERE plan_id = ?", undef, $self->id);
    my $p;
    
    $p->{'read'}   = $perms >= TR_READ;
    $p->{'write'}  = $perms >= TR_WRITE;
    $p->{'delete'} = $perms >= TR_DELETE;
    $p->{'admin'}  = $perms >= TR_ADMIN;
  
    return $p;
}

sub access_list {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;

    my $ref = $dbh->selectall_arrayref(
        "SELECT tpp.userid, permissions 
           FROM test_plan_permissions AS tpp
           JOIN profiles ON profiles.userid = tpp.userid 
          WHERE plan_id = ? AND grant_type = ?
          ORDER BY profiles.realname", {'Slice' =>{}}, ($self->id, GRANT_DIRECT));
    my @rows;
    foreach my $row (@$ref){
        push @rows, {'user'   => Bugzilla::User->new($row->{'userid'}),
                     'read'   => $row->{'permissions'} >= TR_READ,
                     'write'  => $row->{'permissions'} >= TR_WRITE,
                     'delete' => $row->{'permissions'} >= TR_DELETE,
                     'admin'  => $row->{'permissions'} >= TR_ADMIN,
                    };
    }
    $self->{'access_list'} = \@rows;
    return $self->{'access_list'};
}

sub has_admin {
    my ($self, $deleted) = @_;
    my $dbh = Bugzilla->dbh;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT userid 
           FROM test_plan_permissions
          WHERE plan_id = ? 
            AND userid != ?
            AND permissions >= ?",undef,
            $self->id, $deleted, TR_ADMIN);
    
    return scalar @$ref;
}

=head2 attachments

Returns a reference to a list of attachments on this plan

=cut

sub attachments {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'attachments'} if exists $self->{'attachments'};

    my $attachments = $dbh->selectcol_arrayref(
            "SELECT attachment_id
               FROM test_plan_attachments
              WHERE plan_id = ?", 
             undef, $self->{'plan_id'});
    
    my @attachments;
    foreach my $attach (@{$attachments}){
        push @attachments, Bugzilla::Testopia::Attachment->new($attach);
    }
    $self->{'attachments'} = \@attachments;
    return $self->{'attachments'};
    
}

=head2 bugs

Returns a reference to a list of Bugzilla::Bug objects associated
with this plan

=cut

sub bugs {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'bugs'} if exists $self->{'bugs'};
    my $ref = $dbh->selectcol_arrayref(
          "SELECT DISTINCT bug_id
             FROM test_case_bugs 
             JOIN test_cases ON test_case_bugs.case_id = test_cases.case_id
             JOIN test_case_plans ON test_case_plans.case_id = test_cases.case_id 
            WHERE test_case_plans.plan_id = ?", 
           undef, $self->id);
    my @bugs;
    foreach my $id (@{$ref}){
        push @bugs, Bugzilla::Bug->new($id, Bugzilla->user->id);
    }
    $self->{'bugs'} = \@bugs if @bugs;
    $self->{'bug_list'} = join(',', @$ref);
    return $self->{'bugs'};
}

=head2 product

Returns the product this plan is associated with

=cut

sub product {
    my ($self) = @_;
    
    return $self->{'product'} if exists $self->{'product'};

    $self->{'product'} = Bugzilla::Testopia::Product->new($self->product_id);
    return $self->{'product'};
}

=head2 test_cases

Returns a reference to a list of Testopia::TestCase objects linked
to this plan

=cut

sub test_cases {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'test_cases'} if exists $self->{'test_cases'};
    
    require Bugzilla::Testopia::TestCase;
    
    my $caseids = $dbh->selectcol_arrayref(
            "SELECT case_id FROM test_case_plans
              WHERE plan_id = ?", 
             undef, $self->{'plan_id'});
    my @cases;
    foreach my $id (@{$caseids}){
        push @cases, Bugzilla::Testopia::TestCase->new($id);
    }

    $self->{'test_cases'} = \@cases;
    return $self->{'test_cases'};
}

=head2 test_case_count

Returns a count of the test cases linked to this plan

=cut

sub test_case_count {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'test_case_count'} if exists $self->{'test_case_count'};
    $self->{'test_case_count'} = $dbh->selectrow_array(
                                      "SELECT COUNT(case_id) FROM test_case_plans
                                       WHERE plan_id = ?", 
                                       undef, $self->{'plan_id'}) || 0;
    return $self->{'test_case_count'};
}

=head2 test_runs

Returns a reference to a list of test runs in this plan

=cut

sub test_runs {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'test_runs'} if exists $self->{'test_runs'};

    my $runids = $dbh->selectcol_arrayref("SELECT run_id FROM test_runs
                                          WHERE plan_id = ?", 
                                          undef, $self->{'plan_id'});
    my @runs;
    foreach my $id (@{$runids}){
        push @runs, Bugzilla::Testopia::TestRun->new($id);
    }
    
    $self->{'test_runs'} = \@runs;
    return $self->{'test_runs'};
}

=head2 test_run_count

Returns a count of the test cases linked to this plan

=cut

sub test_run_count {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'test_run_count'} if exists $self->{'test_run_count'};
    $self->{'test_run_count'} = $dbh->selectrow_array(
                                      "SELECT COUNT(run_id) FROM test_runs
                                       WHERE plan_id = ?", 
                                       undef, $self->{'plan_id'}) || 0;
    return $self->{'test_run_count'};
}

sub test_case_run_count {
    my $self = shift;
    my ($status_id) = @_;
    my $dbh = Bugzilla->dbh;
    my $query = 
        "SELECT count(case_run_id) FROM test_case_runs 
         INNER JOIN test_runs ON test_case_runs.run_id = test_runs.run_id
         INNER JOIN test_plans ON test_runs.plan_id = test_plans.plan_id
         WHERE test_case_runs.iscurrent = 1 AND test_plans.plan_id = ?";
       $query .= " AND test_case_runs.case_run_status_id = ?" if $status_id;
    my $count;
    if ($status_id){
        ($count) = $dbh->selectrow_array($query,undef,($self->id,$status_id));
    }
    else {
        ($count) = $dbh->selectrow_array($query,undef,$self->id);
    }
    
    return $count;
}

sub builds_seen {
    my $self = shift;
    my ($status_id) = @_;
    my $dbh = Bugzilla->dbh;
    
    require Bugzilla::Testopia::Build;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT test_case_runs.build_id 
           FROM test_case_runs
     INNER JOIN test_runs ON test_case_runs.run_id = test_runs.run_id
          WHERE test_runs.plan_id = ? AND test_case_runs.iscurrent = 1",
          undef,$self->id);
    
    my @o;      
    foreach my $id (@$ref){
        push @o, Bugzilla::Testopia::Build->new($id);
    }
    return \@o;
}

sub environments_seen {
    my $self = shift;
    my ($status_id) = @_;
    my $dbh = Bugzilla->dbh;
    
    require Bugzilla::Testopia::Environment;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT test_case_runs.environment_id 
           FROM test_case_runs
     INNER JOIN test_runs ON test_case_runs.run_id = test_runs.run_id
          WHERE test_runs.plan_id = ? AND test_case_runs.iscurrent = 1",
          undef,$self->id);
          
    my @o; 
    foreach my $id (@$ref){
        push @o, Bugzilla::Testopia::Environment->new($id);
    }
    return \@o;   
}

=head2 tags

Returns a reference to a list of Testopia::TestTag objects 
associated with this plan

=cut

sub tags {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'tags'} if exists $self->{'tags'};
    my $tagids = $dbh->selectcol_arrayref("SELECT test_plan_tags.tag_id 
                                          FROM test_plan_tags
                                          INNER JOIN test_tags ON test_plan_tags.tag_id = test_tags.tag_id
                                          WHERE plan_id = ?
                                          ORDER BY test_tags.tag_name", 
                                          undef, $self->{'plan_id'});
    my @plan_tags;
    foreach my $t (@{$tagids}){
        push @plan_tags, Bugzilla::Testopia::TestTag->new($t);
    }
    $self->{'tags'} = \@plan_tags;
    return $self->{'tags'};
}

=head2 text

Returns the text of the plan document from the latest version 
in the test_plan_texts table

=cut

sub text {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my ($version) = @_;
    trick_taint($version) if $version;
    return $self->{'text'} if exists $self->{'text'} && !$version;
    
    $version = $version || $self->version;
    
    my $text = $dbh->selectrow_hashref(
        "SELECT plan_text, profiles.realname AS author, plan_text_version AS version
           FROM test_plan_texts AS tpt
          INNER JOIN profiles ON tpt.who = profiles.userid
          WHERE plan_id = ? AND plan_text_version = ?", 
          undef, ($self->{'plan_id'}, $version));
    
    return $text if scalar @_;
    
    $self->{'text'} = $text;
    
    return $self->{'text'};
}


=head2 version

Returns the plan text version. This number is incremented any time
changes are made to the plan document.

=cut

sub version { 
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'version'} if exists $self->{'version'};
    my ($ver) = $dbh->selectrow_array("SELECT MAX(plan_text_version)
                                       FROM test_plan_texts
                                       WHERE plan_id = ?", 
                                       undef, $self->{'plan_id'});

    $self->{'version'} = $ver;
    return $self->{'version'};


}

=head2 type

Returns the type of this plan

=cut

sub plan_type {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'plan_type'} if exists $self->{'plan_type'};
    my ($type) = $dbh->selectrow_array("SELECT name
                                       FROM test_plan_types
                                       WHERE type_id = ?", 
                                       undef, $self->{'type_id'});

    $self->{'plan_type'} = $type;
    return $self->{'plan_type'};
}

=head1 TODO

Use Bugzilla::Product and Version in 2.22

=head1 SEE ALSO

Testopia::(TestRun, TestCase, Category, Build, Util)

=head1 AUTHOR

Greg Hendricks <ghendricks@novell.com>

=cut

1;

__END__

=head1 NAME

Bugzilla::Testopia::TestPlan - Testopia Test Plan object

=head1 DESCRIPTION

This module represents a test plan in Testopia. The test plan
is the glue of testopia. Virtually all other objects associate 
to a plan.

=head1 SYNOPSIS

use Bugzilla::Testopia::TestPlan;

 $plan = Bugzilla::Testopia::TestPlan->new($plan_id);
 $plan = Bugzilla::Testopia::TestPlan->new({});

=cut

=head2 new

Instantiate a new test plan. This takes a single argument 
either a test plan ID or a reference to a hash containing keys 
identical to a test plan's fields and desired values.

=cut
