#!/usr/bin/perl -wT
# Print SCRUM-like cards for bugs
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>

use strict;
use Bugzilla;
use Bugzilla::Util qw(trim html_quote);
use Scalar::Util qw(blessed);
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
my $user = Bugzilla->login;
my $args = { %{ $cgi->Vars } };
my $vars = {};

# Default $Layout settings
my $l = {
    cols => int($args->{t_cols} || 0) > 0 ? int($args->{t_cols} || 0) : undef,
    rows => int($args->{t_rows} || 0) > 0 ? int($args->{t_rows} || 0) : undef,
    fs   => 12,
    pw   => 20,
    ph   => 27.7,
    cw   => undef,
    ch   => undef,
    cmt  => 0.3,
    cmr  => 0.1,
    cmb  => 0.1,
    cml  => 0.1,
};

$l->{cardtext} = <<'EOF';
<table class="card" cellspacing="5">
 <tr>
  <td class="dot"><a href="show_bug.cgi?id={bug_id}">{bug_id}</a></td>
  <td class="sevpri">{substr(bug_severity, 0, 3)}&nbsp;{substr(priority, 0, 3)}</td>
  <td class="dot">{substr(target_milestone, 0, 5)}</td>
 </tr>
 <tr><td colspan="3" class="spc"></td></tr>
 <tr>
  <td colspan="3" class="desc"><div>{short_desc}</div></td>
 </tr>
 <tr><td colspan="3" class="spc"></td></tr>
 <tr>
  <td colspan="3" style="font-size: 130%">
   <input type="text" class="est"
     name="e{bug_id}{_repeated}"
     value="{_estimate}" />
  </td>
 </tr>
</table>
EOF

# Parse layout settings from the request
for (qw(pw ph cw ch cmt cmr cmb cml fs))
{
    $l->{$_} = $1 if defined $args->{"t_$_"} && $args->{"t_$_"} =~ /^([\d\.]+)$/ && $1 >= 0;
}

# Parse layout settings from text
if ($args->{load_settings})
{
    my $ls = load_settings($args->{settings_text});
    for (keys %$ls)
    {
        $l->{$_} = $ls->{$_} if $ls->{$_} ne '';
    }
    $vars->{load_settings} = 1;
}

# Calculate card size from wanted count, or count from wanted size
if ($l->{cols} && $l->{rows})
{
    $l->{ncw} = sprintf("%.2f", ($l->{pw} / $l->{cols}) - $l->{cml} - $l->{cmr});
    $l->{nch} = sprintf("%.2f", ($l->{ph} / $l->{rows}) - $l->{cmt} - $l->{cmb});
    $l->{cw} = $l->{ncw} if !$l->{cw} || $l->{ncw} < $l->{cw};
    $l->{ch} = $l->{nch} if !$l->{ch} || $l->{nch} < $l->{ch};
    delete $l->{ncw};
    delete $l->{nch};
}
else
{
    if (!$l->{cw} || !$l->{ch})
    {
        $l->{cw} = 6;
        $l->{ch} = 5;
    }
    $l->{cols} = int($l->{pw} / ($l->{cw} + $l->{cml} + $l->{cmr}));
    $l->{rows} = int($l->{ph} / ($l->{ch} + $l->{cmt} + $l->{cmb}));
}

# Load bugs
my $bugs = [];
my $est = {};

if ($args->{id})
{
    push @$bugs, ($args->{id} =~ /(\d+)/gs);
    my $bug_objects = { map { $_->bug_id => $_ } @{ Bugzilla::Bug->new_from_list([ grep { $_ } @$bugs ]) } };
    for (@$bugs)
    {
        $_ = $bug_objects->{$_} if $_;
    }
    for (@$bugs)
    {
        if ($_)
        {
            if (!$user->can_see_bug($_))
            {
                $_ = { bug_id => $_->bug_id, error => 'AccessDenied' };
            }
            else
            {
                push @{$est->{$_->bug_id}}, 0+$_->estimated_time;
            }
        }
    }
}

# Load time estimates from the request
my $k;
for my $id (keys %$est)
{
    for (0..$#{$est->{$id}})
    {
        $k = "e$id-$_";
        $est->{$id}->[$_] = $args->{$k} if exists $args->{$k};
    }
}

# Fill the sheet with empty cells
if (scalar @$bugs > 1)
{
    if (@$bugs % ($l->{cols} * $l->{rows}))
    {
        push @$bugs, (undef) x ($l->{cols}*$l->{rows} - (@$bugs % ($l->{cols} * $l->{rows})));
    }
}

# Make tables and rows
my $pages = [];
my ($p, $r, $c) = (0, 0, 0);
my $repeated = {};
for (@$bugs)
{
    if ($_ && !$_->{error})
    {
        $_->{_repeated} = $repeated->{$_->{bug_id}} || '';
        $_->{_estimate} = $est->{$_->{bug_id}}->[$_->{_repeated} || 0];
        $_->{_repeated} = '-' . $_->{_repeated} if $_->{_repeated};
        $_ = { bug => $_, html => process_card($_, $l->{cardtext}) };
    }
    $pages->[$p]->{rows}->[$r]->{bugs}->[$c] = $_;
    $c++;
    if ($c >= $l->{cols})
    {
        $c = 0;
        $r++;
        if ($r >= $l->{rows})
        {
            $r = 0;
            $p++;
        }
    }
}

# Output variables
$vars->{pages} = $pages;
$vars->{t} = $l;
$vars->{idlist} = join ',', map { $_ && $_->{bug} && $_->{bug}->id ? $_->{bug}->id : "" } @$bugs;
$vars->{idlist_js} = join ',', map { $_ && $_->{bug} && $_->{bug}->id ? $_->{bug}->id : "''" } @$bugs;
$vars->{estimates} = $est;
$vars->{cardtext} = $l->{cardtext};
$vars->{settings_text} =
"paper=$l->{pw}x$l->{ph}
cardsize=$l->{cw}x$l->{ch}
cards=$l->{cols}x$l->{rows}
fontsize=$l->{fs}
cardmargin=$l->{cmt} $l->{cmr} $l->{cmb} $l->{cml}
template=<<EOF
$l->{cardtext}
EOF";

Bugzilla->template->process('scrum/cards.html.tmpl', $vars)
    || ThrowTemplateError(Bugzilla->template->error());
exit;

sub load_settings
{
    my ($text) = @_;
    my $l = {};
    my @text = split /\n/, $text;
    my %keys = (
        paper       => [ qw(pw ph) ],
        cardsize    => [ qw(cw ch) ],
        cards       => [ qw(cols rows) ],
        fontsize    => [ qw(fs) ],
        cardmargin  => [ qw(cmt cmr cmb cml) ],
    );
    for (my $i = 0; $i < @text; $i++)
    {
        if ($text[$i] =~ /^\s*([a-z_]+)\s*=\s*(<<([a-z_]+)|.*)/iso)
        {
            my ($n, $v) = ($1, $2);
            if ($3)
            {
                # heredoc
                my $eof = $3;
                $i++;
                $v = '';
                $v .= $text[$i++]."\n" while $i < @text && $text[$i] !~ /^\s*$eof\s*/so;
                $v =~ s/\s*$//gso;
            }
            if ($n eq 'template')
            {
                $l->{cardtext} = $v;
            }
            elsif ($keys{$n})
            {
                @$l{@{$keys{$n}}} = $v =~ /([\-\d\.]+)/gso;
            }
        }
    }
    return $l;
}

# The following is a mini template engine -
# we use it because TT is insecure and inconvenient

sub replace
{
    my ($s, $re, $repl) = @_;
    $re = qr/$re/s;
    # Escape \ @ $ % /, but allow $n replacements ($1 $2 $3 ...)
    $repl =~ s!([\\\@\%/]|\$(?\!\d))!\\$1!gso;
    eval("\$s =~ s/\$re/$repl/gs");
    return $s;
}

sub substr { CORE::substr($_[0], $_[1], $_[2]) }
sub uc { CORE::uc($_[0]) }
sub lc { CORE::lc($_[0]) }

sub expression
{
    my ($bug, $e, $byref) = @_;
    my $v;
    if ($e =~ s/^\s*(substr|uc|lc|replace)\s*\(//iso)
    {
        my $f = $1;
        my @a;
        my $a;
        while (defined($a = expression($bug, $e, 1)))
        {
            push @a, $a;
            $e =~ s/^[,\s]*//so;
        }
        $e =~ s/^\s*\)//so;
        no strict 'refs';
        $v = &$f(@a);
    }
    elsif ($e =~ s/^\s*("([^\"\\]+|\\\\|\\\")*"|'([^\'\\]+|\\\\|\\\')*'|-?[\d\.]+)//iso)
    {
        my $x = $1;
        if ($x =~ s/^[\"\'](.*)[\"\']$/$1/so)
        {
            $x =~ s/\\(.)/$1/gso;
        }
        $v = $x;
    }
    elsif ($e =~ s/^\s*([a-z_]+)//iso)
    {
        my $n = $1;
        my $f = Bugzilla->get_field($n);
        if ($f && $f->is_select)
        {
            $v = $bug->get_object($n);
        }
        else
        {
            my ($realname) = $n =~ s/_realname//so;
            $v = $bug->can($n) ? $bug->$n : $bug->{$n};
            if (ref $v eq 'Bugzilla::User')
            {
                $v = $realname ? $v->name : $v->login;
            }
        }
        $v = join(", ", map { blessed($_) ? $_->name : $_ } (ref $v eq 'ARRAY' ? @$v : $v));
    }
    else
    {
        return undef;
    }
    $_[1] = $e if $byref;
    return $v;
}

sub process_card
{
    my ($bug, $tpl) = @_;
    $tpl =~ s/\{((?:[^}\"\']+|"(?:[^\"\\]+|\\\\|\\\")*"|'(?:[^\'\\]+|\\\\|\\\')*')+)\}/html_quote(expression($bug, $1))/geiso;
    return $tpl;
}
