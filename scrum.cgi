#!/usr/bin/perl -wT
# Вывод SCRUM-карточек для печати

use strict;
use Bugzilla;
use Bugzilla::Util qw(trim);
use Bugzilla::Error;

my $cgi = Bugzilla->cgi;
my $user = Bugzilla->login;
my $args = $cgi->Vars;
my $vars = {};

# $l = Layout parameters
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

for (qw(pw ph cw ch cmt cmr cmb cml fs pmt pmr pmb pml))
{
    $l->{$_} = $1 if defined $args->{"t_$_"} && $args->{"t_$_"} =~ /^([\d\.]+)$/ && $1 >= 0;
}

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

my $bugs = [];
my $est = {};
if ($args->{id})
{
    push @$bugs, split /,/, $args->{id}, -1;
    for (@$bugs)
    {
        if ($_)
        {
            $_ = Bugzilla::Bug->new($_);
        }
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
                $est->{$_->bug_id} = 0+$_->estimated_time;
            }
        }
    }
}

for (keys %$est)
{
    $est->{$_} = $args->{"e$_"} if exists $args->{"e$_"};
}

if (@$bugs % ($l->{cols} * $l->{rows}))
{
    push @$bugs, (undef) x ($l->{cols}*$l->{rows} - (@$bugs % ($l->{cols} * $l->{rows})));
}

my $pages = [];
my ($p, $r, $c) = (0, 0, 0);
for (@$bugs)
{
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

$vars->{pages} = $pages;
$vars->{t} = $l;
$vars->{idlist} = join ',', map { $_ && $_->id ? $_->id : "" } @$bugs;
$vars->{idlist_js} = join ',', map { $_ && $_->id ? $_->id : "''" } @$bugs;
$vars->{estimates} = $est;

Bugzilla->template->process('scrum/cards.html.tmpl', $vars)
    || ThrowTemplateError(Bugzilla->template->error());
exit;
