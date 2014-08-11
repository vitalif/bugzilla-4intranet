#!/usr/bin/perl
# "New" ORM base class without separate create() and update() methods.
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: (c) 2014+ Vitaliy Filippov <vitalif@mail.ru>, see http://wiki.4intra.net/Bugzilla4Intranet

package Bugzilla::NewObject;

use strict;
use base qw(Bugzilla::Object);
use Bugzilla::Util;

use constant SETTERS => {}; # field => function(self, value, field_name)

sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my ($param, $return_error) = @_;

    # Constructor for an empty object
    if (!defined $param)
    {
        return bless {}, $class;
    }

    return $class->SUPER::new($param);
}

sub create
{
    my $class = shift;
    $class = ref($class) || $class;
    die("$class has no create() method. You should create an empty $class".
        " object with new(), fill it using setters and call update().");
}

sub update
{
    my $self = shift;
    $self->make_dirty;
    $self->_before_update;
    my $changes = {};
    if ($self->id)
    {
        # Use a copy of old object
        $changes = $self->_do_update($self->{_old_self});
    }
    else
    {
        my $row = {};
        for my $f ($self->DB_COLUMNS)
        {
            next if $f eq $self->ID_FIELD;
            $row->{$f} = $self->{$f};
            trick_taint($row->{$f});
        }
        my $dbh = Bugzilla->dbh;
        $dbh->do(
            'INSERT INTO '.$self->DB_TABLE.' (' . join(', ', keys %$row) .
            ') VALUES ('.join(', ', ('?') x keys %$row).")", undef, values %$row
        );
        $self->{$self->ID_FIELD} = $dbh->bz_last_key($self->DB_TABLE, $self->ID_FIELD);
    }
    $self->_after_update($changes);
    # Remove obsolete internal variables.
    delete $self->{_old_self};
    return $changes;
}

sub _before_update
{
}

sub _after_update
{
}

sub make_dirty
{
    my $self = shift;
    if ($self->id && !$self->{_old_self})
    {
        $self->{_old_self} = bless { %$self }, ref $self;
        for my $f (keys %{$self->{_old_self}})
        {
            if (ref $self->{_old_self}->{$f} eq 'ARRAY')
            {
                $self->{_old_self}->{$f} = [ @{$self->{_old_self}->{$f}} ];
            }
        }
    }
    return $self;
}

sub _check_field_permission
{
}

sub set
{
    my ($self, $field, $value) = @_;
    if (my $setter = $self->SETTERS->{$field})
    {
        $self->make_dirty;
        $value = $self->$setter($value, $field);
        if (defined $value)
        {
            trick_taint($value) if !ref $value;
            $self->{$field} = $value;
        }
        $self->_check_field_permission($field);
        return $value;
    }
    return undef;
}

# Set all field values from $params
sub set_all
{
    my ($self, $params) = @_;
    for my $field (keys %$params)
    {
        $self->set($field, $params->{$field});
    }
}

1;
__END__
