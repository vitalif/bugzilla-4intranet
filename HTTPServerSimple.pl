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
CGI->compile(qw(:cgi -no_xhtml -nph -oldstyle_urls :private_tempfiles :unique_headers SERVER_PUSH :push));
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
my @args = @ARGV;
@ARGV = ();
my $server = Bugzilla::HTTPServerSimple->new(@args);
$server->run();

# HTTP::Server::Simple subclass (the real server)
package Bugzilla::HTTPServerSimple;

use Bugzilla;
use Bugzilla::Util qw(html_quote);
use Time::HiRes qw(gettimeofday tv_interval);
use Sys::Sendfile qw(sendfile);
use POSIX qw(strftime);
use LWP::MediaTypes qw(guess_media_type);

use base qw(HTTP::Server::Simple::CGI);

use constant DEFAULT_CONFIG => (
    class               => 'Net::Server::PreFork',
    port                => '127.0.0.1:8157',
    min_servers         => 4,
    max_servers         => 20,
    min_spare_servers   => 4,
    max_spare_servers   => 8,
    max_requests        => 1000,
    user                => POSIX::geteuid(),
    group               => POSIX::getegid(),
    log_file            => '/var/log/bugzilla.log',
    log_level           => 2,
    pid_file            => '/var/run/bugzilla.pid',
    background          => 1,
    deny_regexp         => '^(localconfig|data/(?!webdot/)|.*\.(pm|pl|sh)($|\?)|(/|^)(CVS|\.(ht|svn|hg|bzr|git)).*)',
    preload             => '*.cgi',
    reload              => 1,
);

# Code cache
my %subs = ();
my %mtime = ();

sub new
{
    my ($class, @args) = @_;
    my $self = HTTP::Server::Simple::new($class);
    my $cmdline = [];
    my $series = [];
    my $nextvalue = 0;
    for (@args)
    {
        if (/^--([^=]+)(?:=(.*))?/s)
        {
            push @$cmdline, 1 if $nextvalue;
            $nextvalue = !$2;
            push @$cmdline, $1;
        }
        elsif ($nextvalue)
        {
            push @$cmdline, $_;
            $nextvalue = 0;
        }
        else
        {
            push @$series, Bugzilla::NetServerConfigParser->_read_conf($_);
        }
    }
    push @$cmdline, 1 if $nextvalue;
    push @$series, $cmdline;
    unshift @$series, [ DEFAULT_CONFIG() ];
    my $r = {};
    for my $array (@$series)
    {
        my $cfg = {};
        for (my $i = 0; $i < @$array; $i += 2)
        {
            push @{$cfg->{$array->[$i]}}, $array->[$i+1];
        }
        $r = { %$r, %$cfg };
    }
    # Preload scripts (before transforming $r)
    for my $script (@{$r->{preload} || []})
    {
        for (glob $script)
        {
            ($_) = /^(.*)$/so;
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
    $self->{_config} = [];
    for my $k (keys %$r)
    {
        push @{$self->{_config}}, map { $k => $_ } @{$r->{$k}};
        ($r->{$k}) = @{$r->{$k}} if @{$r->{$k}} < 2;
    }
    if ($r->{reload})
    {
        # Enable reload support
        $^P |= 0x10;
    }
    $self->{_config_hash} = $r;
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
    print $ENV{SERVER_PROTOCOL}." $status_code $status_line\r\nContent-Type: text/html\r\n\r\n".
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
    my $package = lc $script;
    $package =~ s/^(\W)/'x'.unpack('H*', $1)/es;
    $package =~ s/(\W)/unpack('H*', $1)/ges;
    $content = $for_require ? "$preload package Bugzilla::$package; $content" : "package Bugzilla::$package; sub { $preload$content }";
    return $content;
}

# Load script
sub load_script
{
    my $self = shift;
    my ($script) = @_;
    my $m;
    if (!$subs{$script} || ($self->{_config_hash}->{reload} && ($m = [stat $script]->[9] || 0) > $mtime{$script}))
    {
        my $content = $self->get_script($script);
        $subs{$script} = eval $content;
        $mtime{$script} = $m;
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
    $Bugzilla::Error::IN_EVAL++;
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
    $Bugzilla::Error::IN_EVAL--;
    if ($err)
    {
        $self->internal_error($err);
    }
}

sub handler
{
    my $self = shift;
    $self->handle_request;
}

sub handle_request
{
    my $self = shift;
    # Set SCRIPT_NAME to REQUEST_URI and clear PATH_INFO
    # Prevent path traversal
    $ENV{REQUEST_URI} =~ tr!\\!/!;
    $ENV{REQUEST_URI} =~ s!\.+/+!!giso;
    $ENV{REQUEST_URI} =~ s!^/*!/!iso;
    $ENV{SCRIPT_NAME} = $ENV{REQUEST_URI};
    $ENV{PATH_INFO} = '';
    # Set non-parsed-headers CGI mode
    CGI::nph(1);
    # Determine SCRIPT_FILENAME
    my $script = $ENV{SCRIPT_FILENAME};
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
    if ($script =~ /\/$/s || $self->{_config_hash}->{deny_regexp} &&
        $script =~ /$self->{_config_hash}->{deny_regexp}/s)
    {
        return $self->print_error('403', 'Access Denied', "You are not allowed to access URL $script on this server.");
    }
    # Serve static files (should be done by nginx, but we support it for completeness)
    my $fd;
    $script =~ s!^/*!!so;
    if ($script !~ /\.cgi$/iso || $script =~ /\//so)
    {
        if (open $fd, '<', $script)
        {
            print $ENV{SERVER_PROTOCOL}." 200 OK\r\n".
                "Content-Type: ".guess_media_type($script)."\r\n".
                "Content-Length: ".(-s $script)."\r\n\r\n";
            sendfile(STDOUT, $fd, -s $script);
            close $fd;
            print STDERR strftime("[%Y-%m-%d %H:%M:%S]", localtime)." Served $script via sendfile()\n";
            return 200;
        }
        else
        {
            # Failed to open file
            return $self->print_error('403', 'Access Denied', "You are not allowed to access URL $script on this server.");
        }
    }
    if ($self->{_config_hash}->{http_env})
    {
        # Allow to set environment variables from additional HTTP headers
        foreach (split /[\s,]*,[\s,]*/, $self->{_config_hash}->{http_env})
        {
            $ENV{$_} = $ENV{'HTTP_X_'.uc $_};
        }
    }
    if ($self->{_config_hash}->{reload})
    {
        reload();
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

my $STATS;

# Used to reload Perl modules on-the-fly (debug purposes)
sub reload
{
    my ($file, $mtime);
    my @reload;
    for my $key (keys %INC)
    {
        $file = $INC{$key} or next;
        $file =~ /\.p[ml]$/i or next; # do not reload *.cgi

        $mtime = (stat $file)[9];
        # Startup time as default
        $STATS->{$file} = $^T unless defined $STATS->{$file};

        # Modified
        if ($mtime > $STATS->{$file})
        {
            print STDERR __PACKAGE__ . ": $key -> $file modified, unloading\n";
            unload($key) or next;
            push @reload, $key;
            $STATS->{$file} = $mtime;
        }
    }
    for (@reload)
    {
        print STDERR __PACKAGE__ . ": Reloading $_\n";
        eval { no warnings 'redefine'; require $_ };
        if ($@)
        {
            warn $@;
        }
    }
}

sub unload
{
    my ($key) = @_;
    my $file = $INC{$key} or return;
    my @subs = grep { index($DB::sub{$_}, "$file:") == 0 } keys %DB::sub;
    for my $sub (@subs)
    {
        eval { undef &$sub };
        if ($@)
        {
            warn "Can't unload sub '$sub' in '$file': $@";
            return undef;
        }
        delete $DB::sub{$sub};
    }
    delete $INC{$key};
    return 1;
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
deny_regexp         ^(localconfig|data/(?!webdot/)|.*\.(pm|pl|sh)($|\?)|(/|^)(CVS|\.(ht|svn|hg|bzr|git)).*)

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

# Specify reload=1 to reload all modules (*.pm) on every request
reload              1
