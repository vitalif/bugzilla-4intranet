#!/usr/bin/perl
# Customisable group type (based on GenericObject)
# License: MPL 1.1
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
#   Joel Peshkin <bugreport@peshkin.net>
#   Erik Stambaugh <erik@dasbistro.com>
#   Tiago R. Mello <timello@async.com.br>
#   Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;

package Bugzilla::Group;

use base qw(Bugzilla::GenericObject);

use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Product;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Config qw(:admin);

use constant DB_TABLE => 'groups';
use constant LIST_ORDER => 'isbuggroup, name';
use constant NAME_FIELD => 'name';
use constant CLASS_NAME => 'group';

use constant VALIDATORS => {
    name        => \&_check_name,
    description => \&_check_description,
    userregexp  => \&_check_user_regexp,
    isactive    => \&Bugzilla::Object::check_boolean,
    isbuggroup  => \&Bugzilla::Object::check_boolean,
    icon_url    => \&_check_icon_url,
};

# Parameters that are lists of groups.
use constant GROUP_PARAMS => qw(chartgroup insidergroup timetrackinggroup querysharegroup);

sub is_bug_group { return $_[0]->{isbuggroup};   }
sub user_regexp  { return $_[0]->{userregexp};   }
sub is_active    { return $_[0]->{isactive};     }

sub _bugs
{
    my $self = shift;
    return $self->{bugs} if exists $self->{bugs};
    my $bug_ids = Bugzilla->dbh->selectcol_arrayref(
        'SELECT bug_id FROM bug_group_map WHERE group_id = ?',
        undef, $self->id
    );
    $self->{bugs} = Bugzilla::Bug->new_from_list($bug_ids);
    return $self->{bugs};
}

sub members_direct
{
    my ($self) = @_;
    $self->{members_direct} ||= $self->_get_members(GRANT_DIRECT);
    return $self->{members_direct};
}

sub members_non_inherited
{
    my ($self) = @_;
    $self->{members_non_inherited} ||= $self->_get_members();
    return $self->{members_non_inherited};
}

# A helper for members_direct and members_non_inherited
sub _get_members
{
    my ($self, $grant_type) = @_;
    my $dbh = Bugzilla->dbh;
    my $grant_clause = $grant_type ? "AND grant_type = $grant_type" : "";
    my $user_ids = $dbh->selectcol_arrayref(
        "SELECT DISTINCT user_id FROM user_group_map".
        " WHERE isbless = 0 $grant_clause AND group_id = ?",
        undef, $self->id
    );
    return Bugzilla::User->new_from_list($user_ids);
}

# Returns all active visible users who are in this group or can bless it
sub users_in_group
{
    my $self = shift;
    my %users;

    my $group_grants = {};
    my $group_bless = {};
    for my $row (@{ Bugzilla->dbh->selectall_arrayref("SELECT * FROM group_group_map", {Slice=>{}}) })
    {
        if ($row->{grant_type} == GROUP_MEMBERSHIP)
        {
            # if a user is in member_id, he's automatically in grantor_id
            $group_grants->{$row->{grantor_id}}->{$row->{member_id}} = 1;
        }
        else
        {
            $group_bless->{$row->{grantor_id}}->{$row->{member_id}} = 1;
        }
    }

    my %check_grant = ($self->id => 1);
    my %check_bless = (map { $_ => 1 } keys %{$group_bless->{$self->id}});
    my ($n_grant, $n_bless) = (0, 0);
    while ($n_grant < scalar keys %check_grant || $n_bless < scalar keys %check_bless)
    {
        $n_grant = scalar keys %check_grant;
        $n_bless = scalar keys %check_bless;
        $check_grant{$_} ||= 1 for map { keys %{$group_grants->{$_}} } keys %check_grant;
        $check_bless{$_} ||= 1 for map { keys %{$group_grants->{$_}} } keys %check_bless;
    }

    # Optionally show only users in visible groups
    my $vis = Bugzilla->params->{usevisibilitygroups} && Bugzilla->user->visible_groups_as_string;

    my $rows = Bugzilla->dbh->selectall_arrayref(
        "SELECT ugm.*, g.name group_name FROM user_group_map ugm".
        " INNER JOIN groups g ON g.id=ugm.group_id".
        ($vis ? " INNER JOIN user_group_map uvm ON uvm.user_id=ugm.user_id AND uvm.isbless=0 AND uvm.group_id IN ($vis)" : "").
        " WHERE ugm.group_id IN (".join(', ', keys %check_grant, keys %check_bless).")",
        {Slice=>{}}
    );
    my $res = {};
    my $k;
    foreach my $row (@$rows)
    {
        if ($row->{group_id} == $self->id)
        {
            $k = $row->{isbless} ? 'bless' : 'member';
            if ($row->{grant_type} == GRANT_REGEXP)
            {
                $res->{$row->{user_id}}->{$k.'_regexp'} = 1;
            }
            elsif ($row->{grant_type} == GRANT_DIRECT)
            {
                $res->{$row->{user_id}}->{$k.'_direct'} = 1;
            }
        }
        else
        {
            if ($check_grant{$row->{group_id}})
            {
                $res->{$row->{user_id}}->{member_indirect} = $row->{group_name};
            }
            if ($check_bless{$row->{group_id}})
            {
                $res->{$row->{user_id}}->{bless_indirect} = $row->{group_name};
            }
        }
    }

    my $users = Bugzilla::User->match({
        Bugzilla::User->ID_FIELD => [ keys %$res ],
        is_enabled => 1,
    });
    for my $user (@$users)
    {
        $user = { user => $user, %{$res->{$user->id}} };
    }

    return $users;
}

sub _flag_types
{
    my $self = shift;
    require Bugzilla::FlagType;
    $self->{flag_types} ||= Bugzilla::FlagType::match({ group => $self->id });
    return $self->{flag_types};
}

sub grant_direct
{
    my ($self, $type) = @_;
    $self->{grant_direct} ||= {};
    return $self->{grant_direct}->{$type} if defined $self->{grant_direct}->{$type};
    my $dbh = Bugzilla->dbh;

    my $ids = $dbh->selectcol_arrayref(
        "SELECT member_id FROM group_group_map".
        " WHERE grantor_id = ? AND grant_type = $type",
        undef, $self->id
    ) || [];

    $self->{grant_direct}->{$type} = $self->new_from_list($ids);
    return $self->{grant_direct}->{$type};
}

sub granted_by_direct
{
    my ($self, $type) = @_;
    $self->{granted_by_direct} ||= {};
    return $self->{granted_by_direct}->{$type} if defined $self->{granted_by_direct}->{$type};
    my $dbh = Bugzilla->dbh;

    my $ids = $dbh->selectcol_arrayref(
        "SELECT grantor_id FROM group_group_map".
        " WHERE member_id = ? AND grant_type = $type",
        undef, $self->id
    ) || [];

    $self->{granted_by_direct}->{$type} = $self->new_from_list($ids);
    return $self->{granted_by_direct}->{$type};
}

sub _products
{
    my $self = shift;
    return $self->{products} if exists $self->{products};
    my $product_data = Bugzilla->dbh->selectall_arrayref(
        'SELECT product_id, entry, membercontrol, othercontrol,'.
        ' canedit, editcomponents, editbugs, canconfirm'.
        ' FROM group_control_map WHERE group_id = ?',
        {Slice=>{}}, $self->id
    );
    my @ids = map { $_->{product_id} } @$product_data;
    my $products = Bugzilla::Product->new_from_list(\@ids);
    my %data_map = map { $_->{product_id} => $_ } @$product_data;
    my @retval;
    foreach my $product (@$products)
    {
        # Data doesn't need to contain product_id--we already have
        # the product object.
        delete $data_map{$product->id}->{product_id};
        push @retval, {
            controls => $data_map{$product->id},
            product  => $product
        };
    }
    $self->{products} = \@retval;
    return $self->{products};
}

sub update
{
    my $self = shift;
    my $old = $self->{_old_self};
    my $dbh = Bugzilla->dbh;

    if (!$old && Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
    {
        print get_text('install_group_create', { name => $self->name }) . "\n";
    }

    $dbh->bz_start_transaction();

    my $changes = $self->SUPER::update(@_);

    if (exists $changes->{name})
    {
        my ($old_name, $new_name) = @{$changes->{name}};
        my $update_params;
        foreach my $group (GROUP_PARAMS)
        {
            if ($old_name eq Bugzilla->params->{$group})
            {
                SetParam($group, $new_name);
                $update_params = 1;
            }
        }
        write_params() if $update_params;
    }

    if (!$old)
    {
        # Since we created a new group, give the "admin" group all privileges initially.
        my $admin = new Bugzilla::Group({ name => 'admin' });
        # This function is also used to create the "admin" group itself,
        # so there's a chance it won't exist yet.
        if ($admin)
        {
            $dbh->do(
                'INSERT INTO group_group_map (member_id, grantor_id, grant_type) VALUES (?, ?, ?), (?, ?, ?), (?, ?, ?)',
                undef, map { ($admin->id, $self->id, $_) } (GROUP_MEMBERSHIP, GROUP_BLESS, GROUP_VISIBLE)
            );
        }
    }

    # If we've changed this group to be active, fix any Mandatory groups.
    $self->_enforce_mandatory if $old && exists $changes->{isactive} && $changes->{isactive}->[1];

    $self->_rederive_regexp() if !$old && $self->user_regexp || exists $changes->{userregexp};

    Bugzilla::Hook::process('group_end_of_update', { group => $self, changes => $changes });
    $dbh->bz_commit_transaction();
    return $changes;
}

sub check_remove
{
    my ($self, $params) = @_;

    # System groups cannot be deleted!
    if (!$self->is_bug_group)
    {
        ThrowUserError("system_group_not_deletable", { name => $self->name });
    }

    # Groups having a special role cannot be deleted.
    my @special_groups;
    foreach my $special_group (GROUP_PARAMS)
    {
        if ($self->name eq Bugzilla->params->{$special_group})
        {
            push @special_groups, $special_group;
        }
    }
    if (@special_groups)
    {
        ThrowUserError('group_has_special_role', {
            name   => $self->name,
            groups => \@special_groups,
        });
    }

    return if $params->{test_only};

    my $cantdelete =
        @{$self->members_non_inherited} && !$params->{remove_from_users} ||
        @{$self->_bugs} && !$params->{remove_from_bugs} ||
        @{$self->_products} && !$params->{remove_from_products} ||
        @{$self->_flag_types} && !$params->{remove_from_flags};

    ThrowUserError('group_cannot_delete', { group => $self }) if $cantdelete;
}

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $self->check_remove(@_);
    $dbh->bz_start_transaction();
    Bugzilla::Hook::process('group_before_delete', { group => $self });
    $dbh->do(
        'DELETE FROM whine_schedules WHERE mailto_type = ? AND mailto = ?',
        undef, MAILTO_GROUP, $self->id
    );
    # All the other tables will be handled by foreign keys when we drop the main "groups" row.
    $self->SUPER::remove_from_db(@_);
    $dbh->bz_commit_transaction();
}

sub add_users
{
    my $self = shift;
    my ($users, $isbless) = @_;
    return if !@$users;
    add_user_groups([ map { { group => $self, user => $_ } } @$users ], $isbless);
}

sub remove_users
{
    my $self = shift;
    my ($users, $isbless) = @_;
    return if !@$users;
    remove_user_groups([ map { { group => $self, user => $_ } } @$users ], $isbless);
}

# Add members or blessers to this group
# Bugzilla::Group::add_user_groups([ { user => Bugzilla::User or int id, group => Bugzilla::Group }, ... ], $isbless = 0 or 1)
sub add_user_groups
{
    shift if $_[0] eq __PACKAGE__;
    my ($rows, $isbless) = @_;
    return if !@$rows;
    # Filter duplicates
    my $g = {};
    for my $row (@$rows)
    {
        $g->{int(ref $row->{user} ? $row->{user}->id : $row->{user})}->{int($row->{group}->id)} = $row;
    }
    $isbless = $isbless ? 1 : 0;
    my $dbh = Bugzilla->dbh;
    # Filter already existing members
    for my $row (@{ $dbh->selectall_arrayref(
        "SELECT user_id, group_id FROM user_group_map WHERE (user_id, group_id, grant_type, isbless) IN (".
        join(', ', map {
            my $uid = $_;
            map { "($uid, $_, ".GRANT_DIRECT.", $isbless)" } keys %{$g->{$uid}};
        } keys %$g).") FOR UPDATE", undef
    ) || [] })
    {
        delete $g->{$row->[0]}->{$row->[1]};
        delete $g->{$row->[0]} if !%{$g->{$row->[0]}};
    }
    return if !%$g;
    # Apply update
    $dbh->do(
        "INSERT INTO user_group_map (user_id, group_id, grant_type, isbless) VALUES ".
        join(', ', map {
            my $uid = $_;
            map { "($uid, $_, ".GRANT_DIRECT.", $isbless)" } keys %{$g->{$uid}};
        } keys %$g)
    );
    # Record profiles_activity entries
    my $cur_userid = Bugzilla->user->id;
    my $group_fldid = Bugzilla->get_field('bug_group')->id;
    if (!$isbless)
    {
        # FIXME: should create profiles_activity entries for blesser changes.
        $dbh->do(
            "INSERT INTO profiles_activity (userid, who, profiles_when, fieldid, oldvalue, newvalue) VALUES ".
            join(', ', map {
                my $uid = $_;
                join(', ', map { "($uid, $cur_userid, NOW(), $group_fldid, '', ".$dbh->quote($_->{group}->name).")" } values %{$g->{$uid}})
            } keys %$g)
        );
    }
}

# Remove members or blessers from this group - arguments same as in add_user_groups()
sub remove_user_groups
{
    shift if $_[0] eq __PACKAGE__;
    my ($rows, $isbless) = @_;
    return if !@$rows;
    # Filter duplicates
    $isbless = $isbless ? 1 : 0;
    my $dbh = Bugzilla->dbh;
    # Remember group objects
    my $g = { map { $_->{group}->id => $_->{group} } @$rows };
    # Filter already deleted members
    my $del = {};
    for my $row (@{ $dbh->selectall_arrayref(
        "SELECT user_id, group_id FROM user_group_map WHERE (user_id, group_id, grant_type, isbless) IN (".
        join(', ', map {
            my $uid = int(ref $_->{user} ? $_->{user}->id : $_->{user});
            my $gid = int($_->{group}->id);
            "($uid, $gid, ".GRANT_DIRECT.", $isbless)";
        } @$rows).") FOR UPDATE", undef
    ) || [] })
    {
        push @{$del->{$row->[0]}}, $row->[1];
    }
    return if !%$del;
    # Apply update
    $dbh->do(
        "DELETE FROM user_group_map WHERE (user_id, group_id, grant_type, isbless) IN (".
        join(', ', map {
            my $uid = $_;
            map { "($uid, $_, ".GRANT_DIRECT.", $isbless)" } @{$del->{$uid}};
        } keys %$del).")"
    );
    # Record profiles_activity entries
    my $cur_userid = Bugzilla->user->id;
    my $group_fldid = Bugzilla->get_field('bug_group')->id;
    if (!$isbless)
    {
        # FIXME: should create profiles_activity entries for blesser changes.
        $dbh->do(
            "INSERT INTO profiles_activity (userid, who, profiles_when, fieldid, oldvalue, newvalue) VALUES ".
            join(', ', map {
                my $uid = $_;
                map { "($uid, $cur_userid, NOW(), $group_fldid, ".$dbh->quote($g->{$_}->name).", '')" } @{$del->{$uid}};
            } keys %$del)
        );
    }
}

# Add missing entries in bug_group_map for bugs created while
# a mandatory group was disabled and which is now enabled again.
sub _enforce_mandatory
{
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    my $gid = $self->id;

    my $bug_ids = $dbh->selectcol_arrayref(
        'SELECT b.bug_id FROM bugs b'.
        ' INNER JOIN group_control_map gcm ON gcm.product_id = b.product_id'.
        ' LEFT JOIN bug_group_map bgm ON bgm.bug_id = b.bug_id AND bgm.group_id = gcm.group_id'.
        ' WHERE gcm.group_id = ? AND gcm.membercontrol = ? AND bgm.group_id IS NULL',
        undef, $gid, CONTROLMAPMANDATORY
    );

    my $sth = $dbh->prepare('INSERT INTO bug_group_map (bug_id, group_id) VALUES (?, ?)');
    foreach my $bug_id (@$bug_ids)
    {
        $sth->execute($bug_id, $gid);
    }
}

sub _rederive_regexp
{
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    my $sth = $dbh->prepare(
        "SELECT userid, login_name, group_id FROM profiles".
        " LEFT JOIN user_group_map ON user_group_map.user_id = profiles.userid".
        " AND group_id = ? AND grant_type = ? AND isbless = 0"
    );
    my $sthadd = $dbh->prepare(
        "INSERT INTO user_group_map (user_id, group_id, grant_type, isbless) VALUES (?, ?, ?, 0)"
    );
    my $sthdel = $dbh->prepare(
        "DELETE FROM user_group_map WHERE user_id=? AND group_id=? AND grant_type=? AND isbless=0"
    );
    $sth->execute($self->id, GRANT_REGEXP);
    my $regexp = $self->user_regexp;
    while (my ($uid, $login, $present) = $sth->fetchrow_array)
    {
        if ($regexp ne '' && $login =~ /$regexp/i)
        {
            $sthadd->execute($uid, $self->id, GRANT_REGEXP) unless $present;
        }
        else
        {
            $sthdel->execute($uid, $self->id, GRANT_REGEXP) if $present;
        }
    }
}

sub flatten_group_membership
{
    my ($self, @groups) = @_;
    my $dbh = Bugzilla->dbh;
    my $sth;
    my @groupidstocheck = @groups;
    my %groupidschecked = ();
    $sth = $dbh->prepare(
        "SELECT member_id FROM group_group_map".
        " WHERE grantor_id = ? AND grant_type = " . GROUP_MEMBERSHIP
    );
    while (my $node = shift @groupidstocheck)
    {
        $sth->execute($node);
        my $member;
        while (($member) = $sth->fetchrow_array)
        {
            if (!$groupidschecked{$member})
            {
                $groupidschecked{$member} = 1;
                push @groupidstocheck, $member;
                push @groups, $member unless grep $_ == $member, @groups;
            }
        }
    }
    return \@groups;
}

################################
#####  Module Subroutines    ###
################################

# FIXME Remove ValidateGroupName()
sub ValidateGroupName
{
    my ($name, @users) = (@_);
    my $dbh = Bugzilla->dbh;
    my $query = "SELECT id FROM groups WHERE name = ?";
    if (Bugzilla->params->{usevisibilitygroups})
    {
        my @visible = (-1);
        foreach my $user (@users)
        {
            $user && push @visible, @{$user->visible_groups_direct};
        }
        my $visible = join ', ', @visible;
        $query .= " AND id IN ($visible)";
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($name);
    my ($ret) = $sth->fetchrow_array();
    return $ret;
}

sub get_per_group_permissions
{
    my $class = shift;
    my $rows = Bugzilla->dbh->selectall_arrayref(
        "SELECT g.*, p.name product_name FROM group_control_map g, products p".
        " WHERE p.id=g.product_id", {Slice=>{}}
    );
    my $pergroup = {};
    for my $row (@$rows)
    {
        for (qw(entry canedit editcomponents editbugs canconfirm))
        {
            if ($row->{$_})
            {
                push @{$pergroup->{$row->{group_id}}->{$_}}, $row->{product_name};
            }
        }
        if ($row->{membercontrol} == CONTROLMAPMANDATORY &&
            $row->{othercontrol} == CONTROLMAPMANDATORY)
        {
            push @{$pergroup->{$row->{group_id}}->{access}}, $row->{product_name};
        }
        elsif ($row->{membercontrol} || $row->{othercontrol})
        {
            push @{$pergroup->{$row->{group_id}}->{optional}}, $row->{product_name};
        }
    }
    return $pergroup;
}

###############################
###       Validators        ###
###############################

sub _check_name
{
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("empty_group_name");
    # If we're creating a Group or changing the name...
    if (!ref $invocant || lc($invocant->name) ne lc($name))
    {
        my $exists = new Bugzilla::Group({name => $name });
        ThrowUserError("group_exists", { name => $name }) if $exists;
    }
    return $name;
}

sub _check_description
{
    my ($invocant, $desc) = @_;
    $desc = trim($desc);
    $desc || ThrowUserError("empty_group_description");
    return $desc;
}

sub _check_user_regexp
{
    my ($invocant, $regex) = @_;
    $regex = trim($regex) || '';
    ThrowUserError("invalid_regexp") unless (eval {qr/$regex/});
    return $regex;
}

sub _check_icon_url { return $_[1] ? clean_text($_[1]) : undef; }

1;

__END__

=head1 NAME

Bugzilla::Group - Bugzilla group class.

=head1 SYNOPSIS

    use Bugzilla::Group;

    my $group = new Bugzilla::Group(1);
    my $group = new Bugzilla::Group({name => 'AcmeGroup'});

    my $id           = $group->id;
    my $name         = $group->name;
    my $description  = $group->description;
    my $user_reg_exp = $group->user_reg_exp;
    my $is_active    = $group->is_active;
    my $icon_url     = $group->icon_url;

    my $group_id = Bugzilla::Group::ValidateGroupName('admin', @users);
    my @groups   = Bugzilla::Group->get_all;

=head1 DESCRIPTION

Group.pm represents a Bugzilla Group object. It is an implementation
of L<Bugzilla::Object>, and thus has all the methods that L<Bugzilla::Object>
provides, in addition to any methods documented below.

=head1 SUBROUTINES

=over

=item C<create>

Note that in addition to what L<Bugzilla::Object/create($params)>
normally does, this function also makes the new group be inherited
by the C<admin> group. That is, the C<admin> group will automatically
be a member of this group.

=item C<ValidateGroupName($name, @users)>

 Description: ValidateGroupName checks to see if ANY of the users
              in the provided list of user objects can see the
              named group.

 Params:      $name - String with the group name.
              @users - An array with Bugzilla::User objects.

 Returns:     It returns the group id if successful
              and undef otherwise.

=back

=head1 METHODS

=over

=item C<check_remove>

=over

=item B<Description>

Determines whether it's OK to remove this group from the database, and
throws an error if it's not OK.

=item B<Params>

=over

=item C<test_only>

C<boolean> If you want to only check if the group can be deleted I<at all>,
under any circumstances, specify C<test_only> to just do the most basic tests
(the other parameters will be ignored in this situation, as those tests won't
be run).

=item C<remove_from_users>

C<boolean> True if it would be OK to remove all users who are in this group
from this group.

=item C<remove_from_bugs>

C<boolean> True if it would be OK to remove all bugs that are in this group
from this group.

=item C<remove_from_flags>

C<boolean> True if it would be OK to stop all flagtypes that reference
this group from referencing this group (e.g., as their grantgroup or
requestgroup).

=item C<remove_from_products>

C<boolean> True if it would be OK to remove this group from all group controls
on products.

=back

=item B<Returns> (nothing)

=back

=item C<members_non_inherited>

Returns an arrayref of L<Bugzilla::User> objects representing people who are
"directly" in this group, meaning that they're in it because they match
the group regular expression, or they have been actually added to the
group manually.

=item C<flatten_group_membership>

Accepts a list of groups and returns a list of all the groups whose members 
inherit membership in any group on the list.  So, we can determine if a user
is in any of the groups input to flatten_group_membership by querying the
user_group_map for any user with DIRECT or REGEXP membership IN() the list
of groups returned.

=back
