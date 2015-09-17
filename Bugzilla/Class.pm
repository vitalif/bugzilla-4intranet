#!/usr/bin/perl
# Object class based on the editable metamodel stored in the DB
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Class;

use strict;
use POSIX;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::GenericObject;
use Scalar::Util qw(blessed);

use base qw(Bugzilla::NewObject);

use constant DB_TABLE => 'classdefs';
use constant DB_COLUMNS => qw(
    id
    name
    description
    db_table
    name_field_id
    list_order
);
use constant UPDATE_COLUMNS => grep { $_ ne 'id' && $_ ne 'name' && $_ ne 'db_table' } DB_COLUMNS;
use constant SETTERS => {
    name          => \&_set_name,
    description   => \&_set_description,
    name_field_id => \&_set_name_field,
    list_order    => \&_set_list_order,
};

use constant CLASS_MAP => {
    bug              => 'Bugzilla::Bug',
    attachment       => 'Bugzilla::Attachment',
    comment          => 'Bugzilla::Comment',
    user             => 'Bugzilla::User',
    group            => 'Bugzilla::Group',
    flagtype         => 'Bugzilla::FlagType',
    flag             => 'Bugzilla::Flag',

    bug_status       => 'Bugzilla::Status',
    product          => 'Bugzilla::Product',
    component        => 'Bugzilla::Component',
    version          => 'Bugzilla::Version',
    milestone        => 'Bugzilla::Milestone',
    classification   => 'Bugzilla::Classification',
    keyword          => 'Bugzilla::Keyword',
};

use constant STD_SELECT_CLASS => {
    fields => [
        [ 'value', 'Name', FIELD_TYPE_FREETEXT ],
        [ 'sortkey', 'Sortkey', FIELD_TYPE_INTEGER ],
        [ 'isactive', 'Is active', FIELD_TYPE_BOOLEAN ],
    ],
    name_field_id => 'value',
    list_order => 'sortkey, value',
};

sub _before_update
{
    my $self = shift;

    # We must set up database schema BEFORE inserting a row into classdefs!
    my $dbh = Bugzilla->dbh;
    if (!$dbh->bz_table_info($self->db_table))
    {
        $dbh->_bz_add_field_table($self->db_table, {
            FIELDS => [ id => {TYPE => 'INTSERIAL', NOTNULL => 1, PRIMARYKEY => 1}, ],
            INDEXES => [],
        });
    }

    $self->{list_order} ||= 'id';
}

sub _after_update
{
    my ($self, $changes) = @_;

    # Refresh field cache after creating/updating a class
    my ($any_field) = Bugzilla->get_fields({ class_id => $self->id });
    $any_field ||= Bugzilla->get_field('bug_id');
    $any_field->touch;
}

sub object_count
{
    my $self = shift;
    my $table = $self->db_table;
    my ($count) = Bugzilla->dbh->selectrow_array("SELECT COUNT(*) FROM $table");
    return $count;
}

# Removes class with history!
sub remove_from_db
{
    my $self = shift;
    ThrowUserError('class_delete_objects') if $self->object_count;
    ThrowUserError('class_used_in_fields') if Bugzilla->get_class_fields({ value_class_id => $self->id });
    for my $field (Bugzilla->get_class_fields({ class_id => $self->id }))
    {
        Bugzilla->dbh->bz_drop_table($field->rel_table) if $field->rel_table;
    }
    $self->SUPER::remove_from_db();
}

sub type
{
    my $self = shift;
    return $self->{package} if $self->{package};

    my $package;
    if ($self->CLASS_MAP->{$self->name})
    {
        $package = $self->CLASS_MAP->{$self->name};
        if (!defined *{"${package}::DB_TABLE"})
        {
            eval "require $package";
        }
    }
    else
    {
        # For generic classes, we use a lowercase class name, so as
        # not to interfere with any real subclasses we might make some day.
        $package = "Bugzilla::Object::".$self->name;

        # Eval this code to either create the package or refresh dynamic constants in it.
        my $code = "package $package;
            our \@ISA = qw(Bugzilla::GenericObject);
            BEGIN
            {
                undef *${package}::NAME_FIELD;
                undef *${package}::LIST_ORDER;
                undef *${package}::DB_TABLE;
                undef *${package}::CLASS_NAME;
                undef *${package}::CLASS_ID;
            }
            use constant NAME_FIELD => '".($self->name_field ? $self->name_field->name : 'id')."';
            use constant LIST_ORDER => '".$self->list_order."';
            use constant DB_TABLE => '".$self->db_table."';
            use constant CLASS_NAME => '".$self->name."';
            use constant CLASS_ID => '".$self->id."'";
        eval $code;
    }

    return ($self->{package} = $package);
}

sub new_object
{
    return shift->type->new(@_);
}

sub name { $_[0]->{name} }
sub description { $_[0]->{description} }
sub name_field_id { $_[0]->{name_field_id} }
sub id_field { $_[0]->type->ID_FIELD }
sub list_order { $_[0]->{list_order} }
sub db_table { $_[0]->{db_table} }

sub name_field
{
    my $self = shift;
    my $id = $self->name_field_id;
    return $id && Bugzilla->get_field($id);
}

sub get_fields
{
    my $self = shift;
    my ($params) = @_;
    $params->{class_id} = $self->id;
    return Bugzilla->get_fields($params);
}

sub _set_name
{
    my ($self, $name) = @_;
    # Do not allow to change object names once created
    return $self->name if $self->id;
    $name = lc $name;
    if ($name !~ /^[a-z_][a-z0-9_]*$/so)
    {
        ThrowUserError('class_invalid_name', { name => $name });
    }
    my $other_class = Bugzilla->get_class($name);
    if ($other_class)
    {
        ThrowUserError('class_already_exists', { name => $name });
    }
    # Make an appropriate DB table name
    if (my $pkg = CLASS_MAP->{$name})
    {
        $self->{db_table} = $pkg->DB_TABLE;
    }
    else
    {
        my $tbl = $name.'s';
        my $max = Bugzilla->dbh->_bz_schema->MAX_IDENTIFIER_LEN;
        if (length $tbl > $max)
        {
            ThrowUserError('class_name_too_long', { name => $name, max => $max });
        }
        eval
        {
            Bugzilla->dbh->do("CREATE TEMPORARY TABLE $tbl (id INTEGER)");
        };
        if ($@)
        {
            # Avoid SQL reserved words.
            $tbl = 'tbl_'.$name;
        }
        else
        {
            Bugzilla->dbh->do("DROP TEMPORARY TABLE $tbl");
        }
        $self->{db_table} = $tbl;
    }
    return $name;
}

sub _set_description
{
    my ($self, $description) = @_;
    $description = trim($description || '');
    if (!$description)
    {
        ThrowUserError('class_description_required');
    }
    return $description;
}

sub _set_name_field
{
    my ($self, $name_field) = @_;
    return undef if !$self->id;
    $name_field = $name_field ? Bugzilla->get_class_field($name_field, $self->id) : undef;
    return $name_field && $name_field->id;
}

sub _set_list_order
{
    my ($self, $list_order) = @_;
    return '' if !$self->id;
    my $arr = [ split /[\s,]*,[\s,]*/, lc(trim($list_order)) ];
    my %columns = map { $_ => 1 } $self->type->DB_COLUMNS;
    foreach (@$arr)
    {
        $_ = [ split /\s+/, $_, 2 ];
        $_->[1] ||= 'asc';
        if ($_->[1] ne 'desc' && $_->[1] ne 'asc' ||
            !$columns{$_->[0]})
        {
            ThrowUserError('class_invalid_list_order', { class => ref $self, list_order => $list_order });
        }
        $_ = join ' ', @$_;
    }
    return join ', ', @$arr;
}

1;
__END__
