# Bugzilla Component class, based on GenericObject
# License: MPL 1.1
# Author(s): Vitaliy Filippov <vitalif@mail.ru>
#   still contains some original code from:
#   Tiago R. Mello <timello@async.com.br>
#   Frédéric Buclin <LpSolit@gmail.com>
#   Max Kanat-Alexander <mkanat@bugzilla.org>
#   Akamai Technologies <bugzilla-dev@akamai.com>

package Bugzilla::Component;

use strict;
use base qw(Bugzilla::GenericObject);

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::User;
use Bugzilla::FlagType;
use Bugzilla::FlagType::UserList;
use Bugzilla::Series;

use constant DB_TABLE => 'components';
use constant NAME_FIELD => 'name';
use constant LIST_ORDER => 'product_id, name';
use constant CLASS_NAME => 'component';

use constant OVERRIDE_SETTERS => {
    name => \&_set_name,
    description => \&_set_description,
    initialowner => \&_set_initialowner,
    initialqacontact => \&_set_initialqacontact,
    product_id => \&_set_product_id,
    cc_list => \&_set_cc_list,
};

sub DEPENDENCIES
{
    my ($deps) = @_;
    $deps->{name}->{product_id} = 1;
}

sub new
{
    my $class = shift;
    my $param = shift;
    my $dbh = Bugzilla->dbh;

    my $product;
    if (ref $param)
    {
        $product = $param->{product};
        my $name = $param->{name};
        if (!defined $product)
        {
            ThrowCodeError('bad_arg', {
                argument => 'product',
                function => "${class}::new",
            });
        }
        if (!defined $name)
        {
            ThrowCodeError('bad_arg', {
                argument => 'name',
                function => "${class}::new",
            });
        }

        my $condition = 'product_id = ? AND name = ?';
        my @values = ($product->id, $name);
        $param = { condition => $condition, values => \@values };
    }

    return $class->SUPER::new($param);
}

sub update
{
    my $self = shift;
    if (!$self->product)
    {
        ThrowUserError('component_unknown_product', {});
    }
    my $component = new Bugzilla::Component({ product => $self->product, name => $self->name });
    if ($component && $component->id != $self->id)
    {
        ThrowUserError('component_already_exists', {
            name    => $component->name,
            product => $self->product,
        });
    }
    my $changes = $self->SUPER::update(@_);
    # Duplicate visibility values into fieldvaluecontrol
    Bugzilla->get_field('component')->update_visibility_values($self->id, [ $self->product_id ]);
    return $changes;
}

sub remove_from_db
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    if (my $nb = $self->bug_count)
    {
        if (Bugzilla->params->{allowbugdeletion})
        {
            require Bugzilla::Bug;
            foreach my $bug_id (@{$self->bug_ids})
            {
                # Note: We allow admins to delete bugs even if they can't
                # see them, as long as they can see the product.
                my $bug = new Bugzilla::Bug($bug_id);
                $bug->remove_from_db();
            }
        }
        else
        {
            ThrowUserError('component_has_bugs', { nb => $nb });
        }
    }

    $self->SUPER::remove_from_db();

    $dbh->bz_commit_transaction();
}

################################
# Validators
################################

sub _set_name
{
    my ($self, $name) = @_;
    $name = trim($name) || ThrowUserError('component_blank_name');
    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError('component_name_too_long', { name => $name });
    }
    return $name;
}

sub _set_description
{
    my ($self, $description) = @_;
    $description = trim($description) || ThrowUserError('component_blank_description');
    return $description;
}

sub _set_initialowner
{
    my ($self, $owner, $field) = @_;
    $owner || ThrowUserError('component_need_initialowner');
    return $self->_set_select_field($owner, $field);
}

sub _set_initialqacontact
{
    my ($self, $qa, $field) = @_;
    return $self->initialqacontact if !Bugzilla->get_field('qa_contact')->enabled;
    return $self->_set_select_field($qa, $field);
}

sub _set_product_id
{
    my ($self, $product, $field) = @_;
    $self->{product_id_obj} = Bugzilla->user->check_can_admin_product($product->name);
    return $self->{product_id_obj}->id;
}

sub _set_cc_list
{
    my ($self, $cc_list) = @_;
    my %cc_ids;
    foreach my $cc (@$cc_list)
    {
        my $id = Bugzilla::User::login_to_id($cc, THROW_ERROR);
        $cc_ids{$id} = 1;
    }
    return [ keys %cc_ids ];
}

###############################
####       Methods         ####
###############################

sub create_series
{
    my $self = shift;

    # Insert default charting queries for this product.
    # If they aren't using charting, this won't do any harm.
    my $prodcomp = "&product=" . url_quote($self->product->name) .
        "&component=" . url_quote($self->name);

    my $open_query = 'field0-0-0=resolution&type0-0-0=notregexp&value0-0-0=.' . $prodcomp;
    my $nonopen_query = 'field0-0-0=resolution&type0-0-0=regexp&value0-0-0=.' . $prodcomp;

    my @series = (
        [ get_text('series_all_open'), $open_query ],
        [ get_text('series_all_closed'), $nonopen_query ]
    );

    foreach my $sdata (@series)
    {
        my $series = new Bugzilla::Series({
            category => $self->product->name,
            subcategory => $self->name,
            name => $sdata->[0],
            frequency => 1,
            query => $sdata->[1],
            public => 1,
        });
        $series->writeToDatabase();
    }
}

sub bug_count
{
    my $self = shift;
    return Bugzilla->get_field('component')->count_value_objects($self->id);
}

sub bug_ids
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if (!defined $self->{bug_ids})
    {
        $self->{bug_ids} = $dbh->selectcol_arrayref(
            'SELECT bug_id FROM bugs WHERE component_id = ?',
            undef, $self->id
        );
    }
    return $self->{bug_ids};
}

sub flag_types
{
    my $self = shift;
    if (!defined $self->{flag_types})
    {
        my $flagtypes = Bugzilla::FlagType::match({
            product_id   => $self->product_id,
            component_id => $self->id,
        });

        $self->{flag_types} = {};
        $self->{flag_types}->{bug} = [ grep { $_->target_type eq 'bug' } @$flagtypes ];
        $self->{flag_types}->{attachment} = [ grep { $_->target_type eq 'attachment' } @$flagtypes ];

        foreach my $type (@{$self->{flag_types}->{bug}}, @{$self->{flag_types}->{attachment}})
        {
            # Build custom userlist for setting flag (for enter_bug.cgi)
            my $cl = new Bugzilla::FlagType::UserList;
            $cl->add(DefaultAssignee => $_) for $self->default_assignee || ();
            $cl->add(CompQA => $_) for $self->default_qa_contact || ();
            $cl->add(CC => @{ $self->initial_cc || [] });
            $type = {
                type => $type,
                custom_list => $cl,
                allow_other => 1,
            };
        }
    }
    return $self->{flag_types};
}

###############################
####      Accessors        ####
###############################

sub is_active { $_[0]->isactive }
sub initial_cc { $_[0]->cc_obj }
sub product { $_[0]->product_id_obj }
sub default_assignee { $_[0]->initialowner_obj }
sub default_qa_contact { $_[0]->initialqacontact_obj }

1;

__END__

=head1 NAME

Bugzilla::Component - Bugzilla product component class.

=head1 SYNOPSIS

use Bugzilla::Component;

my $component = Bugzilla::Component->new($comp_id);

my $component = Bugzilla::Component->new({ product => $product, name => $name });

=head1 DESCRIPTION

Component.pm represents a Product Component object. It is a subclass of GenericObject,
so all DB interaction is done exactly as with any other GenericObject.

=head1 FIELDS

=over

=item B<product_id>: Bugzilla::Product

Parent product

=item B<name>: string

Component name, unique in the product

=item B<description>: text

Description (shown on the bug entry form)

=item B<initialowner>: Bugzilla::User

Default assignee for new bugs in this component

=item B<initialqacontact>: Bugzilla::User

Default QA contact for new bugs in this component

=item B<cc>: array(Bugzilla::User)

Default CC list for new bugs in this component

=item B<wiki_url>: string

Overrides product and global wiki URL settings

=item B<isactive>: boolean

Specifies if this component is open for bug entry

=back

=head1 METHODS

=over

=item new($id), new({ product => $product, name => $name })

 Contructor, gets a component from the DB.

=item B<bug_count()>

 Returns the total of bugs that belong to the component.

=item B<bug_ids()>

 Returns all bug IDs that belong to the component.

=item B<flag_types()>

 Returns all bug and attachment flagtypes available for the component
 as { bug => [ <FlagTypes for bugs> ], attachment => [ <FlagTypes for att.> ] }

=back

=cut
