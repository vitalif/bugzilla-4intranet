# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;

package Bugzilla::Report;

use base qw(Bugzilla::Object);

use Bugzilla::CGI;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Search;

use constant DB_TABLE => 'reports';

use constant DB_COLUMNS => qw(
    id
    user_id
    name
    query
);

use constant UPDATE_COLUMNS => qw(
    name
    query
);

use constant REQUIRED_CREATE_FIELDS => qw(
    user_id
    name
    query
);

use constant VALIDATORS => {
    name    => \&_check_name,
    query   => \&_check_query,
};

##############
# Validators #
##############

sub _check_name
{
    my ($invocant, $name) = @_;
    $name = clean_text($name);
    $name || ThrowUserError("report_name_missing");
    $name !~ /[<>&]/ || ThrowUserError("illegal_query_name");
    if (length($name) > MAX_FIELD_VALUE_SIZE)
    {
        ThrowUserError("query_name_too_long");
    }
    return $name;
}

sub _check_query
{
    my ($invocant, $query) = @_;
    $query || ThrowUserError('buglist_parameters_required');
    return http_build_query(Bugzilla::Search->clean_search_params(http_decode_query($query)));
}

#############
# Accessors #
#############

sub query { $_[0]->{query} }
sub user_id { $_[0]->{user_id} }

sub set_name { $_[0]->set('name', $_[1]); }
sub set_query { $_[0]->set('query', $_[1]); }

###########
# Methods #
###########

sub create
{
    my $class = shift;
    my $param = shift;

    Bugzilla->login(LOGIN_REQUIRED);
    $param->{user_id} = Bugzilla->user->id;

    unshift @_, $param;
    my $self = $class->SUPER::create(@_);
}

sub check
{
    my $class = shift;
    my $report = $class->SUPER::check(@_);
    my $user = Bugzilla->user;
    if ($report->user_id != Bugzilla->user->id)
    {
        ThrowUserError('report_access_denied');
    }
    return $report;
}

sub _get_names
{
    my ($names, $isnumeric, $field) = @_;

    # These are all the fields we want to preserve the order of in reports.
    my $f = $field && Bugzilla->get_field($field);
    if ($f && $f->is_select)
    {
        my $values = [ '', map { $_->name } @{ $f->legal_values(1) } ];
        my %dup;
        @$values = grep { exists($names->{$_}) && !($dup{$_}++) } @$values;
        return $values;
    }
    elsif ($isnumeric)
    {
        # It's not a field we are preserving the order of, so sort it
        # numerically...
        sub numerically { $a <=> $b }
        return [ sort numerically keys %$names ];
    }
    else
    {
        # ...or alphabetically, as appropriate.
        return [ sort keys %$names ];
    }
}

sub execute
{
    my $class = shift;
    my ($ARGS, $runner) = @_;

    my $valid_columns = Bugzilla::Search->REPORT_COLUMNS();

    my $field = {};
    for (qw(x y z))
    {
        my $f = $ARGS->{$_.'_axis_field'} || '';
        trick_taint($f);
        if ($f)
        {
            if ($valid_columns->{$f})
            {
                $field->{$_} = $f;
            }
            else
            {
                ThrowCodeError("report_axis_invalid", {fld => $_, val => $f});
            }
        }
    }

    if (!keys %$field)
    {
        ThrowUserError("no_axes_defined");
    }

    my $width = $ARGS->{width} || 600;
    my $height = $ARGS->{height} || 350;

    if (defined($width))
    {
        (detaint_natural($width) && $width > 0)
            || ThrowCodeError("invalid_dimensions");
        $width <= 2000 || ThrowUserError("chart_too_large");
    }

    if (defined($height))
    {
        (detaint_natural($height) && $height > 0)
            || ThrowCodeError("invalid_dimensions");
        $height <= 2000 || ThrowUserError("chart_too_large");
    }

    # These shenanigans are necessary to make sure that both vertical and
    # horizontal 1D tables convert to the correct dimension when you ask to
    # display them as some sort of chart.
    my $is_table;
    if ($ARGS->{format} eq 'table' || $ARGS->{format} eq 'simple')
    {
        $is_table = 1;
        if ($field->{x} && !$field->{y})
        {
            # 1D *tables* should be displayed vertically (with a row_field only)
            $field->{y} = $field->{x};
            delete $field->{x};
        }
    }
    else
    {
        if (!Bugzilla->feature('graphical_reports'))
        {
            ThrowCodeError('feature_disabled', { feature => 'graphical_reports' });
        }
        if ($field->{y} && !$field->{x})
        {
            # 1D *charts* should be displayed horizontally (with an col_field only)
            $field->{x} = $field->{y};
            delete $field->{y};
        }
    }

    my $measures = {
        etime => 'estimated_time',
        rtime => 'remaining_time',
        wtime => 'interval_time',
        count => '_count',
    };
    # Trick Bugzilla::Search: replace report columns SQL + add '_count' column
    # FIXME: Remove usage of global variable COLUMNS in search generation code
    my %old_columns = %{Bugzilla::Search->COLUMNS($runner)};
    %{Bugzilla::Search->COLUMNS($runner)} = (%{Bugzilla::Search->COLUMNS($runner)}, %{Bugzilla::Search->REPORT_COLUMNS});
    Bugzilla::Search->COLUMNS($runner)->{_count}->{name} = '1';

    my $measure = $ARGS->{measure} || '';
    if ($measure eq 'times' ? !$is_table : !$measures->{$measure})
    {
        $measure = 'count';
    }

    # Validate the values in the axis fields or throw an error.
    my %a;
    my @group_by = grep { !($a{$_}++) } values %$field;
    my @axis_fields = @group_by;
    for ($measure eq 'times' ? qw(etime rtime wtime) : $measure)
    {
        push @axis_fields, $measures->{$_} unless $a{$measures->{$_}};
    }

    # Clone the params, so that Bugzilla::Search can modify them
    my $search = new Bugzilla::Search(
        fields => \@axis_fields,
        params => { %$ARGS },
        user => $runner,
    );
    my $query = $search->getSQL();
    $query =
        "SELECT ".
        ($field->{x} || "''")." x, ".
        ($field->{y} || "''")." y, ".
        ($field->{z} || "''")." z, ".
        join(', ', map { "SUM($measures->{$_}) $_" } $measure eq 'times' ? qw(etime rtime wtime) : $measure).
        " FROM ($query) _report_table GROUP BY ".join(", ", @group_by);

    $::SIG{TERM} = 'DEFAULT';
    $::SIG{PIPE} = 'DEFAULT';

    my $results = Bugzilla->dbh->selectall_arrayref($query, {Slice=>{}});

    # We have a hash of hashes for the data itself, and a hash to hold the
    # row/col/table names.
    my %data;
    my %names;

    # Read the bug data and count the bugs for each possible value of row, column
    # and table.
    #
    # We detect a numerical field, and sort appropriately, if all the values are
    # numeric.
    my %isnumeric;

    foreach my $group (@$results)
    {
        for (qw(x y z))
        {
            $isnumeric{$_} &&= ($group->{$_} =~ /^-?\d+(\.\d+)?$/o);
            $names{$_}{$group->{$_}} = 1;
        }
        $data{$group->{z}}{$group->{x}}{$group->{y}} = $is_table ? $group : $group->{$measure};
    }

    my @tbl_names = @{_get_names($names{z}, $isnumeric{z}, $field->{z})};
    my @col_names = @{_get_names($names{x}, $isnumeric{x}, $field->{x})};
    my @row_names = @{_get_names($names{y}, $isnumeric{y}, $field->{y})};

    # The GD::Graph package requires a particular format of data, so once we've
    # gathered everything into the hashes and made sure we know the size of the
    # data, we reformat it into an array of arrays of arrays of data.
    push @tbl_names, "-total-" if scalar(@tbl_names) > 1;

    my @image_data;
    foreach my $tbl (@tbl_names)
    {
        my @tbl_data;
        push @tbl_data, \@col_names;
        foreach my $row (@row_names)
        {
            my @col_data;
            foreach my $col (@col_names)
            {
                $data{$tbl}{$col}{$row} ||= {};
                push @col_data, $data{$tbl}{$col}{$row};
                if ($tbl ne "-total-")
                {
                    # This is a bit sneaky. We spend every loop except the last
                    # building up the -total- data, and then last time round,
                    # we process it as another tbl, and push() the total values
                    # into the image_data array.
                    for my $m (keys %{$data{$tbl}{$col}{$row}})
                    {
                        next if $m eq 'x' || $m eq 'y' || $m eq 'z';
                        $data{"-total-"}{$col}{$row}{$m} += $data{$tbl}{$col}{$row}{$m};
                    }
                }
            }
            push @tbl_data, \@col_data;
        }
        unshift @image_data, \@tbl_data;
    }

    # Below a certain width, we don't see any bars, so there needs to be a minimum.
    if ($width && $ARGS->{format} eq "bar")
    {
        my $min_width = (scalar(@col_names) || 1) * 20;
        if (!$ARGS->{cumulate})
        {
            $min_width *= (scalar(@row_names) || 1);
        }
        $width = $min_width;
    }

    my $vars = {};

    $vars->{fields} = $field;

    # for debugging
    $vars->{query} = $query;

    # We need to keep track of the defined restrictions on each of the
    # axes, because buglistbase, below, throws them away. Without this, we
    # get buglistlinks wrong if there is a restriction on an axis field.
    $vars->{col_vals} = $field->{x} ? http_build_query({ $field->{x} => $ARGS->{$field->{x}} }) : '';
    $vars->{row_vals} = $field->{y} ? http_build_query({ $field->{y} => $ARGS->{$field->{y}} }) : '';
    $vars->{tbl_vals} = $field->{z} ? http_build_query({ $field->{z} => $ARGS->{$field->{z}} }) : '';
    my $a = { %$ARGS };
    delete $a->{$_} for qw(x_axis_field y_axis_field z_axis_field ctype format query_format measure), @axis_fields;
    $vars->{buglistbase} = http_build_query($a);

    $vars->{image_data} = \@image_data;
    $vars->{data} = \%data;
    $vars->{measure} = $measure;
    $vars->{tbl_field} = $field->{z};
    $vars->{col_field} = $field->{x};
    $vars->{row_field} = $field->{y};
    $vars->{col_names} = \@col_names;
    $vars->{row_names} = \@row_names;
    $vars->{tbl_names} = \@tbl_names;
    $vars->{width} = $width;
    $vars->{height} = $height;
    $vars->{cumulate} = $ARGS->{cumulate} ? 1 : 0;
    $vars->{x_labels_vertical} = $ARGS->{x_labels_vertical} ? 1 : 0;

    %{Bugzilla::Search->COLUMNS($runner)} = %old_columns;

    return $vars;
}

1;

__END__

=head1 NAME

Bugzilla::Report - Bugzilla report class.

=head1 SYNOPSIS

    use Bugzilla::Report;

    my $report = new Bugzilla::Report(1);

    my $report = Bugzilla::Report->check({id => $id});

    my $name = $report->name;
    my $query = $report->query;

    my $report = Bugzilla::Report->create({ name => $name, query => $query });

    $report->set_name($new_name);
    $report->set_query($new_query);
    $report->update();

    $report->remove_from_db;

=head1 DESCRIPTION

Report.pm represents a Report object. It is an implementation
of L<Bugzilla::Object>, and thus provides all methods that
L<Bugzilla::Object> provides.

=cut
