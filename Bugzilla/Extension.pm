# -*- Mode: perl; indent-tabs-mode: nil -*-
#
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
# The Initial Developer of the Original Code is Everything Solved, Inc.
# Portions created by the Initial Developers are Copyright (C) 2009 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Extension;

use strict;

# Don't use any more Bugzilla modules here as Bugzilla::Extension
# could be used outside of normal running Bugzilla installation
# (i.e. in checksetup.pl)

use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Hook;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec::Functions;

use base 'Exporter';
our @EXPORT = qw(extension_info required_modules optional_modules extension_version extension_include extension_template_dir extension_code_dir set_hook);

my $extensions = {
#   name => {
#       required_modules => [],
#       optional_modules => [],
#       version          => '',
#       loaded           => boolean,
#       inc              => [ 'path1', 'path2' ],
#   }
};

# List all available extension names
sub available
{
    my $dir = bz_locations()->{extensionsdir};
    my @extension_items = glob(catfile($dir, '*'));
    my @r;
    foreach my $item (@extension_items)
    {
        my $basename = basename($item);
        # Skip CVS directories and any hidden files/dirs.
        next if $basename eq 'CVS' or $basename =~ /^\./;
        if (-d $item)
        {
            if (!-e catfile($item, "disabled"))
            {
                trick_taint($basename);
                push @r, $basename;
            }
        }
    }
    return @r;
}

# List all loaded extensions
sub loaded
{
    return grep { $extensions->{$_}->{loaded} } keys %$extensions;
}

# Get extensions information hashref
sub extension_info
{
    shift if $_[0] eq __PACKAGE__ || ref $_[0];
    my ($name) = @_;
    return $extensions->{$name};
}

# Getters/setters for REQUIRED_MODULES, OPTIONAL_MODULES and version
sub required_modules  { setter('required_modules', @_) }
sub optional_modules  { setter('optional_modules', @_) }
sub extension_version { setter('version', @_) }

# Getter/setter for extension code directory (for old extension system)
sub extension_code_dir
{
    my ($name, $new) = @_;
    my $old = setter('code_dir', $name, $new);
    return $old || catfile(bz_locations()->{extensionsdir}, $name, 'code');
}

# Getter/setter for extension template directory
sub extension_template_dir
{
    my ($name, $new) = @_;
    my $old = setter('template_dir', $name, $new);
    return $old || catfile(bz_locations()->{extensionsdir}, $name, 'template');
}

# Getter/setter for extension include path (@INC)
sub extension_include
{
    my ($name, $new) = @_;
    if ($new)
    {
        if (ref $new && $new !~ /ARRAY/)
        {
            die __PACKAGE__."::extension_include('$name', '$new'): second argument should be an arrayref";
        }
        $new = [ $new ] if !ref $new;
        $new = [ map { abs_path($_) } @$new ];
        trick_taint($_) for @$new;
    }
    my $old = setter('inc', $name, $new);
    # update @INC
    my $oh = { map { $_ => 1 } @$old };
    for (my $i = $#INC; $i >= 0; $i--)
    {
        splice @INC, $i, 1 if $oh->{$INC[$i]};
    }
    unshift @INC, @$new if $new;
    return $old;
}

# Generic getter/setter
sub setter
{
    my ($key, $name, $value) = @_;
    $extensions->{$name} ||= {};
    my $old = $extensions->{$name}->{$key};
    $extensions->{$name}->{$key} = $value if defined $value;
    return $old;
}

# Load all available extensions
sub load_all
{
    shift if $_[0] && ($_[0] eq __PACKAGE__ || ref $_[0]);
    foreach (available())
    {
        load($_);
    }
}

# Load one extension
sub load
{
    my ($name) = @_;
    if ($extensions->{$name} && $extensions->{$name}->{loaded})
    {
        # Extension is already loaded
        return;
    }

    my $dir = bz_locations()->{extensionsdir};
    # Add default include path
    extension_include($name, catfile($dir, $name, 'lib'));

    # Load main extension file
    my $file = catfile($dir, $name, "$name.pl");
    if (-e $file)
    {
        trick_taint($file);
        require $file;
    }

    # Support for old extension system
    my $code_dir = extension_code_dir($name);
    if (-d $code_dir)
    {
        my @hooks = glob(catfile($code_dir, '*.pl'));
        my ($hook, $hook_sub);
        foreach my $filename (@hooks)
        {
            trick_taint($filename);
            $hook = basename($filename);
            $hook =~ s/\.pl$//so;
            if (!-r $filename)
            {
                warn __PACKAGE__."::load(): can't read $filename, skipping";
                next;
            }
            set_hook($name, $hook, { type => 'file', filename => $filename });
        }
    }

    $extensions->{$name}->{loaded} = 1;
}

1;

__END__

=head1 NAME

Bugzilla::Extension - Base class for Bugzilla Extensions.

=head1 BUGZILLA::EXTENSION CLASS METHODS

These are used internally by Bugzilla to load and set up extensions.
If you are an extension author, you don't need to care about these.

=head2 C<load>

Takes two arguments, the path to F<Extension.pm> and the path to F<Config.pm>,
for an extension. Loads the extension's code packages into memory using
C<require>, does some sanity-checking on the extension, and returns the
package name of the loaded extension.

=head2 C<load_all>

Calls L</load> for every enabled extension installed into Bugzilla,
and returns an arrayref of all the package names that were loaded.
