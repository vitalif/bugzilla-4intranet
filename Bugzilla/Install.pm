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
# The Original Code is the Bugzilla Bug Tracking System.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Install;

# Functions in this this package can assume that the database 
# has been set up, params are available, localconfig is
# available, and any module can be used.
#
# If you want to write an installation function that can't
# make those assumptions, then it should go into one of the
# packages under the Bugzilla::Install namespace.

use strict;

use Bugzilla::Component;
use Bugzilla::Config qw(:admin);
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Product;
use Bugzilla::User;
use Bugzilla::User::Setting;
use Bugzilla::Util qw(get_text html_strip);
use Bugzilla::Version;

use constant SETTINGS => {
    # 2005-03-03 travis@sedsystems.ca -- Bug 41972
    display_quips      => { options => ["on", "off"], default => "on" },
    # 2005-03-10 travis@sedsystems.ca -- Bug 199048
    comment_sort_order => { options => ["oldest_to_newest", "newest_to_oldest",
                                        "newest_to_oldest_desc_first"],
                            default => "oldest_to_newest" },
    # 2005-05-12 bugzilla@glob.com.au -- Bug 63536
    post_bug_submit_action => { options => ["next_bug", "same_bug", "nothing"],
                                default => "same_bug" },
    # 2005-06-29 wurblzap@gmail.com -- Bug 257767
    csv_colsepchar     => { options => [',',';'], default => ',' },
    # 2005-10-26 wurblzap@gmail.com -- Bug 291459
    zoom_textareas     => { options => ["on", "off"], default => "on" },
    # 2006-05-01 olav@bkor.dhs.org -- Bug 7710
    state_addselfcc    => { options => ['always', 'never',  'cc_unless_role'],
                            default => 'cc_unless_role' },
    # 2006-08-04 wurblzap@gmail.com -- Bug 322693
    skin               => { subclass => 'Skin', default => 'Dusk' },
    # 2006-12-10 LpSolit@gmail.com -- Bug 297186
    lang               => { subclass => 'Lang',
                            default => ${Bugzilla->languages}[0] },
    # 2007-07-02 altlist@gmail.com -- Bug 225731
    quote_replies      => { options => ['quoted_reply', 'simple_reply', 'off'],
                            default => "quoted_reply" },
    # 2008-08-27 LpSolit@gmail.com -- Bug 182238
    timezone           => { subclass => 'Timezone', default => 'local' },
    # 2008-12-22 vfilippov@custis.ru -- Custis Bug 17481
    remind_me_about_worktime => { options => ['on', 'off'], default => 'on' },
    remind_me_about_flags    => { options => ['on', 'off'], default => 'on' },
    remind_me_about_worktime_newbug => { options => ['on', 'off'], default => 'off' },
    # 2009-10-21 vfilippov@custis.ru -- Custis Bug 53697
    saved_searches_position  => { options => ['footer', 'header', 'both'], default => 'footer' },
    # CustIS Bug 69766 - Default CSV charset for M1cr0$0ft Excel
    csv_charset              => { options => ['utf-8', 'windows-1251', 'koi8-r'], default => 'utf-8' },
    # CustIS Bug 72510 - Choose whether Silent affects flags
    silent_affects_flags     => { options => ['send', 'do_not_send'], default => 'send' },
    # CustIS Bug 87696 - Setting to change comments which are allowed to be marked as collapsed by default ("worktime-only")
    showhide_comments        => { options => ['none', 'worktime', 'all'], default => 'worktime' },
    # CustIS Bug 125374 - Select whether to show comments in full page width
    comment_width            => { options => ['off', 'on'], default => 'on' },
    # CustIS Bug 138596 - Choose whether to hide long comments by default
    preview_long_comments    => { options => ['off', 'on'], default => 'off' },
    # Clear all flag requests when changing bug status to 'closed_bug_status' parameter
    clear_requests_on_close  => { options => ['off', 'on'], default => 'off' },
    # Select whether to show avatar
    show_gravatars           => { options => ['off', 'on'], default => 'on' },
};

# Initial system groups.
# 'admin' group will be added to all these groups as member by default.
use constant SYSTEM_GROUPS => (
    { name => 'admin' },
    { name => 'tweakparams' },
    { name => 'editusers' },
    { name => 'creategroups' },
    { name => 'editclassifications' },
    { name => 'editcomponents' },
    { name => 'editkeywords' },
    { name => 'editbugs', userregexp => '.*' },
    { name => 'canconfirm' },
    { name => 'bz_canusewhineatothers' },
    { name => 'bz_canusewhines', include => [ 'bz_canusewhiteatothers' ] },
    { name => 'bz_sudoers' },
    { name => 'bz_sudo_protect', include => [ 'bz_sudoers' ] },
    { name => 'bz_editcheckers' },
    { name => 'editfields' },
    { name => 'editvalues' },
    { name => 'importxls', include => [ 'editbugs' ] },
    { name => 'worktimeadmin' },
    { name => 'editflagtypes' },
    {
        name => 'admin_index',
        include => [
            qw(tweakparams editusers editclassifications editcomponents creategroups
            editfields editflagtypes editkeywords bz_canusewhines bz_editcheckers)
        ],
    },
);

use constant GROUP_INCLUSIONS => (
    bz_canusewhines => [ 'bz_canusewhineatothers' ],
    bz_sudo_protect => [ 'bz_sudoers' ],
);

use constant DEFAULT_CLASSIFICATION => {
    name        => 'Unclassified',
    description => 'Not assigned to any classification'
};

use constant DEFAULT_PRODUCT => {
    name => 'TestProduct',
    description => 'This is a test product.'
        . ' This ought to be blown away and replaced with real stuff in a'
        . ' finished installation of bugzilla.',
    classification => 'Unclassified',
};

use constant DEFAULT_COMPONENT => {
    name => 'TestComponent',
    description => 'This is a test component in the test product database.'
        . ' This ought to be blown away and replaced with real stuff in'
        . ' a finished installation of Bugzilla.'
};

sub update_settings
{
    my $settings = SETTINGS();
    foreach my $setting (keys %$settings)
    {
        add_setting(
            $setting,
            $settings->{$setting}->{options},
            $settings->{$setting}->{default},
            $settings->{$setting}->{subclass}
        );
    }

    # Delete the obsolete 'per_bug_queries' user preference. Bug 616191.
    Bugzilla->dbh->do('DELETE FROM setting WHERE name = ?', undef, 'per_bug_queries');
}

sub update_system_groups
{
    my $dbh = Bugzilla->dbh;

    foreach my $definition (SYSTEM_GROUPS)
    {
        my $exists = new Bugzilla::Group({ name => $definition->{name} });
        $definition->{isbuggroup} = 0;
        $definition->{description} = html_strip(Bugzilla->messages->{system_groups}->{$definition->{name}});
        my $include = delete $definition->{include};
        if (!$exists)
        {
            Bugzilla::Group->create($definition);
            if ($include && @$include)
            {
                $dbh->do(
                    'INSERT INTO group_group_map (member_id, grantor_id, grant_type)'.
                    ' SELECT g.id, ai.id, 0 FROM groups ai, groups g WHERE ai.name=?'.
                    ' AND g.name IN (\''.join("','", @$include).'\')', undef, $definition->{name}
                );
            }
        }
    }
}

sub create_default_classification {
    my $dbh = Bugzilla->dbh;

    # Make the default Classification if it doesn't already exist.
    if (!$dbh->selectrow_array('SELECT 1 FROM classifications')) {
        print get_text('install_default_classification',
                       { name => DEFAULT_CLASSIFICATION->{name} }) . "\n";
        Bugzilla::Classification->create(DEFAULT_CLASSIFICATION);
    }
}

# This function should be called only after creating the admin user.
sub create_default_product
{
    my $dbh = Bugzilla->dbh;

    # And same for the default product/component.
    if (!$dbh->selectrow_array('SELECT 1 FROM products'))
    {
        print get_text('install_default_product', { name => DEFAULT_PRODUCT->{name} }) . "\n";

        my $product = Bugzilla::Product->create(DEFAULT_PRODUCT);

        # Get the user who will be the owner of the Component.
        # We pick the admin with the lowest id, which is probably the
        # admin checksetup.pl just created.
        my $admin_group = new Bugzilla::Group({name => 'admin'});
        my ($admin_id)  = $dbh->selectrow_array(
            'SELECT user_id FROM user_group_map WHERE group_id = ?'.
            ' ORDER BY user_id ' . $dbh->sql_limit(1),
            undef, $admin_group->id
        );
        my $admin = Bugzilla::User->new($admin_id);

        Bugzilla::Component->create({
            %{ DEFAULT_COMPONENT() },
            product => $product,
            initialowner => $admin->login,
        });
    }
}

sub create_admin {
    my ($params) = @_;
    my $dbh      = Bugzilla->dbh;
    my $template = Bugzilla->template;

    my $admin_group = new Bugzilla::Group({ name => 'admin' });
    my $admin_inheritors = 
        Bugzilla::Group->flatten_group_membership($admin_group->id);
    my $admin_group_ids = join(',', @$admin_inheritors);

    my ($admin_count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM user_group_map 
          WHERE group_id IN ($admin_group_ids)");

    return if $admin_count;

    my %answer    = %{Bugzilla->installation_answers};
    my $login     = $answer{'ADMIN_EMAIL'};
    my $password  = $answer{'ADMIN_PASSWORD'};
    my $full_name = $answer{'ADMIN_REALNAME'};

    if (!$login || !$password || !$full_name) {
        print "\n" . get_text('install_admin_setup') . "\n\n";
    }

    while (!$login)
    {
        print get_text('install_admin_get_email') . ' ';
        $login = <STDIN>;
        chomp $login;
        eval { Bugzilla::User->check_login_name_for_creation($login); };
        if ($@)
        {
            print $@ . "\n";
            undef $login;
        }
    }

    while (!defined $full_name) {
        print get_text('install_admin_get_name') . ' ';
        $full_name = <STDIN>;
        chomp($full_name);
    }

    if (!$password) {
        $password = _prompt_for_password(
            get_text('install_admin_get_password'));
    }

    my $admin = Bugzilla::User->create({ login_name    => $login, 
                                         realname      => $full_name,
                                         cryptpassword => $password });
    make_admin($admin);
}

sub make_admin {
    my ($user) = @_;
    my $dbh = Bugzilla->dbh;

    $user = ref($user) ? $user : Bugzilla::User->check($user);

    my $admin_group = new Bugzilla::Group({ name => 'admin' });

    # Admins get explicit membership and bless capability for the admin group
    $dbh->selectrow_array("SELECT id FROM groups WHERE name = 'admin'");

    my $group_insert = $dbh->prepare(
        'INSERT INTO user_group_map (user_id, group_id, isbless, grant_type)
              VALUES (?, ?, ?, ?)');
    # These are run in an eval so that we can ignore the error of somebody
    # already being granted these things.
    eval { 
        $group_insert->execute($user->id, $admin_group->id, 0, GRANT_DIRECT); 
    };
    eval {
        $group_insert->execute($user->id, $admin_group->id, 1, GRANT_DIRECT);
    };

    # Admins should also have editusers directly, even though they'll usually
    # inherit it. People could have changed their inheritance structure.
    my $editusers = new Bugzilla::Group({ name => 'editusers' });
    eval { 
        $group_insert->execute($user->id, $editusers->id, 0, GRANT_DIRECT); 
    };

    # If there is no maintainer set, make this user the maintainer.
    if (!Bugzilla->params->{'maintainer'}) {
        SetParam('maintainer', $user->email);
        write_params();
    }

    print "\n", get_text('install_admin_created', { user => $user }), "\n";
}

sub _prompt_for_password {
    my $prompt = shift;

    my $password;
    while (!$password) {
        # trap a few interrupts so we can fix the echo if we get aborted.
        local $SIG{HUP}  = \&_password_prompt_exit;
        local $SIG{INT}  = \&_password_prompt_exit;
        local $SIG{QUIT} = \&_password_prompt_exit;
        local $SIG{TERM} = \&_password_prompt_exit;

        system("stty","-echo") unless ON_WINDOWS;  # disable input echoing

        print $prompt, ' ';
        $password = <STDIN>;
        chomp $password;
        print "\n", get_text('install_confirm_password'), ' ';
        my $pass2 = <STDIN>;
        chomp $pass2;
        eval { validate_password($password, $pass2); };
        if ($@) {
            print "\n$@\n";
            undef $password;
        }
        system("stty","echo") unless ON_WINDOWS;
    }
    return $password;
}

# This is just in case we get interrupted while getting a password.
sub _password_prompt_exit {
    # re-enable input echoing
    system("stty","echo") unless ON_WINDOWS;
    exit 1;
}

sub reset_password {
    my $login = shift;
    my $user = Bugzilla::User->check($login);
    my $prompt = "\n" . get_text('install_reset_password', { user => $user });
    my $password = _prompt_for_password($prompt);
    $user->set_password($password);
    $user->update();
    print "\n", get_text('install_reset_password_done'), "\n";
}

1;

__END__

=head1 NAME

Bugzilla::Install - Functions and variables having to do with
  installation.

=head1 SYNOPSIS

 use Bugzilla::Install;
 Bugzilla::Install::update_settings();

=head1 DESCRIPTION

This module is used primarily by L<checksetup.pl> during installation.
This module contains functions that deal with general installation
issues after the database is completely set up and configured.

=head1 CONSTANTS

=over

=item C<SETTINGS>

Contains information about Settings, used by L</update_settings()>.

=back

=head1 SUBROUTINES

=over

=item C<update_settings()>

Description: Adds and updates Settings for users.

Params:      none

Returns:     nothing.

=item C<create_default_classification>

Creates the default "Unclassified" L<Classification|Bugzilla::Classification>
if it doesn't already exist

=item C<create_default_product()>

Description: Creates the default product and component if
             they don't exist.

Params:      none

Returns:     nothing

=back
