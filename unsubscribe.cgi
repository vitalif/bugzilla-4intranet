#!/usr/bin/perl -wT
# Unsubscribe from bug CC list with 1 click
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Bug;
use Bugzilla::BugMail;
use Bugzilla::Mailer;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Error;

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

my $bug = Bugzilla::Bug->check(Bugzilla->input_params->{id});

$vars->{bug} = $bug;

if (grep { $_->id == $user->id } @{$bug->cc_users})
{
    $bug->remove_cc($user);
    $bug->update;
    $vars->{rm_cc_ok} = 1;
}
else
{
    $vars->{not_in_cc} = 1;
}

$template->process('bug/process/unsubscribe.html.tmpl', $vars)
    || ThrowTemplateError($template->error());
exit;

1;
__END__
