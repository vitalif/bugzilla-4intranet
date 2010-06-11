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

use strict;
use lib qw(. lib);
use Bugzilla::Constants;
use lib (bz_locations()->{extensionsdir} . '/testopia/lib');

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Product;
use Bugzilla::Token;

use Testopia::Util;
use Testopia::Constants;
use Testopia::TestPlan;
use Testopia::TestCase;
use Testopia::Category;
use Testopia::Importer;

use XML::Twig;
use Text::CSV;

my $vars = {};
my $template = Bugzilla->template;
my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;

# Re-bless CGI's filehandle lite as a real IO::Handle so that Text::CSV 
# knows what to do with it 
@Fh::ISA= qw( IO::Handle );

Bugzilla->login(LOGIN_REQUIRED);

$cgi->send_header;

my $action = $cgi->param('action') || '';
my $ctype = $cgi->param('ctype') || '';

Bugzilla->error_mode(ERROR_MODE_AJAX) if $ctype eq 'json';

if ($action eq 'upload') {
    my $token = trim($cgi->param('token'));
    if ($token) {
        my ($creator_id, $date, $old_file) = Bugzilla::Token::GetTokenData($token);
        unless ($creator_id
              && ($creator_id == Bugzilla->user->id)
              && ($old_file =~ "^importtests:"))
        {
            # The token is invalid.
            ThrowUserError('token_inexistent');
        }
        $old_file =~ s/^importtests://;
        # Must have hit refresh on the form.
        ThrowUserError('import_repeat') if ($old_file);
        
    }
    defined $cgi->upload('data') || ThrowUserError("file_not_specified");
    my $type = $cgi->uploadInfo($cgi->param("data"))->{'Content-Type'};

    # IE Sends application/octet-stream
    if ($type =~ /application/){
        if ($cgi->param('data') =~ /\.csv$/){
            $type = "text/csv";
        }
        elsif ($cgi->param('data') =~ /\.xml$/){
            $type = "text/xml";
        }
    }
    
    ThrowUserError('invalid_import_type', {type => $type}) unless $type =~ /text\/(plain|xml|csv|x-comma-separated-values)/;
        
    if ($type eq 'text/xml'){
        my $fh = $cgi->upload('data');
        my $data;
        # enable 'slurp' mode
        local $/;
    
        $data = <$fh>;
        # Limit to 1 MB. Anything larger will take way too long to parse.
        ThrowUserError("file_too_large", { filesize => sprintf("%.0f", length($data)/1024) }) if length($data) >  1048576;
         
        my $importer = new Testopia::Importer;
        my $case_ids = $importer->parse($data,$cgi->param('product_id'),$cgi->param('plan_id'));

        if ($ctype eq 'json'){
            print '{success: true}';
            exit;
        }
        else{
            $vars->{'cases'} = join(',', @$case_ids);
            $template->process("testopia/import/importer.html.tmpl", $vars) ||
                ThrowTemplateError($template->error());
        }

    }
    else {
        # Define the fields of the CSV file. The file must be in this order.
        my @fields = qw(
            product
            plans
            summary
            author_id
            default_tester_id
            case_status_id
            priority_id
            category_id
            components
            requirement
            estimated_time
            isautomated
            script
            arguments
            alias
            tags
            bugs
            dependson
            blocks
            runs
            setup
            breakdown
            action
            effect
        );
    
        my $csv = Text::CSV->new({binary => 1, eol => $/});
        my $fh = $cgi->upload('data');
        
        $csv->column_names(\@fields);
        my @rows;
        my @validated;
        while(my $row = $csv->getline_hr($fh)){
    #        print Data::Dumper::Dumper($row);
            push @rows, $row;
        }
    
        if (! $csv->eof()){
            ThrowUserError('csv_parse_failure', {row => scalar @rows + 1});
        }
        # Validate all the fields ahead of time to ensure that we have an atomic upload
        foreach my $row (@rows){
            next if ($row->{'plans'} =~ /Plans/);
            my $product = Bugzilla::Product::check_product($row->{'product'});
            delete $row->{'product'};
            
            my $import_plan = $cgi->param('plan_id');
            if (detaint_natural($import_plan)){
                $row->{'plans'} .= ',' if $row->{'plans'};
                $row->{'plans'} .= "$import_plan"; 
            }
            my @plans;
            foreach my $id (split(/[\s,]+/, $row->{'plans'})){
                my $plan = Testopia::TestPlan->new($id);
                ThrowUserError("invalid-test-id-non-existent", {'id' => $id, 'type' => 'Plan'}) unless $plan;
                ThrowUserError("testopia-create-denied", {'object' => 'Test Case', 'plan' => $plan}) unless $plan->canedit;
                push @plans, $plan;
            }
            $row->{'plans'} = \@plans;
            $row->{'author_id'} ||= Bugzilla->user->id;
            my $category = $row->{'category_id'};
            trick_taint($category);
            if (trim($category) =~ /^\d+$/){
                $row->{'category_id'} = Testopia::Util::validate_selection($row->{'category_id'}, 'category_id', 'test_case_categories');
            }
            else {
                $category = check_case_category($category, $product);
                ThrowUserError("invalid-test-id-non-existent", {'id' => $row->{'category_id'}, 'type' => 'category'}) unless $category;
                $row->{'category_id'} = $category;           
            }
            my @comps;
            foreach my $comp (split(/,+/,$row->{'components'})){
                if (trim($comp) =~ /^\d+$/){
                    push @comps, $comp;
                }
                else {
                    push @comps, {component => trim($comp), product => $product->name};
                }
            }
            $row->{'components'} = \@comps;
            $row->{'isautomated'} = $row->{'isautomated'} =~ /yes/i ? 1 : 0;
            
            $row->{'setup'} =~ s/\n/<BR>/g;
            $row->{'breakdown'} =~ s/\n/<BR>/g;
            $row->{'action'} =~ s/\n/<BR>/g;
            $row->{'effect'} =~ s/\n/<BR>/g;
            
    #        print Data::Dumper::Dumper($row);
            my $case = Testopia::TestCase->new({});
            
            $case->check_required_create_fields($row);
            $case->run_create_validators($row);
            push @validated, $row;
        }
        
        # OK, if we are here, all the fields passed validation. Time to create
        my @case_ids;
        foreach my $row (@validated){
            my $case = Testopia::TestCase->create($row);
            push @case_ids, $case->id;
        }
        if ($ctype eq 'json'){
            print '{success: true}';
            exit;
        }
        else{
            $vars->{'cases'} = join(',',@case_ids);
            $template->process("testopia/import/importer.html.tmpl", $vars) ||
                ThrowTemplateError($template->error());
        }
    }
    if ($token) {
        trick_taint($token);
        my $filename = $cgi->param('data');
        trick_taint($filename);
        $dbh->do('UPDATE tokens SET eventdata = ? WHERE token = ?', undef, 
                 ("importtests:$filename", $token));
    }
}

else {
    $vars->{'token'} = issue_session_token('importtests:');
    $template->process("testopia/import/importer.html.tmpl", $vars) ||
        ThrowTemplateError($template->error());
    
}

