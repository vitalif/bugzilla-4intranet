#!/usr/bin/perl -wT
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
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Gervase Markham <gerv@gerv.net>

use utf8;
use strict;
use lib qw(. lib);

use Encode;
use File::Temp;

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::Status;

Bugzilla->login();

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};

# Check params
my $display = $cgi->param('display') || 'tree';
if (!defined $cgi->param('id') && $display ne 'doall') {
    ThrowCodeError("missing_bug_id");
}

# Connect to the shadow database if this installation is using one to improve
# performance.

my ($seen, $edges, $baselist, $deps) = GetEdges($display, $cgi->param('id'));
my ($nodes, $bugtitles) = GetNodes($seen, $baselist, $deps, $vars);
my ($clusters, $independent) = GetClusters($seen, $edges);
my $graphs = [];
for (grep { %$_ } @$clusters, $independent)
{
    my $filename = MakeDot($edges, $nodes, $_);
    my $gr = { cluster => $_, filename => $filename, alt => $_ eq $independent };
    GetDotUrls($gr, $bugtitles);
    push @$graphs, $gr;
}

# Cleanup any old .dot files created from previous runs.
CleanupOldDots();

my @bugs = keys %$baselist;
$vars->{bug_id} = join ', ', @bugs;
$vars->{multiple_bugs} = scalar(keys %$baselist) > 1;
$vars->{display} = $display;
$vars->{graphs} = $graphs;

# Generate and return the UI (HTML page) from the appropriate template.
$cgi->send_header();
$template->process("bug/dependency-graph.html.tmpl", $vars)
  || ThrowTemplateError($template->error());

# Divide the overall graph into closed clusters
sub GetClusters
{
    my ($seen, $edges) = @_;
    my $twoway = {};
    for my $b (keys %$edges)
    {
        for my $d (keys %{$edges->{$b}})
        {
            $twoway->{$b}->{$d} = 1;
            $twoway->{$d}->{$b} = 1;
        }
    }
    $seen = { %$seen };
    my ($clusters, $independent) = ([], {});
    my $cluster;
    while (%$seen)
    {
        unless ($cluster && %$cluster)
        {
            my ($b) = keys %$seen;
            $cluster = { $b => 1 };
            delete $seen->{$b};
        }
        my $added = 0;
        for (keys %$cluster)
        {
            for (keys %{$twoway->{$_}})
            {
                unless ($cluster->{$_})
                {
                    $cluster->{$_} = 1;
                    delete $seen->{$_};
                    $added++;
                }
            }
        }
        # кластер замкнут
        if (!$added || !%$seen)
        {
            if (scalar(keys %$cluster) == 1)
            {
                my ($b) = keys %$cluster;
                $independent->{$b} = 1;
            }
            else
            {
                push @$clusters, $cluster;
            }
            $cluster = undef;
        }
    }
    return ($clusters, $independent);
}

# Get URLs for HTML usage
sub GetDotUrls
{
    my ($inout, $bugtitles) = @_;
    my $base = Bugzilla->params->{$inout->{alt} ? 'webtwopibase' : 'webdotbase'};
    # Remote dot server. We don't hardcode 'urlbase' here in case
    # 'sslbase' is in use.
    if ($base =~ /^https?:/)
    {
        $inout->{image_url} = $base . $inout->{filename} . ".gif";
        $inout->{map_url} = $base . $inout->{filename} . ".map";
    }
    # Local dot installation
    else
    {
        # First, generate the svg image file from the .dot source
        my ($svgfh, $svgfilename) = DotTemp('.svg');
        DotInto($svgfh, [ $base, '-Tsvg', $inout->{filename} ], sub { s/xlink:title=/xlink:show="new" xlink:title=/; $_; }) or ($inout->{timeout} = 1);
        $inout->{image_svg_url} = DotRel($svgfilename);

        # Next, generate the png image file for those who don't support SVG
        my ($pngfh, $pngfilename) = DotTemp('.png');
        DotInto($pngfh, [ $base, '-Tpng', $inout->{filename} ]) or ($inout->{timeout} = 1);
        $inout->{image_url} = DotRel($pngfilename);

        # Then, generate a imagemap datafile that contains the corner data
        # for drawn bug objects. Pass it on to CreateImagemap that
        # turns this monster into html.
        my ($mapfh, $mapfilename) = DotTemp('.map');
        DotInto($mapfh, [ $base, '-Tismap', $inout->{filename} ]) or ($inout->{timeout} = 1);
        $inout->{image_map_id} = 'imap' . $mapfilename;
        $inout->{image_map_id} =~ s/\W+/_/gso;
        $inout->{image_map} = CreateImagemap($mapfilename, $inout->{image_map_id}, $bugtitles);
    }
}

# DotInto: Run local dot with timeout support and write output into filehandle
sub DotInto
{
    my ($intofh, $cmd, $callback) = @_;
    my $r = 1;
    binmode $intofh;
    my $quot = $^O =~ /MSWin/ ? '"' : "'";
    my $dottimeout = int(Bugzilla->params->{localdottimeout});
    if ($dottimeout && $dottimeout > 0)
    {
        # This creepy way is the only one that seems to be truly crossplatform
        $cmd = "perl -e $quot\$SIG{ALRM} = sub { exit 1 }; alarm $dottimeout; exec(" .
            join(",", map { 'q{'.$_.'}' } @$cmd) .
            ");$quot";
    }
    else
    {
        $cmd = join " ", map { $quot.$_.$quot } @$cmd;
    }
    if (my $pid = open DOT, "$cmd|")
    {
        binmode DOT;
        if ($callback)
        {
            print $intofh $callback->($_) while <DOT>;
        }
        else
        {
            print $intofh $_ while <DOT>;
        }
        close DOT;
    }
    $r = undef unless tell $intofh;
    close $intofh;
    return $r;
}

# CreateImagemap: This sub grabs a local filename as a parameter, reads the 
# dot-generated image map datafile residing in that file and turns it into
# an HTML map element. THIS SUB IS ONLY USED FOR LOCAL DOT INSTALLATIONS.
# The map datafile won't necessarily contain the bug summaries, so we'll
# pull possible HTML titles from the %bugtitles hash (filled elsewhere
# in the code)

# The dot mapdata lines have the following format (\nsummary is optional):
# rectangle (LEFTX,TOPY) (RIGHTX,BOTTOMY) URLBASE/show_bug.cgi?id=BUGNUM BUGNUM[\nSUMMARY]

sub CreateImagemap
{
    my ($mapfilename, $mapid, $bugtitles) = @_;
    $mapid ||= 'imagemap';
    my $map = "<map name=\"$mapid\">\n";
    my $default;

    open MAP, "<$mapfilename";
    while (my $line = <MAP>)
    {
        if ($line =~ /^default ([^ ]*)(.*)$/)
        {
            $default = qq{<area alt="" shape="default" href="$1">\n};
        }

        if ($line =~ /^rectangle \((.*),(.*)\) \((.*),(.*)\) (http[^ ]*(\d+))/iso)
        {
            my ($leftx, $rightx, $topy, $bottomy, $url, $bugid) = ($1, $3, $2, $4, $5, $6);

            # Pick up bugid from the mapdata label field. Getting the title from
            # bugtitle hash instead of mapdata allows us to get the summary even
            # when showsummary is off, and also gives us status and resolution.
            my $bugtitle = html_quote(clean_text($bugtitles->{$bugid})) || '';
            $map .= qq{<area alt="$bugtitle" name="bug$bugid" shape="rect" } .
                    qq{title="$bugtitle" href="$url" } .
                    qq{coords="$leftx,$topy,$rightx,$bottomy">\n};
        }
    }
    close MAP;

    $map .= "$default</map>";
    return $map;
}

sub AddLink
{
    my ($blocked, $dependson, $seen, $edges) = (@_);
    $edges->{$blocked}->{$dependson} = 1;
    $seen->{$blocked} = 1;
    $seen->{$dependson} = 1;
}

sub DotTemp
{
    my ($suffix) = @_;
    return File::Temp::tempfile("XXXXXXXXXX",
        SUFFIX => $suffix,
        DIR => bz_locations()->{webdotdir});
}

# Fix filename
sub DotRel
{
    my ($fn) = @_;
    # On Windows $pngfilename will contain \ instead of /
    $fn =~ s|\\|/|g if ON_WINDOWS;
    # Under mod_perl, pngfilename will have an absolute path, and we
    # need to make that into a relative path.
    my $cgi_root = bz_locations()->{cgi_path};
    $fn =~ s!^\Q$cgi_root\E/?!!;
    return $fn;
}

sub GetEdges
{
    my ($display, $ids) = @_;
    my $seen = {};
    my $edges = {};
    my $baselist = {};
    my $deps = {};
    my $dbh = Bugzilla->switch_to_shadow_db;
    if ($display eq 'doall')
    {
        my $dependencies = $dbh->selectall_arrayref("SELECT blocked, dependson FROM dependencies");
        foreach my $dependency (@$dependencies)
        {
            my ($blocked, $dependson) = @$dependency;
            AddLink($blocked, $dependson, $seen, $edges);
            $deps->{$dependson}++;
        }
    }
    else
    {
        foreach my $i (split('[\s,]+', $ids))
        {
            my $bug = Bugzilla::Bug->check($i);
            $baselist->{$bug->id} = 1;
            $seen->{$bug->id} = 1;
        }

        my @stack = keys %$baselist;

        # web: Any relationship with selected bugs
        # openweb: Any relationship with selected bugs + state must be open
        if ($display eq 'web' || $display eq 'openweb')
        {
            my $openweb = $display eq 'openweb' ? 1 : 0;
            my $sth = $dbh->prepare("SELECT blocked, dependson, bs.bug_status blocked_status, ds.bug_status dependson_status
                                     FROM dependencies, bugs bs, bugs ds
                                     WHERE (blocked=? OR dependson=?) AND bs.bug_id=blocked AND ds.bug_id=dependson");
            foreach my $id (@stack)
            {
                my $dependencies = $dbh->selectall_arrayref($sth, undef, ($id, $id));
                foreach my $dependency (@$dependencies)
                {
                    my ($blocked, $dependson, $bs, $ds) = @$dependency;
                    if ($blocked != $id && !exists $seen->{$blocked})
                    {
                        next if $openweb && !is_open_state($bs); # skip AddLink also
                        push @stack, $blocked;
                    }
                    if ($dependson != $id && !exists $seen->{$dependson})
                    {
                        next if $openweb && !is_open_state($ds); # skip AddLink also
                        push @stack, $dependson;
                    }
                    AddLink($blocked, $dependson, $seen, $edges);
                    $deps->{$dependson}++;
                }
            }
        }
        # Only bugs with direct dependencies to selected
        else
        {
            my @blocker_stack = @stack;
            foreach my $id (@blocker_stack)
            {
                my $blocker_ids = Bugzilla::Bug::EmitDependList('blocked', 'dependson', $id);
                foreach my $blocker_id (@$blocker_ids)
                {
                    push @blocker_stack, $blocker_id unless $seen->{$blocker_id};
                    AddLink($id, $blocker_id, $seen, $edges);
                }
            }
            my @dependent_stack = @stack;
            foreach my $id (@dependent_stack)
            {
                my $dep_bug_ids = Bugzilla::Bug::EmitDependList('dependson', 'blocked', $id);
                foreach my $dep_bug_id (@$dep_bug_ids)
                {
                    push @dependent_stack, $dep_bug_id unless $seen->{$dep_bug_id};
                    AddLink($dep_bug_id, $id, $seen, $edges);
                }
            }
        }
    }
    return ($seen, $edges, $baselist, $deps);
}

sub GetNodes
{
    my ($seen, $baselist, $deps, $vars) = @_;
    return {} unless keys %$seen;
    my $nodes = {};
    my $bugtitles = {};
    # Retrieve bug information from the database
    my $rows = Bugzilla->dbh->selectall_arrayref(
"SELECT
 t1.bug_id,
 t1.bug_status,
 t1.resolution,
 t1.short_desc,
 t1.estimated_time,
 SUM(t3.work_time) AS work_time,
 t1.assigned_to,
 t2.login_name AS assigned_to_login,
 t4.name AS product,
 t5.name AS component,
 t1.bug_severity
FROM bugs AS t1
LEFT JOIN profiles AS t2 ON t2.userid=t1.assigned_to
LEFT JOIN longdescs AS t3 ON t3.bug_id=t1.bug_id AND t3.work_time > 0
LEFT JOIN products AS t4 ON t4.id=t1.product_id
LEFT JOIN components AS t5 ON t5.id=t1.component_id
WHERE t1.bug_id IN (".join(",", ("?") x scalar keys %$seen).")
GROUP BY t1.bug_id", {Slice=>{}}, keys %$seen) || {};
    foreach my $row (@$rows)
    {
        # Resolution and summary are shown only if user can see the bug
        $row->{resolution} = $row->{short_desc} = '' unless Bugzilla->user->can_see_bug($row->{bug_id});
        $row->{bug_status} ||= 'NEW';
        $row->{short_desc_uncut} = $row->{short_desc};
        if (length $row->{short_desc} > 32)
        {
            $row->{short_desc} = substr($row->{short_desc}, 0, 32) . '...';
        }
        # Current bug
        $vars->{short_desc} = $row->{short_desc} if $row->{bug_id} eq Bugzilla->cgi->param('id');
        Encode::_utf8_off($row->{$_}) for keys %$row;

        my $bgnodecolor = GetColorByState($row->{bug_status}, 1);
        my $nodecolor = GetColorByState($row->{bug_status});

        my $assigneecolor = "white";
        $assigneecolor = "red1" if $row->{bug_severity} eq "blocker";
        $assigneecolor = "rosybrown1" if $row->{bug_severity} eq "critical";

        my @params = ("color=" . $nodecolor);
        push @params, "fillcolor=azure2" if exists $baselist->{$row->{bug_id}};

        my $important =
            ($row->{estimated_time} || 0) > 40 ||
            ($row->{work_time} || 0) > 40 ||
            ($deps->{$row->{bug_id}} || 0) > 4;
        if ($important)
        {
            push @params, "height=1.5", "fontsize=13";
        }

        if ($row->{short_desc})
        {
            $row->{short_desc} =~ s/([\\\"])/\\$1/g;
            push @params, <<"EOF";
label=<
<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
<TR>
<TD BGCOLOR=$bgnodecolor>$row->{bug_id}</TD>
<TD BGCOLOR="$assigneecolor"><FONT POINT-SIZE="8">$row->{assigned_to_login}</FONT></TD>
</TR>
<TR>
<TD COLSPAN="2" ALIGN="TEXT">
<FONT POINT-SIZE="8">
$row->{short_desc}
</FONT>
</TD>
</TR>
</TABLE>
>
EOF
        }

        # Push the bug tooltip texts into a global hash so that
        # CreateImagemap sub (used with local dot installations) can
        # use them later on.
        $bugtitles->{$row->{bug_id}} = "[".trim("$row->{bug_status} $row->{resolution}")." $row->{assigned_to_login}]";

        # Show the bug summary in tooltips only if not shown on
        # the graph and it is non-empty (the user can see the bug)
        if ($row->{short_desc}) {
            $bugtitles->{$row->{bug_id}} .= " $row->{product}/$row->{component} - $row->{short_desc_uncut}";
        }

        my $t = $bugtitles->{$row->{bug_id}};
        $t =~ s/([\\\"])/\\$1/gso;
        push @params, "tooltip=\"$t\"";

        $nodes->{$row->{bug_id}} = $row->{bug_id} . (@params ? " [" . join(',', @params) . "]" : "");
    }
    return ($nodes, $bugtitles);
}

sub MakeDot
{
    my ($edges, $nodes, $cluster) = @_;
    $cluster ||= $edges;
    my ($fh, $filename) = DotTemp('.dot');
    my $urlbase = Bugzilla->params->{urlbase};
    no warnings 'utf8';
    print $fh "digraph G {";
    print $fh <<"EOF";
ranksep=0.5;
graph [URL="${urlbase}query.cgi" rankdir=LR overlap=false splines=true]
node [URL="${urlbase}show_bug.cgi?id=\\N" shape=note fontsize=10 fontname="Consolas" style=filled fillcolor=white]
edge [color=blue len=0.5]
EOF
    OutLinks($edges, $cluster, $fh);
    print $fh $nodes->{$_}, "\n" foreach keys %$cluster;
    print $fh "}\n";
    close $fh;
    chmod 0777, $filename;
    return $filename;
}

sub OutLinks
{
    my ($edges, $cluster, $fh) = @_;
    for my $blocked (keys %$edges)
    {
        if ($cluster->{$blocked})
        {
            for my $dependson (keys %{$edges->{$blocked}})
            {
                print $fh "$blocked -> $dependson\n";
            }
        }
    }
}

sub CleanupOldDots
{
    my $since = time() - 24 * 60 * 60;
    # Can't use glob, since even calling that fails taint checks for perl < 5.6
    my $webdotdir = bz_locations()->{webdotdir};
    opendir DIR, $webdotdir;
    my @files = grep { /\.dot$|\.png$|\.svg$|\.map$/ && -f "$webdotdir/$_" } readdir(DIR);
    closedir DIR;
    foreach my $f (@files)
    {
        $f = "$webdotdir/$f";
        # Here we are deleting all old files. All entries are from the
        # $webdot directory. Since we're deleting the file (not following
        # symlinks), this can't escape to delete anything it shouldn't
        # (unless someone moves the location of $webdotdir, of course)
        trick_taint($f);
        if (file_mod_time($f) < $since) {
            unlink $f;
        }
    }
}

sub GetColorByState
{
    my ($state, $base) = (@_);
    $base = $base ? 0 : 0x40;
    my %colorbystate = (
        UNCONFIRMED => 'ffffff',
        NEW         => 'ff8000',
        ASSIGNED    => 'ffff00',
        RESOLVED    => '00ff00',
        VERIFIED    => '675acd',
        CLOSED      => 'd0d0d0',
        REOPENED    => 'ff4000',
        opened      => '00ff00',
        closed      => 'c0c0c0',
    );
    my $color = sprintf("\"#%02x%02x%02x\"", map { int(ord($_)/0xff*(0xff-$base)) }
        split //, pack 'H*',
        $colorbystate{$state} ||
        $colorbystate{is_open_state($state) ? 'opened' : 'closed'});
    return $color;
}
