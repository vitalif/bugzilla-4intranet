#!/usr/bin/perl
# Value of 'platform' field
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Platform;

use strict;

use base qw(Bugzilla::Field::Choice);
use constant DB_TABLE => 'rep_platform';
use constant FIELD_NAME => 'rep_platform';

use constant DB_COLUMNS => (Bugzilla::Field::Choice->DB_COLUMNS, 'ua_regex');
use constant UPDATE_COLUMNS => (Bugzilla::Field::Choice->UPDATE_COLUMNS, 'ua_regex');

sub ua_regex
{
    return $_[0]->{ua_regex};
}

sub set_ua_regex
{
    return $_[0]->set('ua_regex', $_[1]);
}

1;
__END__
