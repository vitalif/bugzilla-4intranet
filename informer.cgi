#!/usr/bin/perl -w
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

use utf8;
use strict;

use lib qw(. lib);
use GD;
use GD::Text;
use GD::Text::Align;

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Status;
use Bugzilla::Util;
use Bugzilla::Constants;

my $cgi = Bugzilla->cgi;
my $id = $cgi->param('id');
my $user = Bugzilla->user;
my $bug = Bugzilla::Bug->new($id);
my $str;
my $format = lc $cgi->param('format') || 'short';
if (!$user || !$bug->{error} && !$user->can_see_bug($bug->bug_id))
{
    # Access denied
    $str = "Bug$id: нет доступа";
    $bug = undef;
}
else
{
    # Bug description
    my $as = $bug->assigned_to;
    $as = $as && $as->login;
    $as =~ s/\@.*$// if $as;
    my $st = $bug->bug_status;
    $st .= '/' . $bug->resolution if $bug->resolution;
    if ($format eq 'long')
    {
        $str = '#' . $bug->bug_id . " [$as] $st " . $bug->bug_severity . ' ' . $bug->product . '/' . $bug->component . " " . $bug->short_desc;
    }
    else
    {
        $str = '#' . $bug->bug_id . " [$as] " . $st;
    }
    $str =~ s/\s{2,}/ /gso;
}

# GD-говнокод
my $size = $cgi->param('fontsize');
my $qual = 1;
$size = Bugzilla->params->{graph_font_size} || 9 if !$size || $size > 25;
$size *= 2 if $qual;
my $font = Bugzilla->params->{graph_font} || gdSmallFont;
my $gdt = GD::Text->new(text => $str, font => $font, ptsize => $size) || die GD::Text::error();
my ($w, $h) = $gdt->get('width', 'height');
$w++;
$h++;
my $gdi = GD::Image->new($w, $h);
my $white = $gdi->colorAllocate(255,255,255);
my $black = $gdi->colorAllocate(0,0,0);
my $fore = $black;
$fore = $gdi->colorAllocate(255,0,0) if !$bug || $bug->bug_severity eq 'critical' || $bug->bug_severity eq 'blocker';
my $border = $fore;
$gdi->trueColor(1);
$gdi->alphaBlending(1);
$gdi->filledRectangle(0,0,$w-1,$h-1,$white);
$gdt = GD::Text::Align->new($gdi, valign => 'top', halign => 'left', text => $str, font => $font, ptsize => $size, color => $fore);
$gdt->draw(1, 1, 0);
if ($bug && $bug->bug_status eq 'VERIFIED')
{
    $border = $gdi->colorAllocate(0x2f/2,0x6f/2,0xab/2);
    $gdi->setStyle(($border) x (3*($qual+1)), (gdTransparent) x (3*($qual+1)));
    $gdi->rectangle(0,0,$w-1,$h-1,gdStyled);
}
elsif ($bug && $bug->bug_status eq 'CLOSED')
{
    $border = $gdi->colorAllocate(0x60,0x60,0x60);
    $gdi->rectangle(0,0,$w-1,$h-1,$border);
}
if ($bug && !is_open_state($bug->bug_status))
{
    $gdi->line(0, $h/2, $w-1, $h/2, $border);
}
if ($qual)
{
    my $i2 = GD::Image->new($w/2, $h/2);
    $i2->copyResampled($gdi, 0, 0, 0, 0, $w/2, $h/2, $w, $h);
    $gdi = $i2;
}

$cgi->header('image/png');
binmode STDOUT;
print $gdi->png;
