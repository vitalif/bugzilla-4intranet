#!/usr/bin/perl
# Standalone HTTP server for running Bugzilla based on HTTP::Server::Simple and Net::Server
# USAGE: perl HTTPServerSimple.pl --conf_file bugzilla.conf
# See bugzilla.conf sample in the end of this file

use strict;

BEGIN
{
    require File::Basename;
    chdir(File::Basename::dirname($0));
}

use lib qw(.);
use CGI ();
CGI->compile(qw(:cgi -no_xhtml -oldstyle_urls :private_tempfiles :unique_headers SERVER_PUSH :push));
$CGI::USE_PARAM_SEMICOLONS = 0;

# Fake exit() function to only terminate current request
my $in_eval = 0;
*CORE::GLOBAL::exit = sub
{
    if ($in_eval)
    {
        die bless { rc => shift }, 'Bugzilla::HTTPServerSimple::FakeExit';
    }
    else
    {
        CORE::exit(@_);
    }
};
$SIG{INT} = sub { warn "Terminating"; CORE::exit(); };

# Create and run
my $server = Bugzilla::HTTPServerSimple->new($ARGV[0]);
$server->run();

# HTTP::Server::Simple subclass (the real server)
package Bugzilla::HTTPServerSimple;

use Bugzilla;
use Time::HiRes qw(gettimeofday tv_interval);
use IO::SendFile qw(sendfile);
use POSIX qw(strftime);
use LWP::MediaTypes qw(guess_media_type);

use base qw(HTTP::Server::Simple::CGI);

# Code cache
my %subs = ();

sub new
{
    my ($class, $conf) = @_;
    my $self = HTTP::Server::Simple::new($class);
    $self->{_config} = Bugzilla::NetServerConfigParser->_read_conf($conf);
    $self->{_config_hash} = {};
    for (my $i = 0; $i < @{$self->{_config}}; $i += 2)
    {
        $self->{_config_hash}->{$self->{_config}->[$i]} ||= $self->{_config}->[$i+1];
        if ($self->{_config}->[$i] eq 'port')
        {
            # Remove first 'port' option (workaround hardcode from HTTP::Server::Simple)
            splice @{$self->{_config}}, $i, 2;
            $i -= 2;
        }
    }
    return $self;
}

sub run
{
    my $self = shift;
    $self->SUPER::run(@{$self->{_config}});
}

sub port
{
    my $self = shift;
    return $self->{_config_hash}->{port};
}

sub net_server
{
    my $self = shift;
    return $self->{_config_hash}->{class};
}

sub handle_request
{
    my $self = shift;
    my ($cgi) = @_;
    # Set non-parsed-headers CGI mode
    $cgi->nph(1);
    $CGI::USE_PARAM_SEMICOLONS = 0;
    # Determine SCRIPT_FILENAME
    my $script = $ENV{SCRIPT_FILENAME};
    $ENV{REQUEST_URI} =~ s!^/*bugs\d*/*!/!iso;
    unless ($script)
    {
        ($script) = $ENV{REQUEST_URI} =~ m!/+([^\?\#]*)!so;
    }
    $script ||= 'index.cgi';
    # Serve static files (should be done by nginx, but we support it for completeness)
    my $fd;
    $script =~ s!^/*!!so;
    if (($script !~ /\.cgi$/iso || $script =~ /\//so) && open $fd, '<', $script)
    {
        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header(-type => guess_media_type($script), -Content_length => -s $script);
        sendfile(fileno(STDOUT), fileno($fd), 0, -s $script);
        close $fd;
        print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script via sendfile()\n";
        return 200;
    }
    binmode STDOUT, ':utf8';
    $Bugzilla::_request_cache = {};
    # Use require() instead of sub caching under NYTProf profiler for more correct reports
    if ($ENV{NYTPROF} && $INC{'Devel/NYTProf.pm'})
    {
        my $start = [gettimeofday];
        delete $INC{$script};
        require $script;
        my $elapsed = tv_interval($start) * 1000;
        print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script via require() in $elapsed ms\n";
        return 200;
    }
    # Simple "FastCGI" implementation - cache *.cgi in subs
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
    # Run cached sub
    if ($subs{$script})
    {
        my $start = [gettimeofday];
        $in_eval = 1;
        eval { &{$subs{$script}}(); };
        $in_eval = 0;
        if ($@ && (!ref($@) || ref($@) ne 'Bugzilla::HTTPServerSimple::FakeExit'))
        {
            warn "Error while running $script:\n$@";
        }
        my $elapsed = tv_interval($start) * 1000;
        print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script in $elapsed ms\n";
    }
    return 404;
}

# Override bad HTTP::Server::Simple::parse_headers implementation with a good one
sub parse_headers
{
    my $self = shift;
    my @headers;
    my $chunk;
    while ($chunk = <STDIN>)
    {
        $chunk =~ s/[\r\l\n\s]+$//so;
        if ($chunk =~ /^([^()<>\@,;:\\"\/\[\]?={} \t]+):\s*(.*)/i)
        {
            push @headers, $1 => $2;
        }
        last if $chunk =~ /^$/so;
    }
    return \@headers;
}

# Net::Server fake subclass used to call _read_conf()
package Bugzilla::NetServerConfigParser;

use base 'Net::Server';

# _read_conf() could call fatal() in case of parse error
sub fatal
{
    shift;
    die @_;
}

# Fake "exit" exception class
package Bugzilla::HTTPServerSimple::FakeExit;

1;
__END__
