#!/usr/bin/perl -wT
# Simple CRUD interface for generic object types
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Token;

# require the user to have logged in
Bugzilla->login(LOGIN_REQUIRED);

my $template = Bugzilla->template;
my $ARGS     = Bugzilla->input_params;
my $vars     = {};

Bugzilla->user->in_group('editvalues')
|| $ARGS->{class} eq 'keyword' && Bugzilla->user->in_group('editkeywords')
|| ThrowUserError('auth_failure', {
    group  => 'editvalues',
    action => 'edit',
    object => 'field_values',
});

my $action = trim($ARGS->{action} || '');
my $token  = $ARGS->{token};

# Object classes listed here must not be edited from this interface.
my %block_list = map { $_ => 1 } qw(
    bug attachment comment user group flagtype flag
    classification product component
);

if (!$ARGS->{class})
{
    my @classes = grep { !$block_list{$_->name} } Bugzilla::Class->get_all;
    $vars->{classes} = \@classes;
    $template->process("admin/fieldvalues/select-field.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

my $class = Bugzilla->get_class($ARGS->{class});
if (!$class)
{
    ThrowUserError('class_invalid', { class => $ARGS->{class} });
}
if ($block_list{$class->name})
{
    ThrowUserError('class_blocked', { class => $ARGS->{class} });
}

my $obj = $class->type->new(int($ARGS->{id} || 0) || undef);
if ($class->name eq 'version' || $class->name eq 'milestone')
{
    $vars->{product} = $obj->id ? $obj->product : ($ARGS->{product_id} ? Bugzilla::Product->new($ARGS->{product_id}) : $ARGS->{product});
    if (!$vars->{product})
    {
        $vars->{product} = Bugzilla::Product->choose_product(Bugzilla->user->get_editable_products, { class => $class->name });
    }
    else
    {
        $vars->{product} = Bugzilla->user->check_can_admin_product($vars->{product});
    }
    delete $ARGS->{product};
    delete $ARGS->{product_id};
}

if ($action eq 'save' || $action eq 'delete')
{
    check_token_data($token, $action.'_object');
    $obj ||= $class->type->new;
    my $changes;
    if ($action eq 'delete')
    {
        $obj->remove_from_db;
    }
    else
    {
        $obj->set_all({
            map { $_->name => $ARGS->{$_->name} }
            grep { defined $ARGS->{$_->name} || $_->type == FIELD_TYPE_BOOLEAN }
            Bugzilla->get_fields({ class_id => $class->id, obsolete => 0 })
        });
        $changes = $obj->update;
        for my $f (Bugzilla->get_class_fields({ value_class_id => $class->id }))
        {
            if ($ARGS->{'defined_visibility_value_id_'.$f->id} &&
                ($f->name ne 'target_milestone' && $f->name ne 'version' || $f->class->name != 'bug'))
            {
                $changes->{_visibility_values} = 1 if $f->update_visibility_values($obj->id, [ list $ARGS->{'visibility_value_id_'.$f->id} ]);
            }
            $changes->{_control_lists} = 1 if $f->update_control_lists($obj->id, $ARGS);
        }
    }
    delete_token($token);
    Bugzilla->add_result_message({
        message => $action eq 'delete' ? 'object_deleted' : ($ARGS->{id} ? 'object_updated' : 'object_created'),
        class_id => $class->id,
        id => $obj->id,
        name => $obj->name,
        changes => $changes,
    });
    Bugzilla->save_session_data;
    print Bugzilla->cgi->redirect(
        'editvalues.cgi?class='.$class->name.
        ($action ne 'delete' && $ARGS->{id} ? '&action=edit&id='.$obj->id :
            ($vars->{product} ? '&product_id=' . $vars->{product}->id : ''))
    );
    exit;
}

$vars->{obj_class} = $class;
if ($action eq 'add' || $action eq 'edit' || $action eq 'del')
{
    # Show add/edit form
    if ($action eq 'edit' || $action eq 'del')
    {
        $vars->{obj} = $obj;
    }
    $vars->{token} = issue_session_token($action eq 'del' ? 'delete_object' : 'save_object');
    $template->process("admin/fieldvalues/".($action eq 'del' ? 'confirm-delete' : 'edit').".html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}

# List values
if ($vars->{product})
{
    # FIXME: Allow to display bug counts for versions and milestones
    $vars->{values} = $class->type->match({ product_id => $vars->{product}->id });
}
else
{
    $vars->{values} = [ $class->type->get_all(INCLUDE_DISABLED) ];
}
$template->process("admin/fieldvalues/list.html.tmpl", $vars)
    || ThrowTemplateError($template->error());
exit;
