#!/usr/bin/perl -wT
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use 5.10.1;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Bug;

use Checkers;

my $cgi = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars = {};
my $user = Bugzilla->login();

my $format = $template->get_format("bug/show", scalar $cgi->param('format'),
                                   scalar $cgi->param('ctype'));

# Editable, 'single' HTML bugs are treated slightly specially in a few places
my $single = !$format->{format} && $format->{extension} eq 'html';

# If we don't have an ID, _AND_ we're only doing a single bug, then prompt
if (!$cgi->param('id') && $single) {
    $template->process("bug/choose.html.tmpl", $vars) ||
      ThrowTemplateError($template->error());
    exit;
}

my (@bugs, @illegal_bugs);
my %marks;

# If the user isn't logged in, we use data from the shadow DB. If he plans
# to edit the bug(s), he will have to log in first, meaning that the data
# will be reloaded anyway, from the main DB.
Bugzilla->switch_to_shadow_db unless $user->id;

if ($single) {
    my $id = $cgi->param('id');
    push @bugs, Bugzilla::Bug->check({ id => $id, cache => 1 });
    if (defined $cgi->param('mark')) {
        foreach my $range (split ',', $cgi->param('mark')) {
            if ($range =~ /^(\d+)-(\d+)$/) {
               foreach my $i ($1..$2) {
                   $marks{$i} = 1;
               }
            } elsif ($range =~ /^(\d+)$/) {
               $marks{$1} = 1;
            }
        }
    }
} else {
    foreach my $id ($cgi->param('id')) {
        # Be kind enough and accept URLs of the form: id=1,2,3.
        my @ids = split(/,/, $id);
        my @check_bugs;

        foreach my $bug_id (@ids) {
            next unless $bug_id;
            my $bug = new Bugzilla::Bug({ id => $bug_id, cache => 1 });
            if (!$bug->{error}) {
                push(@check_bugs, $bug);
            }
            else {
                push(@illegal_bugs, { bug_id => trim($bug_id), error => $bug->{error} });
            }
        }

        $user->visible_bugs(\@check_bugs);

        foreach my $bug (@check_bugs) {
            if ($user->can_see_bug($bug->id)) {
                push(@bugs, $bug);
            }
            else {
                my $error = 'NotPermitted'; # Trick to make 012throwables.t happy.
                push(@illegal_bugs, { bug_id => $bug->id, error => $error });
            }
        }
    }
}

Bugzilla::Bug->preload(\@bugs);

$vars->{'bugs'} = [@bugs, @illegal_bugs];
$vars->{'marks'} = \%marks;

my @bugids = map {$_->bug_id} grep {!$_->error} @bugs;
$vars->{'bugids'} = join(", ", @bugids);

# Work out which fields we are displaying (currently XML only.)
# If no explicit list is defined, we show all fields. We then exclude any
# on the exclusion list. This is so you can say e.g. "Everything except 
# attachments" without listing almost all the fields.
my @fieldlist = (Bugzilla::Bug->fields, 'flag', 'group', 'long_desc',
                 'attachment', 'attachmentdata', 'token');
my %displayfields;

if ($cgi->param("field")) {
    @fieldlist = $cgi->param("field");
}

unless ($user->is_timetracker) {
    @fieldlist = grep($_ !~ /_time$/, @fieldlist);
}

foreach (@fieldlist) {
    $displayfields{$_} = 1;
}

foreach ($cgi->param("excludefield")) {
    $displayfields{$_} = undef;
}

# CustIS Bug 70168
if (my @f = $cgi->param("includefield")) {
    %displayfields = map { $_ => 1 } grep { $displayfields{$_} } @f;
}

# Custis Bug 66910
my @keyword_list = Bugzilla::Keyword->get_all();
my @keyword_list_out = map { { name => $_->{name} } } @keyword_list;
$vars->{keyword_list} = \@keyword_list_out;
# END Custis Bug 66910

$vars->{displayfields} = \%displayfields;

my $sd;
if (Bugzilla->session && ($sd = Bugzilla->session_data) && $sd->{sent})
{
    Bugzilla->save_session_data({
        sent => undef,
        title => undef,
        header => undef,
        sent_attrs => undef,
        failed_checkers => undef,
        message => undef,
        message_vars => undef,
    });
    $vars->{last_title} = $sd->{title};
    $vars->{last_header} = $sd->{header};
    $vars->{sentmail} = $sd->{sent};
    $vars->{failed_checkers} = Checkers::unfreeze_failed_checkers($sd->{failed_checkers});
    if ($sd->{message})
    {
        $vars->{message} = $sd->{message};
        $vars->{$_} = $sd->{message_vars}->{$_} for keys %{$sd->{message_vars} || {}};
    }
    $vars->{$_} = $sd->{sent_attrs}->{$_} for keys %{$sd->{sent_attrs} || {}};
}

$cgi->send_header($format->{ctype});

$template->process($format->{'template'}, $vars)
  || ThrowTemplateError($template->error());
