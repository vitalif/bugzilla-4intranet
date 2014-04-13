#!/usr/bin/perl -w
# "Informer" for bugs - picture with summary information
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

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

# FIXME requirelogin=0: ugly hack :(
Bugzilla->params->{requirelogin} = 0;
my $user = Bugzilla->login(LOGIN_NORMAL);

my $bug = Bugzilla::Bug->new($id);
my $str;
my $format = lc $cgi->param('format') || 'short';
if (!$bug)
{
    $str = "Bug $id не существует";
}
elsif (!$user || !$user->can_see_bug($bug))
{
    # Access denied
    $str = "Bug $id: нет доступа";
    $bug = undef;
}
else
{
    # Bug description
    my $as = $bug->assigned_to;
    $as = $as && $as->login;
    $as =~ s/\@.*$// if $as;
    my $st = $bug->bug_status_obj->name;
    $st .= '/' . $bug->resolution_obj->name if $bug->resolution;
    if ($format eq 'long')
    {
        $str = '#' . $bug->bug_id . " [$as] $st " . $bug->bug_severity_obj->name . ' ' .
            $bug->product . '/' . $bug->component . " " . $bug->short_desc;
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
# FIXME remove hardcode bug_severity == 'critical', 'blocker'
$fore = $gdi->colorAllocate(255,0,0) if !$bug || $bug->bug_severity_obj->name eq 'critical' || $bug->bug_severity_obj->name eq 'blocker';
my $border = $fore;
$gdi->trueColor(1);
$gdi->alphaBlending(1);
$gdi->filledRectangle(0,0,$w-1,$h-1,$white);
$gdt = GD::Text::Align->new($gdi, valign => 'top', halign => 'left', text => $str, font => $font, ptsize => $size, color => $fore);
$gdt->draw(1, 1, 0);
# FIXME remove hardcode bug_status == 'VERIFIED'
if ($bug && $bug->bug_status_obj->name eq 'VERIFIED')
{
    $border = $gdi->colorAllocate(0x2f/2,0x6f/2,0xab/2);
    $gdi->setStyle(($border) x (3*($qual+1)), (gdTransparent) x (3*($qual+1)));
    $gdi->rectangle(0,0,$w-1,$h-1,gdStyled);
}
# FIXME remove hardcode bug_status == 'CLOSED'
elsif ($bug && $bug->bug_status_obj->name eq 'CLOSED')
{
    $border = $gdi->colorAllocate(0x60,0x60,0x60);
    $gdi->rectangle(0,0,$w-1,$h-1,$border);
}
if ($bug && !$bug->bug_status_obj->is_open)
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
exit;
