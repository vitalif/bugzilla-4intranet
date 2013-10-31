# Bugzilla4Intranet Extension engine
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

# See POD documentation at the end of file

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
our @EXPORT = qw(
    set_hook
    add_hook
    clear_hooks
    extension_info
    required_modules
    optional_modules
    extension_version
    extension_include
    extension_template_dir
    extension_code_dir
);

my $extensions = {
#   name => {
#       required_modules => [],
#       optional_modules => [],
#       version          => '',
#       loaded           => boolean,
#       inc              => [ 'path1', 'path2' ],
#   }
};

sub required_modules  { setter('required_modules', @_) }
sub optional_modules  { setter('optional_modules', @_) }
sub extension_version { setter('version', @_) }

sub extension_code_dir
{
    my ($name, $new) = @_;
    my $old = setter('code_dir', $name, $new);
    return $old || catfile(bz_locations()->{extensionsdir}, $name, 'code');
}

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
    return $old if !$new;
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

sub loaded
{
    return grep { $extensions->{$_}->{loaded} } keys %$extensions;
}

# Modifies @INC so that extensions can use modules like
# "use Bugzilla::Extension::Foo::Bar", when Bar.pm is in the lib/
# directory of the extension.
sub modify_inc {
    my ($class, $file) = @_;

    # Note that this package_dir call is necessary to set things up
    # for my_inc, even if we didn't take its return value.
    my $package_dir = __do_call($class, 'package_dir', $file);
    # Don't modify @INC for extensions that are just files in the extensions/
    # directory. We don't want Bugzilla's base lib/CGI.pm being loaded as 
    # Bugzilla::Extension::Foo::CGI or any other confusing thing like that.
    return if $package_dir eq bz_locations->{'extensionsdir'};
    unshift(@INC, sub { __do_call($class, 'my_inc', @_) });
}

sub extension_info
{
    shift if $_[0] eq __PACKAGE__ || ref $_[0];
    my ($name) = @_;
    return $extensions->{$name};
}

sub load_all
{
    shift if $_[0] && ($_[0] eq __PACKAGE__ || ref $_[0]);
    foreach (available())
    {
        load($_);
    }
}

####################
# Instance Methods #
####################

use constant enabled => 1;

sub lib_dir {
    my $invocant = shift;
    my $package_dir = __do_call($invocant, 'package_dir');
    # For extensions that are just files in the extensions/ directory,
    # use the base lib/ dir as our "lib_dir". Note that Bugzilla never
    # uses lib_dir in this case, though, because modify_inc is prevented
    # from modifying @INC when we're just a file in the extensions/ directory.
    # So this particular code block exists just to make lib_dir return
    # something right in case an extension needs it for some odd reason.
    if ($package_dir eq bz_locations()->{'extensionsdir'}) {
        return bz_locations->{'ext_libpath'};
    }
    return File::Spec->catdir($package_dir, 'lib');
}

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

Bugzilla::Extension - core of Bugzilla4Intranet Extension engine,
backwards-compatible with old pre-3.6 Bugzilla extension engine.

=head1 USAGE

Extension engine was refactored by Bugzilla authors in 3.6.
Their new version was incompatible with old extensions, had some
restrictions and was just VERY inconvenient to use.
So, in Bugzilla4Intranet 3.6, I've created my own extension engine.

=head2 Directory layout

All Bugzilla extensions must go into 'extensions' subdirectory.
The basic directory layout for an extension is as follows:

 extensions/
   <name>/
     <name>.pl   ---   Main extension file
     disabled    ---   Extension disabled if this file is present
     code/       ---   Directory with old-style (pre-3.6) hooks
       <hook_name>.pl
     lib/        ---   Extension library directory (with *.pm modules)
     template/   ---   Directory with extension templates and template hooks
       en/
         default/
           <template_path>/
             <template_filename>.tmpl
           hook/
             <template_path>/
               <template_filename>-<hook_name>.tmpl

=head2 Extension main

Main extension file sets extension version, required and optional Perl modules,
and can also set code hooks. It can be omitted if hooks are set using files
(see below), and there is no need for required_modules and optional_modules.

The file typically looks like:

    use strict;
    use Bugzilla;
    use Bugzilla::Extension;

    my $REQUIRED_MODULES = [];
    my $OPTIONAL_MODULES = [
        {
            package => 'Spreadsheet-ParseExcel',
            module  => 'Spreadsheet::ParseExcel',
            version => '0.54',
            feature => 'Import of binary Excel files (*.xls)',
        },
    ];

    required_modules('<extension name>', $REQUIRED_MODULES);
    optional_modules('<extension name>', $OPTIONAL_MODULES);
    extension_version('<extension name>', '1.02');

    clear_hooks('<extension name>');
    set_hook('<extension name>', '<hook name>', 'ExtensionPackage::sub_name');
    add_hook('<extension name>', '<hook name>', 'ExtensionPackage::other_sub_name');
    # other hooks...

    1;
    __END__

Note that main file must not 'use ExtensionPackage', just because the
extension library directory can be unknown at this point. Specify the
package name in a string, and it will be loaded automatically.

=head2 Hooks

A hook is a place in the code into which other code parts can be inserted.
In Bugzilla, there are code hooks and template hooks.
Extensions should use hooks for extending the functionality. The best
is if you use predefined hooks, but you can also add your own and publish
the patch which adds this hooks somewhere on L<http://wiki.4intra.net/>.

Hook functions always get arguments through single hashref parameter ($args).
Their return value is always a boolean value: when it's TRUE, other hooks
(set after this) are also called. When a hook returns FALSE, hook processing
is stopped.

set_hook($extension, $hook_name, $callable) resets $extension's $hook_name to
$callable. add_hook(...) does not reset, but adds an additional hook with the
same name. Try to use set_hook() as much as you can, because it allows for
correct run-time extension reloading support.

Code hooks can be also set using single files inside the extension code
directory, just as it was before Bugzilla 3.6. Such files must 'use Bugzilla'
and get arguments through 'Bugzilla->hook_args'. They also don't need to
return anything - Bugzilla thinks that they always "return true".

You can get the list of all available hooks using grep on Bugzilla code:

    grep -r Bugzilla::Hook::process *.cgi *.pl *.pm Bugzilla/ extensions/

You can also see the list of documented hooks in F<Bugzilla::Hook>.

=head2 Template hooks

Template hooks are just evaluated in the place of corresponding hook call.

You can get the list of all available template hooks using grep:

    grep -r Hook.process template/ extensions/

=head1 METHODS FOR EXTENSIONS

First of all, add

    use Bugzilla::Extension;

to the top of your extension's main file to use these methods.

=head2 $arrayref = required_modules([$new_arrayref]) / optional_modules()

Getters/setters for REQUIRED_MODULES and OPTIONAL_MODULES. Perl modules
specified here are checked by checksetup.pl during installation.
If some of required modules are missing, the installation is aborted.
If some of optional modules are missing, there is a warning.

The format of this arrayref is:

    [ {
        package => 'Text-CSV',
        module  => 'Text::CSV',
        version => '1.06',
        feature => 'CSV Importing of test cases'
      }, ... ]

=head2 $version = extension_version([$new_version])

Getter/setter for extension version.

=head2 $dir = extension_code_dir([$new_code_dir])

Getter/setter for extension code directory, i.e. directory which contains
individual hook .pl files, as it was old Bugzillas (< 3.6).

Default value for code directory is "extensions/<name>/code/".

=head2 $dir = extension_template_dir([$new_template_dir])

Getter/setter for extension template directory. Templates from this directory
will override Bugzilla's built-in ones.

Default value for template directory is "extensions/<name>/template/".

=head1 METHODS FOR BUGZILLA (INTERNAL USAGE)

=head2 @list = Bugzilla::Extension::available()

List all available extension names

=head2 @list = Bugzilla::Extension::loaded()

List all loaded extensions

=head2 $hashref = Bugzilla::Extension::extension_info()

Get extension information hashref

=head2 Bugzilla::Extension::load_all()

Loads all enabled extensions installed into Bugzilla.

=head2 Bugzilla::Extension::load($name)

Load one extension named $name.

=head1 SEE ALSO

F<Bugzilla::Hook>
