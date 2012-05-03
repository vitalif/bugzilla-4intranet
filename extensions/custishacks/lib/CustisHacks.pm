#!/usr/bin/perl
# DB schema updates for custishacks

package CustisHacks;

use strict;
use utf8;

# New tables
sub db_schema_abstract_schema
{
    my ($args) = @_;
    my $schema = $args->{schema};

    # WBS ID mapping for TN-ERP/SM dotProject integration
    # Requires cf_wbs custom field
    $schema->{tnerp_wbs_mapping} = {
        FIELDS => [
            our_id => {TYPE => 'INT2', NOTNULL => 1, PRIMARYKEY => 1},
            tnerp_id => {TYPE => 'INT3', NOTNULL => 1},
        ],
        INDEXES => [
            tnerp_wbs_mapping_tnerp_id => { FIELDS => ['tnerp_id'], TYPE => 'UNIQUE' },
        ],
    };

    return 1;
}

1;
__END__
