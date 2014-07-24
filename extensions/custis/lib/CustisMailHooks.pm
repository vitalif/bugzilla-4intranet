#!/usr/bin/perl
# Various email hooks

package CustisMailHooks;

use strict;

use Bugzilla::Constants;
use Bugzilla::Util;
use POSIX qw(strftime);

# Log all messages with comment and diff count to data/maillog
sub bugmail_pre_template
{
    my ($args) = @_;

    my $vars = $args->{vars};
    my $datadir = bz_locations()->{datadir};
    my $fd;
    if (-w "$datadir/maillog" && open $fd, ">>$datadir/maillog")
    {
        my $s = [ strftime("%Y-%m-%d %H:%M:%S: ", localtime) . ($vars->{isnew} ? "" : "Re: ") . "Bug #$vars->{bugid} mail to $vars->{to}" ];
        if ($vars->{new_comments} && @{$vars->{new_comments}})
        {
            push @$s, scalar(@{$vars->{new_comments}}) . ' comment(s) (#' . (join ',', map { $_->{count} } @{$vars->{new_comments}}) . ')';
        }
        if ($vars->{diffarray} && @{$vars->{diffarray}})
        {
            push @$s, scalar(grep { $_->{type} eq 'change' } @{$vars->{diffarray}}) . ' diffs';
        }
        $s = join "; ", @$s;
        print $fd $s, "\n";
        close $fd;
    }

    return 1;
}

##
## Handling incoming email:
##

sub emailin_filter_body
{
    my ($args) = @_;

    for (${$args->{body}})
    {
        if (/From:\s+bugzilla-daemon(\s*[a-z0-9_\-]+\s*:.*?\n)*\s*Bug\s*\d+<[^>]*>\s*\([^\)]*\)\s*/iso)
        {
            my ($pr, $ps) = ($`, $');
            $ps =~ s/\n+(\r*\n+)+/\n/giso;
            $_ = $pr . $ps;
            s!from\s+.*?<http://plantime[^>]*search=([^>]*)>!from $1!giso;
            s!((Comment|Bug)\s+\#?\d+)<[^<>]*>!$1!giso;
            s!\n[^\n]*<http://plantime[^>]*search=[^>]*>\s+changed:[ \t\r]*\n.*?$!!iso;
            s/\s*\n--\s*Configure\s*bugmail<[^>]*>(([ \t\r]*\n[^\n]*)*)//iso;
        }
    }
    return 1;
}

sub emailin_filter_html
{
    my ($args) = @_;

    for (${$args->{body}})
    {
        s/<table[^<>]*class=[\"\']?difft[^<>]*>.*?<\/table\s*>//giso;
        s/<a[^<>]*>.*?<\/a\s*>/_custis_rmlf($&)/gieso;
    }

    return 1;
}

sub _custis_rmlf
{
    my ($t) = @_;
    $t =~ s/[\n\r]+/ /giso;
    return $t;
}

1;
__END__
