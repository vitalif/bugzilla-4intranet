#!/usr/bin/perl -wT
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
# Contributor(s): Greg Hendricks <ghendricks@novell.com>
#                 Jeff Dayley <jedayley@novell.com>   

use strict;
use lib qw(. lib);
use Bugzilla::Constants;
use lib (bz_locations()->{extensionsdir} . '/testopia/lib');

use Bugzilla;
use Bugzilla::Config;
use Bugzilla::Error;
use Bugzilla::Util;
use Testopia::Util;
use Testopia::Search;
use Testopia::Table;
use Testopia::TestRun;
use Testopia::Constants;

my $vars = {};

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;

Bugzilla->login(LOGIN_REQUIRED);

# Determine the format in which the user would like to receive the output.
# Uses the default format if the user did not specify an output format;
# otherwise validates the user's choice against the list of available formats.
my $format = $template->get_format("testopia/run/list", scalar $cgi->param('format'), scalar $cgi->param('ctype'));

# prevent DOS attacks from multiple refreshes of large data
$::SIG{TERM} = 'DEFAULT';
$::SIG{PIPE} = 'DEFAULT';

my $action = $cgi->param('action') || '';
if ($action eq 'update'){
    Bugzilla->error_mode(ERROR_MODE_AJAX);
    $cgi->send_header;
    
    my @run_ids = split(',', $cgi->param('ids'));
    ThrowUserError('testopia-none-selected', {'object' => 'run'}) unless (scalar @run_ids);

    my @uneditable;
    foreach my $p (@run_ids){
        my $run = Testopia::TestRun->new($p);
        next unless $run;
        
        unless ($run->canedit){
            push @uneditable, $run;
            next;
        }
        
        $run->set_manager($cgi->param('manager')) if $cgi->param('manager');
        $run->set_build($cgi->param('build')) if $cgi->param('build');
        $run->set_environment($cgi->param('environment')) if $cgi->param('environment');
        $run->set_target_pass($cgi->param('target_pass')) if exists $cgi->{'target_pass'};
        $run->set_target_completion($cgi->param('target_completion')) if exists $cgi->{'target_completion'};

        $run->update();
    }
            
    ThrowUserError('testopia-update-failed', {'object' => 'run', 'list' => join(',',@uneditable)}) if (scalar @uneditable);
    print "{'success': true}";    
    
}

elsif ($action eq 'clone'){
    $cgi->send_header;
    Bugzilla->error_mode(ERROR_MODE_AJAX);
    
    my @run_ids = split(',', $cgi->param('ids'));
    ThrowUserError('testopia-none-selected', {'object' => 'run'}) unless (scalar @run_ids);
    
    my %planseen;
    foreach my $planid (split(",", $cgi->param('plan_ids'))){
        validate_test_id($planid, 'plan');
        my $plan = Testopia::TestPlan->new($planid);
        ThrowUserError("testopia-read-only", {'object' => $plan}) unless $plan->canedit;
        $planseen{$planid} = 1;
    }
    
    ThrowUserError('missing-plans-list') unless scalar keys %planseen;
    
    my $dbh = Bugzilla->dbh;

    my @newruns;
    my @failures;
    foreach my $run_id (@run_ids){
        my $run = Testopia::TestRun->new($run_id);
        next unless $run->canview;
        
        my $manager = $cgi->param('keep_run_manager') ? $run->manager->id : Bugzilla->user->id;
        
        my $summary = $cgi->param('new_run_summary') || $run->summary;
        my $build = $cgi->param('new_run_build') || $run->build->id;
        my $env = $cgi->param('new_run_environment') || $run->environment->id;

        trick_taint($summary) if $cgi->param('new_run_summary');
        detaint_natural($build) if $cgi->param('new_run_build');
        detaint_natural($env) if $cgi->param('new_run_environment');
        validate_test_id($build, 'build') if $cgi->param('new_run_build');
        validate_test_id($env, 'environment') if $cgi->param('new_run_environment');

        my @caseruns;
        if ($cgi->param('copy_cases')){
            if ($cgi->param('case_list')){
                foreach my $id (split(",", $cgi->param('case_list'))){
                    my $caserun = Testopia::TestCaseRun->new($id);
                    ThrowUserError('testopia-permission-denied', {'object' => $caserun}) unless ($caserun->canview);
                    push @caseruns, $caserun;
                }
            }
            else{
                $cgi->param('current_tab', 'case_run');
                $cgi->param('run_id', $run->id);
                $cgi->param('viewall', 1);
                $cgi->param('distinct', 1);
                $cgi->delete('product_id');
                $cgi->delete('plan_ids');
                
                my $search = Testopia::Search->new($cgi);
                my $table = Testopia::Table->new('case_run', 'tr_list_caseruns.cgi', $cgi, undef, $search->query);
                @caseruns = @{$table->list};
            }
        }
        
        foreach my $plan_id (keys %planseen){
            my $newrun = Testopia::TestRun->new($run->clone($summary, $manager, $plan_id, $build, $env));
        
            if($cgi->param('copy_tags')){
                foreach my $tag (@{$run->tags}){
                    $newrun->add_tag($tag->name);
                }
            }
    
            if($cgi->param('copy_filters')){
                foreach my $f (@{$run->get_filters}){
                    $newrun->copy_filter($f->{'name'}, $f->{'query'});
                }
            }
    
            foreach my $cr (@caseruns){
                my $result = $newrun->add_case_run($cr->case_id, 
                    $cgi->param('keep_indexes') ? $cr->sortkey : undef,
                    $cgi->param('keep_statuses') ? $cr->status_id : undef);
                if ($result == 0){
                    push @failures, $cr->case_id;
                }
            }
            push @newruns, $newrun->id;
        }
    }
    print "{'success': true, 'runlist': [". join(", ", @newruns) ."], 'failures': [". join(", ", @failures) ."]}";
}

elsif ($action eq 'delete'){
    $cgi->send_header;
    Bugzilla->error_mode(ERROR_MODE_AJAX);
    my @run_ids = split(",", $cgi->param('run_ids'));
    my @uneditable;
    foreach my $id (@run_ids){
        my $run = Testopia::TestRun->new($id);
        unless ($run->candelete){
            push @uneditable, $run;
            next;
        }
        
        $run->obliterate;
    }

    ThrowUserError('testopia-delete-failed', {'object' => 'run', 'list' => join(',',@uneditable)}) if (scalar @uneditable);
    print "{'success': true}";
}

else {
    $cgi->send_header;
    $vars->{'qname'} = $cgi->param('qname') if $cgi->param('qname');
    $cgi->param('current_tab', 'run');
    $cgi->param('distinct', '1');
    my $search = Testopia::Search->new($cgi);
    my $table = Testopia::Table->new('run', 'tr_list_runs.cgi', $cgi, undef, $search->query);

    $vars->{'json'} = $table->to_ext_json;
    $template->process($format->{'template'}, $vars)
        || ThrowTemplateError($template->error());
}
