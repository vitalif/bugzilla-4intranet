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
# The Initial Developer of the Original Code is Frédéric Buclin.
# Portions created by Frédéric Buclin are Copyright (C) 2007
# Frédéric Buclin. All Rights Reserved.
#
# Contributor(s): Frédéric Buclin <LpSolit@gmail.com>

use strict;

package Bugzilla::Status;

use Bugzilla::Error;

use base qw(Bugzilla::Field::Choice);

################################
#####   Initialization     #####
################################

use constant DB_TABLE => 'bug_status';
use constant FIELD_NAME => 'bug_status';

# This has all the standard Bugzilla::Field::Choice columns plus some new ones
sub DB_COLUMNS
{
    return ($_[0]->SUPER::DB_COLUMNS, qw(is_open is_assigned is_confirmed));
}

sub UPDATE_COLUMNS
{
    return ($_[0]->SUPER::UPDATE_COLUMNS, qw(is_open is_assigned is_confirmed));
}

sub VALIDATORS
{
    my $invocant = shift;
    my $validators = $invocant->SUPER::VALIDATORS;
    $validators->{is_open} = \&Bugzilla::Object::check_boolean;
    $validators->{is_assigned} = \&Bugzilla::Object::check_boolean;
    $validators->{is_confirmed} = \&Bugzilla::Object::check_boolean;
    return $validators;
}

#########################
# Database Manipulation #
#########################

sub create
{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    add_missing_bug_status_transitions();
    return $self;
}

sub remove_from_db
{
    my $self = shift;
    if ($self->name eq Bugzilla->params->{duplicate_or_move_bug_status})
    {
        ThrowUserError('cant_delete_duplicate_or_move_bug_status');
    }
    $self->SUPER::remove_from_db();
}

###############################
#####     Accessors        ####
###############################

sub is_open      { return $_[0]->{is_open};  }
sub is_assigned  { return $_[0]->{is_assigned};  }
sub is_confirmed { return $_[0]->{is_confirmed}; }

###############################
#####       Methods        ####
###############################

sub can_change_to
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!ref($self) || !defined $self->{can_change_to})
    {
        my ($cond, @args, $self_exists);
        if (ref($self))
        {
            $cond = '= ?';
            push(@args, $self->id);
            $self_exists = 1;
        }
        else
        {
            $cond = 'IS NULL';
            # Let's do it so that the code below works in all cases.
            $self = {};
        }

        my $new_status_ids = $dbh->selectcol_arrayref(
            "SELECT new_status FROM status_workflow".
            " INNER JOIN bug_status ON id = new_status".
            " WHERE isactive = 1 AND old_status $cond".
            " ORDER BY sortkey", undef, @args
        );

        # Allow the bug status to remain unchanged.
        push(@$new_status_ids, $self->id) if $self_exists;
        $self->{can_change_to} = Bugzilla::Status->new_from_list($new_status_ids);
    }

    return $self->{can_change_to};
}

sub comment_required_on_change_from
{
    my ($self, $old_status) = @_;
    my ($cond, $values) = $self->_status_condition($old_status);
    my ($require_comment) = Bugzilla->dbh->selectrow_array(
        "SELECT require_comment FROM status_workflow WHERE $cond", undef, @$values
    );
    return $require_comment;
}

# Used as a helper for various functions that have to deal with old_status
# sometimes being NULL and sometimes having a value.
sub _status_condition
{
    my ($self, $old_status) = @_;
    my @values;
    my $cond = 'old_status IS NULL';
    # For newly-filed bugs
    if ($old_status)
    {
        $cond = 'old_status = ?';
        push(@values, $old_status->id);
    }
    $cond .= " AND new_status = ?";
    push(@values, $self->id);
    return ($cond, \@values);
}

sub add_missing_bug_status_transitions
{
    my $bug_status = shift || Bugzilla->params->{duplicate_or_move_bug_status};
    my $dbh = Bugzilla->dbh;
    my $new_status = new Bugzilla::Status({ name => $bug_status });

    # Silently discard invalid bug statuses.
    $new_status || return;

    my $missing_statuses = $dbh->selectcol_arrayref(
        'SELECT id FROM bug_status'.
        ' LEFT JOIN status_workflow ON old_status = id AND new_status = ?'.
        ' WHERE old_status IS NULL', undef, $new_status->id
    );

    my $sth = $dbh->prepare(
        'INSERT INTO status_workflow (old_status, new_status) VALUES (?, ?)'
    );

    foreach my $old_status_id (@$missing_statuses)
    {
        next if ($old_status_id == $new_status->id);
        $sth->execute($old_status_id, $new_status->id);
    }
}

1;

__END__

=head1 NAME

Bugzilla::Status - Bug status class.

=head1 SYNOPSIS

    use Bugzilla::Status;

    my $bug_status = new Bugzilla::Status({name => 'ASSIGNED'});
    my $bug_status = new Bugzilla::Status(4);

    Bugzilla::Status::add_missing_bug_status_transitions($bug_status);

=head1 DESCRIPTION

Status.pm represents a bug status object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

The methods that are specific to C<Bugzilla::Status> are listed
below.

=head1 METHODS

=over

=item C<can_change_to>

 Description: Returns the list of active statuses a bug can be changed to
              given the current bug status. If this method is called as a
              class method, then it returns all bug statuses available on
              bug creation.

 Params:      none.

 Returns:     A list of Bugzilla::Status objects.

=item C<comment_required_on_change_from>

=over

=item B<Description>

Checks if a comment is required to change to this status from another
status, according to the current settings in the workflow.

Note that this doesn't implement the checks enforced by the various
C<commenton> parameters--those are checked by internal checks in
L<Bugzilla::Bug>.

=item B<Params>

C<$old_status> - The status you're changing from.

=item B<Returns>

C<1> if a comment is required on this change, C<0> if not.

=back

=item C<add_missing_bug_status_transitions>

 Description: Insert all missing transitions to a given bug status.

 Params:      $bug_status - The value (name) of a bug status.

 Returns:     nothing.

=back

=cut
