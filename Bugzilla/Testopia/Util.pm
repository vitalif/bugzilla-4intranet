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
# Contributor(s): Maciej Maczynski <macmac@xdsnet.pl>
#                 Ed Fuentetaja <efuentetaja@acm.org>
#                 Greg Hendricks <ghendricks@novell.com>

=head1 NAME

Bugzilla::Testopia::Util

=head1 DESCRIPTION

This module contains miscillaneous functions used by Testopia. 
It exports all of these functions using Exporter.

=cut

package Bugzilla::Testopia::Util;

use strict;

use base qw(Exporter);
@Bugzilla::Testopia::Util::EXPORT = qw(get_test_field_id get_time_stamp 
                                       validate_test_id validate_selection
                                       support_server_push process_list
                                       percentage);

use Bugzilla;
use Bugzilla::Config;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Util;
#use Bugzilla::Testopia::TestPlan;

### Methods ###

=head2 get_test_field_id

Takes a field name and table and returns the fieldid from the 
test_fielddefs table.

=cut

sub get_test_field_id {
    my ($field, $table) = @_;
    my $dbh = Bugzilla->dbh;

    my ($field_id) = $dbh->selectrow_array(
             "SELECT fieldid 
              FROM test_fielddefs 
              WHERE name = ? AND table_name = ?",
              undef, $field, $table);
    ThrowCodeError('testopia_undefined_field', {fieldname => $field, table => $table}) unless $field_id;
    return $field_id;
}

=head2 get_time_stamp

Returns an SQL timestamp

=cut

sub get_time_stamp {
   my $dbh = Bugzilla->dbh;
   my ($timestamp) = $dbh->selectrow_array("SELECT NOW()");
   return $timestamp;
}

=head2 tc_alias_to_id

Takes a test case alias and returns the corresponding ID

=cut

sub tc_alias_to_id {
    my ($alias) = @_;
    my $dbh = Bugzilla->dbh;
    trick_taint($alias);
    return $dbh->selectrow_array(
        "SELECT case_id FROM test_cases WHERE alias = ?", undef, $alias);
}

=head2 validate_test_id

Takes an ID and a Testopia type and validates it against the database.
In the case of cases it will validate and return an ID from an alias.
Much of this was taken from Bugzilla. This function assumes all tables
in the database are named test_<object>s

=cut

sub validate_test_id {
    my $dbh = Bugzilla->dbh;
    my ($id, $type) = @_;
    $id = trim($id);
    
    # If the ID isn't a number, it might be an alias, so try to convert it.
    my $alias = $id;
    if (!detaint_natural($id) && $type eq 'case') {
        $id = tc_alias_to_id($alias);
        $id || ThrowUserError("testopia-invalid-test-id-or-alias",
                              {'case_id' => $alias});
    }
    
    # Modify the calling code's original variable to contain the trimmed,
    # converted-from-alias ID.
    $_[0] = $id;
    
    # First check that the object exists
    my ($res) = $dbh->selectrow_array("SELECT ". $type. "_id FROM test_". $type."s 
                                       WHERE ". $type ."_id=?",undef, $id);

    $res
      || ThrowUserError("invalid-test-id-non-existent", 
                            {'id' => $alias, 'type' => $type});
    return $res;
}

=head2 validate_selection

Checks that the selected option is a valid one

=cut

sub validate_selection {
    my $dbh = Bugzilla->dbh;
    my ($id, $field, $table) = @_;
    $id = trim($id);
    trick_taint($id);

    my ($res) = $dbh->selectrow_array(
        "SELECT $field 
           FROM $table
          WHERE $field = ?",
          undef, $id);

    $res
      || ThrowUserError("invalid-test-id-non-existent", 
                            {'id' => $id, 'type' => $table});
    return $res;
}

sub support_server_push {
    my ($cgi) = @_;
    my $serverpush =
    exists $ENV{'HTTP_USER_AGENT'} 
      && $ENV{'HTTP_USER_AGENT'} =~ /Mozilla.[3-9]/ 
        && $ENV{'HTTP_USER_AGENT'} !~ /[Cc]ompatible/
          && $ENV{'HTTP_USER_AGENT'} !~ /WebKit/
            && !defined($cgi->param('serverpush'))
              || $cgi->param('serverpush');
              
  return $serverpush;            
}

sub percentage {
  my ($total, $count) = (@_);
  return $total == 0 ? 0 : int($count*100/$total);
}


=head2 update

Updates this test plan with new values supplied by the user.
Accepts a reference to a hash with keys identical to a test plan's
fields and values representing the new values entered.
Validation tests should be performed on the values 
before calling this method. If a field is changed, a history 
of that change is logged in the test_plan_activity table.

=cut


sub log_activity {
    my ($type, $obj_id, $field, $timestamp, $oldvalue, $newvalue) = @_;
    my $dbh = Bugzilla->dbh;
    $timestamp ||= get_time_stamp();
    
    trick_taint($newvalue) if defined $newvalue;
    my $field_id = Bugzilla::Testopia::Util::get_test_field_id($field, "test_". $type ."s");
    $dbh->do("INSERT INTO test_". $type ."_activity 
              (". $type . "_id, fieldid, who, changed, oldvalue, newvalue)
                   VALUES(?,?,?,?,?,?)",
              undef, ($obj_id, $field_id, Bugzilla->user->id,
              $timestamp, $oldvalue, $newvalue));
    
}

sub process_list { 
    my ($ids) = @_;
    
    my @ids;
    if (ref $ids eq 'ARRAY'){
        @ids = @$ids;
    }
    elsif ($ids =~ /,/){
        @ids = split(/[\s,]+/, $ids);
    }
    else {
        push @ids, $ids if $ids;
    }
    
    return @ids;
}

=head1 AUTHOR

Greg Hendricks <ghendricks@novell.com>

=cut

1;
