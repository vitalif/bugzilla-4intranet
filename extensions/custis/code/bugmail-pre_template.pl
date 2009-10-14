#!/usr/bin/perl

use strict;
use Bugzilla::Constants;
use Bugzilla::Util;
use POSIX qw(strftime);

if (0)
{
my $vars = Bugzilla->hook_args->{vars};
${Bugzilla->hook_args->{tmpl}} = 'email/newchangedmail-'.$vars->{product}.'.txt.tmpl';

my $datadir = bz_locations()->{datadir};
my $fd;
if (-w "$datadir/maillog" && open $fd, ">>$datadir/maillog")
{
    my $s = [ strftime("%Y-%m-%d %H:%M:%S: ", localtime) . ($vars->{isnew} ? "" : "Re: ") . "Bug #$vars->{id} mail to $vars->{to}" ];
    if ($vars->{new_comments} && @{$vars->{new_comments}})
    {
        push @$s, scalar(@{$vars->{new_comments}}) . ' comments (#' . (join ',', map { $_->{count} } @{$vars->{new_comments}}) . ')';
    }
    if ($vars->{diffarray} && @{$vars->{diffarray}})
    {
        push @$s, scalar(grep { $_->{type} eq 'change' } @{$vars->{diffarray}}) . ' diffs';
    }
    $s = join "; ", @$s;
    print $fd $s, "\n";
    close $fd;
}
}
