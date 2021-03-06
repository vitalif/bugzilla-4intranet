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
# Contributor(s): Tiago R. Mello <timello@async.com.br>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::Product;

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Version;
use Bugzilla::Milestone;
use Bugzilla::Field;
use Bugzilla::Status;
use Bugzilla::Install::Requirements;
use Bugzilla::Mailer;
use Bugzilla::Series;
use Bugzilla::FlagType::UserList;
use Bugzilla::Hook;

use base qw(Bugzilla::Field::Choice);

use constant DEFAULT_CLASSIFICATION_ID => 1;

###############################
####    Initialization     ####
###############################

use constant DB_TABLE => 'products';
use constant FIELD_NAME => 'product';
# Reset these back to the Bugzilla::Object defaults, instead of the
# Bugzilla::Field::Choice defaults.
use constant NAME_FIELD => 'name';
use constant LIST_ORDER => 'name';

# Workaround mysterious taint issue:
# join('', DB_COLUMNS) will be tainted if defined as 'use constant'
# (although none of the columns themselves will be tainted in that case)
sub DB_COLUMNS() { qw(
    id
    name
    wiki_url
    notimetracking
    extproduct
    classification_id
    description
    isactive
    votesperuser
    maxvotesperbug
    votestoconfirm
    allows_unconfirmed
    cc_group
    entryheaderhtml
) }

use constant REQUIRED_CREATE_FIELDS => qw(
    name
    description
);

# Allow to update every valid DB column
*UPDATE_COLUMNS = *DB_COLUMNS;

use constant VALIDATORS => {
    allows_unconfirmed => \&Bugzilla::Object::check_boolean,
    classification_id  => \&_check_classification_id,
    name             => \&_check_name,
    description      => \&_check_description,
    version          => \&_check_version,
    isactive         => \&Bugzilla::Object::check_boolean,
    votesperuser     => \&_check_votes_per_user,
    maxvotesperbug   => \&_check_votes_per_bug,
    votestoconfirm   => \&_check_votes_to_confirm,
    notimetracking   => \&Bugzilla::Object::check_boolean,
    extproduct       => \&_check_extproduct,
    # CustIS Bug 38616 - CC list restriction
    # FIXME: Maybe also disallow bug access for these users?
    cc_group         => \&_check_cc_group,
};

###############################
####     Constructors     #####
###############################

sub create
{
    my $class = shift;
    my ($params) = @_;

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    $class->check_required_create_fields($params);

    # Some fields do not exist in the DB as is.
    if (defined $params->{classification})
    {
        $params->{classification_id} = delete $params->{classification};
    }
    my $version = delete $params->{version};

    my $field_values = $class->run_create_validators($params);
    my $product = $class->insert_create_data($field_values);
    Bugzilla->user->clear_product_cache();

    # Add the new version into the DB as valid values.
    if ($version)
    {
        Bugzilla::Version->create({
            name => $version,
            product => $product,
        });
    }

    # Fill visibility values
    $product->set_visibility_values([ $product->classification_id ]);

    Bugzilla::Hook::process('product_end_of_create', { product => $product });

    Bugzilla->get_field(FIELD_NAME)->touch;

    $dbh->bz_commit_transaction();
    return $product;
}

# This is considerably faster than calling new_from_list three times
# for each product in the list, particularly with hundreds or thousands
# of products.
sub preload
{
    my ($products) = @_;
    my %prods = map { $_->id => $_ } @$products;
    my @prod_ids = keys %prods;
    return unless @prod_ids;

    my $dbh = Bugzilla->dbh;
    foreach my $field (qw(component version milestone))
    {
        my $classname = "Bugzilla::" . ucfirst($field);
        my $objects = $classname->match({ product_id => \@prod_ids });

        # Now populate the products with this set of objects.
        foreach my $obj (@$objects)
        {
            my $product_id = $obj->product_id;
            $prods{$product_id}->{"${field}s"} ||= [];
            push(@{$prods{$product_id}->{"${field}s"}}, $obj);
        }
    }
}

sub update
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    # This is for future when we'll have a single "save" (create/update) method
    my $is_new = !$self->id;

    # Don't update the DB if something goes wrong below -> transaction.
    $dbh->bz_start_transaction();

    # Bugzilla::Field::Choice is not a threat as we don't have 'value' field
    # Yet do not call its update() for the future
    my ($changes, $old_self) = Bugzilla::Object::update($self, @_);

    # FIXME when renaming a product, try to rename it in all named queries

    # We also have to fix votes.
    if ($changes->{maxvotesperbug} || $changes->{votesperuser} || $changes->{votestoconfirm})
    {
        # We cannot |use| these modules, due to dependency loops.
        require Bugzilla::Bug;
        require Bugzilla::User;

        # 1. too many votes for a single user on a single bug.
        my @toomanyvotes_list = ();
        if ($self->max_votes_per_bug < $self->votes_per_user)
        {
            my $votes = $dbh->selectall_arrayref(
                'SELECT votes.who, votes.bug_id, profiles.login_name FROM votes, bugs, profiles'.
                ' WHERE bugs.product_id = ? AND votes.vote_count > ?'.
                ' AND bugs.bug_id=votes.bug_id AND profiles.id=votes.who',
                undef, $self->id, $self->max_votes_per_bug
            );
            foreach my $vote (@$votes)
            {
                my ($who, $id, $name) = (@$vote);
                Bugzilla::Bug::RemoveVotes($id, $who, 'votes_too_many_per_bug');
                push @toomanyvotes_list, { id => $id, name => $name };
            }
        }
        $changes->{too_many_votes} = \@toomanyvotes_list;

        # 2. too many total votes for a single user.
        # This part doesn't work in the general case because RemoveVotes
        # doesn't enforce votesperuser (except per-bug when it's less
        # than maxvotesperbug).  See Bugzilla::Bug::RemoveVotes().

        my $votes = $dbh->selectall_arrayref(
            'SELECT votes.who, votes.vote_count, profiles.login_name FROM votes, bugs, profiles'.
            ' WHERE bugs.product_id = ? AND bugs.bug_id = votes.bug_id AND profiles.userid=votes.who', undef, $self->id
        );

        my %counts;
        foreach my $vote (@$votes)
        {
            my ($who, $count, $name) = @$vote;
            if (!defined $counts{$who})
            {
                $counts{$who} = [ $count, $name ];
            }
            else
            {
                $counts{$who}[0] += $count;
            }
        }
        my @toomanytotalvotes_list = ();
        foreach my $who (keys(%counts))
        {
            if ($counts{$who}[0] > $self->votes_per_user)
            {
                my $name = $counts{$who}[1];
                my $bug_ids = $dbh->selectcol_arrayref(
                    'SELECT votes.bug_id FROM votes, bugs'.
                    ' WHERE bugs.product_id = ? AND votes.who = ?',
                    undef, ($self->id, $who)
                );
                foreach my $bug_id (@$bug_ids)
                {
                    Bugzilla::Bug::RemoveVotes($bug_id, $who, 'votes_too_many_per_user');
                    push @toomanytotalvotes_list, {id => $bug_id, name => $name};
                }
            }
        }
        $changes->{too_many_total_votes} = \@toomanytotalvotes_list;

        # 3. enough votes to confirm
        my $bug_list = $dbh->selectcol_arrayref(
            'SELECT bug_id FROM bugs, bug_status WHERE product_id = ?'.
            ' AND bugs.bug_status = bug_status.id AND NOT bug_status.is_confirmed AND votes >= ?',
            undef, ($self->id, $self->votes_to_confirm)
        );

        my @updated_bugs = ();
        foreach my $bug_id (@$bug_list)
        {
            my $bug = Bugzilla::Bug->new($bug_id);
            if ($bug->check_if_voted_confirmed)
            {
                $bug->update;
                push @updated_bugs, $bug_id;
            }
        }
        $changes->{confirmed_bugs} = \@updated_bugs;
    }

    # Also update group settings.
    if ($is_new || $self->{check_group_controls})
    {
        require Bugzilla::Bug;

        my $old_settings = !$is_new ? $old_self->group_controls : {};
        my $new_settings = $self->group_controls;
        my $timestamp = $dbh->selectrow_array('SELECT NOW()');

        $self->check_open_product;

        foreach my $gid (keys %$new_settings)
        {
            my $old_setting = $old_settings->{$gid} || {};
            my $new_setting = $new_settings->{$gid};
            # If all new settings are 0 for a given group, we delete the entry
            # from group_control_map, so we have to track it here.
            my $all_zero = 1;
            my @fields;
            my @values;

            foreach my $field ('entry', 'membercontrol', 'othercontrol', 'canedit',
                'editcomponents', 'editbugs', 'canconfirm')
            {
                my $old_value = $old_setting->{$field};
                my $new_value = $new_setting->{$field};
                $all_zero = 0 if $new_value;
                next if (defined $old_value && $old_value == $new_value);
                push(@fields, $field);
                # The value has already been validated.
                detaint_natural($new_value);
                push(@values, $new_value);
            }

            # Is there anything to update?
            if (@fields)
            {
                if ($all_zero)
                {
                    $dbh->do(
                        'DELETE FROM group_control_map WHERE product_id = ? AND group_id = ?',
                        undef, $self->id, $gid
                    );
                }
                else
                {
                    if (exists $old_setting->{group})
                    {
                        # There is already an entry in the DB.
                        my $set_fields = join(', ', map {"$_ = ?"} @fields);
                        $dbh->do(
                            "UPDATE group_control_map SET $set_fields".
                            " WHERE product_id = ? AND group_id = ?",
                            undef, (@values, $self->id, $gid)
                        );
                    }
                    else
                    {
                        # No entry yet.
                        my $fields = join(', ', @fields);
                        # +2 because of the product and group IDs.
                        my $qmarks = join(',', ('?') x (scalar @fields + 2));
                        $dbh->do(
                            "INSERT INTO group_control_map (product_id, group_id, $fields) VALUES ($qmarks)",
                            undef, ($self->id, $gid, @values)
                        );
                    }
                }
            }

            # If the group is mandatory, restrict all bugs to it.
            if ($new_setting->{membercontrol} == CONTROLMAPMANDATORY)
            {
                my $bug_ids = $dbh->selectcol_arrayref(
                    'SELECT bugs.bug_id FROM bugs'.
                    ' LEFT JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id AND group_id = ?'.
                    ' WHERE product_id = ? AND bug_group_map.bug_id IS NULL',
                    undef, $gid, $self->id
                );

                if (scalar @$bug_ids)
                {
                    my $sth = $dbh->prepare('INSERT INTO bug_group_map (bug_id, group_id) VALUES (?, ?)');

                    foreach my $bug_id (@$bug_ids)
                    {
                        $sth->execute($bug_id, $gid);
                        # Add this change to the bug history.
                        Bugzilla::Bug::LogActivityEntry(
                            $bug_id, 'bug_group', '', $new_setting->{group}->name,
                            Bugzilla->user->id, $timestamp
                        );
                    }
                    push @{$changes->{group_controls}->{now_mandatory}}, {
                        name      => $new_setting->{group}->name,
                        bug_count => scalar @$bug_ids,
                    };
                }
            }
            # If the group can no longer be used to restrict bugs, remove them.
            elsif ($new_setting->{membercontrol} == CONTROLMAPNA)
            {
                my $bug_ids = $dbh->selectcol_arrayref(
                    'SELECT bugs.bug_id FROM bugs'.
                    ' INNER JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id'.
                    ' WHERE product_id = ? AND group_id = ?', undef, $self->id, $gid
                );

                if (scalar @$bug_ids)
                {
                    $dbh->do(
                        'DELETE FROM bug_group_map WHERE group_id = ? AND ' .
                        $dbh->sql_in('bug_id', $bug_ids), undef, $gid
                    );

                    # Add this change to the bug history.
                    foreach my $bug_id (@$bug_ids)
                    {
                        Bugzilla::Bug::LogActivityEntry(
                            $bug_id, 'bug_group', $old_setting->{group}->name, '',
                            Bugzilla->user->id, $timestamp
                        );
                    }
                    push @{$changes->{group_controls}->{now_na}}, {
                        name => $old_setting->{group}->name,
                        bug_count => scalar @$bug_ids
                    };
                }
            }
        }
    }

    # Fill visibility values
    $self->set_visibility_values([ $self->classification_id ]);

    $dbh->bz_commit_transaction();
    # Changes have been committed.
    delete $self->{check_group_controls};
    Bugzilla->user->clear_product_cache();

    # Now that changes have been committed, we can send emails to voters.
    Bugzilla->send_mail;

    Bugzilla->get_field(FIELD_NAME)->touch;

    return $changes;
}

sub check_open_product
{
    my $self = shift;
    if (Bugzilla->params->{forbid_open_products})
    {
        my $new_settings = $self->group_controls;
        my $has_mandatory = 0;
        my $has_entry = 0;
        foreach my $gid (keys %$new_settings)
        {
            if ($new_settings->{$gid}->{entry})
            {
                $has_entry = 1;
            }
            if ($new_settings->{$gid}->{membercontrol} == CONTROLMAPMANDATORY &&
                $new_settings->{$gid}->{othercontrol} == CONTROLMAPMANDATORY)
            {
                $has_mandatory = 1;
            }
        }
        if (!$has_mandatory)
        {
            ThrowUserError('product_mandatory_group_required');
        }
        if (!$has_entry)
        {
            ThrowUserError('product_entry_group_required');
        }
    }
}

sub remove_from_db
{
    my ($self, $params) = @_;
    my $user = Bugzilla->user;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    if ($self->bug_count)
    {
        if (Bugzilla->params->{allowbugdeletion})
        {
            require Bugzilla::Bug;
            foreach my $bug_id (@{$self->bug_ids})
            {
                # Note that we allow the user to delete bugs he can't see,
                # which is okay, because he's deleting the whole Product.
                my $bug = new Bugzilla::Bug($bug_id);
                $bug->remove_from_db();
            }
        }
        else
        {
            ThrowUserError('product_has_bugs', { nb => $self->bug_count });
        }
    }

    if ($params->{delete_series})
    {
        my $series_ids = $dbh->selectcol_arrayref(
            'SELECT series_id FROM series'.
            ' INNER JOIN series_categories ON series_categories.id = series.category'.
            ' WHERE series_categories.name = ?',
            undef, $self->name
        );

        if (scalar @$series_ids)
        {
            $dbh->do('DELETE FROM series WHERE ' . $dbh->sql_in('series_id', $series_ids));
        }

        # If no subcategory uses this product name, completely purge it.
        my $in_use = $dbh->selectrow_array(
            'SELECT 1 FROM series'.
            ' INNER JOIN series_categories ON series_categories.id = series.subcategory'.
            ' WHERE series_categories.name = ? ' . $dbh->sql_limit(1),
            undef, $self->name
        );
        if (!$in_use)
        {
            $dbh->do('DELETE FROM series_categories WHERE name = ?', undef, $self->name);
        }
    }

    # Clear external product reference
    $dbh->do('UPDATE products SET extproduct=NULL WHERE extproduct=?', undef, $self->id);

    $self->SUPER::remove_from_db();

    $dbh->bz_commit_transaction();

    # We have to delete these internal variables, else we get
    # the old lists of products and classifications again.
    delete $user->{selectable_products};
    delete $user->{selectable_classifications};
}

###############################
####      Validators       ####
###############################

sub _check_extproduct
{
    my ($invocant, $product) = @_;
    $product = $product ? Bugzilla::Product->check({ id => $product }) : undef;
    return $product ? $product->id : undef;
}

sub _check_cc_group
{
    my ($invocant, $cc_group) = @_;
    $cc_group = trim($cc_group);
    $cc_group = $cc_group ? Bugzilla::Group->check({ name => $cc_group })->id : undef;
    return $cc_group;
}

sub _check_classification_id
{
    my ($invocant, $classification_name) = @_;

    my $classification_id = 1;
    if (Bugzilla->get_field('classification')->enabled)
    {
        my $classification = ref $classification_name
            ? $classification_name
            : Bugzilla::Classification->check($classification_name);
        $classification_id = $classification->id;
    }
    delete $invocant->{classification_obj} if ref $invocant;
    return $classification_id;
}

sub _check_name
{
    my ($invocant, $name) = @_;

    $name = trim($name);
    $name || ThrowUserError('product_blank_name');

    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError('product_name_too_long', { name => $name });
    }

    my $product = new Bugzilla::Product({ name => $name });
    if ($product && (!ref $invocant || $product->id != $invocant->id))
    {
        # Check for exact case sensitive match:
        if ($product->name eq $name)
        {
            ThrowUserError('product_name_already_in_use', { product => $product->name });
        }
        else
        {
            ThrowUserError('product_name_diff_in_case', {
                product => $name,
                existing_product => $product->name,
            });
        }
    }
    return $name;
}

sub _check_description
{
    my ($invocant, $description) = @_;

    $description = trim($description);
    $description || ThrowUserError('product_must_have_description');
    return $description;
}

sub _check_version
{
    my ($invocant, $version) = @_;
    $version = trim($version);
    # We will check the version length when Bugzilla::Version->create will do it.
    return $version;
}

sub _check_votes_per_user
{
    return _check_votes(@_, 0);
}

sub _check_votes_per_bug
{
    return _check_votes(@_, 10000);
}

sub _check_votes_to_confirm
{
    return _check_votes(@_, 0);
}

# This subroutine is only used internally by other _check_votes_* validators.
sub _check_votes
{
    my ($invocant, $votes, $field, $default) = @_;

    detaint_natural($votes);
    # On product creation, if the number of votes is not a valid integer,
    # we silently fall back to the given default value.
    # If the product already exists and the change is illegal, we complain.
    if (!defined $votes)
    {
        if (ref $invocant)
        {
            ThrowUserError('product_illegal_votes', { field => $field, votes => $_[1] });
        }
        else
        {
            $votes = $default;
        }
    }
    return $votes;
}

#####################################
# Implement Bugzilla::Field::Choice #
#####################################

use constant is_default => 0;

###############################
####       Methods         ####
###############################

sub _create_bug_group
{
    my $self = shift;
    my ($create_admin_group, $normal_group) = @_;
    my $dbh = Bugzilla->dbh;

    my $group_name = ($create_admin_group ? 'admin-' : '') . $self->name;
    my $i = 1;
    while (new Bugzilla::Group({ name => $group_name }))
    {
        $group_name = ($create_admin_group ? 'admin-' : '') . $self->name . ($i++);
    }
    my $group_description = get_text(
        $create_admin_group ? 'admin_group_description' : 'bug_group_description',
        { product => $self }
    );

    my $group = Bugzilla::Group->create({
        name        => $group_name,
        description => $group_description,
        isbuggroup  => 1,
    });

    # Associate the new group and new product.
    $dbh->do(
        'INSERT INTO group_control_map (group_id, product_id, membercontrol, othercontrol, editcomponents, entry)'.
        ' VALUES (?, ?, ?, ?, ?, ?)', undef, $group->id, $self->id,
        ($create_admin_group ? (0, 0, 1, 0) : (CONTROLMAPMANDATORY, CONTROLMAPMANDATORY, 0, 1))
    );

    # Grant current user permission to edit the new group and include him in it
    $dbh->do(
        'INSERT INTO user_group_map (user_id, group_id, isbless, grant_type) VALUES (?, ?, ?, ?), (?, ?, ?, ?)',
        undef, Bugzilla->user->id, $group->id, 1, 0, Bugzilla->user->id, $group->id, 0, 0
    );

    # Allow admin group to grant normal group
    if ($create_admin_group && $normal_group)
    {
        $dbh->do(
            'INSERT INTO group_group_map (member_id, grantor_id, grant_type) VALUES (?, ?, ?)',
            undef, $group->id, $normal_group->id, GROUP_BLESS
        );
    }

    return $group;
}

sub _create_series
{
    my $self = shift;

    my @series;
    # We do every status, every resolution, and an "opened" one as well.
    foreach my $bug_status (@{ Bugzilla->get_field('bug_status')->legal_value_names })
    {
        push(@series, [$bug_status, "bug_status=" . url_quote($bug_status)]);
    }

    foreach my $resolution (@{ Bugzilla->get_field('resolution')->legal_value_names })
    {
        next if !$resolution;
        push(@series, [$resolution, "resolution=" . url_quote($resolution)]);
    }

    my @openedstatuses = map { $_->name } grep { $_->is_open } @{ Bugzilla->get_field('bug_status')->legal_values };
    my $query = join("&", map { "bug_status=" . url_quote($_) } @openedstatuses);
    push(@series, [get_text('series_all_open'), $query]);

    foreach my $sdata (@series)
    {
        my $series = new Bugzilla::Series({
            category => $self->name,
            subcategory => get_text('series_subcategory'),
            name => $sdata->[0],
            frequency => 1,
            query => $sdata->[1] . "&product=" . url_quote($self->name),
            public => 1,
        });
        $series->writeToDatabase();
    }
}

sub set_name { $_[0]->set('name', $_[1]); }
sub set_wiki_url { $_[0]->set('wiki_url', $_[1]); }
sub set_notimetracking { $_[0]->set('notimetracking', $_[1]); }
sub set_description { $_[0]->set('description', $_[1]); }
sub set_is_active { $_[0]->set('isactive', $_[1]); }
sub set_votes_per_user { $_[0]->set('votesperuser', $_[1]); }
sub set_votes_per_bug { $_[0]->set('maxvotesperbug', $_[1]); }
sub set_votes_to_confirm { $_[0]->set('votestoconfirm', $_[1]); }
sub set_allows_unconfirmed { $_[0]->set('allows_unconfirmed', $_[1]); }
sub set_classification { $_[0]->set('classification_id', $_[1]); }
sub set_entryheaderhtml { $_[0]->set('entryheaderhtml', $_[1]); }

sub set_cc_group
{
    my ($self, $g) = @_;
    $self->set('cc_group', $g);
    delete $self->{cc_group_obj};
}

sub set_extproduct
{
    my ($self, $product) = @_;
    $product = Bugzilla::Product->check({ id => $product }) if $product && !ref $product;
    $self->set('extproduct', $product ? $product->id : undef);
    if ($self->{extproduct_obj})
    {
        delete $self->{extproduct_obj}->{intproduct_name};
    }
    delete $self->{extproduct_name};
    delete $self->{extproduct_obj};
}

sub set_group_controls
{
    my ($self, $group, $settings) = @_;

    $group->is_active_bug_group || ThrowUserError('product_illegal_group', { group => $group });

    scalar(keys %$settings) || ThrowCodeError('product_empty_group_controls', { group => $group });

    # We store current settings for this group.
    my $gs = $self->group_controls->{$group->id};
    # If there is no entry for this group yet, create a default hash.
    unless (defined $gs)
    {
        $gs = {
            entry          => 0,
            membercontrol  => CONTROLMAPNA,
            othercontrol   => CONTROLMAPNA,
            canedit        => 0,
            editcomponents => 0,
            editbugs       => 0,
            canconfirm     => 0,
            group          => $group,
        };
    }

    # Both settings must be defined, or none of them can be updated.
    if (defined $settings->{membercontrol} && defined $settings->{othercontrol})
    {
        # Legality of control combination is a function of
        # membercontrol\othercontrol
        #    NA SH DE MA
        # NA  +  -  -  -
        # SH  +  +  +  +
        # DE  +  -  +  +
        # MA  -  -  -  +
        foreach my $field ('membercontrol', 'othercontrol')
        {
            my ($is_legal) = grep { $settings->{$field} == $_ }
                (CONTROLMAPNA, CONTROLMAPSHOWN, CONTROLMAPDEFAULT, CONTROLMAPMANDATORY);
            if (!defined $is_legal)
            {
                ThrowCodeError('product_illegal_group_control', {
                    field => $field,
                    value => $settings->{$field},
                });
            }
        }
        unless ($settings->{membercontrol} == $settings->{othercontrol} ||
            $settings->{membercontrol} == CONTROLMAPSHOWN ||
            ($settings->{membercontrol} == CONTROLMAPDEFAULT && $settings->{othercontrol} != CONTROLMAPSHOWN))
        {
            ThrowUserError('illegal_group_control_combination', { groupname => $group->name });
        }
        $gs->{membercontrol} = $settings->{membercontrol};
        $gs->{othercontrol} = $settings->{othercontrol};
    }

    foreach my $field ('entry', 'canedit', 'editcomponents', 'editbugs', 'canconfirm') {
        next unless defined $settings->{$field};
        $gs->{$field} = $settings->{$field} ? 1 : 0;
    }
    $self->{group_controls}->{$group->id} = $gs;
    $self->{check_group_controls} = 1;
}

sub active_components
{
    my $self = shift;
    if (!defined $self->{active_components})
    {
        require Bugzilla::Component;
        $self->{active_components} = Bugzilla::Component->match({ product_id => $self->id, isactive => 1 });
    }
    return $self->{active_components};
}

sub components
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{components})
    {
        my $ids = $dbh->selectcol_arrayref(
            'SELECT id FROM components WHERE product_id = ? ORDER BY name',
            undef, $self->id
        );

        require Bugzilla::Component;
        $self->{components} = Bugzilla::Component->new_from_list($ids);
    }
    return $self->{components};
}

sub group_controls_full_data
{
    return $_[0]->group_controls(1);
}

sub group_controls
{
    my ($self, $full_data) = @_;
    my $dbh = Bugzilla->dbh;

    # By default, we don't return groups which are not listed in
    # group_control_map. If $full_data is true, then we also
    # return groups whose settings could be set for the product.
    my $where_or_and = 'WHERE';
    my $and_or_where = 'AND';
    if ($full_data)
    {
        $where_or_and = 'AND';
        $and_or_where = 'WHERE';
    }

    # If $full_data is true, we collect all the data in all cases,
    # even if the cache is already populated.
    # $full_data is never used except in the very special case where
    # all configurable bug groups are displayed to administrators,
    # so we don't care about collecting all the data again in this case.
    if (!defined $self->{group_controls} || $full_data)
    {
        # Include name to the list, to allow us sorting data more easily.
        my $query =
            "SELECT id, name, entry, membercontrol, othercontrol,".
            " canedit, editcomponents, editbugs, canconfirm".
            " FROM groups LEFT JOIN group_control_map ON id = group_id".
            " $where_or_and product_id = ?".
            " $and_or_where isbuggroup = 1";
        $self->{group_controls} = $dbh->selectall_hashref($query, 'id', undef, $self->id);

        # For each group ID listed above, create and store its group object.
        my @gids = keys %{$self->{group_controls}};
        my $groups = Bugzilla::Group->new_from_list(\@gids);
        $self->{group_controls}->{$_->id}->{group} = $_ foreach @$groups;
    }

    # We never cache bug counts, for the same reason as above.
    if ($full_data)
    {
        my $counts = $dbh->selectall_arrayref(
            'SELECT group_id, COUNT(bugs.bug_id) AS bug_count FROM bug_group_map'.
            ' INNER JOIN bugs ON bugs.bug_id = bug_group_map.bug_id'.
            ' WHERE bugs.product_id = ? ' . $dbh->sql_group_by('group_id'),
            {Slice => {}}, $self->id
        );
        foreach my $data (@$counts)
        {
            $self->{group_controls}->{$data->{group_id}}->{bug_count} = $data->{bug_count};
        }
    }
    return $self->{group_controls};
}

sub groups_mandatory_for
{
    my ($self, $user) = @_;
    my $groups = $user->groups_as_string;
    my $mandatory = CONTROLMAPMANDATORY;
    # For membercontrol we don't check group_id IN, because if membercontrol
    # is Mandatory, the group is Mandatory for everybody, regardless of their
    # group membership.
    my $ids = Bugzilla->dbh->selectcol_arrayref(
        "SELECT group_id FROM group_control_map WHERE product_id = ?".
        " AND (membercontrol = $mandatory OR (othercontrol = $mandatory AND group_id NOT IN ($groups)))",
        undef, $self->id
    );
    return Bugzilla::Group->new_from_list($ids);
}

sub groups_valid
{
    my ($self) = @_;
    return $self->{groups_valid} if defined $self->{groups_valid};

    # Note that we don't check OtherControl below, because there is no
    # valid NA/* combination.
    my $ids = Bugzilla->dbh->selectcol_arrayref(
        'SELECT DISTINCT group_id FROM group_control_map AS gcm'.
        ' INNER JOIN groups ON gcm.group_id = groups.id'.
        ' WHERE product_id = ? AND isbuggroup = 1'.
        ' AND membercontrol != ' . CONTROLMAPNA,  undef, $self->id
    );
    $self->{groups_valid} = Bugzilla::Group->new_from_list($ids);
    return $self->{groups_valid};
}

sub versions
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{versions})
    {
        my $ids = $dbh->selectcol_arrayref(
            'SELECT id FROM versions WHERE product_id = ?',
            undef, $self->id
        );
        $self->{versions} = Bugzilla::Version->new_from_list($ids);
    }
    return $self->{versions};
}

sub milestones
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{milestones})
    {
        my $ids = $dbh->selectcol_arrayref(
            'SELECT id FROM milestones WHERE product_id = ?',
            undef, $self->id
        );
        $self->{milestones} = Bugzilla::Milestone->new_from_list($ids);
    }
    return $self->{milestones};
}

sub bug_count
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{bug_count})
    {
        $self->{bug_count} = $dbh->selectrow_array(
            'SELECT COUNT(bug_id) FROM bugs WHERE product_id = ?',
            undef, $self->id
        );
    }
    return $self->{bug_count};
}

sub bug_ids
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{bug_ids})
    {
        $self->{bug_ids} = $dbh->selectcol_arrayref(
            'SELECT bug_id FROM bugs WHERE product_id = ?',
            undef, $self->id
        );
    }
    return $self->{bug_ids};
}

sub user_has_access
{
    my ($self, $user) = @_;

    return Bugzilla->dbh->selectrow_array(
        'SELECT CASE WHEN group_id IS NULL THEN 1 ELSE 0 END'.
        ' FROM products LEFT JOIN group_control_map'.
        ' ON group_control_map.product_id = products.id'.
        ' AND group_control_map.entry != 0 AND group_id NOT IN (' . $user->groups_as_string . ')'.
        ' WHERE products.id = ? ' . Bugzilla->dbh->sql_limit(1),
        undef, $self->id
    );
}

sub flag_types
{
    my $self = shift;

    if (!defined $self->{flag_types})
    {
        $self->{flag_types} = {};
        foreach my $type ('bug', 'attachment')
        {
            my %flagtypes;
            foreach my $component (@{$self->active_components})
            {
                foreach my $flagtype (@{$component->flag_types->{$type}})
                {
                    if (!$flagtypes{$flagtype->{id}})
                    {
                        $flagtypes{$flagtype->{id}} = $flagtype;
                    }
                    else
                    {
                        # Merge custom user lists
                        my $cl = new Bugzilla::FlagType::UserList;
                        $cl->merge($flagtypes{$flagtype->{id}}->{custom_list});
                        $cl->merge($flagtype->{custom_list});
                        $flagtypes{$flagtype->{id}}->{custom_list} = $cl;
                    }
                }
            }
            $self->{flag_types}->{$type} = [
                sort { $a->{sortkey} <=> $b->{sortkey}
                     || $a->{name} cmp $b->{name} }
                values %flagtypes
            ];
        }
    }

    return $self->{flag_types};
}

###############################
####      Accessors      ######
###############################

sub allows_unconfirmed { return $_[0]->{allows_unconfirmed}; }
sub description       { return $_[0]->{description};       }
sub isactive          { return $_[0]->{isactive};          }
sub is_active         { return $_[0]->{isactive};          }
sub votesperuser      { return $_[0]->{votesperuser};      }
sub maxvotesperbug    { return $_[0]->{maxvotesperbug};    }
sub votestoconfirm    { return $_[0]->{votestoconfirm};    }
sub votes_per_user    { return $_[0]->{votesperuser};      }
sub max_votes_per_bug { return $_[0]->{maxvotesperbug};    }
sub votes_to_confirm  { return $_[0]->{votestoconfirm};    }
sub classification_id { return $_[0]->{classification_id}; }
sub wiki_url          { return $_[0]->{wiki_url};          }
sub notimetracking    { return $_[0]->{notimetracking};    }
sub extproduct        { return $_[0]->{extproduct};        }
sub cc_group          { return $_[0]->{cc_group};          }
sub entryheaderhtml   { return $_[0]->{entryheaderhtml};   }

###############################
####      Subroutines    ######
###############################

sub classification_obj
{
    my $self = shift;
    $self->{classification_obj} ||= Bugzilla::Classification->new($self->classification_id);
    return $self->{classification_obj};
}

sub extproduct_obj
{
    my $self = shift;
    if (!exists $self->{extproduct_obj})
    {
        $self->{extproduct_obj} = $self->{extproduct} ? $self->new($self->{extproduct}) : undef;
    }
    return $self->{extproduct_obj};
}

sub cc_group_obj
{
    my $self = shift;
    if (!exists $self->{cc_group_obj})
    {
        $self->{cc_group_obj} = $self->{cc_group} ? Bugzilla::Group->new($self->{cc_group}) : undef;
    }
    return $self->{cc_group_obj};
}

sub enterable_extproduct_name
{
    my $self = shift;
    if (!exists $self->{extproduct_name})
    {
        my $n = $self->{extproduct} ? $self->extproduct_obj->name : '';
        $n = '' if $n ne '' && !Bugzilla->user->can_enter_product($n);
        $self->{extproduct_name} = $n;
    }
    return $self->{extproduct_name};
}

sub enterable_intproduct_name
{
    my $self = shift;
    if (!exists $self->{intproduct_name})
    {
        my $n = $self->{extproduct} ? [] : $self->match({ extproduct => $self->id });
        $n = @$n ? $n->[0]->name : '';
        $n = '' if $n ne '' && !Bugzilla->user->can_enter_product($n);
        $self->{intproduct_name} = $n;
    }
    return $self->{intproduct_name};
}

sub check_product
{
    my ($product_name) = @_;

    unless ($product_name)
    {
        ThrowUserError('product_not_specified');
    }
    my $product = new Bugzilla::Product({ name => $product_name });
    unless ($product)
    {
        ThrowUserError('product_doesnt_exist', { product => $product_name });
    }
    return $product;
}

sub check
{
    my ($class, $params) = @_;
    $params = { name => $params } if !ref $params;
    $params->{_error} = 'product_access_denied';
    my $product = $class->SUPER::check($params);
    if (!Bugzilla->user->can_see_product($product))
    {
        ThrowUserError('product_access_denied', $params);
    }
    return $product;
}

# Product is a special case: it has access controls applied.
# So return all products visible to current user.
sub get_all { @{ Bugzilla->user->get_selectable_products } }

###############################
####    Class Methods    ######
###############################

# FIXME: This is a "controller" method and should probably be moved out from "model" class Product
sub choose_product
{
    my $class = shift;
    my ($products, $query_params, $target) = @_;
    $products ||= Bugzilla->user->get_enterable_products;
    ThrowUserError('no_products') unless @$products;
    return $products->[0] if @$products == 1;

    my $qp = { %{ $query_params || Bugzilla->input_params } };
    delete $qp->{classification};
    $qp = http_build_query($qp);
    $qp .= '&' if length $qp;
    if (!$target)
    {
        $target = $ENV{REQUEST_URI};
        $target =~ s/\?.*//so;
        $target =~ s!^/+!/!so;
    }
    my $vars = {
        target => $target,
        query_params => $qp,
    };
    if (Bugzilla->get_field('classification')->enabled)
    {
        my $classifs;
        push @{$classifs->{$_->classification_id}}, $_ for @$products;
        $classifs = [
            map { { object => $_, products => $classifs->{$_->id} } }
            @{ Bugzilla::Classification->new_from_list([ keys %$classifs ]) }
        ];
        if (scalar @$classifs == 1)
        {
            $vars->{classifications} = [ $classifs->[0] ];
            if (scalar @{$classifs->[0]->{products}} == 1)
            {
                return $classifs->[0]->{products}->[0];
            }
        }
        else
        {
            my $cl = Bugzilla->input_params->{classification};
            if (!$cl || $cl ne '__all' && !(($cl) = grep { $_->{object}->name eq $cl } @$classifs))
            {
                $vars->{classifications} = [ map { $_->{object} } @$classifs ];
                Bugzilla->template->process("global/choose-classification.html.tmpl", $vars)
                    || ThrowTemplateError(Bugzilla->template->error());
                exit;
            }
            elsif ($cl eq '__all')
            {
                $vars->{classifications} = $classifs;
            }
            else
            {
                $vars->{classifications} = [ $cl ];
            }
        }
    }
    else
    {
        $vars->{classifications} = [ { object => undef, products => $products } ];
    }

    Bugzilla->template->process('global/choose-product.html.tmpl', $vars)
        || ThrowTemplateError(Bugzilla->template->error());
    exit;
}

1;
__END__

=head1 NAME

Bugzilla::Product - Bugzilla product class.

=head1 SYNOPSIS

    use Bugzilla::Product;

    my $product = new Bugzilla::Product(1);
    my $product = new Bugzilla::Product({ name => 'AcmeProduct' });

    my @components      = @{ $product->components() };
    my @active_components = @{ $product->active_components() };
    my $groups_controls = $product->group_controls();
    my @milestones      = $product->milestones();
    my @versions        = $product->versions();
    my $bugcount        = $product->bug_count();
    my $bug_ids         = $product->bug_ids();
    my $has_access      = $product->user_has_access($user);
    my $flag_types      = $product->flag_types();

    my $id               = $product->id;
    my $name             = $product->name;
    my $description      = $product->description;
    my $isactive         = $product->is_active;
    my $votesperuser     = $product->votes_per_user;
    my $maxvotesperbug   = $product->max_votes_per_bug;
    my $votestoconfirm   = $product->votes_to_confirm;
    my $wiki_url         = $product->wiki_url;
    my $notimetracking   = $product->notimetracking;
    my $classificationid = $product->classification_id;
    my $allows_unconfirmed = $product->allows_unconfirmed;

=head1 DESCRIPTION

Product.pm represents a product object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

The methods that are specific to C<Bugzilla::Product> are listed 
below.

=head1 METHODS

=over

=item C<components>

 Description: Returns an array of component objects belonging to
              the product.

 Params:      none.

 Returns:     An array of Bugzilla::Component object.

=item C<group_controls()>

 Description: Returns a hash (group id as key) with all product
              group controls.

 Params:      $full_data (optional, false by default) - when true,
              the number of bugs per group applicable to the product
              is also returned. Moreover, bug groups which have no
              special settings for the product are also returned.

 Returns:     A hash with group id as key and hash containing 
              a Bugzilla::Group object and the properties of group
              relative to the product.

=item C<groups_mandatory_for>

=over

=item B<Description>

Tells you what groups are mandatory for bugs in this product.

=item B<Params>

C<$user> - The user who you want to check.

=item B<Returns> An arrayref of C<Bugzilla::Group> objects.

=back

=item C<groups_valid>

=over

=item B<Description>

Returns an arrayref of L<Bugzilla::Group> objects, representing groups
that bugs could validly be restricted to within this product. Used mostly
by L<Bugzilla::Bug> to assure that you're adding valid groups to a bug.

B<Note>: This doesn't check whether or not the current user can add/remove
bugs to/from these groups. It just tells you that bugs I<could be in> these
groups, in this product.

=item B<Params> (none)

=item B<Returns> An arrayref of L<Bugzilla::Group> objects.

=back

=item C<versions>

 Description: Returns all valid versions for that product.

 Params:      none.

 Returns:     An array of Bugzilla::Version objects.

=item C<milestones>

 Description: Returns all valid milestones for that product.

 Params:      none.

 Returns:     An array of Bugzilla::Milestone objects.

=item C<bug_count()>

 Description: Returns the total of bugs that belong to the product.

 Params:      none.

 Returns:     Integer with the number of bugs.

=item C<bug_ids()>

 Description: Returns the IDs of bugs that belong to the product.

 Params:      none.

 Returns:     An array of integer.

=item C<user_has_access()>

 Description: Tells you whether or not the user is allowed to enter
              bugs into this product, based on the C<entry> group
              control. To see whether or not a user can actually
              enter a bug into a product, use C<$user-&gt;can_enter_product>.

 Params:      C<$user> - A Bugzilla::User object.

 Returns      C<1> If this user's groups allow him C<entry> access to
              this Product, C<0> otherwise.

=item C<flag_types()>

 Description: Returns flag types available for at least one of
              its components.

 Params:      none.

 Returns:     Two references to an array of flagtype objects.

=back

=head1 SUBROUTINES

=over

=item C<preload>

When passed an arrayref of C<Bugzilla::Product> objects, preloads their
L</milestones>, L</components>, and L</versions>, which is much faster
than calling those accessors on every item in the array individually.

This function is not exported, so must be called like 
C<Bugzilla::Product::preload($products)>.

=item C<check_product($product_name)>

 Description: Checks if the product name was passed in and if is a valid
              product.

 Params:      $product_name - String with a product name.

 Returns:     Bugzilla::Product object.

=back

=head1 SEE ALSO

L<Bugzilla::Object>

=cut
