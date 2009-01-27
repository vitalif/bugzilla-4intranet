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
use lib ".";

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::User;
use Bugzilla::Config;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Testopia::Util;
use Bugzilla::Testopia::TestTag;
use Bugzilla::Testopia::TestPlan;
use Bugzilla::Testopia::TestRun;
use Bugzilla::Testopia::TestCase;
use Bugzilla::Testopia::Constants;

use JSON;

Bugzilla->login(LOGIN_REQUIRED);

local our $cgi = Bugzilla->cgi;
local our $vars = {};
local our $template = Bugzilla->template;

print $cgi->header;

my $action   = $cgi->param('action') || '';
my $type     = $cgi->param('type');

$vars->{'type'} = $type;

if ($action eq 'delete'){
    my $tag_id   = $cgi->param('tagid');
    validate_test_id($tag_id, 'tag');
    my $tag = Bugzilla::Testopia::TestTag->new($tag_id);
    ThrowUserError("testopia-no-delete", {'object' => $tag}) unless $tag->candelete;
    $tag->obliterate;
    $vars->{'tr_message'} = "Tag " . $tag->name . " deleted";
    display();
}
    
####################
### Ajax Actions ###
####################
elsif ($action eq 'addtag' || $action eq 'removetag'){
    Bugzilla->error_mode(ERROR_MODE_AJAX);
    
    my $obj;
    foreach my $id (split(/,/, $cgi->param('id'))){
        if ($type eq 'plan'){
            $obj = Bugzilla::Testopia::TestPlan->new($id);
        } elsif ($type eq 'case'){
            $obj = Bugzilla::Testopia::TestCase->new($id);
        } elsif($type eq 'run'){
            $obj = Bugzilla::Testopia::TestRun->new($id);
        }

        ThrowUserError("unknown-type", {type => $type}) unless ($obj);
        ThrowUserError("testopia-read-only", {'object' => $obj}) unless $obj->canedit;

        if ($action eq 'addtag'){
            $obj->add_tag($cgi->param('tag'));
        }
        else {
            foreach my $tag (split(',', $cgi->param('tag'))){
                trick_taint($tag);
                $obj->remove_tag($tag);
            }
        }
    }
    if ($cgi->param('method')){
        $vars->{'tr_message'} = "Added tag " . $cgi->param('tag') . " To $type " . $obj->id;
        $cgi->param($type.'_id', $obj->id);
        display();
        exit;
    }
    
    print "{success: true}";
        
}
elsif ($action eq 'gettags'){
    Bugzilla->error_mode(ERROR_MODE_AJAX);
    my $json = new JSON;
    my $tags;
    if ($cgi->param('type') eq 'user'){
        $tags = get_user_tags();
    }
    elsif ($cgi->param('type') eq 'product'){
        my $product = Bugzilla::Testopia::Product->new($cgi->param('product_id'));
        $tags = $product->tags if $product->canedit;
    }
    else {
        my $type = $cgi->param('type');
        my $id = $cgi->param('id');
        my $obj;
        if ($type eq 'plan'){
            $obj = Bugzilla::Testopia::TestPlan->new($id);
        } elsif ($type eq 'case'){
            $obj = Bugzilla::Testopia::TestCase->new($id);
        } elsif($type eq 'run'){
            $obj = Bugzilla::Testopia::TestRun->new($id);
        }

        ThrowUserError("unkown-type", {type => $type}) unless ($obj);
        ThrowUserError("testopia-permission-denied", {'object' => $obj}) unless $obj->canview;
        
        $tags = $obj->tags;
    }
    
    my $out =  "{tags:[";
    foreach my $tag (@$tags){
        $out .=  $tag->TO_JSON . ',';
    }
    chop($out) if scalar @$tags;
    print $out ."]}";
    
}
###################
###     Body    ###
###################
else {
    display();
}
###################
### Subroutines ###
###################

sub display {
    my $dbh = Bugzilla->dbh;
    my @tags;
    
    if ($cgi->param('action') eq 'show_all' && Bugzilla->user->in_group('admin')){
        my $tags = $dbh->selectcol_arrayref(
                "SELECT tag_id FROM test_tags 
                 ORDER BY tag_name");
        foreach my $t (@{$tags}){
            push @tags, Bugzilla::Testopia::TestTag->new($t);
        }
        $vars->{'viewall'} = 1;
    }

    
    $vars->{'user_tags'} = get_user_tags();
    $vars->{'user_name'} = $cgi->param('user') ? $cgi->param('user') : Bugzilla->user->login;

    if ($cgi->param('case_id')){
        my $case_id = $cgi->param('case_id');
        detaint_natural($case_id);
        $vars->{'case'} = Bugzilla::Testopia::TestCase->new($case_id);
    }
    if ($cgi->param('plan_id')){
        my $plan_id = $cgi->param('plan_id');
        detaint_natural($plan_id);
        $vars->{'plan'} = Bugzilla::Testopia::TestPlan->new($plan_id);
    }
    if ($cgi->param('run_id')){
        my $run_id = $cgi->param('run_id');
        detaint_natural($run_id);
        $vars->{'run'} = Bugzilla::Testopia::TestRun->new($run_id);
    }
    
    my @products;
    foreach my $id (split(",", $cgi->param('product'))){
        my $product = Bugzilla::Testopia::Product->new($id);
        push @products, $product if  Bugzilla->user->can_see_product($product->name);
    }
    $vars->{'products'} = \@products;
    
    my @tagids = split(/[\s,]/, $cgi->param('tag_id'));
    
    foreach my $id (@tagids){
        detaint_natural($id);
        push @tags, Bugzilla::Testopia::TestTag->new($id);
    }
    
    if ($cgi->param('tag')){
        my $name = trim($cgi->param('tag'));
        trick_taint($name);
        push @tags, Bugzilla::Testopia::TestTag->new($name);
    }
    
    $vars->{'tags'} = \@tags;
    $template->process("testopia/tag/show.html.tmpl", $vars)
        || print $template->error();

}

sub get_user_tags {
    my $user;
    my $dbh = Bugzilla->dbh;
    $user = login_to_id($cgi->param('user')) if $cgi->param('user');
    
    my $userid = $user ? $user : Bugzilla->user->id;
    ThrowUserError("invalid_username", { name => $cgi->param('user') }) unless $userid;        
    my $user_tags = $dbh->selectcol_arrayref(
             "(SELECT test_tags.tag_id, test_tags.tag_name AS name FROM test_case_tags
          INNER JOIN test_tags ON test_case_tags.tag_id = test_tags.tag_id 
               WHERE userid = ?)
        UNION (SELECT test_tags.tag_id, test_tags.tag_name AS name FROM test_plan_tags 
          INNER JOIN test_tags ON test_plan_tags.tag_id = test_tags.tag_id
               WHERE userid = ?)
        UNION (SELECT test_tags.tag_id, test_tags.tag_name AS name FROM test_run_tags 
          INNER JOIN test_tags ON test_run_tags.tag_id = test_tags.tag_id
               WHERE userid = ?)
               ORDER BY name", undef, ($userid, $userid, $userid)); 
    my @user_tags;
    foreach my $id (@$user_tags){
        push @user_tags, Bugzilla::Testopia::TestTag->new($id);
    }
    return \@user_tags;
}