# Keyword value type, rewritten to be just like normal multi-select value
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Keyword;

use strict;
use base qw(Bugzilla::Field::Choice);

use Bugzilla::Error;
use Bugzilla::Util;

use constant DB_TABLE => 'keywords';
use constant FIELD_NAME => 'keywords';
use constant DB_COLUMNS => (Bugzilla::Field::Choice->DB_COLUMNS, 'description');
use constant UPDATE_COLUMNS => (Bugzilla::Field::Choice->UPDATE_COLUMNS, 'description');
use constant REQUIRED_CREATE_FIELDS => qw(value description);

use constant VALIDATORS => {
    %{ Bugzilla::Field::Choice->VALIDATORS },
    description => \&_check_description,
};

sub description { $_[0]->{description} }
sub set_description { $_[0]->set('description', $_[1]); }
sub _check_description
{
    my ($self, $desc) = @_;
    $desc = trim($desc);
    $desc eq '' && ThrowUserError("keyword_blank_description");
    return $desc;
}

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
        push @match_items, "value LIKE ".$dbh->quote($_.'%');
    }
    if (@match_items)
    {
        my $joined = join(' OR ', @match_items);
        $keywords = $dbh->selectall_arrayref("SELECT * FROM keywords WHERE ".$joined, {Slice => {}});
        return [] unless $keywords;
    }
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

This implements all standard C<Bugzilla::Field::Choice> methods.

=head1 SUBROUTINES

This is only a list of subroutines specific to C<Bugzilla::Keyword>.
See L<Bugzilla::Field::Choice> for more subroutines that this object
implements.

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
