#!/usr/bin/perl
# Standalone HTTP server for running Bugzilla based on HTTP::Server::Simple and Net::Server
# USAGE: perl HTTPServerSimple.pl [--option=value] [bugzilla.conf]
# See bugzilla.conf sample in the end of this file

use strict;

BEGIN
{
    require File::Basename;
    my $dir = File::Basename::dirname($0);
    ($dir) = $dir =~ /^(.*)$/s;
    chdir($dir);
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
my $server = Bugzilla::HTTPServerSimple->new(@ARGV);
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
    my ($class, @args) = @_;
    my $self = HTTP::Server::Simple::new($class);
    my @cfg;
    for (@args)
    {
        if (/^--([^=]+)(?:=(.*))?/s)
        {
            push @cfg, $1, $2||1;
        }
        elsif (!$self->{_config})
        {
            $self->{_config} = Bugzilla::NetServerConfigParser->_read_conf($_);
        }
    }
    push @{$self->{_config} ||= []}, @cfg;
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
    $ENV{REQUEST_URI} =~ s!^/*!/!iso;
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
    if ($self->{_config_hash}->{http_env})
    {
        # Allow to set environment variables from additional HTTP headers
        foreach (split /[\s,]*,[\s,]*/, $self->{_config_hash}->{http_env})
        {
            $ENV{$_} = $ENV{'HTTP_X_'.uc $_};
        }
    }
    # Bugzilla-specific tweaks
    binmode STDOUT, ':utf8' if Bugzilla->can('params') && Bugzilla->params->{utf8};
    # Clear request cache for new versions
    $Bugzilla::_request_cache = {};
    # Reload Bugzilla.pm for old versions on each request
    my $preload = Bugzilla->can('request_cache') ? '' : "delete \$INC{'Bugzilla.pm'}; require 'Bugzilla.pm';";
    # Use require() instead of sub caching under NYTProf profiler for more correct reports
    my $content;
    if ((!$subs{$script} || $ENV{NYTPROF} && $INC{'Devel/NYTProf.pm'}) && open $fd, "<$script")
    {
        local $/ = undef;
        $content = <$fd>;
        close $fd;
        # untaint
        ($content) = $content =~ /^(.*)$/s;
        $content =~ s/\n__END__.*/\n/s;
    }
    if ($ENV{NYTPROF} && $INC{'Devel/NYTProf.pm'})
    {
        my $start = [gettimeofday];
        eval "$preload package main; $content";
        my $elapsed = tv_interval($start) * 1000;
        print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script via require() in $elapsed ms\n";
        return 200;
    }
    # Simple "FastCGI" implementation - cache *.cgi in subs
    if (!$subs{$script} && $content)
    {
        $subs{$script} = eval "package main; sub { $preload$content }";
        if ($@)
        {
            warn "Error while loading $script:\n$@";
            return 500;
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

Sample bugzilla.conf (all parameters can be specified on
commandline using --option=value or here in config):

# Net::Server subclass to use for serving
class               Net::Server::PreFork

# That subclass's parameters
port                0.0.0.0:8157
min_servers         4
max_servers         20
min_spare_servers   4
max_spare_servers   8
max_requests        1000
user                www-data
group               www-data
log_file            /var/log/bugzilla.log
log_level           2
pid_file            /var/run/bugzilla.pid
background          1

'http_env' specifies which environment variables to set from
a corresponding 'X-<name>' HTTP header (value is comma-separated).
For example to support multiple Bugzilla 'projects' specify

http_env            PROJECT

And specify an appropriate project in 'X-Project' header on your frontend.
For example, for nginx:

proxy_set_header X-Project 'project';

Or for Apache:

RequestHeader set X-Project project
