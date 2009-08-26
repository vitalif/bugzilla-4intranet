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
*CORE::GLOBAL::exit = sub { die bless { rc => shift }, 'Bugzilla::HTTPServerSimple::FakeExit'; };
$SIG{INT} = sub { warn "Terminating"; CORE::exit(); };
$server->run();

package Bugzilla::HTTPServerSimple;

use Bugzilla;
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
    $Bugzilla::_request_cache = {};
    if ($ENV{NYTPROF} && $INC{'Devel/NYTProf.pm'})
    {
        # use require() when running under NYTProf profiler
        my $start = [gettimeofday];
        delete $INC{$script};
        require $script;
        my $elapsed = tv_interval($start) * 1000;
        warn "Served $script via require() in $elapsed ms";
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
        if ($@ && (!ref($@) || ref($@) ne 'Bugzilla::HTTPServerSimple::FakeExit'))
        {
            warn "Error while running $script:\n$@";
        }
        my $elapsed = tv_interval($start) * 1000;
        warn "Served $script in $elapsed ms";
    }
    return 404;
}

sub parse_headers
{
    my $self = shift;
    my @headers;
    my $chunk;
    while ($chunk = <STDIN>)
    {
        $chunk =~ s/[\r\l\n\s]+$//so;
        if ($chunk =~ /^([^()<>\@,;:\\"\/\[\]?={} \t]+):\s*(.*)/i) {
            push @headers, $1 => $2;
        }
        last if $chunk =~ /^$/so;
    }
    return \@headers;
}

package Bugzilla::HTTPServerSimple::FakeExit;

1;
__END__
