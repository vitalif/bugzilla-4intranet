#!/usr/bin/perl

# Text difference engine
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vladimir Koptev <vladimir.koptev@gmail.com>, Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Diff;

use utf8;
use strict;

use File::Temp;
use Bugzilla::Util;
use Encode;

use base qw(Exporter);
@Bugzilla::Diff::EXPORT = qw(
    get_table
    get_hash
    get_removed
    get_added
);

use constant MIN_LENGTH => 8;
use constant MAX_LENGTH => 80;
use constant MAX_LINES  => 3;

use constant TYPE_ADD  => '+';
use constant TYPE_REM  => '-';
use constant TYPE_UNI  => 'u';
use constant TYPE_EMP  => 'e';
use constant TYPE_SKP  => 's';
use constant SKIP_STRING  => '...';
use constant SKIP_LENGTH  => length(SKIP_STRING);

use constant VIEW_TAGS => {
    '<add>'  => '<b style="background: #CCC; color: #090;">',
    '</add>' => '</b>',
    '<rem>'  => '<b style="background: #CCC; color: #F00;">',
    '</rem>' => '</b>'
};
use constant VIEW_PLAIN_TAGS => {
    '<add>'  => "\n+",
    '</add>' => "\n",
    '<rem>'  => "\n-",
    '</rem>' => "\n"
};

sub new
{
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $object = {};
    my ($old, $new, $a) = @_;
    bless($object, $class) if $object;
    $object->{old} = $old;
    $object->{new} = $new;
    return $object;
}

# returns diff data formatted as a hash
sub get_hash
{
    my ($self, $force) = @_;
    $force = 0 unless $force;
    if ($force || !$self->{context})
    {
        $self->{diff} = $self->diff($self->{old}, $self->{new});
        $self->make_context;
        $self->apply_min_restriction;
        $self->cut_context;
        $self->glue_context;
        $self->{context}->{length} = scalar @{$self->{context}->{removed}};
    }
    return $self->{context};
}

# returns diff formatted as two-column HTML pairs
sub get_table
{
    my ($self, $force, $column) = @_;
    $force = 0 unless $force;
    my $diff = $self->get_hash($force);
    my $result = [];
    for (my $i = 0; $i < $self->{context}->{length}; $i++)
    {
        # old and new texts - [type, value]
        my ($old, $new) = ($self->{context}->{removed}->[$i], $self->{context}->{added}->[$i]);
        my ($oval, $nval) = ($old->{value}, $new->{value});

        for my $key (keys %{ VIEW_TAGS() })
        {
            my $val = VIEW_TAGS->{$key};
            $oval =~ s/$key/$val/g;
            $nval =~ s/$key/$val/g;
            $oval =~ s/\n/<br\/>/g;
            $nval =~ s/\n/<br\/>/g;
        }

        push @$result, '<td style="vertical-align: top' .
            ($old->{type} eq TYPE_REM ? '; border-width: 1px 1px 1px 5px; border-style: solid; border-color: red' : '').'">' .
            $oval . '</td><td style="vertical-align: top' .
            ($new->{type} eq TYPE_ADD ? '; border-width: 1px 1px 1px 5px; border-style: solid; border-color: #0a0' : '').'">' .
            $nval . '</td>';
    }
    return $result;
}

# get only removed (with context)
sub get_removed
{
    my ($self, $force) = @_;
    return $self->get_part(1, $force);
}

# get only added (with context)
sub get_added
{
    my ($self, $force) = @_;
    return $self->get_part(0, $force);
}

#  get only specified part (with context): first param - bool is_removed
sub get_part
{
    my ($self, $removed, $force) = @_;
    $force = 0 unless $force;
    $removed = 0 unless $removed;
    $removed = $removed ? 'removed' : 'added';
    my $diff = $self->get_hash($force);
    my $result = '';
    for (my $i = 0; $i < $self->{context}->{length}; $i++)
    {
        my $line = $self->{context}->{$removed}->[$i];
        my $lval = $line->{value};

        for my $key (keys %{ VIEW_PLAIN_TAGS() })
        {
            my $val = VIEW_PLAIN_TAGS->{$key};
            $lval =~ s/$key/$val/g;
        }

        $result .= "\n" . ($line->{type} eq TYPE_ADD ? TYPE_ADD : ($line->{type} eq TYPE_REM ? TYPE_REM : ' ')) . $lval;
    }
    return $result;
}

# make diff
sub diff
{
    my ($self, $old, $new) = @_;
    my $old_file = File::Temp->new;
    $old_file->unlink_on_destroy(1);
    my $new_file = File::Temp->new;
    $new_file->unlink_on_destroy(1);

    s/(.)/$1\n/gso for $old, $new;
    print $old_file $old;
    print $new_file $new;

    my $diff = `diff -u -U 2147483647 $old_file $new_file`;
    trick_taint($diff);
    Encode::_utf8_on($diff);
    my @diff = split "\n", $diff, -1;
    splice @diff, 0, 2;

    my $result = [[], []];
    ($old, $new) = @$result;
    my ($prev_action, $chunk, $nl);

    push @diff, '^'; # EOF character for if ($prev_action ne $action)
    for my $line (@diff)
    {
        Encode::_utf8_on($line);
        my $action = substr $line, 0, 1, '';
        $action = TYPE_UNI if $action eq ' ';
        if ($prev_action ne $action)
        {
            if (defined $prev_action)
            {
                # save previous chunk
                if ($prev_action eq TYPE_UNI || $prev_action eq TYPE_REM)
                {
                    if (@$new < @$old)
                    {
                        push @$new, [ TYPE_UNI, '' ];
                    }
                    push @$old, [ $prev_action, $chunk ];
                }
                if ($prev_action eq TYPE_UNI || $prev_action eq TYPE_ADD)
                {
                    push @$new, [ $prev_action, $chunk ];
                    if (@$old < @$new)
                    {
                        push @$old, [ TYPE_UNI, '' ];
                    }
                }
            }
            # start new chunk
            $prev_action = $action;
            $chunk = '';
        }
        if ($line eq '')
        {
            # newline character = 2 empty lines
            if ($nl)
            {
                $line = "\n";
                $nl = 0;
            }
            else
            {
                $nl = 1;
            }
        }
        else
        {
            $nl = 0;
        }
        $chunk .= $line;
    }
    if (@$new < @$old)
    {
        push @$new, [ TYPE_UNI, '' ];
    }
    return $result;
}

# Make common (for removed and added parts) context
sub make_context
{
    my ($self) = @_;
    my $len = scalar @{$self->{diff}->[0]};
    my ($removed, $added) = ([], []);
    $self->{context} = { removed => $removed, added => $added };
    for (my $i = 0; $i < $len; $i++)
    {
        # old and new texts - [type, value]
        my ($old, $new) = ($self->{diff}->[0]->[$i], $self->{diff}->[1]->[$i]);
        # if unchanged (context)
        if ($old->[0] eq TYPE_UNI && $new->[0] eq TYPE_UNI)
        {
            # compare lengths and push equal parts of context according to lengths
            my ($rl, $al) = (length($old->[1]), length($new->[1]));
            if ($rl < $al)
            {
                push @$removed, { value => $old->[1], type => TYPE_UNI };
                push @$removed, { value => '', type => TYPE_EMP };
                push @$added,   { value => substr($new->[1], 0, $rl), type => TYPE_UNI };
                push @$added,   { value => substr($new->[1], $rl), type => TYPE_UNI };
            }
            elsif ($rl > $al)
            {
                push @$added,   { value => $new->[1], type => TYPE_UNI };
                push @$added,   { value => '', type => TYPE_EMP };
                push @$removed, { value => substr($old->[1], 0, $al), type => TYPE_UNI };
                push @$removed, { value => substr($old->[1], $al), type => TYPE_UNI };
            }
            else
            {
                push @$removed, { value => $old->[1], type => TYPE_UNI };
                push @$added,   { value => $new->[1], type => TYPE_UNI };
            }
        }
        # if removed
        elsif ($old->[0] eq TYPE_REM && $new->[0] eq TYPE_UNI)
        {
            push @$removed, { value => $old->[1], type => TYPE_REM };
            push @$added,   { value => '', type => TYPE_EMP };
        }
        # if added
        elsif ($old->[0] eq TYPE_UNI && $new->[0] eq TYPE_ADD)
        {
            push @$removed, { value => '', type => TYPE_EMP };
            push @$added,   { value => $new->[1], type => TYPE_ADD };
        }
        # if changed
        elsif ($old->[0] eq TYPE_REM && $new->[0] eq TYPE_ADD)
        {
            push @$removed, { value => $old->[1], type => TYPE_REM };
            push @$added,   { value => $new->[1], type => TYPE_ADD };
        }
        else
        {
            die __PACKAGE__.' BUG at diff part '.$i.'/'.$len.': ' . $old->[0] . ' vs ' . $new->[0];
        }
    }
    # recalc length
    $self->{context}->{length} = scalar @$removed;
}

# apply min length of "u" restriction
sub apply_min_restriction
{
    my ($self) = @_;
    # link to contexts
    my ($removed, $added) = ($self->{context}->{removed}, $self->{context}->{added});
    # for each line
    for (my $i = 0; $i < $self->{context}->{length}; $i++)
    {
        my ($old, $new) = ($removed->[$i], $added->[$i]);
        # if length is less than MIN_LENGTH mark "u" as rem/add
        if ((length($old->{value}) <= MIN_LENGTH) && ($old->{type} eq TYPE_UNI))
        {
            $old->{type} = TYPE_REM;
            $new->{type} = TYPE_ADD;
        }
    }
    # glue close rem/add
    for (my $i = 0; $i < $self->{context}->{length} - 1; $i++)
    {
        # hell condition:
        # (--) && (++ || +e || e+ || ee) || (-- || -e || e- || ee) && (++)
        my $a  = $removed->[$i]->{type} eq TYPE_REM;
        my $a1 = $removed->[$i]->{type} eq TYPE_EMP;
        my $b  = $removed->[$i+1]->{type} eq TYPE_REM;
        my $b1 = $removed->[$i+1]->{type} eq TYPE_EMP;
        my $c  = $added->[$i]->{type} eq TYPE_ADD;
        my $c1 = $added->[$i]->{type} eq TYPE_EMP;
        my $d  = $added->[$i+1]->{type} eq TYPE_ADD;
        my $d1 = $added->[$i+1]->{type} eq TYPE_EMP;
        if (
            $a && $b && ($c && $d || $c && $d1 || $c1 && $d || $c1 && $d1) ||
            $c && $d && ($a && $b || $a && $b1 || $a1 && $b || $a1 && $b1)
        )
        {
            # glue them
            $removed->[$i]->{value} .= $removed->[$i+1]->{value};
            $removed->[$i]->{type} = TYPE_REM;
            $added->[$i]->{value} .= $added->[$i+1]->{value};
            $added->[$i]->{type} = TYPE_ADD;
            splice @$removed, $i+1, 1;
            splice @$added, $i+1, 1;
            $self->{context}->{length} = scalar @$removed;
            $i--;
        }
    }
}

# Make context shorter
sub cut_context
{
    my ($self) = @_;
    # first restrict length
    for (my $i = 0; $i < $self->{context}->{length}; $i++)
    {
        $self->apply_length_restriction($i);
        $self->{context}->{length} = scalar @{$self->{context}->{removed}};
    }
    # then restrict line count
    for (my $i = 0; $i < $self->{context}->{length}; $i++)
    {
        $self->apply_line_restriction($i);
        $self->{context}->{length} = scalar @{$self->{context}->{removed}};
    }
}

# restrict max length of "u"
sub apply_length_restriction
{
    my ($self, $i) = @_;
    for my $what (('removed', 'added'))
    {
        my $array = $self->{context}->{$what};
        my $line = $array->[$i];
        # only if type of line is "u"
        if ($line->{type} eq TYPE_UNI)
        {
            my $l = length($line->{value});
            # length of first item is greater than MAX_LENGTH
            if (($l > MAX_LENGTH) && ($i == 0))
            {
                # cut it to MAX_LENGTH and insert before "skip" line
                $array->[0]->{value} = SKIP_STRING . substr($line->{value}, -(MAX_LENGTH + SKIP_LENGTH));
            }
            # length of last item is greater than MAX_LENGTH
            elsif (($l > MAX_LENGTH) && ($i == $self->{context}->{length} - 1))
            {
                # cut it to MAX_LENGTH and insert after "skip" line
                $array->[$i]->{value} = substr($line->{value}, 0, MAX_LENGTH - SKIP_LENGTH) . SKIP_STRING;
            }
            # length of i-th item is greater than 2*MAX_LENGTH (per MAX_LENGTH for prev and next lines)
            elsif ($l > 2*MAX_LENGTH && ($i > 0) && ($i < $self->{context}->{length} - 1))
            {
                # cut it to (MAX_LENGTH, "skip", MAX_LENGTH)
                splice @$array, $i+1, 0, { type => TYPE_SKP, value => SKIP_STRING };
                splice @$array, $i+2, 0, { type => TYPE_UNI, value => SKIP_STRING . substr($line->{value}, -(MAX_LENGTH + SKIP_LENGTH)) };
                $array->[$i]->{value} = substr($line->{value}, 0, MAX_LENGTH - SKIP_LENGTH) . SKIP_STRING;
            }
        }
    }
}

# restrict max lines count of "u"
sub apply_line_restriction
{
    my ($self, $i) = @_;
    for my $what (('removed', 'added'))
    {
        my $array = $self->{context}->{$what};
        my $line = $array->[$i];
        # only if type of line is "u"
        if ($line->{type} eq TYPE_UNI)
        {
            my $n = ($line->{value} =~ tr/\n/\n/);
            # lines count of first item is greater than MAX_LINES
            if (($n > MAX_LINES) && ($i == 0))
            {
                # cut it to MAX_LINES lines and insert before "skip" line
                my $offset = $self->rindex_i($line->{value}, "\n", MAX_LINES) + 1;
                splice @$array, $i, 0, { type => TYPE_SKP, value => SKIP_STRING };
                $array->[$i+1]->{value} = substr($line->{value}, $offset);
            }
            # lines count of last item is greater than MAX_LINES
            elsif (($n > MAX_LINES) && ($i == $self->{context}->{length} - 1))
            {
                # cut it to MAX_LINES lines and insert after "skip" line
                my $offset = $self->index_i($line->{value}, "\n", MAX_LINES) + 1;
                $array->[$i]->{value} = substr($line->{value}, 0, $offset);
                push @$array, { type => TYPE_SKP, value => SKIP_STRING };
            }
            # other cases
            else
            {
                # apply line restriction for i-th item
                $self->apply_line_restriction_i($i, $what);
            }
        }
    }
}

# apply max lines restriction count to i-th item
sub apply_line_restriction_i
{
    my ($self, $i, $what) = @_;
    my $array = $self->{context}->{$what};
    my $line = $array->[$i];
    my $n = ($line->{value} =~ tr/\n/\n/);
    # if before there is "skip" and current contains more than MAX_LINES lines
    if (($array->[$i-1]->{type} eq TYPE_SKP) && ($n > MAX_LINES))
    {
        # just cut it
        my $offset = $self->rindex_i($line->{value}, "\n", MAX_LINES) + 1;
        $array->[$i]->{value} = substr($line->{value}, $offset);
    }
    # if after there is "skip" and current contains more than MAX_LINES lines
    elsif (($array->[$i+1]->{type} eq TYPE_SKP) && ($n > MAX_LINES))
    {
        # just cut it
        my $offset = $self->index_i($line->{value}, "\n", MAX_LINES) + 1;
        $array->[$i]->{value} = substr($line->{value}, 0, $offset);
    }
    # if around there is no "skip" and current contains more than 2*MAX_LINES (per MAX_LINES for prev and next lines) lines
    elsif ($n > 2*MAX_LINES)
    {
        # cut it to (MAX_LINES, "skip", MAX_LINES)
        my $begin = substr($line->{value}, 0, $self->index_i($line->{value}, "\n", MAX_LINES) + 1);
        my $end   = substr($line->{value}, $self->rindex_i($line->{value}, "\n", MAX_LINES) + 1);
        splice @$array, $i+1, 0, { type => TYPE_SKP, value => SKIP_STRING };
        splice @$array, $i+2, 0, { type => TYPE_UNI, value => $end };
        $array->[$i]->{value} = $begin;
    }
}

# helper: index n-th needle in search
sub index_i
{
    my ($self, $search, $needle, $n) = @_;
    my $offset = 0;
    for(my $j = 0; $j < $n; $j++)
    {
        $offset = index($search, $needle, $offset) + 1;
    }
    return $offset - 1;
}

# helper: rindex n-th needle in search
sub rindex_i
{
    my ($self, $search, $needle, $n) = @_;
    my $offset = length($search);
    for(my $j = 0; $j < $n; $j++)
    {
        $offset = rindex($search, $needle, $offset) - 1;
    }
    return $offset + 1;
}

# Glue adjacent chunks if they span a line.
sub glue_context
{
    my ($self) = @_;
    my ($or, $oa) = @{$self->{context}}{qw(removed added)};
    for (@$or)
    {
        $_->{value} = '<rem>' . $_->{value} . '</rem>' if $_->{type} eq TYPE_REM;
    }
    for (@$oa)
    {
        $_->{value} = '<add>' . $_->{value} . '</add>' if $_->{type} eq TYPE_ADD;
    }
    my $len = scalar @$or;
    for (my $i = 1; $i < $len; $i++)
    {
        if (($or->[$i-1]->{type} ne TYPE_SKP && $or->[$i]->{type} ne TYPE_SKP) &&
            ($or->[$i-1]->{value} !~ /\n$/s || $oa->[$i-1]->{value} !~ /\n$/s))
        {
            for ($or, $oa)
            {
                $_->[$i-1]->{value} .= $_->[$i]->{value};
                # Don't care about (i-1 == EMP && i == UNI) - it doesn't make sense after glue_context
                $_->[$i-1]->{type} = $_->[$i]->{type} if $_->[$i]->{type} eq TYPE_REM || $_->[$i]->{type} eq TYPE_ADD;
                splice @$_, $i, 1;
            }
            $i--;
            $len--;
        }
    }
    $self->{context}->{length} = scalar @{$self->{context}->{removed}};
}

1;
