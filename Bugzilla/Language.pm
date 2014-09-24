#!/usr/bin/perl
# Localisation layer, responsible for loading i18n messages
# FIXME: Allow extensions to have their own i18n with the same structure
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author: Vitaliy Filippov <vitalif@mail.ru>, 2014

package Bugzilla::Language;

use utf8;
use strict;
use Bugzilla::Constants;
use File::Spec;
use File::Basename;

my $message_cache = {};
my $mtime = {};

# Bugzilla::Language is used in Bugzilla::Install::Util, so it shouldn't depend on Bugzilla::Util
sub trick_taint
{
    return undef unless defined $_[0];
    my $match = $_[0] =~ /^(.*)$/s;
    $_[0] = $match ? $1 : undef;
    return (defined($_[0]));
}

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($params) = @_;
    return bless { selected_language => $params->{selected_language} }, $class;
}

# Make an ordered list out of a HTTP Accept-Language header (see RFC 2616, 14.4)
# We ignore '*' and <language-range>;q=0
# For languages with the same priority q the order remains unchanged.
sub get_accept_language
{
    my $self = shift;
    return $self->{accept_language} if $self->{accept_language};

    my $accept_language = $ENV{HTTP_ACCEPT_LANGUAGE};

    # clean up string.
    $accept_language =~ s/[^A-Za-z;q=0-9\.\-,]//g;
    my @qlanguages;
    my @languages;
    foreach (split /,/, $accept_language)
    {
        if (m/([A-Za-z\-]+)(?:;q=(\d(?:\.\d+)))?/)
        {
            my $lang   = $1;
            my $qvalue = $2;
            $qvalue = 1 if not defined $qvalue;
            next if $qvalue == 0;
            $qvalue = 1 if $qvalue > 1;
            push @qlanguages, { qvalue => $qvalue, language => $lang };
        }
    }

    return $self->{accept_language} = [ map { $_->{language} } sort { $b->{qvalue} <=> $a->{qvalue} } @qlanguages ];
}

sub supported_languages
{
    my $self = shift;
    return $self->{languages} if $self->{languages};
    my @files = glob(File::Spec->catfile(bz_locations->{cgi_path}, 'i18n', '*'));
    my @languages;
    foreach my $dir_entry (@files)
    {
        # It's a language directory only if it contains "messages.pl".
        # This auto-excludes various VCS directories as well.
        next unless -f File::Spec->catfile($dir_entry, 'messages.pl');
        $dir_entry = basename($dir_entry);
        # Check for language tag format conforming to RFC 1766.
        next unless $dir_entry =~ /^[a-zA-Z]{1,8}(-[a-zA-Z]{1,8})?$/;
        trick_taint($dir_entry);
        push @languages, $dir_entry;
    }
    return $self->{languages} = \@languages;
}

sub language
{
    my $self = shift;
    if (!$self->{language})
    {
        $self->{language} = $self->{selected_language};
        my $supported = {};
        for (@{$self->supported_languages})
        {
            $supported->{$_} = $_;
            if (/^(.*)-(.*)$/so && !$supported->{$1})
            {
                # If we support the language we want, or *any version* of
                # the language we want, it gets pushed into @usedlanguages.
                #
                # Per RFC 1766 and RFC 2616, things like 'en' match 'en-us' and
                # 'en-uk', but not the other way around. (This is unfortunately
                # not very clearly stated in those RFC; see comment just over 14.5
                # in http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4)
                $supported->{$1} = $_;
            }
        }
        if (!$self->{language})
        {
            ($self->{language}) = map { $supported->{$_} || () } @{$self->get_accept_language};
        }
        else
        {
            $self->{language} = $supported->{$self->{language}};
        }
        $self->{language} ||= 'en';
    }
    return $self->{language};
}

sub runtime_messages
{
    my $self = shift;
    my ($lang) = @_;
    $lang ||= $self->language;
    if (!$self->{runtime_checked}->{$lang})
    {
        my $file = File::Spec->catfile(bz_locations->{cgi_path}, 'i18n', $lang, 'runtime.pl');
        my $m = [ stat $file ]->[9];
        if (!$message_cache->{$lang} || $m && $mtime->{$lang} < $m)
        {
            $mtime->{$lang} = $m;
            $message_cache->{$lang} = do $file;
            warn $@ if $@;
            # Substitute $terms.key and $constants.key during load
            for my $sect (values %{$message_cache->{$lang} || {}})
            {
                for (values %$sect)
                {
                    s/\$terms.(\w+)/$message_cache->{$lang}->{terms}->{$1}/ges;
                    s/\$constants.(\w+)/eval { Bugzilla::Constants->$1() } || '$constants.'.$1/ges;
                }
            }
        }
        $self->{runtime_checked}->{$lang} = 1;
    }
    return $message_cache->{$lang} || {};
}

sub template_messages
{
    my $self = shift;
    my ($lang) = @_;
    $lang ||= $self->language;
    if (!$self->{template_messages}->{$lang})
    {
        # Template messages are needed only during compilation,
        # so they are only loaded for a single request
        my $file = File::Spec->catfile(bz_locations->{cgi_path}, 'i18n', $lang, 'messages.pl');
        if (-e $file)
        {
            $self->{template_messages}->{$lang} = do $file;
            warn $@ if $@;
        }
    }
    return $self->{template_messages}->{$lang};
}

sub template_messages_mtime
{
    my $self = shift;
    my ($lang) = @_;
    $lang ||= $self->language;
    if (!exists $self->{template_message_mtime}->{$lang})
    {
        my $file = File::Spec->catfile(bz_locations->{cgi_path}, 'i18n', $lang, 'messages.pl');
        $self->{template_message_mtime}->{$lang} = [ stat $file ]->[9];
    }
    return $self->{template_message_mtime}->{$lang};
}

1;
__END__
