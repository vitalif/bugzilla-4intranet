#!/usr/bin/perl -wT
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
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Matthew Tuck <matty@chariot.net.au>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Marc Schumann <wurblzap@gmail.com>
#                 Frédéric Buclin <LpSolit@gmail.com>

use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Hook;
use Bugzilla::Util;
use Bugzilla::Status;

###########################################################################
# General subs
###########################################################################

sub get_string
{
    my ($san_tag, $vars) = @_;
    $vars->{san_tag} = $san_tag;
    return get_text('sanitycheck', $vars);
}

sub Status
{
    my ($san_tag, $vars, $alert) = @_;
    my $ARGS = Bugzilla->input_params;
    return if !$alert && Bugzilla->usage_mode == USAGE_MODE_CMDLINE && !$ARGS->{verbose};
    if (Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
    {
        my $linebreak = $alert ? "\nALERT: " : "\n";
        $ARGS->{error_found} = 1 if $alert;
        $ARGS->{output} = ($ARGS->{output} || '') . $linebreak . get_string($san_tag, $vars);
        print $linebreak . get_string($san_tag, $vars);
    }
    else
    {
        my $start_tag = $alert ? '<p class="alert">' : '<p>';
        print $start_tag . get_string($san_tag, $vars) . "</p>\n";
    }
}

###########################################################################
# Start
###########################################################################

my $user = Bugzilla->login(LOGIN_REQUIRED);

my $ARGS = Bugzilla->input_params;
my $dbh = Bugzilla->dbh;
# If the result of the sanity check is sent per email, then we have to
# take the user prefs into account rather than querying the web browser.
my $template;
if (Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
{
    $template = Bugzilla->template_inner($user->settings->{lang}->{value});
}
else
{
    $template = Bugzilla->template;
}
my $vars = {};

Bugzilla->cgi->send_header() unless Bugzilla->usage_mode == USAGE_MODE_CMDLINE;

# Make sure the user is authorized to access sanitycheck.cgi.
# As this script can now alter the group_control_map table, we no longer
# let users with editbugs privs run it anymore.
$user->in_group("editcomponents") || ThrowUserError("auth_failure", {
    group  => "editcomponents",
    action => "run",
    object => "sanity_check",
});

unless (Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
{
    $template->process('admin/sanitycheck/list.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
}

unless ($user->in_group('editcomponents'))
{
    Status('checks_completed');
    $template->process('global/footer.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}

###########################################################################
# Fix vote cache
###########################################################################

if ($ARGS->{rebuildvotecache})
{
    Status('vote_cache_rebuild_start');
    $dbh->bz_start_transaction();
    $dbh->do('UPDATE bugs SET votes = 0');
    my $sth_update = $dbh->prepare('UPDATE bugs SET votes = ? WHERE bug_id = ?');
    my $sth = $dbh->prepare('SELECT bug_id, SUM(vote_count) FROM votes GROUP BY bug_id');
    $sth->execute();
    while (my ($id, $v) = $sth->fetchrow_array)
    {
        $sth_update->execute($v, $id);
    }
    $dbh->bz_commit_transaction();
    Status('vote_cache_rebuild_end');
}

###########################################################################
# Create missing group_control_map entries
###########################################################################

if ($ARGS->{createmissinggroupcontrolmapentries})
{
    Status('group_control_map_entries_creation');

    my $na    = CONTROLMAPNA;
    my $shown = CONTROLMAPSHOWN;
    my $insertsth = $dbh->prepare(
        'INSERT INTO group_control_map (group_id, product_id, membercontrol, othercontrol)'.
        ' VALUES (?, ?, $shown, $na)'
    );

    my $updatesth = $dbh->prepare(
        'UPDATE group_control_map SET membercontrol = $shown WHERE group_id = ? AND product_id = ?'
    );
    my $counter = 0;

    # Find all group/product combinations used for bugs but not set up
    # correctly in group_control_map
    my $invalid_combinations = $dbh->selectall_arrayref(
        "SELECT bugs.product_id, bgm.group_id, gcm.membercontrol, groups.name, products.name FROM bugs".
        " INNER JOIN bug_group_map AS bgm ON bugs.bug_id = bgm.bug_id".
        " INNER JOIN groups ON bgm.group_id = groups.id".
        " INNER JOIN products ON bugs.product_id = products.id".
        " LEFT JOIN group_control_map AS gcm".
        " ON bugs.product_id = gcm.product_id AND bgm.group_id = gcm.group_id".
        " WHERE COALESCE(gcm.membercontrol, $na) = $na".
        $dbh->sql_group_by('bugs.product_id, bgm.group_id', 'gcm.membercontrol, groups.name, products.name')
    );

    foreach (@$invalid_combinations)
    {
        my ($product_id, $group_id, $currentmembercontrol, $group_name, $product_name) = @$_;
        $counter++;
        if (defined($currentmembercontrol))
        {
            Status('group_control_map_entries_update', {
                group_name => $group_name,
                product_name => $product_name,
            });
            $updatesth->execute($group_id, $product_id);
        }
        else
        {
            Status('group_control_map_entries_generation', {
                group_name => $group_name,
                product_name => $product_name,
            });
            $insertsth->execute($group_id, $product_id);
        }
    }

    Status('group_control_map_entries_repaired', {counter => $counter});
}

###########################################################################
# Fix missing creation date
###########################################################################

if ($ARGS->{repair_creation_date})
{
    Status('bug_creation_date_start');

    my $bug_ids = $dbh->selectcol_arrayref('SELECT bug_id FROM bugs WHERE creation_ts IS NULL');
    my $sth_UpdateDate = $dbh->prepare('UPDATE bugs SET creation_ts=? WHERE bug_id=?');

    # All bugs have an entry in the 'longdescs' table when they are created,
    # even if no comment is required.
    my $sth_getDate = $dbh->prepare('SELECT MIN(bug_when) FROM longdescs WHERE bug_id = ?');
    foreach my $bugid (@$bug_ids)
    {
        $sth_getDate->execute($bugid);
        my $date = $sth_getDate->fetchrow_array;
        $sth_UpdateDate->execute($date, $bugid);
    }
    Status('bug_creation_date_fixed', { bug_count => scalar @$bug_ids });
}

###########################################################################
# Fix everconfirmed
###########################################################################

if ($ARGS->{repair_everconfirmed})
{
    Status('everconfirmed_start');

    my $unconfirmed_states = join(', ', map { $dbh->quote($_->name) } grep { !$_->is_confirmed } Bugzilla::Status->get_all);
    my $confirmed_states = join(', ', map { $dbh->quote($_->name) } grep { $_->is_confirmed } Bugzilla::Status->get_all);

    $dbh->do("UPDATE bugs SET everconfirmed = 0 WHERE bug_status IN ($unconfirmed_states)");
    $dbh->do("UPDATE bugs SET everconfirmed = 1 WHERE bug_status IN ($confirmed_states)");

    Status('everconfirmed_end');
}

###########################################################################
# Fix entries in Bugs full_text
###########################################################################

if ($ARGS->{repair_bugs_fulltext} && !Bugzilla->localconfig->{sphinx_index})
{
    Status('bugs_fulltext_start');

    my $bug_ids = $dbh->selectcol_arrayref(
        'SELECT bugs.bug_id FROM bugs'.
        ' LEFT JOIN bugs_fulltext ON bugs_fulltext.bug_id = bugs.bug_id'.
        ' WHERE bugs_fulltext.bug_id IS NULL'
    );
    foreach my $bugid (@$bug_ids)
    {
        Bugzilla::Bug->new($bugid)->_sync_fulltext('new_bug');
    }

    Status('bugs_fulltext_fixed', { bug_count => scalar @$bug_ids });
}

###########################################################################
# Send unsent mail
###########################################################################

if ($ARGS->{rescanallBugMail})
{
    require Bugzilla::BugMail;

    Status('send_bugmail_start');
    my $time = $dbh->sql_date_math('NOW()', '-', 30, 'MINUTE');

    my $list = $dbh->selectcol_arrayref(
        "SELECT bug_id FROM bugs WHERE (lastdiffed IS NULL OR lastdiffed < delta_ts)".
        " AND delta_ts < $time ORDER BY bug_id"
    );

    Status('send_bugmail_status', { bug_count => scalar @$list });

    # We cannot simply look at the bugs_activity table to find who did the
    # last change in a given bug, as e.g. adding a comment doesn't add any
    # entry to this table. And some other changes may be private
    # (such as time-related changes or private attachments or comments)
    # and so choosing this user as being the last one having done a change
    # for the bug may be problematic. So the best we can do at this point
    # is to choose the currently logged in user for email notification.
    $vars->{changer} = Bugzilla->user->login;

    foreach my $bugid (@$list)
    {
        Bugzilla::BugMail::Send($bugid, $vars);
    }

    Status('send_bugmail_end') if scalar(@$list);

    unless (Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
    {
        $template->process('global/footer.html.tmpl', $vars)
            || ThrowTemplateError($template->error());
    }
    exit;
}

###########################################################################
# Remove all references to deleted bugs
###########################################################################

if ($ARGS->{remove_invalid_bug_references})
{
    Status('bug_reference_deletion_start');

    $dbh->bz_start_transaction();

    foreach my $pair (
        'attachments/', 'bug_group_map/', 'bugs_activity/',
        'bugs_fulltext/', 'cc/',
        'dependencies/blocked', 'dependencies/dependson',
        'duplicates/dupe', 'duplicates/dupe_of',
        'flags/', 'keywords/', 'longdescs/', 'votes/')
    {
        my ($table, $field) = split('/', $pair);
        $field ||= "bug_id";

        my $bug_ids = $dbh->selectcol_arrayref(
            "SELECT $table.$field FROM $table".
            " LEFT JOIN bugs ON $table.$field = bugs.bug_id".
            " WHERE bugs.bug_id IS NULL"
        );
        if (scalar @$bug_ids)
        {
            $dbh->do("DELETE FROM $table WHERE $field IN (" . join(',', @$bug_ids) . ")");
        }
    }

    $dbh->bz_commit_transaction();
    Status('bug_reference_deletion_end');
}

###########################################################################
# Remove all references to deleted users or groups from whines
###########################################################################

if ($ARGS->{remove_old_whine_targets})
{
    Status('whines_obsolete_target_deletion_start');
    $dbh->bz_start_transaction();
    foreach my $target (['groups', 'id', MAILTO_GROUP], ['profiles', 'userid', MAILTO_USER])
    {
        my ($table, $col, $type) = @$target;
        my $old_ids = $dbh->selectcol_arrayref(
            "SELECT DISTINCT mailto FROM whine_schedules".
            " LEFT JOIN $table ON $table.$col = whine_schedules.mailto".
            " WHERE mailto_type = $type AND $table.$col IS NULL"
        );
        if (scalar(@$old_ids))
        {
            $dbh->do(
                "DELETE FROM whine_schedules WHERE mailto_type = $type".
                " AND mailto IN (" . join(',', @$old_ids) . ")"
            );
        }
    }
    $dbh->bz_commit_transaction();
    Status('whines_obsolete_target_deletion_end');
}

###########################################################################
# Repair hook
###########################################################################

Bugzilla::Hook::process('sanitycheck_repair', { status => \&Status });

###########################################################################
# Checks
###########################################################################
Status('checks_start');

###########################################################################
# Perform referential (cross) checks
###########################################################################

# This checks that a simple foreign key has a valid primary key value.
# NULL references are acceptable and cause no problem.
# FIXME: CrossCheck is useless on DBMSes with foreign key support (mostly on ALL DBMSes).
sub CrossCheck
{
    my $table = shift @_;
    my $field = shift @_;
    my $dbh = Bugzilla->dbh;

    Status('cross_check_to', { table => $table, field => $field });

    while (@_)
    {
        my $ref = shift @_;
        my ($refertable, $referfield, $keyname) = @$ref;

        Status('cross_check_from', {table => $refertable, field => $referfield});

        my $query = "SELECT DISTINCT $refertable.$referfield".
            ($keyname ? ", $refertable.$keyname" : "").
            " FROM $refertable LEFT JOIN $table ON $refertable.$referfield = $table.$field".
            " WHERE $table.$field IS NULL AND $refertable.$referfield IS NOT NULL";

        my $sth = $dbh->prepare($query);
        $sth->execute;

        my $has_bad_references = 0;

        while (my ($value, $key) = $sth->fetchrow_array)
        {
            Status('cross_check_alert', {
                value => $value,
                table => $refertable,
                field => $referfield,
                keyname => $keyname,
                key => $key,
            }, 'alert');
            $has_bad_references = 1;
        }
        # References to non existent bugs can be safely removed, bug 288461
        if ($table eq 'bugs' && $has_bad_references)
        {
            Status('cross_check_bug_has_references');
        }
        # References to non existent attachments can be safely removed.
        if ($table eq 'attachments' && $has_bad_references)
        {
            Status('cross_check_attachment_has_references');
        }
    }
}

my $sch = Bugzilla->dbh->_bz_schema;
for my $table (keys %$sch)
{
    my %fields = @{$sch->{$table}->{FIELDS} || []};
    for my $f (keys %fields)
    {
        if (my $r = $fields{$f}{REFERENCES})
        {
            CrossCheck($r->{TABLE}, $r->{COLUMN}, [ $table, $f ]);
        }
    }
}

###########################################################################
# Perform double field referential (cross) checks
###########################################################################

# This checks that a compound two-field foreign key has a valid primary key
# value.  NULL references are acceptable and cause no problem.
#
# The first parameter is the primary key table name.
# The second parameter is the primary key first field name.
# The third parameter is the primary key second field name.
# Each successive parameter represents a foreign key, it must be a list
# reference, where the list has:
#   the first value is the foreign key table name
#   the second value is the foreign key first field name.
#   the third value is the foreign key second field name.
#   the fourth value is optional and represents a field on the foreign key
#     table to display when the check fails
sub DoubleCrossCheck
{
    my $table = shift @_;
    my $field1 = shift @_;
    my $field2 = shift @_;
    my $dbh = Bugzilla->dbh;

    Status('double_cross_check_to', { table => $table, field1 => $field1, field2 => $field2 });

    while (@_)
    {
        my $ref = shift @_;
        my ($refertable, $referfield1, $referfield2, $keyname) = @$ref;

        Status('double_cross_check_from', { table => $refertable, field1 => $referfield1, field2 => $referfield2 });

        my $d_cross_check = $dbh->selectall_arrayref(
            "SELECT DISTINCT $refertable.$referfield1, $refertable.$referfield2" .
            ($keyname ? ", $refertable.$keyname" : "") .
            " FROM $refertable LEFT JOIN $table ON $refertable.$referfield1 = $table.$field1".
            " AND $refertable.$referfield2 = $table.$field2".
            " WHERE $table.$field1 IS NULL AND $table.$field2 IS NULL".
            " AND $refertable.$referfield1 IS NOT NULL AND $refertable.$referfield2 IS NOT NULL"
        );
        foreach my $check (@$d_cross_check)
        {
            my ($value1, $value2, $key) = @$check;
            Status('double_cross_check_alert', {
                value1 => $value1,
                value2 => $value2,
                table => $refertable,
                field1 => $referfield1,
                field2 => $referfield2,
                keyname => $keyname,
                key => $key,
            }, 'alert');
        }
    }
}

DoubleCrossCheck(
    'attachments', 'bug_id', 'attach_id',
    ['flags', 'bug_id', 'attach_id'],
    ['bugs_activity', 'bug_id', 'attach_id']
);
DoubleCrossCheck(
    'components', 'product_id', 'id',
    ['bugs', 'product_id', 'component_id', 'bug_id'],
    ['flagexclusions', 'product_id', 'component_id'],
    ['flaginclusions', 'product_id', 'component_id']
);
DoubleCrossCheck(
    'versions', 'product_id', 'id',
    ['bugs', 'product_id', 'version', 'bug_id']
);
DoubleCrossCheck(
    'milestones', 'product_id', 'id',
    ['bugs', 'product_id', 'target_milestone', 'bug_id']
);

###########################################################################
# Perform login checks
###########################################################################

Status('profile_login_start');

my $sth = $dbh->prepare("SELECT userid, login_name FROM profiles");
$sth->execute;
while (my ($id, $email) = $sth->fetchrow_array)
{
    validate_email_syntax($email) || Status('profile_login_alert', { id => $id, email => $email }, 'alert');
}

###########################################################################
# Perform vote/keyword cache checks
###########################################################################

check_votes_or_keywords();

sub check_votes_or_keywords
{
    my $check = shift || 'all';

    my $dbh = Bugzilla->dbh;
    my $sth = $dbh->prepare("SELECT bug_id, votes FROM bugs WHERE votes != 0");
    $sth->execute;

    my %votes;
    while (my ($id, $v, $k) = $sth->fetchrow_array)
    {
        $votes{$id} = $v;
    }

    Status('vote_count_start');
    $sth = $dbh->prepare(
        "SELECT bug_id, SUM(vote_count) FROM votes GROUP BY bug_id"
    );
    $sth->execute;

    my $offer_votecache_rebuild = 0;
    while (my ($id, $v) = $sth->fetchrow_array)
    {
        if ($v <= 0)
        {
            Status('vote_count_alert', { id => $id }, 'alert');
        }
        else
        {
            if (!defined $votes{$id} || $votes{$id} != $v)
            {
                Status('vote_cache_alert', { id => $id }, 'alert');
                $offer_votecache_rebuild = 1;
            }
            delete $votes{$id};
        }
    }
    foreach my $id (keys %votes)
    {
        Status('vote_cache_alert', { id => $id }, 'alert');
        $offer_votecache_rebuild = 1;
    }

    Status('vote_cache_rebuild_fix') if $offer_votecache_rebuild;
}

###########################################################################
# Check for flags being in incorrect products and components
###########################################################################

Status('flag_check_start');

my $invalid_flags = $dbh->selectall_arrayref(
    'SELECT DISTINCT flags.id, flags.bug_id, flags.attach_id FROM flags'.
    ' INNER JOIN bugs ON flags.bug_id = bugs.bug_id'.
    ' LEFT JOIN flaginclusions AS i ON flags.type_id = i.type_id'.
    ' AND (bugs.product_id = i.product_id OR i.product_id IS NULL)'.
    ' AND (bugs.component_id = i.component_id OR i.component_id IS NULL)'.
    'WHERE i.type_id IS NULL'
);

my @invalid_flags = @$invalid_flags;

$invalid_flags = $dbh->selectall_arrayref(
    'SELECT DISTINCT flags.id, flags.bug_id, flags.attach_id FROM flags'.
    ' INNER JOIN bugs ON flags.bug_id = bugs.bug_id'.
    ' INNER JOIN flagexclusions AS e ON flags.type_id = e.type_id'.
    ' WHERE (bugs.product_id = e.product_id OR e.product_id IS NULL)'.
    ' AND (bugs.component_id = e.component_id OR e.component_id IS NULL)'
);

push @invalid_flags, @$invalid_flags;

if (@invalid_flags)
{
    if ($ARGS->{remove_invalid_flags})
    {
        Status('flag_deletion_start');
        my @flag_ids = map { $_->[0] } @invalid_flags;
        # Silently delete these flags, with no notification to requesters/setters.
        $dbh->do('DELETE FROM flags WHERE id IN (' . join(',', @flag_ids) .')');
        Status('flag_deletion_end');
    }
    else
    {
        foreach my $flag (@$invalid_flags)
        {
            my ($flag_id, $bug_id, $attach_id) = @$flag;
            Status('flag_alert', { flag_id => $flag_id, attach_id => $attach_id, bug_id => $bug_id }, 'alert');
        }
        Status('flag_fix');
    }
}

###########################################################################
# General bug checks
###########################################################################

sub BugCheck
{
    my ($middlesql, $errortext, $repairparam, $repairtext) = @_;
    my $dbh = Bugzilla->dbh;
    my $badbugs = $dbh->selectcol_arrayref(
        "SELECT DISTINCT bugs.bug_id FROM $middlesql ORDER BY bugs.bug_id"
    );
    if (scalar(@$badbugs))
    {
        Status('bug_check_alert', { errortext => get_string($errortext), badbugs => $badbugs }, 'alert');
        if ($repairparam)
        {
            $repairtext ||= 'repair_bugs';
            Status('bug_check_repair', { param => $repairparam, text => get_string($repairtext) });
        }
    }
}

Status('bug_check_creation_date');

BugCheck(
    "bugs WHERE creation_ts IS NULL", 'bug_check_creation_date_error_text',
    'repair_creation_date', 'bug_check_creation_date_repair_text'
);

if (!Bugzilla->localconfig->{sphinx_index})
{
    Status('bug_check_bugs_fulltext');
    BugCheck(
        "bugs LEFT JOIN bugs_fulltext ON bugs_fulltext.bug_id = bugs.bug_id " .
        "WHERE bugs_fulltext.bug_id IS NULL", 'bug_check_bugs_fulltext_error_text',
        'repair_bugs_fulltext', 'bug_check_bugs_fulltext_repair_text'
    );
}

Status('bug_check_res_dupl');

BugCheck(
    "bugs INNER JOIN duplicates ON bugs.bug_id = duplicates.dupe " .
    "WHERE bugs.resolution != 'DUPLICATE'", 'bug_check_res_dupl_error_text'
);

BugCheck(
    "bugs LEFT JOIN duplicates ON bugs.bug_id = duplicates.dupe WHERE " .
    "bugs.resolution = 'DUPLICATE' AND duplicates.dupe IS NULL", 'bug_check_res_dupl_error_text2'
);

Status('bug_check_status_res');

my @open_states = map($_->id, grep { $_->is_open } Bugzilla::Status->get_all);
my $open_states = join(', ', @open_states);

BugCheck(
    "bugs WHERE bug_status IN ($open_states) AND resolution IS NOT NULL",
    'bug_check_status_res_error_text'
);
BugCheck(
    "bugs WHERE bug_status NOT IN ($open_states) AND resolution IS NULL",
    'bug_check_status_res_error_text2'
);

Status('bug_check_status_everconfirmed');

my $unconfirmed_states = join(', ', map { $_->id } grep { !$_->is_confirmed } Bugzilla::Status->get_all);

BugCheck(
    "bugs WHERE bug_status IN ($unconfirmed_states) AND everconfirmed = 1",
    'bug_check_status_everconfirmed_error_text', 'repair_everconfirmed'
);

my $confirmed_states = join(', ', map { $_->id } grep { $_->is_confirmed } Bugzilla::Status->get_all);

BugCheck(
    "bugs WHERE bug_status IN ($confirmed_states) AND everconfirmed = 0",
    'bug_check_status_everconfirmed_error_text2', 'repair_everconfirmed'
);

Status('bug_check_votes_everconfirmed');

BugCheck(
    "bugs INNER JOIN products ON bugs.product_id = products.id " .
    "WHERE everconfirmed = 0 AND votestoconfirm > 0 AND votestoconfirm <= votes",
    'bug_check_votes_everconfirmed_error_text'
);

###########################################################################
# Control Values
###########################################################################

# Checks for values that are invalid OR
# not among the 9 valid combinations
Status('bug_check_control_values');
my $groups = join(", ", (CONTROLMAPNA, CONTROLMAPSHOWN, CONTROLMAPDEFAULT, CONTROLMAPMANDATORY));
my $query = "SELECT COUNT(product_id) FROM group_control_map".
    " WHERE membercontrol NOT IN ($groups)".
    " OR othercontrol NOT IN ($groups) OR ((membercontrol != othercontrol)".
    " AND (membercontrol != " . CONTROLMAPSHOWN . ")".
    " AND ((membercontrol != " . CONTROLMAPDEFAULT . ")".
    " OR (othercontrol = " . CONTROLMAPSHOWN . ")))";

my $entries = $dbh->selectrow_array($query);
Status('bug_check_control_values_alert', { entries => $entries }, 'alert') if $entries;

Status('bug_check_control_values_violation');
BugCheck(
    "bugs INNER JOIN bug_group_map ON bugs.bug_id = bug_group_map.bug_id".
    " LEFT JOIN group_control_map ON bugs.product_id = group_control_map.product_id".
    " AND bug_group_map.group_id = group_control_map.group_id".
    " WHERE ((group_control_map.membercontrol = " . CONTROLMAPNA . ")".
    " OR (group_control_map.membercontrol IS NULL))",
    'bug_check_control_values_error_text',
    'createmissinggroupcontrolmapentries',
    'bug_check_control_values_repair_text'
);

BugCheck(
    "bugs INNER JOIN group_control_map ON bugs.product_id = group_control_map.product_id".
    " INNER JOIN groups ON group_control_map.group_id = groups.id".
    " LEFT JOIN bug_group_map ON bugs.bug_id = bug_group_map.bug_id".
    " AND group_control_map.group_id = bug_group_map.group_id".
    " WHERE group_control_map.membercontrol = " . CONTROLMAPMANDATORY .
    " AND bug_group_map.group_id IS NULL AND groups.isactive != 0",
    'bug_check_control_values_error_text2'
);

###########################################################################
# Unsent mail
###########################################################################

Status('unsent_bugmail_check');

my $time = $dbh->sql_date_math('NOW()', '-', 30, 'MINUTE');
my $badbugs = $dbh->selectcol_arrayref(
    "SELECT bug_id FROM bugs WHERE (lastdiffed IS NULL OR lastdiffed < delta_ts)".
    " AND delta_ts < $time ORDER BY bug_id"
);
if (@$badbugs)
{
    Status('unsent_bugmail_alert', { badbugs => $badbugs }, 'alert');
    Status('unsent_bugmail_fix');
}

###########################################################################
# Whines
###########################################################################

Status('whines_obsolete_target_start');

my $display_repair_whines_link = 0;
foreach my $target (['groups', 'id', MAILTO_GROUP], ['profiles', 'userid', MAILTO_USER])
{
    my ($table, $col, $type) = @$target;
    my $old = $dbh->selectall_arrayref(
        "SELECT whine_schedules.id, mailto FROM whine_schedules".
        " LEFT JOIN $table ON $table.$col = whine_schedules.mailto".
        " WHERE mailto_type = $type AND $table.$col IS NULL"
    );
    if (scalar @$old)
    {
        Status('whines_obsolete_target_alert', { schedules => $old, type => $type }, 'alert');
        $display_repair_whines_link = 1;
    }
}
Status('whines_obsolete_target_fix') if $display_repair_whines_link;

###########################################################################
# Check hook
###########################################################################

Bugzilla::Hook::process('sanitycheck_check', { status => \&Status });

###########################################################################
# End
###########################################################################

Status('checks_completed');

unless (Bugzilla->usage_mode == USAGE_MODE_CMDLINE)
{
    $template->process('global/footer.html.tmpl', $vars)
        || ThrowTemplateError($template->error());
    exit;
}
