#!/usr/bin/perl
# DB schema updates for custishacks extension

package CustisHacks;

use strict;
use utf8;

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
                REFERENCES => {TABLE => 'cf_wbs', COLUMN => 'id'}
            },
            tnerp_id => {TYPE => 'INT4', NOTNULL => 1},
        ],
        INDEXES => [
            tnerp_wbs_mapping_tnerp_id => { FIELDS => ['tnerp_id'], TYPE => 'UNIQUE' },
        ],
    };

    return 1;
}

# DB schema updates
sub install_update_db
{
    my ($args) = @_;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_alter_column('tnerp_wbs_mapping', tnerp_id => {TYPE => 'INT4', NOTNULL => 1}, 0);

    return 1;
}

# Bug synchornisation hook (doesn't matter create or update)
# Uses arguments: { bug => $bug }
sub sync_bug
{
    my ($args) = @_; # { bug => $bug, timestamp => $timestamp }
    if (Bugzilla->params->{sm_dotproject_wsdl_url} && # only if enabled
        !$Bugzilla::SmMapping::InWS && # prevent syncing changes which come from dotProject
        $args->{bug}->product =~ /^СМ-/so) # only for external bugs
    {
        my $tnerp_id = get_wbs_mapping(undef, get_wbs(undef, $args->{bug}->cf_wbs)->id);
        if ($tnerp_id)
        {
            # Only sync bugs which have WBS known to TN-ERP
            Bugzilla->job_queue->insert('sm_sync', { bug_id => $args->{bug}->id });
        }
    }
    return 1;
}

1;
__END__
