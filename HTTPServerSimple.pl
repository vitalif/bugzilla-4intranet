#!/usr/bin/perl

use strict;

BEGIN {
    require File::Basename;
    chdir(File::Basename::dirname($0));
}

use lib qw(.);
use CGI ();
CGI->compile(qw(:cgi -no_xhtml -oldstyle_urls :private_tempfiles
                :unique_headers SERVER_PUSH :push));
$CGI::USE_PARAM_SEMICOLONS = 0;

my $server = Bugzilla::HTTPServerSimple->new(8157);
$server->run();

package Bugzilla::HTTPServerSimple;

use Time::HiRes qw(gettimeofday tv_interval);
use IO::SendFile qw(sendfile);
use base qw(HTTP::Server::Simple::CGI);

my %subs = ();

sub handle_request
{
    my $self = shift;
    my ($cgi) = @_;
    $cgi->nph(1);
    $CGI::USE_PARAM_SEMICOLONS = 0;
    my $script = $ENV{SCRIPT_FILENAME};
    $ENV{REQUEST_URI} =~ s!^/*bugs\d*/*!/!iso;
    unless ($script)
    {
        ($script) = $ENV{REQUEST_URI} =~ m!/+([^\?\#]*)!so;
    }
    $script ||= 'index.cgi';
    my $fd;
    $script =~ s!^/*!!so;
    if (($script !~ /\.cgi$/iso || $script =~ /\//so) && open $fd, '<', $script)
    {
        sendfile(fileno(STDOUT), fileno($fd), 0, -s $script);
        close $fd;
        return 200;
    }
    if (!$subs{$script})
    {
        my $content;
        if (open $fd, "<$script")
        {
            local $/ = undef;
            $content = <$fd>;
            close $fd;
        }
        if ($content)
        {
            $subs{$script} = eval "sub { $content }";
            if ($@)
            {
                warn "Error while loading $script:\n$@";
                return 500;
            }
        }
    }
    if ($subs{$script})
    {
        my $start = [gettimeofday];
        eval { &{$subs{$script}}(); };
        if ($@)
        {
            warn "Error while running $script:\n$@";
        }
        my $elapsed = tv_interval($start) * 1000;
        warn "Served $script in $elapsed ms";
    }
    return 404;
}

1;
__END__
