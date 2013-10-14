#!/usr/bin/perl
# DB schema updates for custishacks extension

package CustisHacks;

use strict;
use utf8;
use Bugzilla::Constants;
use Bugzilla::SmMapping;

# New tables
sub db_schema_abstract_schema
{
    my ($args) = @_;
    my $schema = $args->{schema};

    # WBS ID mapping for TN-ERP/SM dotProject integration
    # Requires cf_wbs custom field
    $schema->{tnerp_wbs_mapping} = {
        FIELDS => [
            our_id => {
                TYPE => 'INT2',
                NOTNULL => 1,
                PRIMARYKEY => 1,
                REFERENCES => {TABLE => 'cf_wbs', COLUMN => 'id', DELETE => 'CASCADE'}
            },
            tnerp_id => {TYPE => 'INT4', NOTNULL => 1},
            syncing => {TYPE => 'BOOLEAN', NOTNULL => 1},
        ],
        INDEXES => [
            tnerp_wbs_mapping_tnerp_id => { FIELDS => ['tnerp_id'], TYPE => 'UNIQUE' },
        ],
    };

    if ($schema->{cf_wbs})
    {
        # Bug 121622 - Additional flag for WBS: time tracking enabled or not for this WBS
        push @{$schema->{cf_wbs}->{FIELDS}}, timetracking => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1};
    }

    return 1;
}

# DB schema updates
sub install_update_db
{
    my ($args) = @_;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_alter_column('tnerp_wbs_mapping', tnerp_id => {TYPE => 'INT4', NOTNULL => 1}, 0);
    $dbh->bz_add_column('tnerp_wbs_mapping', syncing => {TYPE => 'BOOLEAN', NOTNULL => 1}, 0);
    my $f = { @{ $dbh->bz_table_info('tnerp_wbs_mapping')->{FIELDS} } };
    if ($f->{our_id}->{REFERENCES}->{DELETE} ne 'CASCADE')
    {
        $dbh->bz_drop_fk('tnerp_wbs_mapping', 'our_id');
        # Bugzilla will recreate it by itself
    }

    if ($dbh->bz_table_info('cf_wbs'))
    {
        # Bug 121622 - Additional flag for WBS: time tracking enabled or not for this WBS
        $dbh->bz_add_column('cf_wbs', timetracking => {TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1});
    }

    return 1;
}

# Bug synchronisation hook (doesn't matter create or update)
# Uses arguments: { bug => $bug }
sub sync_bug
{
    my ($args) = @_; # { bug => $bug, timestamp => $timestamp }
    if (Bugzilla->params->{sm_dotproject_wsdl_url} && # only if enabled
        !$Bugzilla::SmMapping::InWS && # prevent syncing changes coming from dotProject
        $args->{bug}->product =~ /^СМ-/so) # only for external bugs
    {
        my $tnerp_id = get_wbs_mapping(undef, get_wbs(undef, $args->{bug}->cf_wbs)->id);
        if ($tnerp_id && $tnerp_id->{syncing})
        {
            # Only sync bugs with WBS known to TN-ERP and syncing flag = 1
            Bugzilla->job_queue->insert('sm_sync', { bug_id => $args->{bug}->id, delta_ts => $args->{timestamp} });
        }
    }
    return 1;
}

# "Static" column definitions - freely cached by Bugzilla forever
sub buglist_static_columns
{
    my ($args) = @_;
    my $columns = $args->{columns};

    # CustIS Bug 121622 - "WBS timetracking enabled" column
    my $cf = Bugzilla->get_field('cf_wbs');
    if ($cf && $cf->type == FIELD_TYPE_SINGLE_SELECT)
    {
        my $t = $cf->name;
        $columns->{$t.'_timetracking'} = {
            title => $cf->description.' timetracking enabled',
            name => "$t.timetracking",
            joins => [ "LEFT JOIN $t ON $t.value=bugs.$t" ],
        };
    }

    return 1;
}

# CustIS Bug 121622 - Patch cf_wbs value class to add 'timetracking' attribute...
# See also action=update in editvalues.cgi
my $cf = Bugzilla->get_field('cf_wbs');
if ($cf)
{
    my $pkg = Bugzilla::Field::Choice->type($cf);
    eval('*'.$pkg.'::DB_COLUMNS = sub { return qw('.join(' ', Bugzilla::Field::Choice->DB_COLUMNS, 'timetracking').'); }');
    eval('*'.$pkg.'::UPDATE_COLUMNS = sub { return qw('.join(' ', Bugzilla::Field::Choice->UPDATE_COLUMNS, 'timetracking').'); }');
    eval('*'.$pkg.'::timetracking = sub { return $_[0]->{timetracking}; }');
    eval('package '.$pkg.'; sub set_timetracking { return $_[0]->set("timetracking", $_[1]); }');
}

1;
__END__