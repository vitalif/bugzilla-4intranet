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
    $Bugzilla::HTTPServerSimple::DOCROOT = $dir;
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
use Bugzilla::Util qw(html_quote);
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
        elsif ($self->{_config}->[$i] eq 'preload')
        {
            # Preload a script
            my $script = $self->{_config}->[$i+1];
            for (glob $script)
            {
                eval
                {
                    $self->load_script($_);
                };
                if ($@ && ref $@ eq 'Bugzilla::HTTPServerSimple::FakeExit')
                {
                    print STDERR "Preloading $_ failed: $@->{error}->[2]\n";
                }
            }
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

# Returns Net::Server subclass to run under
sub net_server
{
    my $self = shift;
    return $self->{_config_hash}->{class};
}

# Format an error in HTML
sub print_error
{
    my $self = shift;
    my ($status_code, $status_line, $error_text) = @_;
    print STDERR strftime("[%Y-%m-%d %H:%M:%S] ", localtime) . $error_text . "\n";
    print $self->{_cgi}->header(-status => $status_code).
        "<html><head><title>$status_line</title></head>".
        "<body><h1>$status_line</h1><p>".html_quote($error_text).
        "</p><hr /><p>".$ENV{SERVER_SOFTWARE}."</p></body></html>";
    return $status_code;
}

# Abort request with error
sub throw
{
    my $self = shift;
    die bless { error => [ @_ ] }, 'Bugzilla::HTTPServerSimple::FakeExit';
}

# Print a "Not found" error
sub not_found
{
    my $self = shift;
    my ($script) = @_;
    $self->throw(404, 'Not Found', "The requested URL $script was not found on this server.");
}

# Print an "Internal Server Error"
sub internal_error
{
    my $self = shift;
    my ($text) = @_;
    $self->throw(500, 'Internal Server Error', $text);
}

# Load CGI script from file
sub get_script
{
    my $self = shift;
    my ($script, $for_require) = @_;
    my $fd;
    if (!open $fd, "<$script")
    {
        $self->not_found($script);
    }
    # Reload Bugzilla.pm for old versions on each request
    my $preload = Bugzilla->can('request_cache') ? '' : "delete \$INC{'Bugzilla.pm'}; require 'Bugzilla.pm';";
    my $content;
    local $/ = undef;
    $content = <$fd>;
    close $fd;
    # untaint
    ($content) = $content =~ /^(.*)$/s;
    $content =~ s/\n__END__.*/\n/s;
    $content = "\n#line 1 \"$script\"\n$content";
    $content = $for_require ? "$preload package main; $content" : "package main; sub { $preload$content }";
    return $content;
}

# Load script
sub load_script
{
    my $self = shift;
    my ($script) = @_;
    if (!$subs{$script})
    {
        my $content = $self->get_script($script);
        $subs{$script} = eval $content;
        if ($@)
        {
            $self->internal_error("Error while loading $script:\n$@");
        }
    }
}

# Simple "FastCGI" implementation - cache *.cgi in subs
sub run_script
{
    my $self = shift;
    my ($script) = @_;
    $self->load_script($script);
    my $start = [gettimeofday];
    $in_eval = 1;
    eval { &{$subs{$script}}(); };
    $self->check_errors($script);
    my $elapsed = tv_interval($start) * 1000;
    print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script in $elapsed ms\n";
}

# Use require() instead of sub caching under NYTProf profiler for more correct reports
sub run_script_require
{
    my $self = shift;
    my ($script) = @_;
    my $content = $self->get_script($script, 1);
    my $start = [gettimeofday];
    $in_eval = 1;
    eval $content;
    $self->check_errors($script);
    my $elapsed = tv_interval($start) * 1000;
    print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script via require() in $elapsed ms\n";
}

# Finish script run and check for errors
sub check_errors
{
    my $self = shift;
    my ($script) = @_;
    my $err;
    if ($@ && (!ref($@) || ref($@) ne 'Bugzilla::HTTPServerSimple::FakeExit'))
    {
        $err = "Error while running $script:\n$@";
    }
    eval { Bugzilla::_cleanup(); };
    if ($@ && (!ref($@) || ref($@) ne 'Bugzilla::HTTPServerSimple::FakeExit'))
    {
        print STDERR "Error in _cleanup():\n$@";
    }
    $in_eval = 0;
    if ($err)
    {
        $self->internal_error($err);
    }
}

sub handle_request
{
    my $self = shift;
    my ($cgi) = @_;
    # Set SCRIPT_NAME to REQUEST_URI and clear PATH_INFO
    $ENV{SCRIPT_NAME} = $ENV{REQUEST_URI};
    $ENV{PATH_INFO} = '';
    # Set non-parsed-headers CGI mode
    $cgi->nph(1);
    $self->{_cgi} = $cgi;
    $CGI::USE_PARAM_SEMICOLONS = 0;
    # Determine SCRIPT_FILENAME
    my $script = $ENV{SCRIPT_FILENAME};
    $ENV{REQUEST_URI} =~ s!^/*!/!iso;
    unless ($script)
    {
        ($script) = $ENV{REQUEST_URI} =~ m!/+([^\?\#]*)!so;
    }
    if ($self->{_config_hash}->{path_parent_regexp})
    {
        $script =~ s!^($self->{_config_hash}->{path_parent_regexp})($|/+)!!s;
    }
    $script ||= 'index.cgi';
    $ENV{SCRIPT_FILENAME} = $Bugzilla::HTTPServerSimple::DOCROOT.'/'.$script;
    # Check access
    if ($self->{_config_hash}->{deny_regexp} &&
        $script =~ /$self->{_config_hash}->{deny_regexp}/s)
    {
        return $self->print_error('403', 'Access Denied', "You are not allowed to access URL $script on this server.");
    }
    # Serve static files (should be done by nginx, but we support it for completeness)
    my $fd;
    $script =~ s!^/*!!so;
    if (($script !~ /\.cgi$/iso || $script =~ /\//so) && open $fd, '<', $script)
    {
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
    eval
    {
        if ($ENV{NYTPROF} && $INC{'Devel/NYTProf.pm'})
        {
            $self->run_script_require($script);
        }
        else
        {
            $self->run_script($script);
        }
    };
    if ($@ && ref($@) eq 'Bugzilla::HTTPServerSimple::FakeExit')
    {
        return $self->print_error(@{$@->{error}});
    }
    return 200;
}

# This implementation is nearly the same as the original, but also uses buffered input
sub parse_request
{
    my $self = shift;
    my $chunk = <STDIN>;
    defined($chunk) or return undef;

    $chunk =~ m/^(\w+)\s+(\S+)(?:\s+(\S+))?\r?$/;
    my $method   = $1 || '';
    my $uri      = $2 || '';
    my $protocol = $3 || '';

    return ($method, $uri, $protocol);
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

# This regexp (optional) will be stripped from the URI beginning
path_parent_regexp  bugs|bugzilla

# HTTP 403 Access Denied will be shown for URLs matching deny_regexp:
# You are URGED also to disable these URLs on your frontend.
deny_regexp         ^(localconfig|data/|.*\.(pm|pl|sh)($|\?)|.*\.(ht|svn|hg|bzr|git).*)

# 'http_env' specifies which environment variables to set from
# a corresponding 'X-<name>' HTTP header (value is comma-separated).
# For example to support multiple Bugzilla 'projects' specify:
http_env            PROJECT

# For http_env to work you need to push an appropriate header from your
# frontend. For example, for nginx:
#   proxy_set_header X-Project 'project';
# Or for Apache:
#   RequestHeader set X-Project project

# You can preload all scripts during startup so the maximum amount
# of memory will be shared between workers
preload             *.cgi
