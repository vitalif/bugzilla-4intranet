#!/usr/bin/perl -w
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
# Contributor(s): Matthew Tuck <matty@chariot.net.au>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 Colin Ogilvie <colin.ogilvie@gmail.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

# This script compiles all the documentation.

use strict;
use Cwd;

# We need to be in this directory to use our libraries.
BEGIN {
    require File::Basename;
    import File::Basename qw(dirname);
    chdir dirname($0);
}

use lib qw(.. ../lib lib);

# We only compile our POD if Pod::Simple is installed. We do the checks
# this way so that if there's a compile error in Pod::Simple::HTML::Bugzilla,
# makedocs doesn't just silently fail, but instead actually tells us there's
# a compile error.
my $pod_simple;
if (eval { require Pod::Simple })
{
    require Pod::Simple::HTMLBatch::Bugzilla;
    require Pod::Simple::HTML::Bugzilla;
    $pod_simple = 1;
};

use Bugzilla::Config;
use Bugzilla::Install::Util qw(install_string);
use Bugzilla::Install::Requirements qw(REQUIRED_MODULES OPTIONAL_MODULES);
use Bugzilla::Constants qw(DB_MODULE BUGZILLA_VERSION);

###############################################################################
# Generate minimum version list
###############################################################################

print "Creating required Perl module list...\n";
my $fd;
open($fd, '>', 'required-modules.asciidoc') or die('Could not open required-modules.asciidoc: ' . $!);
print_versions($fd, REQUIRED_MODULES);
my $db_modules = DB_MODULE;
foreach my $db (keys %$db_modules)
{
    my $dbd = $db_modules->{$db}->{dbd};
    my $version = $dbd->{version} || 'any';
    my $db_version = $db_modules->{$db}->{db_version};
    print $fd ". $dbd->{module} ($version): $db_modules->{$db}->{name} ($db_version)\n";
}
close $fd;
open($fd, '>', 'optional-modules.asciidoc') or die('Could not open optional-modules.asciidoc: ' . $!);
print_versions($fd, OPTIONAL_MODULES);
close $fd;

###############################################################################
# Generate configuration parameter list
###############################################################################

print "Creating configuration parameter documentation...\n";
my $par = Bugzilla::Config::param_panel_props();
my $tplctx = Bugzilla->template->context;
my $param_descs = {};
my $param_doc = '';
for my $p (sort { $a->{sortkey} <=> $b->{sortkey} || $a->{name} cmp $b->{name} } values %$par)
{
    next if !-f '../template/en/default/admin/params/'.$p->{name}.'.html.tmpl';
    $tplctx->process('template/en/default/admin/params/'.$p->{name}.'.html.tmpl', {});
    $p->{title} = $tplctx->stash->get('title');
    $p->{info} = $tplctx->stash->get('info');
    $p->{description} = $tplctx->stash->get('desc');
    $p->{param_descs} = $tplctx->stash->get('param_descs');
    my $first = 1;
    for ($p->{info}, values %{$p->{param_descs}})
    {
        my $wrap = 0;
        s/&lt;/</gso;
        s/&gt;/>/gso;
        s/&amp;/&/gso;
        s/&quot;/\"/gso;
        s/&#64;/@/g;
        s/(\[+)/\$\$$1\$\$/gso;
        s/<(tt|code|kbd)>(.*?)<\/\1>/+$2+/gso;
        s/<(b|strong)>(.*?)<\/\1>/*$2*/gso;
        s/<(i|em)>(.*?)<\/\1>/'$2'/gso;
        s/<a href=[\"\'](?:editparams\.cgi)?\?section=(\w+)(?:#(\w+))?[\"\']>(.*?)<\/a>/"<<param-$1,".($3||$2).">>"/geso;
        s/<a href=[\"\']([^\"\']*)[\"\']>(.*?)<\/a>/link:$1\[$2]/gso;
        $wrap = 1 if s/\s*<pre(?:\s+[^>]+)?>(.*?)<\/pre>\s*/\n----\n$1\n----\n/gso;
        $wrap = 1 if s/(\s*<br\s*\/?>\s*)+|<p(\s+[^>]+)?>/\n\n/gso;
        s/<\/p>//gso;
        $wrap = 1 if s/\s*<[ud]l>\s*/\n\n/gso;
        s/\s*<\/[ud]l>\s*/\n/gso;
        s/<li>\s*(.*?)\s*<\/li>\s*/my $a = "* $1\n"; $a =~ s!\s{2,}! !gso; $a/geso;
        s/<dt>\s*(.*?)\s*<\/dt>\s*/my $a = "$1 :: "; $a =~ s!\s{2,}! !gso; $a/geso;
        s/<dd>\s*(.*?)\s*<\/dd>\s*/my $a = "$1\n"; $a =~ s!\s{2,}! !gso; $a/geso;
        s/^\s*//so;
        s/\s*$//so;
        $_ = "+\n--\n$_\n--" if $wrap && !$first;
        $first = 0;
    }
    $param_doc .= "[[param-".$p->{name}."]]\n==== ".$p->{title}."\n\n".($p->{info} || $p->{description})."\n\n";
    for (@{$p->{params}})
    {
        if (!$p->{param_descs}->{$_->{name}})
        {
            warn "Missing documentation for $p->{name} / $_->{name}\n";
            next;
        }
        $param_doc .= $_->{name}." ::\n".$p->{param_descs}->{$_->{name}}."\n\n";
    }
}
open($fd, '>', 'en/params.asciidoc') or die('Could not open en/params.asciidoc: ' . $!);
print $fd $param_doc;
close $fd;

###############################################################################
# Make the docs
###############################################################################

my @langs = glob(getcwd().'/*/asciidoc');
foreach my $lang (@langs)
{
    chdir "$lang/..";
    for (qw(txt pdf html html/api))
    {
        if (!-d $_)
        {
            unlink $_;
            mkdir $_, 0755;
        }
    }
    make_pod() if $pod_simple;
    -l 'asciidoc/images' or system('ln -s ../images asciidoc/images');

    make_docs('big HTML', "asciidoc -a data-uri -a icons -a toc -a toclevels=5 -o html/Bugzilla-Guide.html asciidoc/Bugzilla-Guide.asciidoc");
    make_docs('big text', "lynx -dump -justify=off -nolist html/Bugzilla-Guide.html > txt/Bugzilla-Guide.txt");
    make_docs('chunked HTML', "a2x -a toc -a toclevels=5 -f chunked -D html/ asciidoc/Bugzilla-Guide.asciidoc");

    next unless grep($_ eq "--with-pdf", @ARGV);

    make_docs('PDF', "a2x -a toc -a toclevels=5 -f pdf -D pdf/ asciidoc/Bugzilla-Guide.asciidoc");
}

sub print_versions
{
    my ($fd, $modules) = @_;
    foreach my $module (@$modules)
    {
        my $name = $module->{module};
        # This needs to be a string comparison, due to the modules having
        # version numbers like 0.9.4
        my $version = ($module->{version} || 0) eq 0 ? 'any' : $module->{version};
        my $feature = '';
        for ($module->{feature})
        {
            $_ = $_->[0] ? install_string("feature_".$_->[0]) : '' if ref $_;
            $feature = ': '.$_ if $_;
        }
        print $fd ". $name ($version)$feature\n";
    }
}

sub make_docs
{
    my ($name, $cmdline) = @_;
    print "Creating $name documentation ...\n" if defined $name;
    print "$cmdline\n";
    system $cmdline;
    print "\n";
}

sub make_pod
{
    print "Creating API documentation...\n";

    my $converter = Pod::Simple::HTMLBatch::Bugzilla->new;
    # Don't output progress information.
    $converter->verbose(0);
    $converter->html_render_class('Pod::Simple::HTML::Bugzilla');

    my $doctype      = Pod::Simple::HTML::Bugzilla->DOCTYPE;
    my $content_type = Pod::Simple::HTML::Bugzilla->META_CT;
    my $bz_version   = BUGZILLA_VERSION;

    my $contents_start = <<END_HTML;
$doctype
<html>
  <head>
    $content_type
    <title>Bugzilla $bz_version API Documentation</title>
  </head>
  <body class="contentspage">
    <h1>Bugzilla $bz_version API Documentation</h1>
END_HTML

    $converter->contents_page_start($contents_start);
    $converter->contents_page_end("</body></html>");
    $converter->add_css('./../../../style.css');
    $converter->javascript_flurry(0);
    $converter->css_flurry(0);
    $converter->batch_convert(['../../'], 'html/api/');

    print "\n";
}
