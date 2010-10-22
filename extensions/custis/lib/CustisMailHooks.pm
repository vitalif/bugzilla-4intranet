#!/usr/bin/perl
# Хуки во всевозможную обработку почты

package CustisMailHooks;

use strict;

use Bugzilla::Constants;
use CustisLocalBugzillas;
use Bugzilla::Util;
use POSIX qw(strftime);

# Hack into urlbase and set it to be correct for email recipient
sub bugmail_pre_template
{
    my ($args) = @_;

    my $vars = $args->{vars};
    ${$args->{tmpl}} = 'email/newchangedmail-'.$vars->{product}.'.txt.tmpl';

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

    CustisLocalBugzillas::HackIntoUrlbase($vars->{to});
    return 1;
}

# Unhack urlbase :-)
sub bugmail_post_send
{
    my ($args) = @_;
    CustisLocalBugzillas::HackIntoUrlbase(undef);
    return 1;
}

# Hack into urlbase and set it to be correct for email recipient
sub flag_notify_pre_template
{
    my ($args) = @_;
    my $vars = $args->{vars};
    CustisLocalBugzillas::HackIntoUrlbase($vars->{to});
    return 1;
}

# Unhack urlbase :-)
sub flag_notify_post_send
{
    my ($args) = @_;
    CustisLocalBugzillas::HackIntoUrlbase(undef);
    return 1;
}

##
## Обработка исходящей почты:
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
