#!/usr/bin/perl -wT
# Class editor
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

# FIXME: This editor should also be based on the generic object editor

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Field;
use Bugzilla::Token;

my $template = Bugzilla->template;
my $ARGS = Bugzilla->input_params;
my $vars = {};

# Make sure the user is logged in and is an administrator.
my $user = Bugzilla->login(LOGIN_REQUIRED);
$user->in_group('editfields') || ThrowUserError('auth_failure', {
    group  => 'editfields',
    action => 'edit',
    object => 'classes',
});

my $action = trim($ARGS->{action} || '');
my $token = $ARGS->{token};

if (!$action)
{
    $vars->{classes} = [ sort { lc $a->name cmp lc $b->name } @{ Bugzilla->get_classes } ];
    $template->process('admin/classes/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'add' || $action eq 'edit')
{
    if ($action eq 'edit')
    {
        $vars->{class} = Bugzilla->get_class($ARGS->{id}) || ThrowUserError('class_not_exists');
        if ($vars->{class})
        {
            $vars->{possible_name_fields} = [ Bugzilla->get_class_fields({
                class_id => $vars->{class}->id,
                type => [ FIELD_TYPE_FREETEXT, FIELD_TYPE_NUMERIC, FIELD_TYPE_INTEGER ]
            }) ];
        }
    }
    $vars->{field_types} = Bugzilla->messages->{field_types};
    $vars->{token} = issue_session_token('save_object');
    $template->process('admin/classes/edit.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}
elsif ($action eq 'save' || $action eq 'delete')
{
    check_token_data($token, 'save_object');
    my $class = $ARGS->{id} ? Bugzilla->get_class($ARGS->{id}) : Bugzilla::Class->new;
    $class || ThrowUserError('class_not_exists');
    if ($action eq 'delete')
    {
        $class->remove_from_db;
    }
    else
    {
        $class->set_all($ARGS, '_');
        $class->update;
    }
    delete_token($token);
    Bugzilla->add_result_message({
        message => 'class_updated',
        action => $action eq 'delete' ? 'delete' : ($ARGS->{id} ? 'update' : 'create'),
        class => { name => $class->name, description => $class->description },
    });
    Bugzilla->save_session_data;
    print Bugzilla->cgi->redirect('editclasses.cgi');
}
else
{
    ThrowCodeError('no_valid_action');
}
exit;
