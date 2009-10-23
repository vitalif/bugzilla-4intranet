package Text::TabularDisplay::Utf8;

use utf8;
use strict;
use base 'Text::TabularDisplay';

# -------------------------------------------------------------------
# render([$start, $end])
#
# Returns the data formatted as a table.  By default, all rows are
# returned; if $start or $end are specified, then only those indexes
# are returned.  Those are the start and end indexes!
# -------------------------------------------------------------------
sub render {
    my $self = shift;
    my $start = shift || 0;
    my $end = shift || $#{ $self->{ _DATA } };
    my $size = $self->{ _SIZE };
    my (@columns, $datum, @text);

    push @text, '┌' . join("┬", map( { "─" x ($_ + 2) } @{ $self->{ _LENGTHS } })) . '┐';

    if (@columns = $self->columns) {
        push @text, _format_line(\@columns, $self->{ _LENGTHS });
        push @text, '├' . join("┼", map( { "─" x ($_ + 2) } @{ $self->{ _LENGTHS } })) . '┤';
    }

    for (my $i = $start; $i <= $end; $i++) {
        $datum = $self->{ _DATA }->[$i];
        last unless defined $datum;

        # Pad the array if there are more elements in @columns
        push @$datum, ""
            until (@$datum == $size);
        push @text, _format_line($datum, $self->{ _LENGTHS });
    }

    push @text, '└' . join("┴", map( { "─" x ($_ + 2) } @{ $self->{ _LENGTHS } })) . '┘';
    return join "\n", @text;
}

# -------------------------------------------------------------------
# _column_length($str)
# -------------------------------------------------------------------
sub _column_length
{
    my ($str) = @_;

    my $len = 0;
    for (split "\n", $str) {
        $len = length
            if $len < length;
    }
    # why the /hell/ this length is tainted?..
    if (${^TAINT})
    {
        ($len) = $len =~ /(\d+)/so;
    }

    return $len;
}

*Text::TabularDisplay::_column_length = \&_column_length;

# -------------------------------------------------------------------
# _format_line(\@columns, \@lengths)
#
# Returns a formatted line out of @columns; the size of $column[$i]
# is determined by $length[$i].
# -------------------------------------------------------------------
sub _format_line {
    my ($columns, $lengths) = @_;

    my $height = 0;
    my @col_lines;
    for (@$columns) {
        my @lines = split "\n";
        $height = scalar @lines
            if $height < @lines;
        push @col_lines, \@lines;
    }

    my @lines;
    for my $h (0 .. $height - 1 ) {
        my @line;
        for (my $i = 0; $i <= $#$columns; $i++) {
            my $val = defined($col_lines[$i][$h]) ? $col_lines[$i][$h] : '';
            push @line, sprintf " %-" . $lengths->[$i] . "s ", $val;
        }
        push @lines, join '│', "", @line, "";
    }

    return join "\n", @lines;
}

1;
__END__

=head1 NAME

Text::TabularDisplay::Utf8 - Display text in formatted table output using UTF-8 pseudographics

=head1 SYNOPSIS

 use Text::TabularDisplay::Utf8;

 my $table = Text::TabularDisplay::Utf8->new(@columns);
 $table->add(@row)
     while (@row = $sth->fetchrow);
 print $table->render;

 ┌────┬──────────────┐
 │ id │ name         │
 ├────┼──────────────┤
 │ 1  │ Tom          │
 │ 2  │ Dick         │
 │ 3  │ Barry        │
 │    │  (aka Bazza) │
 │ 4  │ Harry        │
 └────┴──────────────┘

=head1 DESCRIPTION

The program interface is fully compatible with C<Text::TabularDisplay> -
see its perldoc for more information.
