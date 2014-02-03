#!/usr/bin/perl -wT
# Вывод SCRUM-карточек для печати

use strict;
use Bugzilla;
use Bugzilla::Util qw(trim html_quote);
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
my $user = Bugzilla->login;
my $args = { %{ $cgi->Vars } };
my $vars = {};

# Параметры по умолчанию:
# $l = настройки Layout
my $l = {
    cols => int($args->{t_cols} || 0) > 0 ? int($args->{t_cols} || 0) : undef,
    rows => int($args->{t_rows} || 0) > 0 ? int($args->{t_rows} || 0) : undef,
    fs   => 12,
    pw   => 20,
    ph   => 25.2,
    cw   => undef,
    ch   => undef,
    cmt  => 0.5,
    cmr  => 0.1,
    cmb  => 0.1,
    cml  => 0.1,
    pmt  => 0.5,
    pmr  => 0.5,
    pmb  => 0.5,
    pml  => 0.5,
};

$l->{cardtext} = <<'EOF';
<table class="card" cellspacing="5">
 <tr>
  <td class="dot"><a href="show_bug.cgi?id={bug_id}">{bug_id}</a></td>
  <td class="sevpri">{substr(bug_severity, 0, 3)}&nbsp;{priority}</td>
  <td class="dot">{substr(target_milestone, 0, 5)}</td>
 </tr>
 <tr>
  <td colspan="3" class="desc" style="font-size: 120%">{short_desc}</td>
 </tr>
 <tr>
  <td colspan="3" style="font-size: 130%">
   <input type="text" class="est"
     name="e{bug_id}{_repeated}"
     value="{_estimate}" />
  </td>
 </tr>
</table>
EOF

# Загрузка параметров из запроса
for (qw(pw ph cw ch cmt cmr cmb cml fs pmt pmr pmb pml))
{
    $l->{$_} = $1 if defined $args->{"t_$_"} && $args->{"t_$_"} =~ /^([\d\.]+)$/ && $1 >= 0;
}

# Загрузка параметров из текста настроек
if ($args->{load_settings})
{
    my $ls = load_settings($args->{settings_text});
    for (keys %$ls)
    {
        $l->{$_} = $ls->{$_} if $ls->{$_} ne '';
    }
    $vars->{load_settings} = 1;
}

# Вычисление размера карточек по количеству, либо количества по размерам
my ($pw, $ph) = ($l->{pw} - $l->{pml} - $l->{pmr}, $l->{ph} - $l->{pmt} - $l->{pmb});

if ($l->{cols} && $l->{rows})
{
    $l->{ncw} = sprintf("%.2f", ($pw / $l->{cols}) - $l->{cml} - $l->{cmr});
    $l->{nch} = sprintf("%.2f", ($ph / $l->{rows}) - $l->{cmt} - $l->{cmb});
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
    $l->{cols} = int($pw / ($l->{cw} + $l->{cml} + $l->{cmr}));
    $l->{rows} = int($ph / ($l->{ch} + $l->{cmt} + $l->{cmb}));
}

# Загрузка багов
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
        if ($_ && !$_->{error})
        {
            if (!$user->can_see_bug($_))
            {
                $_ = bless { bug_id => $_->bug_id, error => 'AccessDenied' }, 'Bugzilla::Bug';
            }
            else
            {
                push @{$est->{$_->bug_id}}, 0+$_->estimated_time;
            }
        }
    }
}

# Загрузка оценок из запроса
my $k;
for my $id (keys %$est)
{
    for (0..$#{$est->{$id}})
    {
        $k = "e$id-$_";
        $est->{$id}->[$_] = $args->{$k} if exists $args->{$k};
    }
}

# Дополнение таблицы пустыми ячейками
if (scalar @$bugs > 1)
{
    if (@$bugs % ($l->{cols} * $l->{rows}))
    {
        push @$bugs, (undef) x ($l->{cols}*$l->{rows} - (@$bugs % ($l->{cols} * $l->{rows})));
    }
}

# Разбиение на таблицы и строки
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

# Вывод в шаблон
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
papermargin=$l->{pmt} $l->{pmr} $l->{pmb} $l->{pml}
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
        papermargin => [ qw(pmt pmr pmb pml) ],
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

# Дальше очередной мини-шаблонизатор, потому что TT выставлять
# наружу и неудобно, и непонятно, как, и небезопасно...

sub replace
{
    my ($s, $re, $repl) = @_;
    s!/!\\/!gso for $re, $repl;
    eval("\$s =~ s/$re/$repl/gso");
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
            $x =~ s/\\//gso;
        }
        $v = $x;
    }
    elsif ($e =~ s/^\s*([a-z_]+)//iso)
    {
        my $n = $1;
        my ($realname) = $n =~ s/_realname//so;
        $v = $bug->can($n) ? $bug->$n : $bug->{$n};
        if (ref $v eq 'Bugzilla::User')
        {
            $v = $realname ? $v->name : $v->login;
        }
        elsif (ref $v eq 'ARRAY')
        {
            $v = join(",", @$v);
        }
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
