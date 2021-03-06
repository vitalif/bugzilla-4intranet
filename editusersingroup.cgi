#!/usr/bin/perl -wT
# UI for adding/removing users in a group
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>, Stas Fomin <stas-fomin@yandex.ru>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Hook;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Token;

my $ARGS = Bugzilla->input_params;
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $vars;

$vars->{allow_bless} = $user->in_group('editusers');
$vars->{group} = Bugzilla::Group->new($ARGS->{group});

if (!$vars->{group})
{
    ThrowUserError('invalid_group_ID');
}
elsif (!$user->in_group('creategroups') && !$vars->{allow_bless} && !$user->can_bless($vars->{group}->id))
{
    ThrowUserError('auth_failure', {
        group  => 'creategroups',
        action => 'edit',
        object => 'groups',
    });
}

Bugzilla::User::match_field({
    add_members => { type => 'multi' },
    ($vars->{allow_bless} ? (add_bless => { type => 'multi' }) : ()),
});

my @add_members = list $ARGS->{add_members};
my @add_bless = $vars->{allow_bless} ? (list $ARGS->{add_bless}) : ();
my @rm_members = list $ARGS->{remove};
my @rm_bless = $vars->{allow_bless} ? (list $ARGS->{unbless}) : ();

if (@add_members || @add_bless || @rm_members || @rm_bless)
{
    check_token_data($ARGS->{token}, 'editusersingroup');
    if (@add_members || @add_bless)
    {
        my $users = { map { lc($_->login) => $_ } @{
            Bugzilla::User->match({ login_name => [ @add_members, @add_bless ] })
        } };
        for (\@add_members, \@add_bless)
        {
            @$_ = map { $users->{lc $_} || ThrowUserError('invalid_username', { name => $_ }) } @$_;
        }
        $vars->{group}->add_users(\@add_members, 0);
        $vars->{group}->add_users(\@add_bless, 1);
    }
    trick_taint($_) for @rm_members, @rm_bless;
    $vars->{group}->remove_users(\@rm_members, 0);
    $vars->{group}->remove_users(\@rm_bless, 1);
    if (@add_members || @rm_members)
    {
        Bugzilla::Hook::process('editusersingroup-post_add', {
            added_ids => \@add_members,
            removed_ids => \@rm_members,
            group_id => $vars->{group}->id,
        });
    }
    if (@add_members || @rm_members)
    {
        Bugzilla::Views::refresh_some_views();
        # Refresh fieldvaluecontrol cache
        Bugzilla->get_field('delta_ts')->touch;
    }
    delete_token($ARGS->{token});
    my $url = "editusersingroup.cgi?group=".$vars->{group}->id;
    print Bugzilla->cgi->redirect(-location => $url);
    exit;
}

$vars->{token} = issue_session_token('editusersingroup');
$vars->{user_members} = $vars->{group}->users_in_group;

Bugzilla->template->process("admin/groups/usersingroup.html.tmpl", $vars)
    || ThrowTemplateError(Bugzilla->template->error());

1;
__END__
