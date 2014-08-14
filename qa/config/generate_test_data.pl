#!/usr/bin/perl -w
# -*- Mode: perl; indent-tabs-mode: nil -*-

use strict;
use warnings;

my $conf_path;
my $config; 

BEGIN {
    print "reading the config file...\n";
    my $conf_file = "selenium_test.conf";
    $config = do "$conf_file"
        or die "can't read configuration '$conf_file': $!$@";

    $conf_path = $config->{bugzilla_path};
}

use lib $conf_path;

use Bugzilla;
use Bugzilla::Attachment;
use Bugzilla::Bug;
use Bugzilla::User;
use Bugzilla::Install;
use Bugzilla::Milestone;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Group;
use Bugzilla::Version;
use Bugzilla::Constants;
use Bugzilla::Config qw(:admin);

my $dbh = Bugzilla->dbh;

# set Bugzilla usage mode to USAGE_MODE_CMDLINE
Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

##########################################################################
# Set Parameters
##########################################################################

my $params_modified = 0;
# Some parameters must be turned on to create bugs requiring them.
# They are also expected to be turned on by some webservice_*.t scripts.
for (qw(alias qa_contact))
{
    if ((my $f = Bugzilla->get_field($_))->obsolete)
    {
        $f->set_obsolete(0);
        $f->update;
    }
}
# Do not try to send emails for real!
if (Bugzilla->params->{mail_delivery_method} ne 'Test') {
    SetParam('mail_delivery_method', 'Test');
    $params_modified = 1;
}

write_params() if $params_modified;
##########################################################################
# Create Users
##########################################################################
# First of all, remove the default .* regexp for the editbugs group.
my $group = new Bugzilla::Group({ name => 'editbugs' });
$group->set_user_regexp('');
$group->update();

my @usernames = (
    'admin',            'no-privs',
    'QA-Selenium-TEST', 'canconfirm',
    'tweakparams',      'permanent_user',
    'editbugs',         'disabled',
);

print "creating user accounts...\n";
for my $username (@usernames) {

    my $password;
    my $login;
       
    if ($username eq 'permanent_user') {
        $password = $config->{admin_user_passwd};
        $login = $config->{$username};
    }
    elsif ($username eq 'no-privs') {
        $password = $config->{unprivileged_user_passwd};
        $login = $config->{unprivileged_user_login};   
    }
    elsif ($username eq 'QA-Selenium-TEST') {
        $password = $config->{QA_Selenium_TEST_user_passwd};
        $login = $config->{QA_Selenium_TEST_user_login};
    }
    else {
        $password = $config->{"$username" . "_user_passwd"};
        $login = $config->{"$username" . "_user_login"};
    }

    if ( is_available_username($login) ) {
       my %extra_args;
       if ($username eq 'disabled') {
           $extra_args{disabledtext} = '!!This is the text!!';
       }

        Bugzilla::User->create(
            {   login_name    => $login,
                realname      => $username,
                cryptpassword => $password,
                %extra_args,
            }
        );

        if ( $username eq 'admin' or $username eq 'permanent_user' ) {

            Bugzilla::Install::make_admin($login);
        }
    }
}

##########################################################################
# Create Bugs
##########################################################################

# login to bugzilla
my $admin_user = Bugzilla::User->check($config->{admin_user_login});
Bugzilla->set_user($admin_user);

my %field_values = (
    'priority'     => 'Highest',
    'bug_status'   => 'NEW',
    'version'      => 'unspecified',
    'bug_file_loc' => '',
    'comment'      => 'please ignore this bug',
    'component'    => 'TestComponent',
    'rep_platform' => 'All',
    'short_desc'   => 'This is a testing bug only',
    'product'      => 'TestProduct',
    'op_sys'       => 'Linux',
    'bug_severity' => 'normal',
);

print "creating bugs...\n";
Bugzilla::Bug->create( \%field_values );
if (!Bugzilla::Bug->new('public_bug')) {
    # The deadline must be set so that this bug can be used to test
    # timetracking fields using WebServices.
    Bugzilla::Bug->create({ %field_values, alias => 'public_bug', deadline => '2010-01-01' });
}

##########################################################################
# Create Classifications
##########################################################################
my @classifications = ({ name        => "Class2_QA",
                         description => "required by Selenium... DON'T DELETE" },
);

print "creating classifications...\n";
for my $class (@classifications) {
    my $new_class = Bugzilla::Classification->new({ name => $class->{name} });
    if (!$new_class) {
        $dbh->do('INSERT INTO classifications (name, description) VALUES (?, ?)',
                 undef, ( $class->{name}, $class->{description} ));
    }
}
##########################################################################
# Create Products
##########################################################################
my @products = (
    {   product_name     => 'QA-Selenium-TEST',
        description      => "used by Selenium test.. DON'T DELETE",
        versions         => ['unspecified', 'QAVersion'],
        milestones       => ['QAMilestone'],
        components       => [
            {   name             => "QA-Selenium-TEST",
                description      => "used by Selenium test.. DON'T DELETE",
                initialowner     => $config->{QA_Selenium_TEST_user_login},
                initialqacontact => $config->{QA_Selenium_TEST_user_login},
                initial_cc       => [$config->{QA_Selenium_TEST_user_login}],

            }
        ],
    },

    {   product_name => 'Another Product',
        description =>
            "Alternate product used by Selenium. <b>Do not edit!</b>",
        versions         => ['unspecified', 'Another1', 'Another2'],
        milestones       => ['AnotherMS1', 'AnotherMS2', 'Milestone'],
        
        components       => [
            {   name             => "c1",
                description      => "c1",
                initialowner     => $config->{permanent_user},
                initialqacontact => '',
                initial_cc       => [],

            },
            {   name             => "c2",
                description      => "c2",
                initialowner     => $config->{permanent_user},
                initialqacontact => '',
                initial_cc       => [],

            },
        ],
    },

    {   product_name     => 'C2 Forever',
        description      => 'I must remain in the Class2_QA classification ' .
                            'in all cases! Do not edit!',
        classification   => 'Class2_QA',
        versions         => ['unspecified', 'C2Ver'],
        milestones       => ['C2Mil'],
        components       => [
            {   name             => "Helium",
                description      => "Feel free to add bugs to me",
                initialowner     => $config->{permanent_user},
                initialqacontact => '',
                initial_cc       => [],

            }
        ],
    },

    {   product_name     => 'QA Entry Only',
        description      => 'Only the QA group may enter bugs here.',
        versions         => ['unspecified'],
        milestones       => [],
        components       => [
            {   name             => "c1",
                description      => "Same name as Another Product's component",
                initialowner     => $config->{QA_Selenium_TEST_user_login},
                initialqacontact => '',
                initial_cc       => [],
            }
        ],
    },

    {   product_name     => 'QA Search Only',
        description      => 'Only the QA group may search for bugs here.',
        versions         => ['unspecified'],
        milestones       => [],
        components       => [
            {   name             => "c1",
                description      => "Still same name as the Another component",
                initialowner     => $config->{QA_Selenium_TEST_user_login},
                initialqacontact => '',
                initial_cc       => [],
            }
        ],
    },
);

print "creating products...\n";
for my $product (@products) {
    my $new_product = 
        Bugzilla::Product->new({ name => $product->{product_name} });
    if (!$new_product) {
        my $class_id = 1;
        if ($product->{classification}) {
            $class_id = Bugzilla::Classification->new({ name => $product->{classification} })->id;
        }
        $dbh->do('INSERT INTO products (name, description, classification_id) VALUES (?, ?, ?)',
            undef, ( $product->{product_name}, $product->{description}, $class_id ));

        $new_product
            = new Bugzilla::Product( { name => $product->{product_name} } );

        # Now clear the internal list of accessible products.
        delete Bugzilla->user->{selectable_products};

        for my $component ( @{ $product->{components} } ) {

            Bugzilla::Component->create(
                {   name             => $component->{name},
                    product          => $new_product,
                    description      => $component->{description},
                    initialowner     => $component->{initialowner},
                    initialqacontact => $component->{initialqacontact},
                    initial_cc       => $component->{initial_cc},

                }
            );
        }
    }

    foreach my $version (@{ $product->{versions} }) {
        if (!new Bugzilla::Version({ name    => $version, 
                                     product => $new_product })) 
        {
            Bugzilla::Version->create({name => $version, product => $new_product});
        }
    }

    foreach my $milestone (@{ $product->{milestones} }) {
        if (!new Bugzilla::Milestone({ name    => $milestone,
                                       product => $new_product }))
        {
            # We don't use Bugzilla::Milestone->create because we want to
            # bypass security checks.
            $dbh->do('INSERT INTO milestones (product_id, value) VALUES (?,?)',
                     undef, $new_product->id, $milestone);
        }
    }
}

##########################################################################
# Create Groups
##########################################################################
# create Master group
my ( $group_name, $group_desc )
    = ( "Master", "Master Selenium Group <b>DO NOT EDIT!</b>" );

print "creating groups...\n";
if ( !Bugzilla::Group->new( { name => $group_name } ) ) {
    my $group = Bugzilla::Group->create({ name => $group_name,
                                          description => $group_desc,
                                          isbuggroup => 1});

    $dbh->do('INSERT INTO group_control_map
              (group_id, product_id, entry, membercontrol, othercontrol, canedit)
              SELECT ?, products.id, 0, ?, ?, 0 FROM products',
              undef, ( $group->id, CONTROLMAPSHOWN, CONTROLMAPSHOWN ) );
}

# create QA-Selenium-TEST group. Do not use Group->create() so that
# the admin group doesn't inherit membership (yes, that's what we want!).
( $group_name, $group_desc )
    = ( "QA-Selenium-TEST", "used by Selenium test.. DON'T DELETE" );

if ( !Bugzilla::Group->new( { name => $group_name } ) ) {
    $dbh->do('INSERT INTO groups (name, description, isbuggroup, isactive)
              VALUES (?, ?, 1, 1)', undef, ( $group_name, $group_desc ) );
}

##########################################################################
# Add Users to Groups
##########################################################################
my @users_groups = (
    { user => $config->{QA_Selenium_TEST_user_login}, group => 'QA-Selenium-TEST' },
    { user => $config->{tweakparams_user_login},      group => 'tweakparams' },
    { user => $config->{canconfirm_user_login},       group => 'canconfirm' },
    { user => $config->{editbugs_user_login},         group => 'editbugs' },
);

print "adding users to groups...\n";
for my $user_group (@users_groups) {

    my $group = new Bugzilla::Group( { name => $user_group->{group} } );
    my $user = new Bugzilla::User( { name => $user_group->{user} } );

    my $sth_add_mapping = $dbh->prepare(
        qq{INSERT INTO user_group_map (user_id, group_id, isbless, grant_type)
           VALUES (?, ?, ?, ?)});
    # Don't crash if the entry already exists.
    eval {
        $sth_add_mapping->execute( $user->id, $group->id, 0, GRANT_DIRECT );
    };
}

##########################################################################
# Associate Products with groups
##########################################################################
# Associate the QA-Selenium-TEST group with the QA-Selenium-TEST.
my $created_group   = new Bugzilla::Group(   { name => 'QA-Selenium-TEST' } );
my $secret_product = new Bugzilla::Product( { name => 'QA-Selenium-TEST' } );
my $no_entry = new Bugzilla::Product({ name => 'QA Entry Only' });
my $no_search = new Bugzilla::Product({ name => 'QA Search Only' });

print "restricting products to groups...\n";
# Don't crash if the entries already exist.
my $sth = $dbh->prepare('INSERT INTO group_control_map
                         (group_id, product_id, entry, membercontrol, othercontrol, canedit)
                         VALUES (?, ?, ?, ?, ?, ?)');
eval {
    $sth->execute($created_group->id, $secret_product->id, 1, CONTROLMAPMANDATORY,
                  CONTROLMAPMANDATORY, 0);
};
eval {
    $sth->execute($created_group->id, $no_entry->id, 1, CONTROLMAPNA, CONTROLMAPNA, 0);
};
eval {
    $sth->execute($created_group->id, $no_search->id, 0, CONTROLMAPMANDATORY,
                  CONTROLMAPMANDATORY, 0);
};

##########################################################################
# Create flag types
##########################################################################
my @flagtypes = (
    {name => 'spec_multi_flag', desc => 'Specifically requestable and multiplicable bug flag',
     is_requestable => 1, is_requesteeble => 1, is_multiplicable => 1, grant_group => 'editbugs',
     target_type => 'b', inclusions => ['Another Product:c1']},
);

print "creating flag types...\n";
foreach my $flag (@flagtypes) {
    # The name is not unique, even within a single product/component, so there is NO WAY
    # to know if the existing flag type is the one we want or not.
    # As our Selenium scripts would be confused anyway if there is already such a flag name,
    # we simply skip it and assume the existing flag type is the one we want.
    next if new Bugzilla::FlagType({ name => $flag->{name} });

    my $grant_group_id = $flag->{grant_group} ? Bugzilla::Group->new({ name => $flag->{grant_group} })->id : undef;
    my $request_group_id = $flag->{request_group} ? Bugzilla::Group->new({ name => $flag->{request_group} })->id : undef;

    $dbh->do('INSERT INTO flagtypes (name, description, cc_list, target_type, is_requestable,
                                     is_requesteeble, is_multiplicable, grant_group_id, request_group_id)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
             undef, ($flag->{name}, $flag->{desc}, $flag->{cc_list}, $flag->{target_type},
                     $flag->{is_requestable}, $flag->{is_requesteeble}, $flag->{is_multiplicable},
                     $grant_group_id, $request_group_id));

    my $type_id = $dbh->bz_last_key('flagtypes', 'id');

    foreach my $inclusion (@{$flag->{inclusions}}) {
        my ($product, $component) = split(':', $inclusion);
        my ($prod_id, $comp_id);
        if ($product) {
            my $prod_obj = Bugzilla::Product->new({ name => $product });
            $prod_id = $prod_obj->id;
            if ($component) {
                $comp_id = Bugzilla::Component->new({ name => $component, product => $prod_obj})->id;
            }
        }
        $dbh->do('INSERT INTO flaginclusions (type_id, product_id, component_id)
                  VALUES (?, ?, ?)',
                 undef, ($type_id, $prod_id, $comp_id));
    }
}

##########################################################################
# Create custom fields
##########################################################################
my @fields = (
    { name        => 'cf_QA_status',
      description => 'QA Status',
      type        => FIELD_TYPE_MULTI_SELECT,
      sortkey     => 100,
      mailhead    => 0,
      enter_bug   => 1,
      obsolete    => 0,
      custom      => 1,
      values      => ['verified', 'in progress', 'untested']
    },
    { name        => 'cf_single_select',
      description => 'SingSel',
      type        => FIELD_TYPE_SINGLE_SELECT,
      mailhead    => 0,
      enter_bug   => 1,
      custom      => 1,
      values      => [qw(one two three)],
    },
);

print "creating custom fields...\n";
foreach my $f (@fields) {
    # Skip existing custom fields.
    next if Bugzilla::Field->new({ name => $f->{name} });

    my @values;
    if (exists $f->{values}) {
        @values = @{$f->{values}};
        # We have to delete this key, else create() will complain
        # that 'values' is not an existing column name.
        delete $f->{values};
    }
    my $field = Bugzilla::Field->create($f);

    # Now populate the table with valid values, if necessary.
    next unless scalar @values;

    my $sth = $dbh->prepare('INSERT INTO ' . $field->name . ' (value) VALUES (?)');
    foreach my $value (@values) {
        $sth->execute($value);
    }
}

####################################################################
# Set Parameters That Require Other Things To Have Been Done First #
####################################################################

if (Bugzilla->params->{insidergroup} ne 'QA-Selenium-TEST') {
    SetParam('insidergroup', 'QA-Selenium-TEST');
    $params_modified = 1;
}

if ($params_modified) {
    write_params();
    print <<EOT
** Parameters have been modified by this script. Please re-run
** checksetup.pl to set file permissions on data/params correctly.

EOT
}

########################
# Create a Private Bug #
########################

my $test_user = Bugzilla::User->check($config->{QA_Selenium_TEST_user_login});
Bugzilla->set_user($test_user);

print "Creating private bug(s)...\n";
if (!Bugzilla::Bug->new('private_bug')) {
    my %priv_values = %field_values;
    $priv_values{alias} = 'private_bug';
    $priv_values{product} = 'QA-Selenium-TEST';
    $priv_values{component} = 'QA-Selenium-TEST';
    my $bug = Bugzilla::Bug->create(\%priv_values);
}

######################
# Create Attachments #
######################

print "creating attachments...\n";
# We use the contents of this script as the attachment.
open(my $attachment_fh, '<', __FILE__) or die __FILE__ . ": $!";
my $attachment_contents;
{ local $/; $attachment_contents = <$attachment_fh>; }
close($attachment_fh);
foreach my $alias (qw(public_bug private_bug)) {
    my $bug = new Bugzilla::Bug($alias);
    foreach my $is_private (0, 1) {
        Bugzilla::Attachment->create({
            bug  => $bug,
            data => $attachment_contents,
            description => "${alias}_${is_private}",
            filename  => "${alias}_${is_private}.pl",
            mimetype  => 'application/x-perl',
            isprivate => $is_private,
        });
    }
}

print "installation and configuration complete!\n";
