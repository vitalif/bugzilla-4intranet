# Text diffirence engine
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vladimir Koptev <vladimir.koptev@gmail.com>


package Bugzilla::Diff;

use utf8;
use strict;

use String::Diff;

use base qw(Exporter);
@Bugzilla::Diff::EXPORT = qw(
    get_table
    get_hash
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

use constant TAGS => {
    '+' => ['<add>', '</add>'],
    '-' => ['<rem>', '</rem>']
};

use constant VIEW_TAGS => {
    '<add>'  => '<b style="background: #CCC; color: #090;">',
    '</add>' => '</b>',
    '<rem>'  => '<b style="background: #CCC; color: #F00;">',
    '</rem>' => '</b>'
};

sub new
{
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $object = {};
    my ($old, $new) = @_;
    bless($object, $class) if $object;
    $object->{'old'} = $old;
    $object->{'new'} = $new;
    $object->{'diff'} = String::Diff::diff_fully($old, $new, line_break => 1);
    return $object;
}

# Diffs with full context
sub get_hash
{
    my ($self, $force) = @_;
    $force = 0 if !$force;
    if ($force || !($self->{'context'}))
    {
        $self->make_context;
        $self->apply_min_restriction;
        $self->short_context;
        $self->glue_context;
    }
    return $self->{'context'};
}

# templated diff
sub get_table
{
    my ($self, $force) = @_;
    $force = 0 if !$force;
    my $diff = $self->get_hash($force);
    my $result = '<table width="100%">';
    for (my $i = 0; $i < $self->{'context'}->{'length'}; $i++)
    {
        # old and new texts - [type, value]
        my ($old, $new) = ($self->{'context'}->{'removed'}->[$i], $self->{'context'}->{'added'}->[$i]);
        my ($oval, $nval) = ($old->{'value'}, $new->{'value'});

        for my $key (keys VIEW_TAGS)
        {
            my $val = VIEW_TAGS->{$key};
            $oval =~ s/$key/$val/g;
            $nval =~ s/$key/$val/g;
            $oval =~ s/\n/<br\/>/g;
            $nval =~ s/\n/<br\/>/g;
        }

        $result .= '<tr>';
        $result .= '<td valign="top" width="1%">' . ($old->{'type'} eq TYPE_REM ? TYPE_REM : '') . '</td>';
        $result .= '<td valign="top" width="49%"' . ($old->{'type'} eq TYPE_REM ? ' style="border: 1px solid #900;"' : '') . '>' . $oval . '</td>';
        $result .= '<td valign="top" width="1%">' . ($new->{'type'} eq TYPE_ADD ? TYPE_ADD : '') . '</td>';
        $result .= '<td valign="top" width="49%"' . ($new->{'type'} eq TYPE_ADD ? ' style="border: 1px solid #090;"' : '') . '>' . $nval . '</td>';
        $result .= '</tr>';
    }
    $result .= '</table>';
    return $result;
}

# Make common (for removed and added parts) context
sub make_context
{
    my ($self) = @_;
    # indexes to $self->{diff} arrays
    my ($ri, $ai) = (0, 0);
    # lengthes of $self->{diff} arrays
    my ($r_count, $a_count) = ((scalar @{$self->{'diff'}->[0]}), (scalar @{$self->{'diff'}->[1]}));

    # clear context
    $self->{'context'} = {'removed' => [], 'added' => []};
    # link to contexts
    my ($removed, $added) = ($self->{'context'}->{'removed'}, $self->{'context'}->{'added'});
    # Go!
    for (; $ri < $r_count && $ai < $a_count ;)
    {
        # old and new texts - [type, value]
        my ($old, $new) = ($self->{'diff'}->[0]->[$ri], $self->{'diff'}->[1]->[$ai]);
         # if not changed
        if ($old->[0] eq TYPE_UNI && $new->[0] eq TYPE_UNI)
        {
            # compare lengthes and push to context equal parts according to lengthes
            my ($rl, $al) = (length($old->[1]), length($new->[1]));
            if ($rl < $al)
            {
                push $removed, {'value' => $old->[1], 'type' => TYPE_UNI};
                push $removed, {'value' => '', 'type' => TYPE_EMP};
                push $added,   {'value' => substr($new->[1], 0, $rl), 'type' => TYPE_UNI};
                push $added,   {'value' => substr($new->[1], $rl), 'type' => TYPE_UNI};
            }
            elsif ($rl > $al)
            {
                push $added,   {'value' => $new->[1], 'type' => TYPE_UNI};
                push $added,   {'value' => '', 'type' => TYPE_EMP};
                push $removed, {'value' => substr($old->[1], 0, $al), 'type' => TYPE_UNI};
                push $removed, {'value' => substr($old->[1], $al), 'type' => TYPE_UNI};
            }
            else
            {
                push $removed, {'value' => $old->[1], 'type' => TYPE_UNI};
                push $added,   {'value' => $new->[1], 'type' => TYPE_UNI};
            }
            $ri++;
            $ai++;
        }
        # if old removed and new not changed
        elsif ($old->[0] eq TYPE_REM && $new->[0] eq TYPE_UNI)
        {
            push $removed, {'value' => $old->[1], 'type' => TYPE_REM};
            push $added,   {'value' => '', 'type' => TYPE_EMP};
            $ri++;
        }
        # if old not changed and new added
        elsif ($old->[0] eq TYPE_UNI && $new->[0] eq TYPE_ADD)
        {
            push $removed, {'value' => '', 'type' => TYPE_EMP};
            push $added,   {'value' => $new->[1], 'type' => TYPE_ADD};
            $ai++;
        }
        # if old removed and new added
        elsif ($old->[0] eq TYPE_REM && $new->[0] eq TYPE_ADD)
        {
            push $removed, {'value' => $old->[1], 'type' => TYPE_REM};
            push $added,   {'value' => $new->[1], 'type' => TYPE_ADD};
            $ri++;
            $ai++;
        }
    }
    # if something removed from end
    for (; $ri < $r_count; $ri++)
    {
        push $removed, {'value' => $self->{'diff'}->[0]->[$ri]->[1], 'type' => $self->{'diff'}->[0]->[$ri]->[0]};
        push $added,   {'value' => '', 'type' => TYPE_EMP};
    }
    # if something added to end
    for (; $ai < $a_count; $ai++)
    {
        push $removed, {'value' => '', 'type' => TYPE_EMP};
        push $added,   {'value' => $self->{'diff'}->[1]->[$ai]->[1], 'type' => $self->{'diff'}->[1]->[$ai]->[0]};
    }
    # recacl length
    $self->{'context'}->{'length'} = scalar @$removed;
}

# apply min length of "u" restriction
sub apply_min_restriction
{
    my ($self) = @_;
    # link to contexts
    my ($removed, $added) = ($self->{'context'}->{'removed'}, $self->{'context'}->{'added'});
    # for each line
    for (my $i = 0; $i < $self->{'context'}->{'length'}; $i++)
    {
        my ($old, $new) = ($removed->[$i], $added->[$i]);
        # if length is less than MIN_LENGTH mark "u" as rem/add
        if ((length($old->{'value'}) <= MIN_LENGTH) && ($old->{'type'} eq TYPE_UNI))
        {
            $old->{'type'} = TYPE_REM;
            $new->{'type'} = TYPE_ADD;
        }
    }
    # glue close rem/add
    for (my $i = 0; $i < $self->{'context'}->{'length'} - 1; $i++)
    {
        # hell condition:
        # (--) && (++ || +e || e+ || ee) || (-- || -e || e- || ee) && (++)
        my $a  = $removed->[$i]->{'type'} eq TYPE_REM;
        my $a1 = $removed->[$i]->{'type'} eq TYPE_EMP;
        my $b  = $removed->[$i+1]->{'type'} eq TYPE_REM;
        my $b1 = $removed->[$i+1]->{'type'} eq TYPE_EMP;
        my $c  = $added->[$i]->{'type'} eq TYPE_ADD;
        my $c1 = $added->[$i]->{'type'} eq TYPE_EMP;
        my $d  = $added->[$i+1]->{'type'} eq TYPE_ADD;
        my $d1 = $added->[$i+1]->{'type'} eq TYPE_EMP;
        if (
            $a && $b && ($c && $d || $c && $d1 || $c1 && $d || $c1 && $d1) ||
            $c && $d && ($a && $b || $a && $b1 || $a1 && $b || $a1 && $b1)
        )
        {
            # glue them
            $removed->[$i]->{'value'} .= $removed->[$i+1]->{'value'};
            $removed->[$i]->{'type'} = TYPE_REM;
            $added->[$i]->{'value'} .= $added->[$i+1]->{'value'};
            $added->[$i]->{'type'} = TYPE_ADD;
            splice $removed, $i+1, 1;
            splice $added, $i+1, 1;
            $self->{'context'}->{'length'} = scalar @$removed;
            $i--;
        }
    }
}

# Make context shorter
sub short_context
{
    my ($self) = @_;
    # first apply length restriction
    for (my $i = 0; $i < $self->{'context'}->{'length'}; $i++)
    {
        $self->apply_length_restriction($i);
        $self->{'context'}->{'length'} = scalar @{$self->{'context'}->{'removed'}};
    }
    #last apply lines restriction
    for (my $i = 0; $i < $self->{'context'}->{'length'}; $i++)
    {
        $self->apply_line_restriction($i);
        $self->{'context'}->{'length'} = scalar @{$self->{'context'}->{'removed'}};
    }
}

# apply max length of "u" restriction
sub apply_length_restriction
{
    my ($self, $i) = @_;
    for my $what (('removed', 'added'))
    {
        my $array = $self->{'context'}->{$what};
        my $line = $array->[$i];
        # only if type of line is "u"
        if ($line->{'type'} eq TYPE_UNI)
        {
            my $l = length($line->{'value'});
            # length of first item is greater than MAX_LENGTH
            if (($l > MAX_LENGTH) && ($i == 0))
            {
                # cut it to MAX_LENGTH and insert before "skip" line
                splice $array, $i, 0, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
                $array->[$i+1]->{'value'} = SKIP_STRING . substr($line->{'value'}, -(MAX_LENGTH + SKIP_LENGTH));
            }
            # length of last item is greater than MAX_LENGTH
            elsif (($l > MAX_LENGTH) && ($i == $self->{'context'}->{'length'} - 1))
            {
                # cut it to MAX_LENGTH and insert after "skip" line
                $array->[$i]->{'value'} = substr($line->{'value'}, 0, MAX_LENGTH - SKIP_LENGTH) . SKIP_STRING;
                push $array, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
            }
            # length of i-th item is greater than 2*MAX_LENGTH (per MAX_LENGTH for prev and next lines)
            elsif ($l > 2*MAX_LENGTH && ($i > 0) && ($i < $self->{'context'}->{'length'} - 1))
            {
                # cut it to (MAX_LENGTH, "skip", MAX_LENGTH)
                splice $array, $i+1, 0, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
                splice $array, $i+2, 0, {'type' => TYPE_UNI, 'value' => SKIP_STRING . substr($line->{'value'}, -(MAX_LENGTH + SKIP_LENGTH))};
                $array->[$i]->{'value'} = substr($line->{'value'}, 0, MAX_LENGTH - SKIP_LENGTH) . SKIP_STRING;
            }
        }
    }
}

# apply max lines count of "u" restriction
sub apply_line_restriction
{
    my ($self, $i) = @_;
    for my $what (('removed', 'added'))
    {
        my $array = $self->{'context'}->{$what};
        my $line = $array->[$i];
        # only if type of line is "u"
        if ($line->{'type'} eq TYPE_UNI)
        {
            my $n = ($line->{'value'} =~ tr/\n/\n/);
            # lines count of first item is greater than MAX_LINES
            if (($n > MAX_LINES) && ($i == 0))
            {
                # cut it to MAX_LINES lines and insert before "skip" line
                my $offset = $self->rindex_i($line->{'value'}, "\n", MAX_LINES) + 1;
                splice $array, $i, 0, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
                $array->[$i+1]->{'value'} = substr($line->{'value'}, $offset);
            }
            # lines count of last item is greater than MAX_LINES
            elsif (($n > MAX_LINES) && ($i == $self->{'context'}->{'length'} - 1))
            {
                # cut it to MAX_LINES lines and insert after "skip" line
                my $offset = $self->index_i($line->{'value'}, "\n", MAX_LINES) + 1;
                $array->[$i]->{'value'} = substr($line->{'value'}, 0, $offset);
                push $array, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
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
    my $array = $self->{'context'}->{$what};
    my $line = $array->[$i];
    my $n = ($line->{'value'} =~ tr/\n/\n/);
    # if before there is "skip" and current contains more than MAX_LINES lines
    if (($array->[$i-1]->{'type'} eq TYPE_SKP) && ($n > MAX_LINES))
    {
        # just cut it
        my $offset = $self->rindex_i($line->{'value'}, "\n", MAX_LINES) + 1;
        $array->[$i]->{'value'} = substr($line->{'value'}, $offset);
    }
    # if after there is "skip" and current contains more than MAX_LINES lines
    elsif (($array->[$i+1]->{'type'} eq TYPE_SKP) && ($n > MAX_LINES))
    {
        # just cut it
        my $offset = $self->index_i($line->{'value'}, "\n", MAX_LINES) + 1;
        $array->[$i]->{'value'} = substr($line->{'value'}, 0, $offset);
    }
    # if around there is no "skip" and current contains more than 2*MAX_LINES (per MAX_LINES for prev and next lines) lines
    elsif ($n > 2*MAX_LINES)
    {
        # cut it to (MAX_LINES, "skip", MAX_LINES)
        my $begin = substr($line->{'value'}, 0, $self->index_i($line->{'value'}, "\n", MAX_LINES) + 1);
        my $end   = substr($line->{'value'}, $self->rindex_i($line->{'value'}, "\n", MAX_LINES) + 1);
        splice $array, $i+1, 0, {'type' => TYPE_SKP, 'value' => SKIP_STRING};
        splice $array, $i+2, 0, {'type' => TYPE_UNI, 'value' => $end};
        $array->[$i]->{'value'} = $begin;
    }
}

# helper: index n-th needle in search
sub index_i()
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
sub rindex_i()
{
    my ($self, $search, $needle, $n) = @_;
    my $offset = length($search);
    for(my $j = 0; $j < $n; $j++)
    {
        $offset = rindex($search, $needle, $offset) - 1;
    }
    return $offset + 1;
}

# glue context if there are no linebreaks at begin or end of item
sub glue_context
{
    my ($self) = @_;
    # recalc count every iteration
    for (my $i = 0; $i < (scalar @{$self->{'context'}->{'removed'}}) - 1; $i++)
    {
        # glue i-th item
        $i += $self->glue_context_i($i);
    }
    $self->{'context'}->{'length'} = scalar @{$self->{'context'}->{'removed'}};
    # encloed in tags if item is full rem/add
    for (my $i = 0; $i < $self->{'context'}->{'length'}; $i++)
    {
        for my $key (('removed', 'added'))
        {
            my $line = $self->{'context'}->{$key}->[$i];
            my $act = TYPE_REM;
            $act = TYPE_ADD if $key ne 'removed';
            $line->{'value'} = TAGS->{$act}->[0] . $line->{'value'} . TAGS->{$act}->[1] if $line->{'type'} eq $act;
            $line->{'type'} = $act if $line->{'type'} eq TYPE_UNI . $act;
        }
    }
}

# glue context of i-th item
sub glue_context_i
{
    my ($self, $i, $what) = @_;
    $what = 'removed' if !$what;
    my $array = $self->{'context'}->{$what};
    my $rarray = $self->{'context'}->{$what eq 'removed' ? 'added' : 'removed'};
    my $act = TYPE_REM;
    my $ract = TYPE_ADD;
    $act = TYPE_ADD if $what ne 'removed';
    $ract = TYPE_REM if $what ne 'removed';
    if (substr($array->[$i]->{'value'}, -1) ne "\n" && substr($array->[$i+1]->{'value'}, 0, 1) ne "\n")
    {
        # glue variants (x(what) = {removed => -, added => +}; u = [u, u+, u-, e]): {i=>x, i+1=>u}, {i=>x, i+1=>u}, {i=>u, i+1=>u, reverse}
        if ($array->[$i]->{'type'} eq $act && substr($array->[$i+1]->{'type'}, 0, 1) eq TYPE_UNI)
        {
            $array->[$i]->{'value'} = TAGS->{$act}->[0] . $array->[$i]->{'value'} . TAGS->{$act}->[1] . $array->[$i+1]->{'value'};
            $array->[$i]->{'type'} = TYPE_UNI . $act;
            my $result = $self->glue_context_i($i, 'added') if ($what eq 'removed');
            splice $array, $i+1, 1;
            return $result if ($what eq 'removed');
            return -1;
        }
        elsif (substr($array->[$i]->{'type'}, 0, 1) eq TYPE_UNI && $array->[$i+1]->{'type'} eq $act)
        {
            $array->[$i]->{'value'} = $array->[$i]->{'value'} . TAGS->{$act}->[0] . $array->[$i+1]->{'value'} . TAGS->{$act}->[1];
            $array->[$i]->{'type'} = TYPE_UNI . $act;
            my $result = $self->glue_context_i($i, 'added') if ($what eq 'removed');
            splice $array, $i+1, 1;
            return $result if ($what eq 'removed');
            return -1;
        }
        elsif (($array->[$i]->{'type'} ne TYPE_SKP) && ($array->[$i+1]->{'type'} ne TYPE_SKP) && ($rarray->[$i]->{'type'} ne $ract) && ($rarray->[$i+1]->{'type'} ne $ract))
        {
            $array->[$i]->{'value'} = $array->[$i]->{'value'} . $array->[$i+1]->{'value'};
            $array->[$i]->{'type'} = (
                $array->[$i]->{'type'} ne TYPE_UNI && $array->[$i]->{'type'} ne TYPE_EMP  ? $array->[$i]->{'type'} :
                ($array->[$i+1]->{'type'} ne TYPE_UNI && $array->[$i+1]->{'type'} ne TYPE_EMP ? $array->[$i+1]->{'type'} : TYPE_UNI)
            );
            my $result = $self->glue_context_i($i, 'added') if ($what eq 'removed');
            splice $array, $i+1, 1;
            return $result if ($what eq 'removed');
            return -1;
        }
    }
    return 0;
}

1;
