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
#                 Ed Fuentetaja <efuentetaja@acm.org>
#                 Joel Smith <jsmith@novell.com>

package Bugzilla::Testopia::TestRun;

use strict;

use Bugzilla::Util;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Bug;
use Bugzilla::Config;

use Bugzilla::Testopia::Constants;
use Bugzilla::Testopia::Environment;
use Bugzilla::Testopia::Build;

use JSON;
use Date::Parse;
use base qw(Exporter Bugzilla::Object);

@Bugzilla::Testopia::TestRun::EXPORT = qw(calculate_percent);

###############################
####    Initialization     ####
###############################

use constant DB_TABLE => "test_runs";
use constant NAME_FIELD => "summary";
use constant ID_FIELD => "run_id";
use constant DB_COLUMNS => qw(
    run_id
    plan_id
    environment_id
    product_version
    build_id
    plan_text_version
    manager_id  
    start_date
    stop_date
    summary
    notes
    target_pass
    target_completion
);

sub report_columns {
    my $self = shift;
    my %columns;
    # Changes here need to match Report.pm
    $columns{'Status'}        = "run_status";        
    $columns{'Version'}       = "default_product_version";
    $columns{'Product'}       = "product";
    $columns{'Build'}         = "build";
    $columns{'Milestone'}     = "milestone";
    $columns{'Environment'}   = "environment";
    $columns{'Tags'}          = "tags";
    $columns{'Manager'}       = "manager";
    my @result;
    push @result, {'name' => $_, 'id' => $columns{$_}} foreach (sort(keys %columns));
    unshift @result, {'name' => '<none>', 'id'=> ''};
    return \@result;     
        
}

use constant REQUIRED_CREATE_FIELDS => qw(plan_id environment_id build_id 
                                          product_version summary manager_id 
                                          plan_text_version);

use constant UPDATE_COLUMNS         => qw(environment_id build_id product_version 
                                          summary manager_id plan_text_version notes
                                          stop_date target_pass target_completion);

use constant VALIDATORS => {
    plan_id           => \&_check_plan,
    environment_id    => \&_check_env,
    build_id          => \&_check_build,
    summary           => \&_check_summary,
    manager_id        => \&_check_manager,
    plan_text_version => \&_check_plan_text_version,
    notes             => \&_check_notes,
    target_pass       => \&_check_target,
    target_completion => \&_check_target,
};

###############################
####       Validators      ####
###############################
sub _check_plan {
    my ($invocant, $plan_id) = @_;
    trick_taint($plan_id);
    ThrowUserError('testopia-missing-required-field', {'field' => 'plan'}) unless $plan_id;
    Bugzilla::Testopia::Util::validate_test_id($plan_id, 'plan');
    return $plan_id;
}

sub _check_env {
    my ($invocant, $env_id) = @_;
    trick_taint($env_id);
    ThrowUserError('testopia-missing-required-field', {'field' => 'environment'}) unless $env_id;
    Bugzilla::Testopia::Util::validate_test_id($env_id, 'environment');
    return $env_id;
}

sub _check_build {
    my ($invocant, $build_id) = @_;
    trick_taint($build_id);
    ThrowUserError('testopia-missing-required-field', {'field' => 'build'}) unless $build_id;
    Bugzilla::Testopia::Util::validate_test_id($build_id, 'build');
    return $build_id;
}

sub _check_product_version {
    my ($invocant, $version, $product) = @_;
    if (ref $invocant){
        $product = $invocant->plan->product;
    }
    $version = trim($version);
    trick_taint($version);
    $version = Bugzilla::Version->check({product => $product, name => $version});
    return $version->name;
}

sub _check_summary{
    my ($invocant, $summary) = @_;
    $summary = clean_text($summary) if $summary;
    trick_taint($summary);
    if (!defined $summary || $summary eq '') {
        ThrowUserError('testopia-missing-required-field', {'field' => 'summary'});
    }
    return $summary;
}

sub _check_manager {
    my ($invocant, $login) = @_;
    $login = trim($login);
    ThrowUserError('testopia-missing-required-field', {'field' => 'manager'}) unless $login;
    if ($login =~ /^\d+$/){
        $login = Bugzilla::User->new($login);
        return $login->id;
    }
    else {
        my $id = login_to_id($login, THROW_ERROR);
        return $id;
    }
}

#TODO: Check that version is in plan versions
sub _check_plan_text_version {
    my ($invocant, $version) = @_;
    trick_taint($version);
    ThrowUserError('testopia-missing-required-field', {'field' => 'plan_version'}) unless $version;
    return $version;
}

sub _check_notes {
    my ($invocant, $notes) = @_;
    trick_taint($notes);
    $notes = trim($notes);
    $notes =~ s/\n$//;
    return $notes;
}

sub _check_target {
    my ($invocant, $target) = @_;
    detaint_natural($target);
    return unless $target;
    ThrowUserError('invalid_target') unless $target >= 0 && $target <= 100;
    return $target;
}

###############################
####       Mutators        ####
###############################
sub set_environment        { $_[0]->set('environment_id', $_[1]); }
sub set_build              { $_[0]->set('build_id', $_[1]); }
sub set_summary            { $_[0]->set('summary', $_[1]); }
sub set_manager            { $_[0]->set('manager_id', $_[1]); }
sub set_plan_text_version  { $_[0]->set('plan_text_version', $_[1]); }
sub set_notes              { $_[0]->set('notes', $_[1]); }
sub set_stop_date          { $_[0]->set('stop_date', $_[1]); }
sub set_target_pass        { $_[0]->set('target_pass', $_[1]); }
sub set_target_completion  { $_[0]->set('target_completion', $_[1]); }

sub set_product_version    { 
    my ($self, $value) = @_;
    $value = $self->_check_product_version($value);
    $self->set('product_version', $value); 
}

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $param = shift;
    
    # We want to be able to supply an empty object to the templates for numerous
    # lists etc. This is much cleaner than exporting a bunch of subroutines and
    # adding them to $vars one by one. Probably just Laziness shining through.
    if (ref $param eq 'HASH'){
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
    my $plan = Bugzilla::Testopia::TestPlan->new($params->{plan_id});
    
    $params->{product_version} = $class->_check_product_version($params->{product_version}, $plan->product);
    
    return $params;
}

sub create {
    my ($class, $params) = @_;
    require Bugzilla::Testopia::TestPlan;
    
    $class->SUPER::check_required_create_fields($params);
    my $field_values = $class->run_create_validators($params);
    my $timestamp = Bugzilla::Testopia::Util::get_time_stamp();
    $field_values->{start_date} = $timestamp; 
    $field_values->{stop_date} = Bugzilla::Testopia::Util::get_time_stamp() if $field_values->{status} == 0;  
    delete $field_values->{status};
    
    my $self = $class->SUPER::insert_create_data($field_values);

    return $self;
}

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $timestamp = Bugzilla::Testopia::Util::get_time_stamp();

    $dbh->bz_start_transaction();
    
    my $changed = $self->SUPER::update();

    foreach my $field (keys %$changed){
        Bugzilla::Testopia::Util::log_activity('run', $self->id, $field, $timestamp, $changed->{$field}->[0], $changed->{$field}->[1]);
    }

    $dbh->bz_commit_transaction();
}

###############################
####       Methods         ####
###############################

=head2 calculate_percent_completed

Calculates a percentage from two numbers. Takes the total number
of IDLE case runs and the number of those that have another status
and adds them to get a total then takes the percentage.

=cut

sub calculate_percent {
  my ($total, $count) = (@_);
  my $percent;
  if ($total == 0) {
    $percent = 0;
  } else {
    $percent = $count*100/$total;
    $percent = int($percent + 0.5);
    if (($percent == 100) && ($count != $total)) {
      #I don't want to see 100% unless every test is run
      $percent = 99;
    }
  }
  return $percent; 
}

=head2 add_cc

Adds a user to the CC list for this run

=cut

sub add_cc{
    my $self = shift;
    my ($ccid) = (@_);
    my $dbh = Bugzilla->dbh;
    $dbh->do("INSERT INTO test_run_cc(run_id, who) 
              VALUES (?,?)", undef, $self->{'run_id'}, $ccid);
    #TODO: send mail
    return 1;
}

=head2 remove_cc

Removes a user from the CC list of this run

=cut

sub remove_cc{
    my $self = shift;
    my ($ccid) = (@_);
    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM test_run_cc 
              WHERE run_id=? AND who=?", 
              undef, $self->{'run_id'}, $ccid);
    #TODO: send mail
    return 1;
}

=head2 add_tag

Associates a tag with this test run

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

Disassociates a tag from this test run

=cut

sub remove_tag {    
    my $self = shift;
    my ($tag_name) = @_;
    my $tag = Bugzilla::Testopia::TestTag->check_tag($tag_name);
    ThrowUserError('testopia-unknown-tag', {'name' => $tag}) unless $tag;
    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM test_run_tags 
              WHERE tag_id=? AND run_id=?",
              undef, $tag->id, $self->{'run_id'});
    return;
}

=head2 add_case_run

Associates a test case with this run by adding a new row to 
the test_case_runs table

=cut

sub add_case_run {
    my $self = shift;
    my ($case_id, $sortkey, $status) = @_;
    $status ||=IDLE;
    trick_taint($case_id);
    return 0 if $self->check_case($case_id);
    my $case = Bugzilla::Testopia::TestCase->new($case_id);
    $sortkey = $case->sortkey unless $sortkey;

    return 0 if $case->status ne 'CONFIRMED';
    my $assignee = $case->default_tester ? $case->default_tester->id : undef;
    my $caserun = Bugzilla::Testopia::TestCaseRun->create({
        'run_id'     => $self->{'run_id'},
        'case_id'    => $case_id,
        'assignee'   => $assignee,
        'case_text_version'  => $case->version,
        'build_id'           => $self->build->id,
        'environment_id'     => $self->environment_id,
        'case_run_status_id' => $status,
        'sortkey'            => $sortkey,
    });
    return 1;
}

=head2 store

Stores a test run object in the database. This method is used to store a 
newly created test run. It returns the new ID.

=cut

sub store {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    # Exclude the auto-incremented field from the column list.
    my $columns = join(", ", grep {$_ ne 'run_id'} DB_COLUMNS);
    my $timestamp = Bugzilla::Testopia::Util::get_time_stamp();

    $dbh->do("INSERT INTO test_runs ($columns) VALUES (?,?,?,?,?,?,?,?,?,?)",
              undef, ($self->{'plan_id'}, $self->{'environment_id'},
              $self->{'product_version'}, $self->{'build_id'}, 
              $self->{'plan_text_version'}, $self->{'manager_id'}, 
              $timestamp, undef, $self->{'summary'}, $self->{'notes'}));
    my $key = $dbh->bz_last_key( 'test_runs', 'run_id' );
    return $key;
}

=head2 update_notes

Updates just the notes for this run

=cut

sub update_notes {
    my $self = shift;
    my ($notes) = @_;
    my $dbh = Bugzilla->dbh;
    $dbh->do("UPDATE test_runs 
              SET notes = ? WHERE run_id = ?",
              undef, $notes, $self->{'run_id'});
}

=head2 clone

Creates a copy of this test run. Accepts the summary of the new run
and the build id to use.

=cut

sub clone {
    my $self = shift;
    my ($summary, $manager, $plan_id, $build_id, $env_id) = @_;
    my $dbh = Bugzilla->dbh;
    # Exclude the auto-incremented field from the column list.
    my $columns = join(", ", grep {$_ ne 'run_id'} DB_COLUMNS);
    my $timestamp = Bugzilla::Testopia::Util::get_time_stamp();

    $dbh->do("INSERT INTO test_runs ($columns) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
              undef, ($plan_id, $env_id,
              $self->{'product_version'}, $build_id, 
              $self->{'plan_text_version'}, $manager, 
              $timestamp, undef, $summary, undef, 
              $self->{'target_pass'}, $self->{'target_completion'}));
    my $key = $dbh->bz_last_key( 'test_runs', 'run_id' );
    return $key;   
}

=head2 history

Returns a reference to a list of history entries from the 
test_run_activity table.

=cut

sub history {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectall_arrayref(
            "SELECT defs.description AS what, 
                    p.login_name AS who, a.changed, a.oldvalue, a.newvalue
               FROM test_run_activity AS a
               JOIN test_fielddefs AS defs ON a.fieldid = defs.fieldid
               JOIN profiles AS p ON a.who = p.userid
              WHERE a.run_id = ?",
              {'Slice'=>{}}, $self->{'run_id'});

    foreach my $row (@$ref){
        if ($row->{'what'} eq 'Environment'){
            $row->{'oldvalue'} = $self->lookup_environment($row->{'oldvalue'});
            $row->{'newvalue'} = $self->lookup_environment($row->{'newvalue'});
        }
        elsif ($row->{'what'} eq 'Default Build'){
            $row->{'oldvalue'} = $self->lookup_build($row->{'oldvalue'});
            $row->{'newvalue'} = $self->lookup_build($row->{'newvalue'});
        }
        elsif ($row->{'what'} eq 'Manager'){
            $row->{'oldvalue'} = $self->lookup_manager($row->{'oldvalue'});
            $row->{'newvalue'} = $self->lookup_manager($row->{'newvalue'});
        }
    }        
    return $ref;
}

=head2 obliterate

Removes this run and all things that reference it.

=cut

sub obliterate {
    my $self = shift;
    my ($cgi, $template) = @_;
    my $dbh = Bugzilla->dbh;
    my $vars;
    
    my $progress_interval = 500;
    my $i = 0;
    my $total = scalar @{$self->caseruns};
    
    foreach my $obj (@{$self->caseruns}){
        $i++;
        if ($cgi && $i % $progress_interval == 0){
            print $cgi->multipart_end;
            print $cgi->multipart_start;
            $vars->{'complete'} = $i;
            $vars->{'total'} = $total;
            $vars->{'process'} = "Deleting Run " . $self->id;
        
            $template->process("testopia/progress.html.tmpl", $vars)
              || ThrowTemplateError($template->error());
        }
    
        $obj->obliterate;
    }

    $dbh->do("DELETE FROM test_run_cc WHERE run_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_run_tags WHERE run_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_run_activity WHERE run_id = ?", undef, $self->id);
    $dbh->do("DELETE FROM test_runs WHERE run_id = ?", undef, $self->id);
    return 1;
}

=head2 Check_case

Checks if the given test case is already associated with this run

=cut

sub check_case {
    my $self = shift;
    my ($case_id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT case_run_id 
               FROM test_case_runs
              WHERE case_id = ? AND run_id = ?",
              undef, ($case_id, $self->{'run_id'}));
    return $value;
}

sub TO_JSON {
    my $self = shift;
    my $obj;
    my $json = new JSON;
    my $rc = $self->case_run_count;
    
    $self->bugs();
    
    foreach my $field ($self->DB_COLUMNS){
        $obj->{$field} = $self->{$field};
    }
    $obj->{'plan'}          = { id => $self->plan->id, product_id => $self->plan->product_id} if $self->plan;
    $obj->{'build'}         = { id => $self->build->id, name => $self->build->name} if $self->build;
    $obj->{'environment'}   = { id => $self->environment->id, name => $self->environment->name} if $self->environment;
    $obj->{'case_count'}    = $self->case_run_count;
    $obj->{'manager'}       = { login_name => $self->manager->login, name => $self->manager->name} if $self->manager;
    $obj->{'manager_name'}  = $self->manager->name if $self->manager;
    $obj->{'canedit'}       = $self->canedit;
    $obj->{'canview'}       = $self->canview;
    $obj->{'candelete'}     = $self->candelete;
    $obj->{'status'}        = $self->stop_date ? 'STOPPED' : 'RUNNING';
    $obj->{'type'}          = $self->type;
    $obj->{'id'}            = $self->id;
    $obj->{'product_id'}    = $self->plan->product_id if $self->plan;
    $obj->{'passed_pct'}    = $self->case_run_count(PASSED) / $rc if $rc; 
    $obj->{'failed_pct'}    = $self->case_run_count(FAILED) / $rc if $rc;
    $obj->{'blocked_pct'}   = $self->case_run_count(BLOCKED) / $rc if $rc;
    $obj->{'complete_pct'}  = $self->percent_complete() . '%';
    $obj->{'bug_list'}      = $self->{'bug_list'};
    
    return $json->encode($obj); 
}

=head2 lookup_environment

Takes an ID of the envionment field and returns the value

=cut

sub lookup_environment {
    my $self = shift;
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT name 
               FROM test_environments
              WHERE environment_id = ?",
              undef, $id);
    return $value;
}

=head2 lookup_environment_by_name

Takes the name of an envionment and returns its id

=cut

sub lookup_environment_by_name {
    my ($name) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT environment_id 
               FROM test_environments
              WHERE name = ?",
              undef, $name);
    return $value;
}

=head2 lookup_build

Takes an ID of the build field and returns the value

=cut

sub lookup_build {
    my $self = shift;
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT name 
               FROM test_builds
              WHERE build_id = ?",
              undef, $id);
    return $value;
}

=head2 lookup_manager

Takes an ID of the manager field and returns the value

=cut

sub lookup_manager {
    my $self = shift;
    my ($id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($value) = $dbh->selectrow_array(
            "SELECT login_name 
               FROM profiles
              WHERE userid = ?",
              undef, $id);
    return $value;
}

=head2 last_changed

Returns the date of the last change in the history table

=cut

sub last_changed {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my ($date) = $dbh->selectrow_array(
            "SELECT MAX(changed)
               FROM test_run_activity 
              WHERE run_id = ?",
              undef, $self->id);

    return $self->{'creation_date'} unless $date;
    return $date;
}

sub filter_case_categories {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my $ids = $dbh->selectcol_arrayref(
            "SELECT DISTINCT tcc.category_id, tcc.name
               FROM test_case_categories AS tcc
               JOIN test_cases ON test_cases.category_id = tcc.category_id
               JOIN test_case_runs AS tcr ON test_cases.case_id = tcr.case_id  
              WHERE run_id = ?
              ORDER BY tcc.name",
              undef, $self->id);
    
    my @categories;
    foreach my $id (@$ids){
        push @categories, Bugzilla::Testopia::Category->new($id);
    }
    
    return \@categories;
}

sub filter_builds {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my $ids = $dbh->selectcol_arrayref(
            "SELECT DISTINCT test_case_runs.build_id, test_builds.name
               FROM test_case_runs
               INNER JOIN test_builds on test_builds.build_id = test_case_runs.build_id
              WHERE run_id = ?
              ORDER BY test_builds.name",
              undef, $self->id);
    
    my @builds;
    foreach my $id (@$ids){
        push @builds, Bugzilla::Testopia::Build->new($id);
    }
    return \@builds;
}

sub filter_components {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my $ids = $dbh->selectcol_arrayref(
            "SELECT DISTINCT components.id, components.name
               FROM components
               JOIN test_case_components AS tcc ON tcc.component_id = components.id
               JOIN test_cases ON test_cases.case_id = tcc.case_id
               JOIN test_case_runs AS tcr ON test_cases.case_id = tcr.case_id  
              WHERE run_id = ?
              ORDER BY components.name",
              undef, $self->id);
    
    my @components;
    foreach my $id (@$ids){
        push @components, Bugzilla::Component->new($id);
    }
    
    return \@components;
}

=head2 environments

Returns a reference to a list of Testopia::Environment objects.

=cut

sub environments {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'environments'} if exists $self->{'environments'};

    my $environments = 
      $dbh->selectcol_arrayref("SELECT environment_id
                                FROM test_environments");
    
    my @environments;
    foreach my $id (@{$environments}){
        push @environments, Bugzilla::Testopia::Environment->new($id);
    }
    $self->{'environments'} = \@environments;
    return $self->{'environments'};
}

=head2 get_status_list

Returns a list of statuses for a run

=cut

sub get_status_list {
    my @status = (
        { 'id' => 1, 'name' => 'RUNNING' },
        { 'id' => 0, 'name' => 'STOPPED' },
    );
    return \@status;
}


=head2 get_fields

Returns a reference to a list of test run field descriptions from 
the test_fielddefs table. 

=cut

sub get_fields {
    my $self = shift;
    my $dbh = Bugzilla->dbh;    

    my $types = $dbh->selectall_arrayref(
            "SELECT fieldid AS id, description AS name 
             FROM test_fielddefs 
             WHERE table_name=?", 
             {"Slice"=>{}}, "test_runs");
    unshift @$types, {id => '[Creation]', name => '[Started]'};
    return $types;
}

=head2 get_distinct_builds

Returns a list of build names for use in searches

=cut

sub get_distinct_builds {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $query = "SELECT build.name AS id, build.name " .
                  "FROM test_builds AS build " .
                  "JOIN products ON build.product_id = products.id " .
             "LEFT JOIN group_control_map " .
              "ON group_control_map.product_id = products.id ";
    if (Bugzilla->params->{'useentrygroupdefault'}) {
        $query .= "AND group_control_map.entry != 0 ";
    } else {
        $query .= "AND group_control_map.membercontrol = " .
              CONTROLMAPMANDATORY . " ";
    }
    if (@{Bugzilla->user->groups}) {
        $query .= "AND group_id NOT IN(" . 
              join(',', map { $_->id } @{Bugzilla->user->groups}) . ") ";
    }
    $query .= "WHERE group_id IS NULL AND build.isactive = 1 ORDER BY build.name";
    
    my $ref = $dbh->selectall_arrayref($query, {'Slice'=>{}});

    return $ref;             
}

=head2 get_distinct_milestones

Returns a list of milestones for use in searches

=cut

sub get_distinct_milestones {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectall_arrayref(
            "SELECT DISTINCT value AS id, value as name
             FROM milestones
             ORDER BY sortkey", {'Slice'=>{}});

    return $ref;             
}

=head2 get_environments

Returns a list of environments for use in searches

=cut

sub get_environments {
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectall_arrayref(
                "SELECT DISTINCT name AS id, name
                 FROM test_environments
                 ORDER BY name",
                 {'Slice'=>{}});
                 
    return $ref;
}

=head2 canview

Returns true if the logged in user has rights to view this test run.

=cut

sub canview {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('Testers');
    return 1 if $self->plan->get_user_rights(Bugzilla->user->id) & TR_READ;
    return 0;

}

=head2 canedit

Returns true if the logged in user has rights to edit this test run.

=cut

sub canedit {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('Testers');
    return 1 if $self->plan->get_user_rights(Bugzilla->user->id) & TR_WRITE;
    return 0;
}

# Only certain people are able to change the status of a run.
sub canstatus {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('admin');
    return 1 if $self->plan->get_user_rights(Bugzilla->user->id) & TR_ADMIN;
    return 1 if $self->manager->id == Bugzilla->user->id;
    return 0;
}

=head2 candelete

Returns true if the logged in user has rights to delete this test run.

=cut

sub candelete {
    my $self = shift;
    return 1 if Bugzilla->user->in_group('admin');
    return 0 unless Bugzilla->params->{"allow-test-deletion"};
    return 1 if Bugzilla->user->in_group('Testers') && Bugzilla->params->{"testopia-allow-group-member-deletes"};
    return 1 if $self->plan->get_user_rights(Bugzilla->user->id) & TR_DELETE;
    return 0;
}

sub completion_percent {
    my $self = shift;
    my ($products, $plans, $runs) = @_;
    my $dbh = Bugzilla->dbh;
    my @runs;
    foreach my $p (@$products){
        foreach my $plan (@{$p->plans}){
            push @runs, $_->id foreach (@{$plan->test_runs});
        }
    }
    push @runs, $_->id foreach (@{$plans->test_runs});
    push @runs, $_->id foreach (@$runs);
    return 0 unless scalar @runs;
    
    my $run_ids = join (',',@runs);
    
    
}

sub total_time {
    my $self = shift;

    return 0 unless $self->stop_date;
    
    my $seconds = str2time($self->stop_date) - str2time($self->start_date);    
    
    my @time = gmtime($seconds);
    my %time;
    
    $time{day} = $time[7];
    $time{hr}  = $time[2];
    $time{min} = $time[1];
    $time{sec} = $time[0];

    return $time{day}.":".$time{hr}.":".$time{min}.":".$time{sec};
}

###############################
####      Accessors        ####
###############################

=head1 ACCESSOR METHODS

=head2 id

Returns the ID for this object

=head2 plan_text_version

Returns the plan's text version of this run

=head2 plan_id

Returns the  plan idof this run

=head2 environment_id

Returns the environment id of this run

=head2 manager

Returns a Bugzilla::User object representing the run's manager

=head2 start_date

Returns the time stamp of when this run was started

=head2 stop_date

Returns the  time stamp of when this run was completed

=head2 summary

Returns the summary of this run

=head2 notes

Returns the notes for this run

=head2 product_version

Returns the product version of this run

=cut

sub id                { return $_[0]->{'run_id'};          }
sub plan_text_version { return $_[0]->{'plan_text_version'};  }
sub plan_id           { return $_[0]->{'plan_id'};  }
sub environment_id    { return $_[0]->{'environment_id'};  }
sub manager           { return Bugzilla::User->new($_[0]->{'manager_id'});  }
sub start_date        { return $_[0]->{'start_date'};        }
sub stop_date         { return $_[0]->{'stop_date'}; }
sub summary           { return $_[0]->{'summary'};  }
sub notes             { return $_[0]->{'notes'};  }
sub product_version   { return $_[0]->{'product_version'};  }
sub target_pass       { return $_[0]->{'target_pass'};  }
sub target_completion { return $_[0]->{'target_completion'};  }

=head2 type

Returns 'case'

=cut

sub type {
    my $self = shift;
    $self->{'type'} = 'run';
    return $self->{'type'};
}

=head2 plan

Returns the Testopia::TestPlan object of the plan this run 
is assoceated with

=cut

sub plan {
    my $self = shift;
    return $self->{'plan'} if exists $self->{'plan'};
    require Bugzilla::Testopia::TestPlan;
    $self->{'plan'} = Bugzilla::Testopia::TestPlan->new($self->{'plan_id'});
    return $self->{'plan'};
}

=head2 tags

Returns a reference to a list of Testopia::TestTag objects 
associated with this run

=cut

sub tags {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return $self->{'tags'} if exists $self->{'tags'};
    my $tagids = $dbh->selectcol_arrayref("SELECT test_run_tags.tag_id 
                                          FROM test_run_tags
                                          INNER JOIN test_tags ON test_run_tags.tag_id = test_tags.tag_id
                                          WHERE run_id = ?
                                          ORDER BY test_tags.tag_name", 
                                          undef, $self->{'run_id'});
    my @tags;
    foreach my $t (@{$tagids}){
        push @tags, Bugzilla::Testopia::TestTag->new($t);
    }
    $self->{'tags'} = \@tags;
    return $self->{'tags'};
}

=head2 environment

Returns the Testopia::Environment object of the environment 
this run is assoceated with

=cut

sub environment {
    my $self = shift;
    return $self->{'environment'} if exists $self->{'environment'};
    $self->{'environment'} = Bugzilla::Testopia::Environment->new($self->{'environment_id'});
    return $self->{'environment'};
    
}

=head2 build

Returns the Testopia::Build object of the plan this run 
is assoceated with

=cut

sub build {
    my $self = shift;
    return $self->{'build'} if exists $self->{'build'};
    $self->{'build'} = Bugzilla::Testopia::Build->new($self->{'build_id'});
    return $self->{'build'};
    
}

=head2 runtime

Returns the total time the run took to complete

=cut

sub runtime {
    
}

=head2 bugs

Returns a reference to a list of Bugzilla::Bug objects associated
with this run

=cut

sub bugs {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'bugs'} if exists $self->{'bugs'};
    my $ref = $dbh->selectcol_arrayref(
          "SELECT DISTINCT bug_id
             FROM test_case_bugs b
             JOIN test_case_runs r ON r.case_run_id = b.case_run_id
            WHERE r.run_id = ? AND r.iscurrent = 1 ORDER BY bug_id", 
           undef, $self->{'run_id'});
    my @bugs;
    foreach my $id (@{$ref}){
        push @bugs, Bugzilla::Bug->new($id, Bugzilla->user->id);
    }
    $self->{'bugs'} = \@bugs if @bugs;
    $self->{'bug_list'} = join(',', @$ref);
    return $self->{'bugs'};
}

=head2 cc

Returns a reference to a list of Bugzilla::User objects
on the CC list of this run

=cut

sub cc {
    my $self = shift;
    return $self->{'cc'} if exists $self->{'cc'};
    my $dbh = Bugzilla->dbh;
    my $ref = $dbh->selectcol_arrayref(
        "SELECT who FROM test_run_cc 
         WHERE run_id=?", undef, $self->{'run_id'});
    my @cc;     
    foreach my $id (@{$ref}){
        push @cc, Bugzilla::User->new($id);
    }
    $self->{'cc'} = \@cc;
    return $self->{'cc'};
}

=head2 cases

Returns a reference to a list of Testopia::TestCase objects 
associated with this run

=cut

sub cases {
    my $self = shift;
    return $self->{'cases'} if exists $self->{'cases'};
    my @cases;
    foreach my $cr (@{$self->current_caseruns}){
        push @cases, Bugzilla::Testopia::TestCase->new($cr->case_id);
    }
    $self->{'cases'} = \@cases;
    return $self->{'cases'};
    
}

sub case_ids {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'case_ids'} if exists $self->{'case_ids'};
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT case_id FROM test_case_runs
         WHERE run_id=? AND iscurrent=1", undef,
         $self->{'run_id'});
    
    $self->{'case_ids'} = $ref;
    return $self->{'case_ids'};
    
}

=head2 case_count

Returns a count of the test cases associated with this run

=cut

sub case_count {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    
    my ($count) = $dbh->selectrow_array(
                    "SELECT COUNT(case_run_id) FROM test_case_runs
                      WHERE run_id=? AND iscurrent=1", undef,
                      $self->{'run_id'});

    return scalar $count;
}

sub case_run_count {
    my $self = shift;
    my ($status_id, $runs, $plans, $products) = @_;    
    my $dbh = Bugzilla->dbh;
    
    my @runs;
    if ($products){
        foreach my $p (@$products){
            foreach my $plan (@{$p->plans}){
                push @runs, $_->id foreach (@{$plan->test_runs});
            }
        }
    }
    if ($plans){
        push @runs, $_->id foreach (@{$plans->test_runs});
    }
    if ($runs){
        push @runs, $_->id foreach (@$runs);
    }
    push @runs, $self->id if $self->id;
    
    return 0 unless scalar @runs > 0;
    
    my $run_ids = join (',', @runs);

    my $query = 
           "SELECT COUNT(*) 
              FROM test_case_runs 
             WHERE run_id IN (" . $run_ids .") AND iscurrent = 1";
    $query .= " AND case_run_status_id = ?" if $status_id;
    
    my $count;
    if ($status_id){
        ($count) = $dbh->selectrow_array($query,undef,($status_id));
    }
    else {
        ($count) = $dbh->selectrow_array($query);
    }

    return $count;
}

sub case_run_count_by_date {
    my $self = shift;
    my ($start, $stop, $status_id, $tester, $runs, $plans, $products) = @_;    
    my $dbh = Bugzilla->dbh;
    
    my @runs;
    if ($products){
        foreach my $p (@$products){
            foreach my $plan (@{$p->plans}){
                push @runs, $_->id foreach (@{$plan->test_runs});
            }
        }
    }
    if ($plans){
        push @runs, $_->id foreach (@{$plans->test_runs});
    }
    if ($runs){
        push @runs, $_->id foreach (@$runs);
    }
    push @runs, $self->id if $self->id;
    
    return 0 unless scalar @runs > 0;
    
    my $run_ids = join (',', @runs);

    my $query = 
           "SELECT COUNT(*) 
              FROM test_case_runs 
             WHERE run_id IN (" . $run_ids .") 
               AND close_date >= ?
               AND close_date <= ?
               AND iscurrent = 1";
    $query .= " AND case_run_status_id = ?" if $status_id;
    $query .= " AND testedby = $tester" if $tester;
    
    my $count;
    if ($status_id){
        ($count) = $dbh->selectrow_array($query,undef,($start,$stop,$status_id));
    }
    else {
        ($count) = $dbh->selectrow_array($query,undef,($start,$stop));
    }

    return $count;
}

sub case_run_count_by_priority {
    my $self = shift;
    my ($priority, $status_id, $runs, $plans, $products) = @_;    
    trick_taint($priority);
    my $dbh = Bugzilla->dbh;
    
    my @runs;
    if ($products){
        foreach my $p (@$products){
            foreach my $plan (@{$p->plans}){
                push @runs, $_->id foreach (@{$plan->test_runs});
            }
        }
    }
    if ($plans){
        push @runs, $_->id foreach (@{$plans->test_runs});
    }
    if ($runs){
        push @runs, $_->id foreach (@$runs);
    }
    push @runs, $self->id if $self->id;
    
    return 0 unless scalar @runs > 0;
    
    my $run_ids = join (',', @runs);

    my $query = 
           "SELECT COUNT(*) 
              FROM test_case_runs
        INNER JOIN test_cases on test_case_runs.case_id = test_cases.case_id 
             WHERE run_id IN (" . $run_ids .") 
               AND test_cases.priority_id = ?
               AND iscurrent = 1";
    $query .= " AND case_run_status_id = ?" if $status_id;

    my $count;
    if ($status_id){
        ($count) = $dbh->selectrow_array($query,undef,($priority, $status_id));
    }
    else {
        ($count) = $dbh->selectrow_array($query,undef,($priority));
    }

    return $count;
}

sub finished_count {
    my $self = shift;
    my ($status_id) = @_;
    my $dbh = Bugzilla->dbh;
    my ($count) = $dbh->selectrow_array( 
           "SELECT COUNT(*) 
              FROM test_case_runs 
             WHERE run_id = ? AND iscurrent = 1
               AND case_run_status_id IN (?,?,?)",undef, ($self->id, FAILED, PASSED, BLOCKED)); 
        
    return $count;       
}



=head2 percent_complete

Returns a number representing the percentage of case-runs
that have a status vs. those with a status of IDLE

=cut

sub percent_complete {    
    my $self = shift;
    return $self->{'percent_complete'} if defined $self->{'percent_complete'};
    $self->{'percent_complete'} = calculate_percent($self->case_run_count,$self->finished_count);
    return $self->{'percent_complete'};
}

sub percent_of_total {
    my $self = shift;
    my ($status_id) = @_;
    return calculate_percent($self->case_run_count,$self->case_run_count($status_id));    
}

sub percent_of_finished {
    my $self = shift;
    my ($status_id) = @_;
    return calculate_percent($self->finished_count,$self->case_run_count($status_id));        
}

=head2 current_caseruns

Returns a reference to a list of TestCaseRun objects that are the
current case-runs on this run

=cut

sub current_caseruns {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'current_caseruns'} if exists $self->{'current_caseruns'};
    
    require Bugzilla::Testopia::TestCaseRun;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT case_run_id FROM test_case_runs
         WHERE run_id=? AND iscurrent=1", undef,
         $self->{'run_id'});
    my @caseruns;
    
    foreach my $id (@{$ref}){
        push @caseruns, Bugzilla::Testopia::TestCaseRun->new($id);
    }
    $self->{'current_caseruns'} = \@caseruns;
    return $self->{'current_caseruns'};
}

=head2 caseruns

Returns a reference to a list of TestCaseRun objects that belong
to this run

=cut

sub caseruns {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    return $self->{'caseruns'} if exists $self->{'caseruns'};
    
    require Bugzilla::Testopia::TestCaseRun;
    
    my $ref = $dbh->selectcol_arrayref(
        "SELECT case_run_id FROM test_case_runs
         WHERE run_id=?", undef, $self->{'run_id'});
    my @caseruns;
    
    foreach my $id (@{$ref}){
        push @caseruns, Bugzilla::Testopia::TestCaseRun->new($id);
    }
    $self->{'caseruns'} = \@caseruns;
    return $self->{'caseruns'};
}

=head2 case_id_list

Returns a list of case_id's from the current case runs.

=cut

sub case_id_list {
    my $self = shift;
    my @ids;
    foreach my $c (@{$self->current_caseruns}){
        push @ids, $c->case_id;
    }
    
    return join(",", @ids);
}

=head1 SEE ALSO

Testopia::(TestPlan, TestCase, Category, Build, Environment)

=head1 AUTHOR

Greg Hendricks <ghendricks@novell.com>

=cut

1;

__END__

=head1 NAME

Bugzilla::Testopia::TestRun - Testopia Test Run object

=head1 DESCRIPTION

This module represents a test run in Testopia. A test run is the 
place where most of the work of testing is done. A run is associated 
with a single test plan and multiple test cases through the test 
case-runs.

=head1 SYNOPSIS

use Bugzilla::Testopia::TestRun;

 $run = Bugzilla::Testopia::TestRun->new($run_id);
 $run = Bugzilla::Testopia::TestRun->new(\%run_hash);

=cut

=head1 FIELDS

    run_id
    plan_id
    environment_id
    product_version
    build_id
    plan_text_version
    manager_id
    start_date
    stop_date
    summary
    notes

=cut

=head2 new

Instantiate a new Test Run. This takes a single argument 
either a test run ID or a reference to a hash containing keys 
identical to a test run's fields and desired values.

=cut
