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
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Zach Lipton <zach@zachlipton.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Hook;

use strict;
no strict 'refs';
use Bugzilla::Util;
use base 'Exporter';
our @EXPORT = qw(set_hook add_hook run_hooks clear_hooks);

my %hooks;
my @hook_stack;
my %hook_hash;

# Set extension hook or hooks
# The idea is to allow reloading main extension file:
# If there is more than one hook in one extension,
#  call set_hook to set first of them and add_hook to set others.
# So, if main extension file is occasionally reloaded in runtime,
#  the hook list would be correctly overwritten.
sub set_hook
{
    my ($extension, $hook, $callable) = @_;
    die "set_hook($extension, $hook, undef) called" if !$callable;
    $hook =~ tr/-/_/;
    $hooks{$hook}{$extension} = $callable;
}

# Clear all extension's hooks
sub clear_hooks
{
    my ($extension) = @_;
    delete $_->{$extension} for values %hooks;
}

# Add extension hook or hooks
sub add_hook
{
    my ($extension, $hook, $callable) = @_;
    die "add_hook($extension, $hook, undef) called" if !$callable;
    $hook =~ tr/-/_/;
    if (!$hooks{$hook}{$extension})
    {
        $hooks{$hook}{$extension} = $callable;
    }
    else
    {
        if (ref $hooks{$hook}{$extension} ne 'ARRAY')
        {
            $hooks{$hook}{$extension} = [ $hooks{$hook}{$extension} ];
        }
        $callable = [ $callable ] if ref $callable ne 'ARRAY';
        push @{$hooks{$hook}{$extension}}, @$callable;
    }
}

# An alias
sub run_hooks
{
    goto &process;
}

# Process all hooks with name $name
sub process
{
    my ($name, $args) = @_;
    $name =~ tr/-/_/;

    push @hook_stack, $name;
    $hook_hash{$name}++;

    my @process = values %{$hooks{$name}};
    for my $f (@process)
    {
        if (!defined $f)
        {
            next;
        }
        elsif (ref $f eq 'ARRAY')
        {
            push @process, @$f;
            next;
        }
        elsif (ref $f eq 'CODE')
        {
            # Fall through if()
        }
        elsif (!ref $f && $f =~ /^(.*)::[^:]*$/)
        {
            my $pk = $1 . '.pm';
            $pk =~ s/::/\//gso;
            if ($pk)
            {
                eval { require $pk };
                if ($@)
                {
                    die __PACKAGE__."::process(): Error autoloading hook package $pk: $@";
                    next;
                }
            }
        }
        elsif (ref $f eq 'HASH' && $f->{type} eq 'file' &&
            open my $fd, $f->{filename})
        {
            # Slurp file content into $hook_sub
            my $sub;
            {
                local $/ = undef;
                $sub = <$fd>;
                trick_taint($sub);
            }
            close $fd;
            $sub =~ s/Bugzilla->hook_args/\$args/gso;
            my $pk = $f->{filename};
            $pk =~ s/\W+/_/gso;
            $pk = "Bugzilla::Hook::$pk";
            $sub = eval "package $pk; sub { my (\$args) = \@_;\n#line 1 \"$f->{filename}\"\n$sub; return 1; };";
            if ($@)
            {
                die __PACKAGE__."::process(): error during loading $f->{filename} into a subroutine (note that Bugzilla->hook_args was replaced by \$args): $@";
                next;
            }
            $f = $sub;
        }
        else
        {
            die "Don't know what to do with hook callable \"$f\". Is it really callable?";
        }
        # OK, call the function!
        # When a hook returns TRUE, other hooks are also called
        # When a hook returns FALSE, hook processing is stopped
        &$f($args) || last;
    }

    $hook_hash{$name}--;
    pop @hook_stack;
}

sub in
{
    my $hook_name = shift;
    return $hook_hash{$hook_name} || 0;
}

1;

__END__

=head1 NAME

Bugzilla::Hook - Extendable extension hooks for Bugzilla code

=head1 SYNOPSIS

 use Bugzilla::Hook;

 Bugzilla::Hook::process("hookname", { arg => $value, arg2 => $value2 });

=head1 DESCRIPTION

Bugzilla allows extension modules to drop in and add routines at 
arbitrary points in Bugzilla code. These points are referred to as
hooks. When a piece of standard Bugzilla code wants to allow an extension
to perform additional functions, it uses Bugzilla::Hook's L</process>
subroutine to invoke any extension code if installed. 

The implementation of extensions is described in L<Bugzilla::Extension>.

There is sample code for every hook in the Example extension, located in
F<extensions/Example/Extension.pm>.

=head2 How Hooks Work

When a hook named C<HOOK_NAME> is run, Bugzilla looks through all
enabled L<extensions|Bugzilla::Extension> for extensions that implement
a subroutine named C<HOOK_NAME>.

See L<Bugzilla::Extension> for more details about how an extension
can run code during a hook.

=head1 SUBROUTINES

=over

=item C<process>

=over

=item B<Description>

Invoke any code hooks with a matching name from any installed extensions.

See L<Bugzilla::Extension> for more information on Bugzilla's extension
mechanism.

=item B<Params>

=over

=item C<$name> - The name of the hook to invoke.

=item C<$args> - A hashref. The named args to pass to the hook. 
They will be passed as arguments to the hook method in the extension.

=back

=item B<Returns> (nothing)

=back

=back

=head1 HOOKS

This describes what hooks exist in Bugzilla currently. They are mostly
in alphabetical order, but some related hooks are near each other instead
of being alphabetical.

=head2 attachment_process_data

This happens at the very beginning process of the attachment creation.
You can edit the attachment content itself as well as all attributes
of the attachment, before they are validated and inserted into the DB.

Params:

=over

=item C<data> - A reference pointing either to the content of the file
being uploaded or pointing to the filehandle associated with the file.

=item C<attributes> - A hashref whose keys are the same as the input to
L<Bugzilla::Attachment/create>. The data in this hashref hasn't been validated
yet.

=back

=head2 auth_login_methods

This allows you to add new login types to Bugzilla.
(See L<Bugzilla::Auth::Login>.)

Params:

=over

=item C<modules>

This is a hash--a mapping from login-type "names" to the actual module on
disk. The keys will be all the values that were passed to 
L<Bugzilla::Auth/login> for the C<Login> parameter. The values are the
actual path to the module on disk. (For example, if the key is C<DB>, the
value is F<Bugzilla/Auth/Login/DB.pm>.)

For your extension, the path will start with 
F<Bugzilla/Extension/Foo/>, where "Foo" is the name of your Extension. 
(See the code in the example extension.)

If your login type is in the hash as a key, you should set that key to the
right path to your module. That module's C<new> method will be called,
probably with empty parameters. If your login type is I<not> in the hash,
you should not set it.

You will be prevented from adding new keys to the hash, so make sure your
key is in there before you modify it. (In other words, you can't add in
login methods that weren't passed to L<Bugzilla::Auth/login>.)

=back

=head2 auth_verify_methods

This works just like L</auth_login_methods> except it's for
login verification methods (See L<Bugzilla::Auth::Verify>.) It also
takes a C<modules> parameter, just like L</auth_login_methods>.

=head2 bug_columns

This allows you to add new fields that will show up in every L<Bugzilla::Bug>
object. Note that you will also need to use the L</bug_fields> hook in
conjunction with this hook to make this work.

Params:

=over

=item C<columns> - An arrayref containing an array of column names. Push
your column name(s) onto the array.

=back

=head2 bug_end_of_create

This happens at the end of L<Bugzilla::Bug/create>, after all other changes are
made to the database. This occurs inside a database transaction.

Params:

=over

=item C<bug> - The created bug object.

=item C<timestamp> - The timestamp used for all updates in this transaction,
as a SQL date string.

=back

=head2 bug_end_of_create_validators

This happens during L<Bugzilla::Bug/create>, after all parameters have
been validated, but before anything has been inserted into the database.

Params:

=over

=item C<params>

A hashref. The validated parameters passed to C<create>.

=back

=head2 bug_end_of_update

This happens at the end of L<Bugzilla::Bug/update>, after all other changes are
made to the database. This generally occurs inside a database transaction.

Params:

=over

=item C<bug> 

The changed bug object, with all fields set to their updated values.

=item C<old_bug>

A bug object pulled from the database before the fields were set to
their updated values (so it has the old values available for each field).

=item C<timestamp> 

The timestamp used for all updates in this transaction, as a SQL date
string.

=item C<changes> 

The hash of changed fields. C<< $changes->{field} = [old, new] >>

=back

=head2 bug_fields

Allows the addition of database fields from the bugs table to the standard
list of allowable fields in a L<Bugzilla::Bug> object, so that
you can call the field as a method.

Note: You should add here the names of any fields you added in L</bug_columns>.

Params:

=over

=item C<columns> - A arrayref containing an array of column names. Push
your column name(s) onto the array.

=back

=head2 bug_format_comment

Allows you to do custom parsing on comments before they are displayed. You do
this by returning two regular expressions: one that matches the section you
want to replace, and then another that says what you want to replace that
match with.

The matching and replacement will be run with the C</g> switch on the regex.

Params:

=over

=item C<regexes>

An arrayref of hashrefs.

You should push a hashref containing two keys (C<match> and C<replace>)
in to this array. C<match> is the regular expression that matches the
text you want to replace, C<replace> is what you want to replace that
text with. (This gets passed into a regular expression like 
C<s/$match/$replace/>.)

Instead of specifying a regular expression for C<replace> you can also
return a coderef (a reference to a subroutine). If you want to use
backreferences (using C<$1>, C<$2>, etc. in your C<replace>), you have to use
this method--it won't work if you specify C<$1>, C<$2> in a regular expression
for C<replace>. Your subroutine will get a hashref as its only argument. This
hashref contains a single key, C<matches>. C<matches> is an arrayref that
contains C<$1>, C<$2>, C<$3>, etc. in order, up to C<$10>. Your subroutine
should return what you want to replace the full C<match> with. (See the code
example for this hook if you want to see how this actually all works in code.
It's simpler than it sounds.)

B<You are responsible for HTML-escaping your returned data.> Failing to
do so could open a security hole in Bugzilla.

=item C<text>

A B<reference> to the exact text that you are parsing.

Generally you should not modify this yourself. Instead you should be 
returning regular expressions using the C<regexes> array.

The text has not been parsed in any way. (So, for example, it is not
HTML-escaped. You get "&", not "&amp;".)

=item C<bug>

The L<Bugzilla::Bug> object that this comment is on. Sometimes this is
C<undef>, meaning that we are parsing text that is not on a bug.

=item C<comment>

A L<Bugzilla::Comment> object representing the comment you are about to
parse.

Sometimes this is C<undef>, meaning that we are parsing text that is
not a bug comment (but could still be some other part of a bug, like
the summary line).

=back

=head2 buglist_columns

This happens in L<Bugzilla::Search/COLUMNS>, which determines legal bug
list columns for F<buglist.cgi> and F<colchange.cgi>. It gives you the
opportunity to add additional display columns.

Params:

=over

=item C<columns> - A hashref, where the keys are unique string identifiers
for the column being defined and the values are hashrefs with the
following fields:

=over

=item C<name> - The name of the column in the database.

=item C<title> - The title of the column as displayed to users.

=back

The definition is structured as:

 $columns->{$id} = { name => $name, title => $title };

=back

=head2 bugmail_recipients

This allows you to modify the list of users who are going to be receiving
a particular bugmail. It also allows you to specify why they are receiving
the bugmail.

Users' bugmail preferences will be applied to any users that you add
to the list. (So, for example, if you add somebody as though they were
a CC on the bug, and their preferences state that they don't get email
when they are a CC, they won't get email.)

This hook is called before watchers or globalwatchers are added to the
recipient list.

Params:

=over

=item C<bug>

The L<Bugzilla::Bug> that bugmail is being sent about.

=item C<recipients>

This is a hashref. The keys are numeric user ids from the C<profiles>
table in the database, for each user who should be receiving this bugmail.
The values are hashrefs. The keys in I<these> hashrefs correspond to
the "relationship" that the user has to the bug they're being emailed
about, and the value should always be C<1>. The "relationships"
are described by the various C<REL_> constants in L<Bugzilla::Constants>.

Here's an example of adding userid C<123> to the recipient list
as though he were on the CC list:

 $recipients->{123}->{+REL_CC} = 1

(We use C<+> in front of C<REL_CC> so that Perl interprets it as a constant
instead of as a string.)

=back


=head2 colchange_columns

This happens in F<colchange.cgi> right after the list of possible display
columns have been defined and gives you the opportunity to add additional
display columns to the list of selectable columns.

Params:

=over

=item C<columns> - An arrayref containing an array of column IDs.  Any IDs
added by this hook must have been defined in the the L</buglist_columns> hook.

=back

=head2 config_add_panels

If you want to add new panels to the Parameters administrative interface,
this is where you do it.

Params:

=over

=item C<panel_modules>

A hashref, where the keys are the "name" of the panel and the value
is the Perl module representing that panel. For example, if
the name is C<Auth>, the value would be C<Bugzilla::Config::Auth>.

For your extension, the Perl module would start with 
C<Bugzilla::Extension::Foo>, where "Foo" is the name of your Extension.
(See the code in the example extension.)

=back

=head2 config_modify_panels

This is how you modify already-existing panels in the Parameters
administrative interface. For example, if you wanted to add a new
Auth method (modifying Bugzilla::Config::Auth) this is how you'd
do it.

Params:

=over

=item C<panels>

A hashref, where the keys are lower-case panel "names" (like C<auth>, 
C<admin>, etc.) and the values are hashrefs. The hashref contains a
single key, C<params>. C<params> is an arrayref--the return value from
C<get_param_list> for that module. You can modify C<params> and
your changes will be reflected in the interface.

Adding new keys to C<panels> will have no effect. You should use
L</config_add_panels> if you want to add new panels.

=back

=head2 email_in_before_parse

This happens right after an inbound email is converted into an Email::MIME
object, but before we start parsing the email to extract field data. This
means the email has already been decoded for you. It gives you a chance
to interact with the email itself before L<email_in> starts parsing its content.

=over

=item C<mail> - An Email::MIME object. The decoded incoming email.

=item C<fields> - A hashref. The hash which will contain extracted data.

=back

=head2 email_in_after_parse

This happens after all the data has been extracted from the email, but before
the reporter is validated, during L<email_in>. This lets you do things after
the normal parsing of the email, such as sanitizing field data, changing the
user account being used to file a bug, etc.

=over

=item C<fields> - A hashref. The hash containing the extracted field data.

=back

=head2 enter_bug_entrydefaultvars

B<DEPRECATED> - Use L</template_before_process> instead.

This happens right before the template is loaded on enter_bug.cgi.

Params:

=over

=item C<vars> - A hashref. The variables that will be passed into the template.

=back

=head2 flag_end_of_update

This happens at the end of L<Bugzilla::Flag/update_flags>, after all other
changes are made to the database and after emails are sent. It gives you a
before/after snapshot of flags so you can react to specific flag changes.
This generally occurs inside a database transaction.

Note that the interface to this hook is B<UNSTABLE> and it may change in the
future.

Params:

=over

=item C<object> - The changed bug or attachment object.

=item C<timestamp> - The timestamp used for all updates in this transaction,
as a SQL date string.

=item C<old_flags> - The snapshot of flag summaries from before the change.

=item C<new_flags> - The snapshot of flag summaries after the change. Call
C<my ($removed, $added) = diff_arrays(old_flags, new_flags)> to get the list of
changed flags, and search for a specific condition like C<added eq 'review-'>.

=back

=head2 group_before_delete

This happens in L<Bugzilla::Group/remove_from_db>, after we've confirmed
that the group can be deleted, but before any rows have actually
been removed from the database. This occurs inside a database
transaction.

Params:

=over

=item C<group> - The L<Bugzilla::Group> being deleted.

=back

=head2 group_end_of_create

This happens at the end of L<Bugzilla::Group/create>, after all other
changes are made to the database. This occurs inside a database transaction.

Params:

=over

=item C<group> 

The new L<Bugzilla::Group> object that was just created.

=back

=head2 group_end_of_update

This happens at the end of L<Bugzilla::Group/update>, after all other 
changes are made to the database. This occurs inside a database transaction.

Params:

=over

=item C<group> - The changed L<Bugzilla::Group> object, with all fields set 
to their updated values.

=item C<changes> - The hash of changed fields. 
C<< $changes->{$field} = [$old, $new] >>

=back

=head2 install_before_final_checks

Allows execution of custom code before the final checks are done in 
checksetup.pl.

Params:

=over

=item C<silent>

A flag that indicates whether or not checksetup is running in silent mode.
If this is true, messages that are I<always> printed by checksetup.pl should be
suppressed, but messages about any changes that are just being done this one
time should be printed.

=back

=head2 install_update_db

This happens at the very end of all the tables being updated
during an installation or upgrade. If you need to modify your custom
schema or add new columns to existing tables, do it here. No params are
passed.

=head2 db_schema_abstract_schema

This allows you to add tables to Bugzilla. Note that we recommend that you 
prefix the names of your tables with some word (preferably the name of
your Extension), so that they don't conflict with any future Bugzilla tables.

If you wish to add new I<columns> to existing Bugzilla tables, do that
in L</install_update_db>.

Params:

=over

=item C<schema> - A hashref, in the format of 
L<Bugzilla::DB::Schema/ABSTRACT_SCHEMA>. Add new hash keys to make new table
definitions. F<checksetup.pl> will automatically add these tables to the
database when run.

=back

=head2 mailer_before_send

Called right before L<Bugzilla::Mailer> sends a message to the MTA.

Params:

=over

=item C<email> - The C<Email::MIME> object that's about to be sent.

=item C<mailer_args> - An arrayref that's passed as C<mailer_args> to
L<Email::Sender::Transport::XX/new>.

=back

=head2 object_before_create

This happens at the beginning of L<Bugzilla::Object/create>.

Params:

=over

=item C<class>

The name of the class that C<create> was called on. You can check this 
like C<< if ($class->isa('Some::Class')) >> in your code, to perform specific
tasks before C<create> for only certain classes.

=item C<params>

A hashref. The set of named parameters passed to C<create>.

=back


=head2 object_before_delete

This happens in L<Bugzilla::Object/remove_from_db>, after we've confirmed
that the object can be deleted, but before any rows have actually
been removed from the database. This sometimes occurs inside a database
transaction.

Params:

=over

=item C<object> - The L<Bugzilla::Object> being deleted. You will probably
want to check its type like C<< $object->isa('Some::Class') >> before doing
anything with it.

=back


=head2 object_before_set

Called during L<Bugzilla::Object/set>, before any actual work is done.
You can use this to perform actions before a value is changed for
specific fields on certain types of objects.

Params:

=over

=item C<object>

The object that C<set> was called on. You will probably want to
do something like C<< if ($object->isa('Some::Class')) >> in your code to
limit your changes to only certain subclasses of Bugzilla::Object.

=item C<field>

The name of the field being updated in the object.

=item C<value> 

The value being set on the object.

=back

=head2 object_end_of_create

Called at the end of L<Bugzilla::Object/create>, after all other changes are
made to the database. This occurs inside a database transaction.

Params:

=over

=item C<class>

The name of the class that C<create> was called on. You can check this 
like C<< if ($class->isa('Some::Class')) >> in your code, to perform specific
tasks for only certain classes.

=item C<object>

The created object.

=back

=head2 object_end_of_create_validators

Called at the end of L<Bugzilla::Object/run_create_validators>. You can
use this to run additional validation when creating an object.

If a subclass has overridden C<run_create_validators>, then this usually
happens I<before> the subclass does its custom validation.

Params:

=over

=item C<class>

The name of the class that C<create> was called on. You can check this 
like C<< if ($class->isa('Some::Class')) >> in your code, to perform specific
tasks for only certain classes.

=item C<params>

A hashref. The set of named parameters passed to C<create>, modified and
validated by the C<VALIDATORS> specified for the object.

=back


=head2 object_end_of_set

Called during L<Bugzilla::Object/set>, after all the code of the function
has completed (so the value has been validated and the field has been set
to the new value). You can use this to perform actions after a value is
changed for specific fields on certain types of objects.

The new value is not specifically passed to this hook because you can
get it as C<< $object->{$field} >>.

Params:

=over

=item C<object>

The object that C<set> was called on. You will probably want to
do something like C<< if ($object->isa('Some::Class')) >> in your code to
limit your changes to only certain subclasses of Bugzilla::Object.

=item C<field>

The name of the field that was updated in the object.

=back


=head2 object_end_of_set_all

This happens at the end of L<Bugzilla::Object/set_all>. This is a
good place to call custom set_ functions on objects, or to make changes
to an object before C<update()> is called.

Params:

=over

=item C<object>

The L<Bugzilla::Object> which is being updated. You will probably want to
do something like C<< if ($object->isa('Some::Class')) >> in your code to
limit your changes to only certain subclasses of Bugzilla::Object.

=item C<params>

A hashref. The set of named parameters passed to C<set_all>.

=back

=head2 object_end_of_update

Called during L<Bugzilla::Object/update>, after changes are made
to the database, but while still inside a transaction.

Params:

=over

=item C<object>

The object that C<update> was called on. You will probably want to
do something like C<< if ($object->isa('Some::Class')) >> in your code to
limit your changes to only certain subclasses of Bugzilla::Object.

=item C<old_object>

The object as it was before it was updated.

=item C<changes>

The fields that have been changed, in the same format that
L<Bugzilla::Object/update> returns.

=back

=head2 page_before_template

This is a simple way to add your own pages to Bugzilla. This hooks C<page.cgi>,
which loads templates from F<template/en/default/pages>. For example,
C<page.cgi?id=fields.html> loads F<template/en/default/pages/fields.html.tmpl>.

This hook is called right before the template is loaded, so that you can
pass your own variables to your own pages.

You can also use this to implement complex custom pages, by doing your own
output and then calling  C<exit> at the end of the hook, thus preventing
the normal C<page.cgi> behavior from occurring.

Params:

=over

=item C<page_id>

This is the name of the page being loaded, like C<fields.html>.

Note that if two extensions use the same name, it is uncertain which will
override the others, so you should be careful with how you name your pages.
Usually extensions prefix their pages with a directory named after their
extension, so for an extension named "Foo", page ids usually look like
C<foo/mypage.html>.

=item C<vars>

This is a hashref--put variables into here if you want them passed to
your template.

=back

=head2 product_confirm_delete

B<DEPRECATED> - Use L</template_before_process> instead.

Called before displaying the confirmation message when deleting a product.

Params:

=over

=item C<vars> - The template vars hashref.

=back

=head2 sanitycheck_check

This hook allows for extra sanity checks to be added, for use by
F<sanitycheck.cgi>.

Params:

=over

=item C<status> - a CODEREF that allows status messages to be displayed
to the user. (F<sanitycheck.cgi>'s C<Status>)

=back

=head2 product_end_of_create

Called right after a new product has been created, allowing additional
changes to be made to the new product's attributes. This occurs inside of
a database transaction, so if the hook throws an error, all previous
changes will be rolled back, including the creation of the new product.
(However, note that such rollbacks should not normally be used, as
some databases that Bugzilla supports have very bad rollback performance.
If you want to validate input and throw errors before the Product is created,
use L</object_end_of_create_validators> instead.)

Params:

=over

=item C<product> - The new L<Bugzilla::Product> object that was just created.

=back

=head2 sanitycheck_repair

This hook allows for extra sanity check repairs to be made, for use by
F<sanitycheck.cgi>.

Params:

=over

=item C<status> - a CODEREF that allows status messages to be displayed
to the user. (F<sanitycheck.cgi>'s C<Status>)

=back

=head2 template_before_create

This hook allows you to modify the configuration of L<Bugzilla::Template>
objects before they are created. For example, you could add a new
global template variable this way.

Params:

=over

=item C<config>

A hashref--the configuration that will be passed to L<Template/new>.
See L<http://template-toolkit.org/docs/modules/Template.html#section_CONFIGURATION_SUMMARY>
for information on how this configuration variable is structured (or just
look at the code for C<create> in L<Bugzilla::Template>.)

=back

=head2 template_before_process

This hook is called any time Bugzilla processes a template file, including
calls to C<< $template->process >>, C<PROCESS> statements in templates,
and C<INCLUDE> statements in templates. It is not called when templates
process a C<BLOCK>, only when they process a file.

This hook allows you to define additional variables that will be available to
the template being processed, or to modify the variables that are currently
in the template. It works exactly as though you inserted code to modify
template variables at the top of a template.

You probably want to restrict this hook to operating only if a certain 
file is being processed (which is why you get a C<file> argument
below). Otherwise, modifying the C<vars> argument will affect every single
template in Bugzilla.

B<Note:> This hook is not called if you are already in this hook.
(That is, it won't call itself recursively.) This prevents infinite
recursion in situations where this hook needs to process a template
(such as if this hook throws an error).

Params:

=over

=item C<vars>

This is the entire set of variables that the current template can see.
Technically, this is a L<Template::Stash> object, but you can just
use it like a hashref if you want.

=item C<file>

The name of the template file being processed. This is relative to the
main template directory for the language (i.e. for
F<template/en/default/bug/show.html.tmpl>, this variable will contain
C<bug/show.html.tmpl>).

=item C<context>

A L<Template::Context> object. Usually you will not have to use this, but
if you need information about the template itself (other than just its
name), you can get it from here.

=back

=head2 webservice

This hook allows you to add your own modules to the WebService. (See
L<Bugzilla::WebService>.)

Params:

=over

=item C<dispatch>

A hashref where you can specify the names of your modules and which Perl
module handles the functions for that module. (This is actually sent to 
L<SOAP::Lite/dispatch_with>. You can see how that's used in F<xmlrpc.cgi>.)

The Perl module name will most likely start with C<Bugzilla::Extension::Foo::>
(where "Foo" is the name of your extension).

Example:

  $dispatch->{'Example.Blah'} = "Bugzilla::Extension::Example::Webservice::Blah";

And then you'd have a module F<extensions/Example/lib/Webservice/Blah.pm>,
and could call methods from that module like C<Example.Blah.Foo()> using
the WebServices interface.

It's recommended that all the keys you put in C<dispatch> start with the
name of your extension, so that you don't conflict with the standard Bugzilla
WebService functions (and so that you also don't conflict with other
plugins).

=back

=head2 webservice_error_codes

If your webservice extension throws custom errors, you can set numeric
codes for those errors here.

Extensions should use error codes above 10000, unless they are re-using
an already-existing error code.

Params:

=over

=item C<error_map>

A hash that maps the names of errors (like C<invalid_param>) to numbers.
See L<Bugzilla::WebService::Constants/WS_ERROR_CODE> for an example.

=back

=head1 SEE ALSO

L<Bugzilla::Extension>
