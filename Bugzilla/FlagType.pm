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
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Myk Melez <myk@mozilla.org>
#                 Kevin Benton <kevin.benton@amd.com>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::FlagType;

use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Group;

use base qw(Bugzilla::Object);

use constant DB_TABLE => 'flagtypes';
use constant LIST_ORDER => 'sortkey, name';

use constant DB_COLUMNS => qw(
    id
    name
    description
    target_type
    sortkey
    is_active
    is_requestable
    is_requesteeble
    is_multiplicable
    grant_group_id
    request_group_id
);
use constant UPDATE_COLUMNS => grep { $_ ne 'id' } DB_COLUMNS;
use constant REQUIRED_CREATE_FIELDS => UPDATE_COLUMNS;

use constant VALIDATORS => {
    name => \&_check_name,
    description => \&_check_description,
    target_type => \&_check_target_type,
    sortkey => \&_check_sortkey,
    is_active => \&Bugzilla::Object::check_boolean,
    is_requestable => \&Bugzilla::Object::check_boolean,
    is_requesteeble => \&Bugzilla::Object::check_boolean,
    is_multiplicable => \&Bugzilla::Object::check_boolean,
    grant_group_id => \&_check_group,
    request_group_id => \&_check_group,
    cc_list => \&_check_cc_list,
};

=head1 NAME

Bugzilla::FlagType - A module to deal with Bugzilla flag types.

=head1 SYNOPSIS

FlagType.pm provides an interface to flag types as stored in Bugzilla.
See below for more information.

=head1 ACCESSORS

=over

=item B<id>

Returns the ID of the flagtype.

=item B<name>

Returns the name of the flagtype.

=item B<description>

Returns the description of the flagtype.

=item B<cc_list>

Returns the CC list for the flagtype, as an arrayref of Bugzilla::User objects.

=item B<target_type>

Returns whether the flagtype applies to bugs or attachments.

=item B<is_active>

Returns whether the flagtype is active or disabled. Flags being
in a disabled flagtype are not deleted. It only prevents you from
adding new flags to it.

=item B<is_requestable>

Returns whether you can request for the given flagtype
(i.e. whether the '?' flag is available or not).

=item B<is_requesteeble>

Returns whether you can ask someone specifically or not.

=item B<is_multiplicable>

Returns whether you can have more than one flag for the given
flagtype in a given bug/attachment.

=item B<sortkey>

Returns the sortkey of the flagtype.

=item B<grant_group_id>, B<grant_group>

Returns the group (as a Bugzilla::Group object) in which a user
must be in order to grant or deny a request.

=item B<request_group_id>, B<request_group>

Returns the group (as a Bugzilla::Group object) in which a user
must be in order to request or clear a flag.

=item B<cc_list_obj>, B<cc_list_str>

Returns the flag type's CC list as an arrayref of Bugzilla::User
objects or as a string.

=item B<flag_count>

Returns the number of flags belonging to the flagtype.

=item B<inclusions>

Return a hash of product/component IDs and names
explicitly associated with the flagtype.

=item B<exclusions>

Return a hash of product/component IDs and names
explicitly excluded from the flagtype.

=back

=cut

sub id               { return $_[0]->{id};               }
sub name             { return $_[0]->{name};             }
sub description      { return $_[0]->{description};      }
sub target_type      { return $_[0]->{target_type} eq 'b' ? 'bug' : 'attachment'; }
sub is_active        { return $_[0]->{is_active};        }
sub is_requestable   { return $_[0]->{is_requestable};   }
sub is_requesteeble  { return $_[0]->{is_requesteeble};  }
sub is_multiplicable { return $_[0]->{is_multiplicable}; }
sub sortkey          { return $_[0]->{sortkey};          }
sub request_group_id { return $_[0]->{request_group_id}; }
sub grant_group_id   { return $_[0]->{grant_group_id};   }

sub cc_list_obj
{
    my $self = shift;
    return $self->{cc_list} if $self->{cc_list};
    $self->{cc_list} = Bugzilla->dbh->selectall_arrayref(
        'SELECT p.* FROM profiles p, flagtype_cc_list c'.
        ' WHERE c.value_id=p.userid AND c.object_id=?', {Slice=>{}}, $self->id
    );
    bless $_, 'Bugzilla::User' for @{$self->{cc_list}};
    return $self->{cc_list};
}

sub cc_list_str
{
    my $self = shift;
    return join(', ', map { $_->login } @{$self->cc_list_obj});
}

sub grant_group
{
    my $self = shift;
    if (!defined $self->{grant_group} && $self->{grant_group_id})
    {
        $self->{grant_group} = new Bugzilla::Group($self->{grant_group_id});
    }
    return $self->{grant_group};
}

sub request_group
{
    my $self = shift;
    if (!defined $self->{request_group} && $self->{request_group_id})
    {
        $self->{request_group} = new Bugzilla::Group($self->{request_group_id});
    }
    return $self->{request_group};
}

sub flag_count
{
    my $self = shift;
    if (!defined $self->{flag_count})
    {
        $self->{flag_count} = Bugzilla->dbh->selectrow_array(
            'SELECT COUNT(*) FROM flags WHERE type_id = ?', undef, $self->{id}
        );
    }
    return $self->{flag_count};
}

sub inclusions
{
    my $self = shift;
    $self->{inclusions} ||= _get_clusions($self->id, 'in');
    return $self->{inclusions};
}

sub exclusions
{
    my $self = shift;
    $self->{exclusions} ||= _get_clusions($self->id, 'ex');
    return $self->{exclusions};
}

=pod

=head1 PUBLIC FUNCTIONS

=over

=item B<Bugzilla::FlagType::match($criteria)>

Queries the database for flag types matching the given criteria
and returns a list of matching flagtype objects.

=item B<Bugzilla::FlagType::count($criteria)>

Returns the total number of flag types matching the given criteria.

=back

=cut

sub create
{
    my ($class, $params) = @_;
    my $cc = $class->_check_cc_list(delete $params->{cc_list});
    my $self = $class->SUPER::create($params);
    $self->{cc_list} = $cc;
    $self->save_cc_list;
    return $self;
}

sub update
{
    my $self = shift;
    my $ch = $self->SUPER::update(@_);
    $self->save_cc_list;
    return $ch;
}

sub save_cc_list
{
    my $self = shift;
    Bugzilla->dbh->do("DELETE FROM flagtype_cc_list WHERE object_id=?", undef, $self->id);
    if (@{$self->{cc_list}})
    {
        Bugzilla->dbh->do(
            "INSERT INTO flagtype_cc_list (object_id, value_id) VALUES ".
            join(', ', map { "(?, ?)" } @{$self->{cc_list}}), undef, map { ($self->id, $_->id) } @{$self->{cc_list}}
        );
    }
}

sub match
{
    my ($criteria) = @_;
    my $dbh = Bugzilla->dbh;

    # Depending on the criteria, we may have to append additional tables.
    my $tables = [DB_TABLE];
    my @criteria = _sqlify_criteria($criteria, $tables);
    $tables = join(' ', @$tables);
    $criteria = join(' AND ', @criteria);

    my $flagtype_ids = $dbh->selectcol_arrayref("SELECT id FROM $tables WHERE $criteria");

    return Bugzilla::FlagType->new_from_list($flagtype_ids);
}

sub count
{
    my ($criteria) = @_;
    my $dbh = Bugzilla->dbh;

    # Depending on the criteria, we may have to append additional tables.
    my $tables = [DB_TABLE];
    my @criteria = _sqlify_criteria($criteria, $tables);
    $tables = join(' ', @$tables);
    $criteria = join(' AND ', @criteria);

    my $count = $dbh->selectrow_array("SELECT COUNT(flagtypes.id) FROM $tables WHERE $criteria");
    return $count;
}

######################################################################
# Validators
######################################################################

sub _check_name
{
    my ($invocant, $name) = @_;
    ($name && $name !~ /[ ,]/ && length($name) <= 255)
        || ThrowUserError("flag_type_name_invalid", { name => $name });
    return $name;
}

sub _check_description
{
    my ($invocant, $description) = @_;
    $description = trim($description);
    length($description) < 2**16-1
        || ThrowUserError("flag_type_description_invalid");
    return $description;
}

sub _check_target_type
{
    my ($invocant, $type) = @_;
    unless ($type eq 'bug' || $type eq 'attachment' || $type eq 'b' || $type eq 'a')
    {
        ThrowCodeError("flag_type_target_type_invalid", { target_type => $type });
    }
    return $type eq 'bug' || $type eq 'b' ? 'b' : 'a';
}

sub _check_sortkey
{
    my ($invocant, $sortkey) = @_;
    my $k = $sortkey;
    if (!detaint_natural($sortkey))
    {
        ThrowUserError("flag_type_sortkey_invalid", { sortkey => $k });
    }
    return $sortkey;
}

sub _check_group
{
    my ($invocant, $group, $field) = @_;
    # Convert group names to group IDs
    if ($group)
    {
        trick_taint($group);
        my $gid = Bugzilla->dbh->selectrow_array('SELECT id FROM groups WHERE name=?', undef, $group);
        $gid || ThrowUserError("group_unknown", { name => $group });
        $group = $gid;
    }
    else
    {
        $group = undef;
    }
    return $group;
}

sub _check_cc_list
{
    my ($invocant, $cc_list) = @_;
    return Bugzilla::User->match({ login_name => [ split /[\s,]*,[\s,]*/, $cc_list ] });
}

######################################################################
# Private Functions
######################################################################

sub _get_clusions
{
    my ($id, $type) = @_;
    my $dbh = Bugzilla->dbh;

    my $list = $dbh->selectall_arrayref(
        "SELECT products.id, products.name, components.id, components.name" .
        " FROM flagtypes, flag${type}clusions" .
        " LEFT JOIN products ON flag${type}clusions.product_id = products.id" .
        " LEFT JOIN components ON flag${type}clusions.component_id = components.id" .
        " WHERE flagtypes.id = ? AND flag${type}clusions.type_id = flagtypes.id",
        undef, $id
    );
    my %clusions;
    foreach my $data (@$list)
    {
        my ($product_id, $product_name, $component_id, $component_name) = @$data;
        $product_id ||= 0;
        $product_name ||= "__Any__";
        $component_id ||= 0;
        $component_name ||= "__Any__";
        $clusions{"$product_id:$component_id"} = "$product_name:$component_name";
    }
    return \%clusions;
}

sub _sqlify_criteria
{
    my ($criteria, $tables) = @_;
    my $dbh = Bugzilla->dbh;

    # the generated list of SQL criteria; "1=1" is a clever way of making sure
    # there's something in the list so calling code doesn't have to check list
    # size before building a WHERE clause out of it
    my @criteria = ("1=1");

    if ($criteria->{name})
    {
        my $name = $dbh->quote($criteria->{name});
        trick_taint($name); # Detaint data as we have quoted it.
        push @criteria, "flagtypes.name = $name";
    }
    if ($criteria->{target_type})
    {
        # The target type is stored in the database as a one-character string
        # ("a" for attachment and "b" for bug), but this function takes complete
        # names ("attachment" and "bug") for clarity, so we must convert them.
        my $target_type = $criteria->{target_type} eq 'bug'? 'b' : 'a';
        push @criteria, "flagtypes.target_type = '$target_type'";
    }
    if (exists $criteria->{is_active})
    {
        my $is_active = $criteria->{is_active} ? "1" : "0";
        push @criteria, "flagtypes.is_active = $is_active";
    }
    if ($criteria->{product_id} && $criteria->{component_id})
    {
        my $product_id = $criteria->{product_id};
        my $component_id = $criteria->{component_id};

        # Add inclusions to the query, which simply involves joining the table
        # by flag type ID and target product/component.
        push @$tables, "INNER JOIN flaginclusions AS i ON flagtypes.id = i.type_id";
        push @criteria, "(i.product_id = $product_id OR i.product_id IS NULL)";
        push @criteria, "(i.component_id = $component_id OR i.component_id IS NULL)";

        # Add exclusions to the query, which is more complicated.  First of all,
        # we do a LEFT JOIN so we don't miss flag types with no exclusions.
        # Then, as with inclusions, we join on flag type ID and target product/
        # component.  However, since we want flag types that *aren't* on the
        # exclusions list, we add a WHERE criteria to use only records with
        # NULL exclusion type, i.e. without any exclusions.
        my $join_clause = "flagtypes.id = e.type_id" .
            " AND (e.product_id = $product_id OR e.product_id IS NULL)" .
            " AND (e.component_id = $component_id OR e.component_id IS NULL)";
        push @$tables, "LEFT JOIN flagexclusions AS e ON ($join_clause)";
        push @criteria, "e.type_id IS NULL";
    }
    if ($criteria->{group})
    {
        my $gid = $criteria->{group};
        detaint_natural($gid);
        push @criteria, "(flagtypes.grant_group_id = $gid OR flagtypes.request_group_id = $gid)";
    }

    return @criteria;
}

1;
