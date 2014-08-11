# Keyword type, rewritten to be just like normal multi-select value
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Keyword;

use strict;
use base qw(Bugzilla::GenericObject);

use Bugzilla::Error;
use Bugzilla::Util;

use constant NAME_FIELD => 'value';
use constant LIST_ORDER => 'sortkey, value';
use constant DB_TABLE => 'keywords';
use constant CLASS_NAME => 'keyword';

sub bug_count { $_[0]->{bug_count} }

sub get_all_with_bug_count
{
    my $class = shift;
    my $dbh = Bugzilla->dbh;
    my $keywords = $dbh->selectall_arrayref(
        'SELECT k.*, COUNT(1) AS bug_count' .
        ' FROM keywords k LEFT JOIN bug_keywords b ON k.id = b.value_id ' .
        ' GROUP BY k.id ORDER BY k.sortkey, k.value', {Slice => {}}
    );
    return [] unless $keywords;

    foreach my $keyword (@$keywords)
    {
        bless $keyword, $class;
    }
    return $keywords;
}

sub get_by_match
{
    my $self = shift;
    my ($keywords, @match_items);
    my $dbh = Bugzilla->dbh;
    foreach (@_)
    {
        push @match_items, $self->NAME_FIELD." LIKE ".$dbh->quote($_.'%');
    }
    if (@match_items)
    {
        return $self->_do_list_select(join(' OR ', @match_items));
    }
    return [];
}

1;

__END__

=head1 NAME

Bugzilla::Keyword - A Keyword that can be added to a bug.

=head1 SYNOPSIS

 use Bugzilla::Keyword;

 my $description = $keyword->description;

 my $keywords = Bugzilla::Keyword->get_all_with_bug_count();

=head1 DESCRIPTION

Bugzilla::Keyword represents a keyword that can be added to a bug.

=head1 SUBROUTINES

This is only a list of subroutines specific to C<Bugzilla::Keyword>.

=over

=item C<get_all_with_bug_count()>

 Description: Returns all defined keywords. This is an efficient way
              to get the associated bug counts, as only one SQL query
              is executed with this method, instead of one per keyword
              when calling get_all and then bug_count.
 Params:      none
 Returns:     A reference to an array of Keyword objects, or an empty
              arrayref if there are no keywords.

=back

=cut
