#!/usr/bin/perl -wT
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
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Albert Ting
#
# Contributor(s): Albert Ting <alt@sonic.net>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Classification;
use Bugzilla::Token;

my $ARGS = Bugzilla->input_params;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = { doc_section => 'classifications.html' };

Bugzilla->login(LOGIN_REQUIRED);

Bugzilla->user->in_group('editclassifications') || ThrowUserError("auth_failure", {
    group  => "editclassifications",
    action => "edit",
    object => "classifications",
});

ThrowUserError("auth_classification_not_enabled")
    unless Bugzilla->get_field('classification')->enabled;

my $action = trim($ARGS->{action} || '');
my $class_name = trim($ARGS->{classification} || '');
my $token = $ARGS->{token};

#
# action='reclassify' -> reclassify products for the classification
#
if ($action eq 'reclassify')
{
    my $classification = Bugzilla::Classification->check($class_name);

    if (defined $ARGS->{add_products})
    {
        check_token_data($token, 'reclassify_classifications');
        if (defined $ARGS->{prodlist})
        {
            foreach my $prod (list $ARGS->{prodlist})
            {
                my $obj = Bugzilla::Product->check($prod);
                $obj->set_classification($classification);
                $obj->update;
            }
        }
        delete_token($token);
    }
    elsif (defined $ARGS->{remove_products})
    {
        check_token_data($token, 'reclassify_classifications');
        if (defined $ARGS->{myprodlist})
        {
            foreach my $prod (list $ARGS->{myprodlist})
            {
                trick_taint($prod);
                my $obj = Bugzilla::Product->check($prod);
                $obj->set_classification('Unclassified');
                $obj->update;
            }
        }
        delete_token($token);
    }

    $vars->{classification} = $classification;
    $vars->{token} = issue_session_token('reclassify_classifications');
    $vars->{classifications} = [ Bugzilla::Classification->get_all ];

    $template->process("admin/classifications/reclassify.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

ThrowCodeError("action_unrecognized", { action => $action });
