#!/usr/bin/perl
# Extract strings for localisation from Bugzilla Template Toolkit templates
# and automatically replaces them with with L('...') calls.
# Reads blacklist from i18n/en/blacklist.pl, processes all templates. Outputs:
# 1) Translated versions of all templates to template/localized/
# 2) Extracted messages to i18n/en/messages.pl
# 3) For convenience, also writes messages that were added or removed since
#    the previous run to i18n/en/added.pl and i18n/en/removed.pl.

use strict;
use Encode;
use lib qw(..);
use Cwd;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Find;

my $bz_root = Cwd::abs_path(dirname(__FILE__).'/..');
my $msg_path = "$bz_root/i18n/en";
-d $msg_path or make_path($msg_path);

my $blacklist;

if (-f "$msg_path/blacklist.pl")
{
    $blacklist = do "$msg_path/blacklist.pl";
    $blacklist or die "blacklist.pl should define \$blacklist = { 'template' => { 'string' => anything } };";
}

my $strings = {};

#$File::Find::name = '/var/home/www/localhost/bugs3/template/en/default/global/header.html.tmpl';
#process_file();
#exit;

File::Find::find(\&process_file, "$bz_root/template/en", glob("$bz_root/extensions/*/template/en"));

my ($removed, $added) = diff_strings("$msg_path/messages.pl", $strings);

write_dump("$msg_path/messages.pl", $strings);
write_dump("$msg_path/removed.pl", $removed) if $removed && %$removed;
write_dump("$msg_path/added.pl", $added) if $added && %$added;

#print_duplicated($strings);

exit;

sub process_file
{
    my $n = $File::Find::name;
    if ($n =~ /\.(txt|html)\.tmpl$/ && open FD, '<', $n)
    {
        local $/ = undef;
        my $s = <FD>;
        close FD;
        my $rel = substr($n, 1 + length $bz_root);
        $rel =~ s!^extensions/([^/]*)/template/en/(default|custom)/(.*)$!extensions/$1/$3!so;
        $rel =~ s!^template/en/(default|custom)/(.*)$!$2!so;
        ($s, $strings->{$rel}) = translate_template($s, $n =~ /\.txt\.tmpl$/ ? 1 : 0, $blacklist->{$rel});
        delete $strings->{$rel} if !%{$strings->{$rel}};
        my $tr = $n;
        $tr =~ s!/en/!/localized/!;
        -d dirname($tr) or make_path(dirname($tr));
        open FD, '>', $tr or die "Can't write $tr";
        print FD $s;
        close FD;
    }
}

sub diff_strings
{
    my ($fn, $strings) = @_;
    my ($removed, $added);
    -f $fn or return;
    my $old_strings = do $fn or return;
    for (keys %$old_strings)
    {
        $strings->{$_} = $old_strings->{$_} if !/\.tmpl$/so;
    }
    my %all_keys = map { map { $_ => 1 } keys %$_ } ($old_strings, $strings);
    for my $fn (keys %all_keys)
    {
        $removed->{$fn}->{''} = [ grep { !exists $strings->{$fn}->{$_} } keys %{$old_strings->{$fn} || {}} ];
        $added->{$fn}->{''} = [ grep { !exists $old_strings->{$fn}->{$_} } @{$strings->{$fn} ? $strings->{$fn}->{''} : []} ];
        for ($removed, $added)
        {
            delete $_->{$fn} if !@{$_->{$fn}->{''}};
        }
    }
    return ($removed, $added);
}

sub write_dump
{
    my ($fn, $strings) = @_;
    my $dump = "use utf8;\n{\n";
    for my $file (sort keys %$strings)
    {
        $dump .= "  '$file' => {\n";
        for my $s (@{$strings->{$file}->{''}})
        {
            $s =~ s/([\\\'])/\\$1/gso;
            $dump .= "    '$s' =>\n      '$s',\n";
        }
        $dump .= "  },\n";
    }
    $dump .= "};\n";
    Encode::_utf8_off($dump);
    open FD, '>', $fn or die "Can't write $fn";
    print FD $dump;
    close FD;
}

sub print_duplicated
{
    my $all = {};
    for my $file (sort keys %$strings)
    {
        for my $s (@{$strings->{$file}->{''}})
        {
            push @{$all->{$s}}, $file;
        }
    }
    for (sort keys %$all)
    {
        if (@{$all->{$_}} > 1)
        {
            print "$_\n";
            for (@{$all->{$_}})
            {
                print "  $_\n";
            }
        }
    }
}

sub translate_template
{
    my ($template, $is_txt, $blacklist) = @_;
    my $translated = '';
    my $strings = {};
    my $last = '';
    my $last_raw = '';
    my $outtag;    # translated tag/directive/whatever
    my $pre_nl;    # newlines before non-special string match (to preserve them if not translating)
    while ($is_txt ? $template =~ s/^(.*?)(\[\%|<|\n\s*\n|$)//so : $template =~ s/^(.*?)(\[\%|<|$)//so)
    {
        $outtag = $pre_nl = '';
        my ($pre, $tag) = ($1, $2);
        my $pre_raw = $last_raw.$pre;
        $pre = $last.$pre;
        $last_raw = '';
        $last = '';
        $pre =~ s/\s+$//so and $outtag .= $&;
        $pre =~ s/^\s+//so and $pre_nl = $&;
        $pre_raw =~ s/^\s+//so;
        $pre_raw =~ s/\s+$//so;
        $pre =~ s/\s+/ /gso;
        if ($tag eq '[%')
        {
            if ($template =~ s/^([\-\+]?)\s*terms.(\w+)\s*-?\%\]//so)
            {
                $outtag = ' ' if $outtag;
                $last_raw = $pre_nl.$pre.$outtag.'[%'.$1.' terms.'.$2.' %]';
                $last = $pre_nl.$pre.$outtag.($1 eq '+' ? ' ' : '').'$terms.'.$2;
                next;
            }
            $outtag .= '[%' . tt_dir($template, $strings, $blacklist);
        }
        elsif ($tag eq '<')
        {
            if ($template =~ s/^(\/?)(u|b|i|strong|em)>//iso)
            {
                $outtag = ' ' if $outtag;
                $last_raw = $last = $pre_nl.$pre.$outtag.'<'.$1.$2.'>';
                next;
            }
            $outtag .= '<';
            my ($script) = $template =~ /^\s*(script|style)/iso;
            my ($tagname) = $template =~ /^\/?(\S+)/so;
            my $is_button = 0;
            while ($template =~ s/^(.*?)(\[\%|\s+|>)//so)
            {
                $outtag .= $1 . $2;
                my $d = $2;
                if ($d eq '[%')
                {
                    $outtag .= tt_dir($template, $strings, $blacklist, 1);
                }
                elsif ($d eq '>')
                {
                    last;
                }
                elsif ($template =~ s/^((title|alt)\s*=[\"\'])//iso ||
                    $tagname eq 'input' && $template =~ s/^((type)\s*=[\"\'])//iso ||
                    $is_button && $template =~ s/^((value)\s*=[\"\'])//iso)
                {
                    $outtag .= $1;
                    if (lc($2) eq 'type')
                    {
                        $is_button = $template =~ /^(submit|button)/iso ? 1 : 0;
                        next;
                    }
                    my $last = '';
                    my $last_raw = '';
                    while ($template =~ s/^([^\"\']*?)(\[\%|\"|\')//so)
                    {
                        my $pre = $last.$1;
                        my $pre_raw = $last_raw.$1;
                        my $n = $2;
                        my $outtag2 = '';
                        $last = '';
                        $last_raw = '';
                        $pre =~ s/\s+/ /gso;
                        $pre =~ s/^\s*//so;
                        $pre_raw =~ s/^\s*//so;
                        if ($n ne '"' && $n ne "'")
                        {
                            if ($template =~ s/^-?\s*terms.(\w+)\s*-?\%\]//so)
                            {
                                $last = $pre.'$terms.'.$1;
                                $last_raw = $pre.'[%'.$&;
                                next;
                            }
                            elsif ($template =~ s/^\s*\%\]//so)
                            {
                                # empty directive
                                $last_raw = $last = $pre;
                                next;
                            }
                            $outtag2 .= '[%' . tt_dir($template, $strings, $blacklist);
                        }
                        else
                        {
                            $outtag2 .= $n;
                        }
                        if (add_str($strings, $pre, $blacklist))
                        {
                            $pre =~ s/([\'\\])/\\$1/gso;
                            $outtag .= ($outtag =~ /\%\]\s+$/ ? '[%+' : '[%')." L('$pre') %]";
                        }
                        else
                        {
                            $outtag .= $pre_raw;
                        }
                        $outtag .= $outtag2;
                        last if $n eq '"' || $n eq "'";
                    }
                }
            }
            if ($script)
            {
                if (lc $script eq 'script')
                {
                    # Extract messages from TT directives inside <script>..</script>
                    while ($template =~ s/^(.*?)(\[\%|<\/\s*script\s*>)//iso)
                    {
                        $outtag .= $1 . $2;
                        if ($2 eq '[%')
                        {
                            $outtag .= tt_dir($template, $strings, $blacklist);
                        }
                        else
                        {
                            last;
                        }
                    }
                }
                else
                {
                    $template =~ s!.*?</$script\s*>!!is and $outtag .= $&;
                }
            }
        }
        elsif ($tag ne '')
        {
            $outtag = $tag;
        }
        $translated .= $pre_nl;
        if (add_str($strings, $pre, $blacklist))
        {
            $pre =~ s/([\'\\])/\\$1/gso;
            $translated .= ($translated =~ /\%\]\s+$/ ? '[%+' : '[%')." L('$pre') %]";
            if ($translated =~ /\%\](\s*)$/ && ($1 || $outtag =~ /^\s+\[\%/))
            {
                # Preserve space...
                $outtag =~ s/^(\s*)\[\%(?!\+|\s*\#)-?/$1\[\%\+/;
            }
        }
        else
        {
            $translated .= $pre_raw;
        }
        $translated .= $outtag;
        last if $tag eq '';
    }
    $translated .= "\n";
    return ($translated, $strings);
}

sub tt_dir
{
    my (undef, $strings, $blacklist, $ignore) = @_;
    my $out = '';
    while ($_[0] =~ s/^\s*#(?:(?:[^\n\%]+|\%[^\]])*)//so || $_[0] =~ s/^(?:
        [^\"\'\%]+ |
        \%(?!\]) |
        \"((?:[^\"\\]+|\\.)*)\" |
        \'((?:[^\'\\]+|\\.)*)\')//xso)
    {
        my $m = $&;
        my $s = $1 || $2;
        $1 ? $s =~ s/\\([\\\"])/$1/gso : $s =~ s/\\([\\\'])/$1/gso;
        if ($s ne '')
        {
            while ($_[0] =~ s/^\s*_\s*(?:
                \"((?:[^\"\\]+|\\.)*)\" |
                \'((?:[^\'\\]+|\\.)*)\')//xso)
            {
                $m .= $&;
                my $a = $1 || $2;
                $1 ? $a =~ s/\\([\\\"])/$1/gso : $a =~ s/\\([\\\'])/$1/gso;
                $s .= $a;
            }
        }
        if (!$ignore && length $s > 2 && $s =~ /[^\x00-\x80]|[a-z].*[A-Z]|[A-Z].*[a-z]|\w.*\W|\W.*\w/so &&
            add_str($strings, $s, $blacklist))
        {
            $s =~ s/([\'\\])/\\$1/gso;
            $out .= "L('$s')";
        }
        else
        {
            if ($s)
            {
                #print STDERR "Skip: $s\n";
            }
            $out .= $m;
        }
    }
    $_[0] =~ s/\s*\%\]//so or die $_[0];
    $out .= "%]";
    return $out;
}

sub add_str
{
    my ($strings, $s, $blacklist) = @_;
    my $chk = $s;
    $chk =~ s/<[^>]*>//gso;
    $chk =~ s/&([a-z]+|#x[0-9a-f]+|#\d+);|\$[a-z]+(\.[a-z_]+)?/ /giso;
    return 0 if $chk !~ /[^\W\d]|[^\x00-\x80]/ ||
        $chk =~ /^[a-z0-9_\-]*\.cgi(\?\S*)?$|^[a-z0-9_\-\/]*\.html(\.tmpl)?(#\S*)?$|^\/*skins.*\.css$|^\/*js.*\.js$/;
    $s =~ s/\n[ \t]+/\n/gso;
    return 0 if $blacklist->{$s};
    $_[1] = $s;
    if (!$strings->{$s})
    {
        $strings->{$s} = 1;
        push @{$strings->{''}}, $s;
    }
    return 1;
}
