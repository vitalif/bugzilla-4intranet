#!/usr/bin/perl
# Bug predicate / "checker" object
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Checker;

use strict;
use base qw(Bugzilla::Object Exporter);

use JSON;
use Bugzilla::Search;
use Bugzilla::Search::Saved;
use Bugzilla::Error;
use Bugzilla::Util;

use constant DB_TABLE => 'checkers';

use constant {
    # Yes => check old state of the bug ("freezer")
    # No => check new state of the bug ("checker")
    CF_FREEZE => 0x01,
    # Yes => throw an error, no => give a warning
    CF_FATAL  => 0x02,
    # Yes <=> check new bugs
    CF_CREATE => 0x04,
    # Yes <=> check updates
    CF_UPDATE => 0x08,
    # Yes => forbid to change everything except except_fields
    # No => allow to change everything except except_fields
    # except_fields are empty => CF_DENY added automatically
    CF_DENY   => 0x10,
};

our @EXPORT = qw(CF_FREEZE CF_FATAL CF_CREATE CF_UPDATE CF_DENY);

use constant DB_COLUMNS => (
    'id',
    'query_id', # "Bad state" is described by this search query
    'user_id',  # Creator
    'flags',    # Bit field of CF_* flags
    'message',  # Error message text
    'sql_code', # SQL code for query is cached here
    'except_fields', # "Exception" fields - see CF_DENY above.
    'triggers', # Triggers (bug changes) (requires CF_FREEZE & !CF_FATAL)
);
use constant NAME_FIELD => 'message';
use constant ID_FIELD   => 'id';
use constant LIST_ORDER => 'id';

use constant REQUIRED_CREATE_FIELDS => qw(query_id message);

use constant VALIDATORS => {
    query_id => \&_check_query_id,
    flags    => \&_check_flags,
};

use constant UPDATE_COLUMNS => (
    'query_id',
    'flags',
    'message',
    'sql_code',
    'except_fields',
    'triggers',
);

# The check works by executing this SQL query with added bugs.bug_id=? condition.
# Rebuild and save SQL code in the DB, from under the superuser
# (without permission checks). ORDER BY and SELECT ... FROM are removed
# and then added for more security.
sub refresh_sql
{
    my $self = shift;
    my ($query) = @_;
    if (!$query || $query->id != $self->query_id)
    {
        $query = $self->query;
    }
    my $search = new Bugzilla::Search(
        params => http_decode_query($query->query),
        fields => [ 'bug_id' ],
        user   => $query->user,
    );
    my $terms = Bugzilla::Search::simplify_expression([
        'AND_MANY', { term => 'bugs.bug_id=?' },
        $search->{terms_without_security}
    ]);
    my $sql = $search->get_expression_sql($terms, 'force joins');
    $sql =~ s/^\s*SELECT.*?FROM/SELECT DISTINCT $self->{id} FROM/;
    $self->set_sql_code($sql);
}

# Create a predicate, generating SQL code for it
sub create
{
    my ($class, $params) = @_;
    if ($params->{except_fields})
    {
        $params->{except_fields} = encode_json($params->{except_fields});
    }
    if ($params->{triggers})
    {
        $params->{triggers} = encode_json($params->{triggers});
    }
    my $self = Bugzilla::Object::create($class, $params);
    $self->update;
    $self->query->set_shared_with_group(Bugzilla::Group->check({ name => 'bz_editcheckers' }));
    return $self;
}

# Update a predicate, regenerating SQL code for it
sub update
{
    my $self = shift;
    $self->refresh_sql;
    $self->query->set_shared_with_group(Bugzilla::Group->check({ name => 'bz_editcheckers' }));
    if ($self->triggers)
    {
        $self->{flags} |= CF_FREEZE;
    }
    $self->SUPER::update(@_);
}

# Check this named query exists and is accessible to the user
sub _check_query_id
{
    my ($invocant, $value, $field) = @_;
    my $q = Bugzilla::Search::Saved->check({ id => $value });
    # This code allows to create predicates using searches shared by other users,
    # but the UI doesn't allow it (yet?).
    if ($q->user->id != Bugzilla->user->id &&
        (!$q->shared_with_group || !Bugzilla->user->in_group($q->shared_with_group)))
    {
        ThrowUserError('query_access_denied', { query => $q });
    }
    # Check if a named query is not a search query, but just an HTTP url
    if ($q->query =~ /^[a-z][a-z0-9]*:/iso)
    {
        ThrowUserError('query_not_savedsearch', { query => $q });
    }
    return $q->id;
}

sub _check_flags
{
    my ($invocant, $value, $field) = @_;
    $value = int($value);
    return $value;
}

sub id              { $_[0]->{id} }
sub query_id        { $_[0]->{query_id} }
sub user_id         { $_[0]->{user_id} }
sub message         { $_[0]->{message} }
sub sql_code        { $_[0]->{sql_code} }
sub flags           { $_[0]->{flags} }

# Specific flags from the bitfield
sub is_freeze       { $_[0]->{flags} & CF_FREEZE }
sub is_fatal        { ($_[0]->{flags} & CF_FATAL) && !$_[0]->triggers }
sub on_create       { $_[0]->{flags} & CF_CREATE }
sub on_update       { $_[0]->{flags} & CF_UPDATE }
sub deny_all        { $_[0]->{flags} & CF_DENY }

# { field_name => value }
# Make an exception for change of field_name to 'value', or to any value if value is undef
sub except_fields
{
    my $self = shift;
    if (!exists $self->{except_fields_obj})
    {
        $self->{except_fields_obj} = $self->{except_fields} ? decode_json($self->{except_fields}) : undef;
    }
    return $self->{except_fields_obj};
}

# { field_name => value }
# Change field 'field_name' to 'value'. For multivalued fields field_name may also
# by 'add_<field_name>' or 'remove_<field_name>', which means add or remove something.
# FIXME Now the only functions supported are 'add_cc' and 'clear_flags'
sub triggers
{
    my $self = shift;
    if (!exists $self->{triggers_obj})
    {
        $self->{triggers_obj} = $self->{triggers} ? decode_json($self->{triggers}) : undef;
    }
    return $self->{triggers_obj};
}

sub name
{
    my $self = shift;
    return $self->query->name;
}

sub query
{
    my $self = shift;
    if (!$self->{query})
    {
        $self->{query} = Bugzilla::Search::Saved->new({ id => $self->query_id });
    }
    return $self->{query};
}

sub user
{
    my $self = shift;
    if (!$self->{user})
    {
        $self->{user} = Bugzilla::User->new({ id => $self->user_id });
    }
    return $self->{user};
}

sub set_query_id { $_[0]->set('query_id', Bugzilla::Search::Saved->check({ id => $_[1] })->id) }
sub set_user_id  { $_[0]->set('user_id', Bugzilla::User->check({ userid => $_[1] })->id) }
sub set_flags    { $_[0]->set('flags', $_[1]) }
sub set_message  { $_[0]->set('message', $_[1]) }
sub set_sql_code { $_[0]->set('sql_code', $_[1]) }

sub set_except_fields
{
    my ($self, $value) = @_;
    $self->set('except_fields', $value ? encode_json($value) : undef);
    delete $self->{except_fields_obj};
}

sub set_triggers
{
    my ($self, $value) = @_;
    $self->set('triggers', $value ? encode_json($value) : undef);
    delete $self->{triggers_obj};
}

1;
__END__
