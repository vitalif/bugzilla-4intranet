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
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::FlagType::UserList;

use strict;
use Bugzilla::User;

our %roleindex = (
    Watcher  => 0,
    CC       => 1,
    CompQA   => 2,
    Reporter => 3,
    Assignee => 4,
    QA       => 5,
);

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    return bless { cl => {} }, $class;
}

sub clear
{
    my $self = shift;
    $self->{cl} = {};
    delete $self->{r};
}

sub add
{
    my $self = shift;
    my $role = shift;
    for (@_)
    {
        $_ || next;
        if ($self->{cl}->{$_->id})
        {
            $self->{cl}->{$_->id}->[1] = $role if $roleindex{$self->{cl}->{$_->id}->[1]} < $roleindex{$role};
        }
        else
        {
            $self->{cl}->{$_->id} = [ $_, $role ];
            $self->add(Watcher => $_->watching_list);
        }
    }
    delete $self->{r};
}

sub merge
{
    my $self = shift;
    for (@_)
    {
        $self->add($_->[1], $_->[0]) for values %{$_->{cl}};
    }
}

sub ready_list
{
    my $self = shift;
    $self->{r} ||= [
        map { {
            email => $_->[0]->login,
            real_name => $_->[1] . ': ' . $_->[0]->name,
            visible => 1,
        } }
        sort { ($roleindex{$b->[1]} <=> $roleindex{$a->[1]})
            || ($a->[0]->login cmp $b->[0]->login) }
        values %{$self->{cl}}
    ];
    return $self->{r};
}

1;
__END__
