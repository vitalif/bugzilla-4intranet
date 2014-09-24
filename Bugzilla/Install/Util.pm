# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Everything Solved.
# Portions created by Everything Solved are Copyright (C) 2006
# Everything Solved. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Install::Util;

# The difference between this module and Bugzilla::Util is that this
# module may require *only* Bugzilla::Constants and built-in
# perl modules.

use strict;

use Bugzilla::Constants;
use Bugzilla::Extension;
use Bugzilla::Language;

use File::Basename;
use POSIX qw(setlocale LC_CTYPE);
use Safe;
use Scalar::Util qw(tainted);

use base qw(Exporter);
our @EXPORT_OK = qw(
    bin_loc
    get_version_and_os
    indicate_progress
    install_string
    template_include_path
    vers_cmp
    get_console_locale
    init_console
);

sub bin_loc
{
    my ($bin) = @_;
    return '' if ON_WINDOWS;
    # Don't print any errors from "which"
    open(my $saveerr, ">&STDERR");
    open(STDERR, '>/dev/null');
    my $loc = `which $bin`;
    close(STDERR);
    open(STDERR, ">&", $saveerr);
    my $exit_code = $? >> 8; # See the perlvar manpage.
    return '' if $exit_code > 0;
    chomp($loc);
    return $loc;
}

sub get_version_and_os
{
    # Display version information
    my @os_details = POSIX::uname;
    # 0 is the name of the OS, 2 is the major version,
    my $os_name = $os_details[0] . ' ' . $os_details[2];
    if (ON_WINDOWS)
    {
        require Win32;
        $os_name = Win32::GetOSName();
    }
    # $os_details[3] is the minor version.
    return {
        bz_ver   => BUGZILLA_VERSION,
        perl_ver => sprintf('%vd', $^V),
        os_name  => $os_name,
        os_ver   => $os_details[3],
    };
}

sub indicate_progress
{
    my ($params) = @_;
    my $current = $params->{current};
    my $total   = $params->{total};
    my $every   = $params->{every} || 1;
    print "." if !($current % $every);
    if ($current == $total || $current % ($every * 60) == 0)
    {
        print "$current/$total (" . int($current * 100 / $total) . "%)\n";
    }
}

sub install_string
{
    my ($string_id, $vars) = @_;

    my $lang = (_cache()->{language} ||= Bugzilla::Language->new());

    my $string_template = $lang->runtime_messages->{install_strings}->{$string_id};
    if (!defined $string_template)
    {
        # Don't throw an error, it's a stupid way -- <vitalif@yourcmc.ru>
        $string_template = $string_id;
        $string_template =~ s/^feature_//so;
    }

    utf8::decode($string_template) if !utf8::is_utf8($string_template);

    $vars ||= {};
    my @replace_keys = keys %$vars;
    foreach my $key (@replace_keys)
    {
        my $replacement = $vars->{$key};
        die "'$key' in '$string_id' is tainted: '$replacement'" if tainted($replacement);
        # We don't want people to start getting clever and inserting
        # ##variable## into their values. So we check if any other
        # key is listed in the *replacement* string, before doing
        # the replacement. This is mostly to protect programmers from
        # making mistakes.
        if (grep($replacement =~ /##$key##/, @replace_keys))
        {
            die "Unsafe replacement for '$key' in '$string_id': '$replacement'";
        }
        $string_template =~ s/\Q##$key##\E/$replacement/g;
    }

    return $string_template;
}

# Used by template_include_path
sub _template_custom_directories
{
    my ($templatedir) = @_;
    my @add = qw(custom default);
    my $project = bz_locations->{project};
    unshift @add, $project if $project;
    my @result;
    foreach my $dir (@add)
    {
        my $full_dir = "$templatedir/localized/$dir";
        if (-d $full_dir)
        {
            trick_taint($full_dir);
            push(@result, $full_dir);
        }
    }
    return @result;
}

# Used by template_include_path
sub _template_base_directories
{
    my @template_dirs;
    Bugzilla::Extension::load_all();
    my $dir;
    foreach (Bugzilla::Extension::loaded())
    {
        $dir = extension_template_dir($_);
        if (-d $dir)
        {
            push @template_dirs, $dir;
        }
    }
    push @template_dirs, bz_locations()->{templatedir};
    return \@template_dirs;
}

sub template_include_path
{
    my ($params) = @_;
    # Now, we add template directories in the order they will be searched:
    my $template_dirs = _template_base_directories();
    my @include_path;
    foreach my $template_dir (@$template_dirs)
    {
        my @dirs = _template_custom_directories($template_dir);
        # Hooks get each set of extension directories separately.
        if ($params->{hook})
        {
            push @include_path, \@dirs if @dirs;
        }
        # Whereas everything else just gets a whole INCLUDE_PATH.
        else
        {
            push @include_path, @dirs;
        }
    }
    # Allow to fallback to full template path - not a security risk,
    # because TT anyway allows to include any file from the FS
    push @include_path, bz_locations()->{libpath} unless $params->{hook};
    return \@include_path;
}

# This is taken straight from Sort::Versions 1.5, which is not included
# with perl by default.
sub vers_cmp
{
    my ($a, $b) = @_;
    $a = '' if !defined $a;
    $b = '' if !defined $b;

    # Remove leading zeroes - Bug 344661
    $a =~ s/^0*(\d.+)/$1/;
    $b =~ s/^0*(\d.+)/$1/;

    my @A = ($a =~ /([-.]|\d+|[^-.\d]+)/g);
    my @B = ($b =~ /([-.]|\d+|[^-.\d]+)/g);

    my ($A, $B);
    while (@A && @B)
    {
        $A = shift @A;
        $B = shift @B;
        if ($A eq '-' && $B eq '-')
        {
            next;
        }
        elsif ($A eq '-')
        {
            return -1;
        }
        elsif ($B eq '-')
        {
            return 1;
        }
        elsif ($A eq '.' && $B eq '.')
        {
            next;
        }
        elsif ($A eq '.')
        {
            return -1;
        }
        elsif ($B eq '.')
        {
            return 1;
        }
        elsif ($A =~ /^\d+$/ && $B =~ /^\d+$/)
        {
            if ($A =~ /^0/ || $B =~ /^0/)
            {
                return $A cmp $B if $A cmp $B;
            }
            else
            {
                return $A <=> $B if $A <=> $B;
            }
        }
        else
        {
            $A = uc $A;
            $B = uc $B;
            return $A cmp $B if $A cmp $B;
        }
    }
    @A <=> @B;
}

######################
# Helper Subroutines #
######################

# Used by install_string
sub _get_string_from_file
{
    my ($string_id, $file) = @_;
    return undef if !-e $file;
    my $safe = new Safe;
    $safe->rdo($file);
    my %strings = %{$safe->varglob('strings')};
    return $strings{$string_id};
}

sub get_console_locale
{
    require Locale::Language;
    my $locale = setlocale(LC_CTYPE);
    my $language;
    # Some distros set e.g. LC_CTYPE = fr_CH.UTF-8. We clean it up.
    if ($locale =~ /^([^\.]+)/)
    {
        $locale = $1;
    }
    $locale =~ s/_/-/;
    # It's pretty sure that there is no language pack of the form fr-CH
    # installed, so we also include fr as a wanted language.
    if ($locale =~ /^(\S+)\-/)
    {
        $language = $1;
        $locale .= ",$language";
    }
    else
    {
        $language = $locale;
    }
    # Some OSs or distributions may have setlocale return a string of the form
    # German_Germany.1252 (this example taken from a Windows XP system), which
    # is unsuitable for our needs because Bugzilla works on language codes.
    # We try and convert them here.
    if ($language = Locale::Language::language2code($language))
    {
        $locale .= ",$language";
    }
    return $locale;
}

sub init_console
{
    eval { ON_WINDOWS && require Win32::Console::ANSI; };
    $ENV{ANSI_COLORS_DISABLED} = 1 if ($@ || !-t *STDOUT);
    $ENV{HTTP_ACCEPT_LANGUAGE} ||= get_console_locale();
    prevent_windows_dialog_boxes();
}

sub prevent_windows_dialog_boxes
{
    # This code comes from http://bugs.activestate.com/show_bug.cgi?id=82183
    # and prevents Perl modules from popping up dialog boxes, particularly
    # during checksetup (since loading DBD::Oracle during checksetup when
    # Oracle isn't installed causes a scary popup and pauses checksetup).
    #
    # Win32::API ships with ActiveState by default, though there could
    # theoretically be a Windows installation without it, I suppose.
    if (ON_WINDOWS and eval { require Win32::API })
    {
        # Call kernel32.SetErrorMode with arguments that mean:
        # "The system does not display the critical-error-handler message box.
        # Instead, the system sends the error to the calling process." and
        # "A child process inherits the error mode of its parent process."
        my $SetErrorMode = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
        my $SEM_FAILCRITICALERRORS = 0x0001;
        my $SEM_NOGPFAULTERRORBOX  = 0x0002;
        $SetErrorMode->Call($SEM_FAILCRITICALERRORS | $SEM_NOGPFAULTERRORBOX);
    }
}

# This is like request_cache, but it's used only by installation code
# for checksetup.pl and things like that.
our $_cache = {};
sub _cache
{
    # If the normal request_cache is available (which happens any time
    # after the requirements phase) then we should use that.
    if (eval { Bugzilla->request_cache; })
    {
        return Bugzilla->request_cache;
    }
    return $_cache;
}

###############################
# Copied from Bugzilla::Util #
##############################

sub trick_taint
{
    return undef unless defined $_[0];
    my $match = $_[0] =~ /^(.*)$/s;
    $_[0] = $match ? $1 : undef;
    return (defined($_[0]));
}

1;
__END__

=head1 NAME

Bugzilla::Install::Util - Utility functions that are useful both during
installation and afterwards.

=head1 DESCRIPTION

This module contains various subroutines that are used primarily
during installation. However, these subroutines can also be useful to
non-installation code, so they have been split out into this module.

The difference between this module and L<Bugzilla::Util> is that this
module is safe to C<use> anywhere in Bugzilla, even during installation,
because it depends only on L<Bugzilla::Constants> and built-in perl modules.

None of the subroutines are exported by default--you must explicitly
export them.

=head1 SUBROUTINES

=over

=item C<bin_loc>

On *nix systems, given the name of a binary, returns the path to that
binary, if the binary is in the C<PATH>.

=item C<get_version_and_os>

Returns a hash containing information about what version of Bugzilla we're
running, what perl version we're using, and what OS we're running on.

=item C<get_console_locale>

Returns the language to use based on the LC_CTYPE value returned by the OS.
If LC_CTYPE is of the form fr-CH, then fr is appended to the list.

=item C<init_console>

Sets the C<ANSI_COLORS_DISABLED> and C<HTTP_ACCEPT_LANGUAGE> environment variables.

=item C<indicate_progress>

=over

=item B<Description>

This prints out lines of dots as a long update is going on, to let the user
know where we are and that we're not frozen. A new line of dots will start
every 60 dots.

Sample usage: C<indicate_progress({ total =E<gt> $total, current =E<gt>
$count, every =E<gt> 1 })>

=item B<Sample Output>

Here's some sample output with C<total = 1000> and C<every = 10>:

 ............................................................600/1000 (60%)
 ........................................

=item B<Params>

=over

=item C<total> - The total number of items we're processing.

=item C<current> - The number of the current item we're processing.

=item C<every> - How often the function should print out a dot.
For example, if this is 10, the function will print out a dot every
ten items. Defaults to 1 if not specified.

=back

=item B<Returns>: nothing

=back

=item C<install_string>

=over

=item B<Description>

This is a very simple method of templating strings for installation.
It should only be used by code that has to run before the Template Toolkit
can be used. (See the comments at the top of the various L<Bugzilla::Install>
modules to find out when it's safe to use Template Toolkit.)

It pulls strings out of the F<strings.txt.pl> "template" and replaces
any variable surrounded by double-hashes (##) with a value you specify.

This allows for localization of strings used during installation.

=item B<Example>

Let's say your template string looks like this:

 The ##animal## jumped over the ##plant##.

Let's say that string is called 'animal_jump_plant'. So you call the function
like this:

 install_string('animal_jump_plant', { animal => 'fox', plant => 'tree' });

That will output this:

 The fox jumped over the tree.

=item B<Params>

=over

=item C<$string_id> - The name of the string from F<strings.txt.pl>.

=item C<$vars> - A hashref containing the replacement values for variables
inside of the string.

=back

=item B<Returns>: The appropriate string, with variables replaced.

=back

=item C<template_include_path>

Used by L<Bugzilla::Template> and L</install_string> to determine the
directories where templates are installed. Templates can be installed
in many places. They're listed here in the basic order that they're
searched:

=over

=item extensions/C<$extension>/template/C<$language>/C<$project>

=item extensions/C<$extension>/template/C<$language>/custom

=item extensions/C<$extension>/template/C<$language>/default

=item template/C<$language>/C<$project>

=item template/C<$language>/custom

=item template/C<$language>/default

=back

C<$project> has to do with installations that are using the C<$ENV{PROJECT}>
variable to have different "views" on a single Bugzilla.

The F<default> directory includes templates shipped with Bugzilla.

The F<custom> directory is a directory for local installations to override
the F<default> templates. Any individual template in F<custom> will
override a template of the same name and path in F<default>.

C<$language> is a language code, C<en> being the default language shipped
with Bugzilla. Localizers ship other languages.

C<$extension> is the name of any directory in the F<extensions/> directory.
Each extension has its own directory.

Note that languages are sorted by the user's preference (as specified
in their browser, usually), and extensions are sorted alphabetically.

=item C<vers_cmp>

=over

=item B<Description>

This is a comparison function, like you would use in C<sort>, except that
it compares two version numbers. So, for example, 2.10 would be greater
than 2.2.

It's based on versioncmp from L<Sort::Versions>, with some Bugzilla-specific
fixes.

=item B<Params>: C<$a> and C<$b> - The versions you want to compare.

=item B<Returns>

C<-1> if C<$a> is less than C<$b>, C<0> if they are equal, or C<1> if C<$a>
is greater than C<$b>.

=back

=back
