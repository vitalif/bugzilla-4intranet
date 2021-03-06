# Totally Rewritten Bugzilla4Intranet search engine
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

=head1 NAME

This is totally rewritten Bugzilla4Intranet search engine.

Original Bugzilla::Search was ugly and stupid. It contained
a lot of legacy code and often generated queries very complex
for the DBMS, and search performance was awful on big databases.

Although we could expect the authors to refactor it in Bugzilla 4.0,
they've just decomposed overlong subroutines into small ones.

So in Bugzilla4Intranet, I (Vitaliy Filippov) have rewritten it totally.

License is dual-license GPL 3.0+ or MPL 1.1+ ("+" means "or any later version"),
to be compatible with both GPL and Bugzilla code.

Most of the functionality remains unchanged, but the internals are totally
different, as well as query performance is (tested on MySQL) :)

=head1 BOOLEAN CHARTS

A boolean chart is a way of representing the terms in a logical
expression. Bugzilla builds SQL queries depending on how you enter
terms into the boolean chart. Boolean charts are represented in
urls as three-tuples of (chart, row, column) = (field, operator, value).
The query form (query.cgi) may contain an arbitrary number of
boolean charts where each chart represents a condition in SQL query.

The expressions represented by columns are ORed together.
The expressions represented by rows are ANDed together and can be negated.
The expressions represented by each chart are ORed together.
So, boolean charts specify a logical expression in the form of:

    OR(AND(OR()), NOT(AND(OR())), ...)

Original boolean charts in Bugzilla 2.x really consisted of tables
with rows and columns. Now, there is no tables, but three levels
of charts remain.

Original boolean charts also were ANDed together, not ORed.
I.e. the expression was AND(AND(OR())), not OR(AND(OR())).

Original boolean charts also were "constraints on a single piece of data".
I.e. '(cc = foo) and (cc = bar)' within one boolean chart would match
nothing in original Bugzilla, as this would run the check on a single
user, which could not be 'foo' and 'bar' simultaneously.
But, '(cc = foo)' and '(cc = bar)' as two separate charts would match
bugs which have 'foo' as one CC AND 'bar' as another.

Now, this magic is only enabled for bug comments, bug changes, flags
and attachments. See "CORRELATED SEARCH TERMS" below.

FIXME: This magic is now a single piece of functionality which is lost
compared to the old search engine. The most correct solution is to allow
specifying 'subqueries' on _other_entities_ (not just bugs). For example:
(comment: subquery(author=A1 & date=D1)) & (comment: subquery(author=A2 & date=D2))

=head1 QUERY OPTIMISATION

The two main problems of Bugzilla query complexity on big databases were:

B<OR operators inside query which stop DBMS from using indexes for query speed-up.>

=over

I.e. for example "cc=X or commenter=X" was translated to 2 LEFT JOINs -
to cc and longdescs tables - and a term like "cc.who=X or longdescs.who=X".
DBMS can't do an index merge here, so this leads to a scan + two index checks.

B<SOLUTION:>

Use UNIONs instead of ORs. I.e. this same query is now translated to
(SELECT bug_id FROM cc WHERE who=X) UNION (SELECT bug_id FROM longdescs WHERE who=X).

It's important to note that the UNION of "non-seeding" queries is worse than OR,
because UNION must be always executed fully and can't be just checked while
executing other part of query.

B<SOLUTION:> (Partially experimental by now, but works)

Expand brackets in expressions. I.e. transform AND(a,OR(b,c)) to
OR(AND(a,b),AND(a,c)). This also allows to handle OR query parts with
correlated search terms.

=back

B<Usage of multiple JOINS with many rows in one query, leading to insane
amounts of rows when multiplied.>

=over

B<SOLUTION:>

Wrap them into (SELECT DISTINCT) subqueries if there is more than one such
term in the query. This removes duplicate rows from the result and makes
DBMS's life easier. To do so in Bugzilla, specify { many_rows => 1 } for such terms.

=back

=head1 SEARCH FUNCTIONS

Search functions get and return arguments through $self. Input arguments:

=over

=item $self->{sequence}

Sequence number of current condition, starting with 0. Used mostly to prevent table name collisions.

=item $self->{field}

Field name.

=item $self->{fieldsql}

Field SQL representation.

=item $self->{type}

Search operator type (equals, greaterthan, etc)

=item $self->{negated}

Most "negative" search operators (notequals, etc) are
automatically derived from negated terms for corresponding
"posivite" operators. So $self->{type} cannot be "negative",
and $self->{negated} contains true if it's really negative.

=item $self->{value}

Search value.

=item $self->{quoted}

SQL representation of value. Search functions must set this field
before calling default search operator implementation ($self->call_op)
if they want to use different SQL code for the value.

=back

=head2 OUTPUT ARGUMENT, $self->{term}

Resulting SQL condition or an expression consisting of several conditions.

All conditions are logically divided into two classes:
"scalar" conditions and "list" conditions. "Scalar" condition is a check of a
single value linked to single bug (for example, "bug assignee = somebody").
"List" condition is a check in the form of "ANY of linked values match condition"
or "NONE of linked values match condition". Many search conditions in Bugzilla
are specified as "List" conditions. A simple example is "CC" field:
"CC = somebody" is really "ANY CC is somebody" and "CC != somebody" is really
"NONE of CC is somebody".

"Scalar" conditions can be returned either as a simple string with SQL condition,
or as a hashref with following keys:

=over

=over

=item supp => [ " LEFT JOIN t1 ON ...", ... ]

Arrayref with table JOINs (plaintext with ON) required to match.

=item term => string

SQL condition string.

=item description => [ 'field', 'operator', 'value' ]

Search term description for the UI. It is not required for search functions to provide
this description unless they return an expression consisting of several terms.
The default 'field', 'operator' and 'value' are taken from the request.

=back

=back

"List" conditions must be always returned as a hashref with the following keys:

=over

=over

=item table => string,

Table specification with alias(es), just like <table> inside SQL query:

 ... JOIN <table> ON <condition> ...

For example, it may itself contain JOINs inside brace expressions:

 ... JOIN (table1 JOIN table2 ON ...) ON <condition> ...

$self->{sequence} should be appended to alias(es) to easily combat
table name collisions.

=item where => string,

Join <condition>. fields of 'bugs' table could be used for joining.

=item bugid_field => string,

When the <table> is joined to 'bugs' simply on 'bug_id',
and none of other 'bugs' fields are used, function should omit
"bugs.bug_id=table_alias.bug_id" from 'where', and specify
"tablealias.bug_id" as 'bugid_field'.

=item notnull_field => string,

When the <table> is joined to 'bugs' on some field other than 'bug_id',
'bugid_field' key MUST be omitted and any field of table that cannot
be NULL must be specified in 'notnull_field'. This is used in negative
lookups ("NONE of linked values match") for NULL checks.

=item neg => boolean value (1 or 0),

If a positive term corresponds to negative lookup, search function
can specify a true value for this key. Bugzilla search engine will then
negate the term itself.

=item many_rows => boolean value (1 or 0),

If many_rows is true, this term will be wrapped into a (SELECT DISTINCT bug_id ...)
subquery when INNER JOINed to different terms with many_rows. Use it when 'table'
could have relatively many rows for a single bug.

=item description => [ 'field', 'operator', 'value' ],

=back

=back

=head2 CORRELATED SEARCH TERMS

There is also a subclass of "list" conditions - conditions that can be
correlated. I.e., conditions that can possibly match different fields of
one entity linked to a bug (for example, comment date and comment author).
If the user specifies "comment date is ..." AND "comment author is ...",
then he probably means to find ONE comment with date and author matching
these terms.

To specify such conditions, search term must have different keys:

=over

=over

=item base_table => string,

The name of base table in which the entities linked to a bug are stored
without any aliases, subqueries or JOINs.

=item base_joins => [ [ 'LEFT'|'INNER', <table name>, <alias>, <on> ], ... ],

The names of tables which must be additionally joined to base table
to run the term.
LEFT|INNER is join type. <alias> MUST be non-unique (MUST not contain
$self->{sequence}). When two such terms are united, base_joins duplicates
are filtered based on <alias>. Unique aliases are then generated
automatically by SQL core.

=item where => string or [ string1, string2, ... ],

=item bugid_field => string,

=item notnull_field => string,

=item neg => 1|0,

=item many_rows => 1|0,

=item description => [ 'field', 'operator', 'value' ],

All these fields have meaning identical to their meaning in simple "list" conditions.

=back

=back

=head3 EXPLANATION

As it was mentioned above, original boolean charts in Bugzilla were
"constraints on a single piece of data".

This magic enables certain amount of power in queries, but is useful
only when the binary relation between the field and value is not
enough to spell the real condition.

Such conditions are possible only for ANDed terms, and only for "list"
bug fields, i.e. when there can be more than one entity linked to bug:
((e1 in A) & (e2 in B)) is not necessarily equal to (e in (A intersect B)),
which the user probably meant.

When there is no more than 1 entity linked to a bug, the situation
((e1 in A) & (e2 in B)) is impossible, as e1 and e2 may not be different.
So the condition is always (e in (A intersect B)).
Also, they are impossible for OR: swap e1 and e2 in ((e1 in A) | (e2 in B)),
and you'll get ((e2 in A) | (e1 in B)), OR it with unswapped term, and
you'll get (e in (A union B)).

In Bugzilla, this is possible for bug comments, bug changes, flags and attachments.
I.e. if somebody writes:

   commented after 2010-01-01
   AND commented before 2010-02-01
   AND commented by foo@bar.org

Then he probably means to search for bugs with a comment from foo@bar.org
left between 2010-01-01 and 2010-02-01, not for bugs with 3 different comments
corresponding to single terms.

=head2 EXPRESSIONS

Although this should be needed very rarely, search functions can also
return expressions consisting of several single conditions.

B<ATTENTION!> Functions that return expressions MUST specify $term->{description}
for each single term inside this expression to correctly generate search
descriptions in the UI.

An expression is an arrayref with the operation name as the first
element and operation arguments as the following ones. Possible operation
names are 'OR', 'AND', 'OR_MANY', 'AND_MANY', 'OR_NE', 'AND_NE'.
Each argument may either be an expression itself, or a search term in a
format returned by search functions.

OR is replaced with SQL UNION.

There are (partially experimental) variations of OR:

OR_NE is not expanded when its outer expression is expanded, i.e.
AND(OR(a,b),OR_NE(c,d)) becomes OR(AND(a,OR_NE(c,d)),AND(b,OR_NE(c,d))).

OR_MANY is attached as LEFT JOINs instead of an INNER JOIN to UNION,
if there are any terms ANDed with it.

Example: ((assignee=X) and (changed since 2008 or commented since 2008))
The second, predictably, produces an insane amount of rows itself,
so it's faster to scan rows selected by first and check the second on them.
But, it's faster to select simply (changed since 2008 or commented since 2008)
using indexes and UNION.

=cut

use strict;
use warnings;

package Bugzilla::Search;
use base qw(Exporter);

use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Constants;
use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::Field;
use Bugzilla::Status;
use Bugzilla::Keyword;
use Bugzilla::Search::Saved;

use Storable qw(dclone);
use Date::Format;
use Date::Parse;
use DateTime;

##############################################
## Catalogs: columns, search operators, etc ##
##############################################

# Some fields are not sorted on themselves, but on other fields.
# We need to have a list of these fields and what they map to.
# Each field points to an array that contains the fields mapped
# to, in order.
# Also when we add certain fields to the ORDER BY, we need to then add a
# table join to the FROM statement. This hash maps input fields to
# the join statements that need to be added.
sub SPECIAL_ORDER
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{special_order} if $cache->{special_order};
    my $special_order = {};
    my @select_fields = Bugzilla->get_fields({ type => FIELD_TYPE_SINGLE_SELECT });
    foreach my $field (@select_fields)
    {
        next if $field->name eq 'product' ||
            $field->name eq 'component' ||
            $field->name eq 'classification';
        my $type = $field->value_type;
        my $name = $type->DB_TABLE;
        $special_order->{$field->name} = {
            fields => [ map { "$name.$_" } split /\s*,\s*/, $type->LIST_ORDER ],
            joins  => [ "LEFT JOIN $name ON $name.".$type->ID_FIELD."=bugs.".$field->name ],
        };
    }
    Bugzilla::Hook::process('search_special_order', { columns => $special_order });
    return $cache->{special_order} = $special_order;
}

# Backwards-compatibility for old field names. Goes old_name => new_name.
sub COLUMN_ALIASES
{
    my $cache = Bugzilla->cache_fields;
    return $cache->{column_aliases} if $cache->{column_aliases};
    my $COLUMN_ALIASES = {
        opendate => 'creation_ts',
        changeddate => 'delta_ts',
        actual_time => 'work_time',
        changedin => 'days_elapsed',
        long_desc => 'longdesc',
        '[Bug creation]' => 'creation_ts',
    };
    Bugzilla::Hook::process('search_column_aliases', { aliases => $COLUMN_ALIASES });
    return $cache->{column_aliases} = $COLUMN_ALIASES;
}

# STATIC_COLUMNS and COLUMNS define the columns that can be selected in a query
# and/or displayed in a bug list. These are hashes of hashes. The key is field
# name, and the value is a hash with following data:
#
# FIXME change hash key names (id -> name, name -> sql, subid -> subname)
# 1. id: equals to the key of the outer hash (field name).
# 2. name: SQL code for field value.
# 3. joins: arrayref of table join SQL code needed to use this value.
# 4. title: The title of the column as displayed to users.
# 5. nobuglist: 1 for fields that cannot be displayed in bug list.
# 6. nocharts: 1 for fields that cannot be used in Boolean Charts.
#
# STATIC_COLUMNS is a constant and is freely cached between requests.
# COLUMNS is a subroutine that takes STATIC_COLUMNS, copies the hash,
# modifies it for the needs of current request and caches once per request.
# I.e. it removes time-tracking fields for non-timetrackers etc.

sub STATIC_COLUMNS
{
    my $dbh = Bugzilla->dbh;
    my $cache = Bugzilla->cache_fields;
    return $cache->{columns} if $cache->{columns};

    # ---- vfilippov@custis.ru 2010-02-02
    # Originally, JOINed longdescs table was used for actual_time calculation:
    # "(SUM(ldtime.work_time) * COUNT(DISTINCT ldtime.bug_when)/COUNT(bugs.bug_id))"
    # It was VERY slow on large databases, as there is normally A LOT OF comments to bugs.
    # It could also include boolean charts magic - modification of column meaning
    # depending on search terms, but it didn't :) so Mozilla guys, you don't even use
    # the full power of your magic approach :)
    #
    # Now, 'actual_time' is calculated using a subquery, and there is 'interval_time'
    # column which is modified depending on values entered into "Bug Changes" area
    # on the query form (chfieldfrom, chfieldto, chfieldwho fields)
    my $actual_time = '(SELECT SUM(ldtime.work_time) FROM longdescs ldtime WHERE ldtime.bug_id=bugs.bug_id)';

    my $columns = {
        relevance            => { title => 'Relevance' },
        assigned_to_realname => { title => 'Assignee Name' },
        reporter_realname    => { title => 'Reporter Name' },
        qa_contact_realname  => { title => 'QA Contact Name' },
        assigned_to_short    => { title => 'Assignee Login' },
        reporter_short       => { title => 'Reporter Login' },
        qa_contact_short     => { title => 'QA Contact Login' },
        # FIXME save aggregated work_time in bugs table and search on it
        work_time            => { name => $actual_time, numeric => 1 },
        interval_time        => { name => $actual_time, title => 'Period Worktime', numeric => 1 },
        percentage_complete  => {
            name => "(CASE WHEN $actual_time + bugs.remaining_time = 0.0 THEN 0.0" .
                " ELSE 100 * ($actual_time / ($actual_time + bugs.remaining_time)) END)",
            numeric => 1,
        },
        'flagtypes.name' => {
            name =>
                "(SELECT ".$dbh->sql_group_concat($dbh->sql_string_concat('col_ft.name', 'col_f.status'), "', '").
                " flagtypes FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id".
                " WHERE col_f.bug_id=bugs.bug_id)",
            title => "Flags and Requests",
        },
        flags => {
            name =>
                "(SELECT ".$dbh->sql_group_concat($dbh->sql_string_concat('col_ft.name', 'col_f.status'), "', '").
                " flags FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id".
                " WHERE col_f.bug_id=bugs.bug_id AND (col_ft.is_requesteeble=0 OR col_ft.is_requestable=0))",
            title => "Flags",
        },
        requests => {
            name => "(SELECT ".
                $dbh->sql_group_concat(
                    $dbh->sql_string_concat(
                        'col_ft.name', 'col_f.status',
                        'CASE WHEN col_p.login_name IS NULL THEN \'\' ELSE '.
                        $dbh->sql_string_concat("' '", 'col_p.login_name').' END'
                    ), "', '"
                )." requests FROM flags col_f JOIN flagtypes col_ft ON col_f.type_id=col_ft.id".
                " INNER JOIN profiles col_p ON col_f.requestee_id=col_p.userid".
                " WHERE col_f.bug_id=bugs.bug_id AND col_ft.is_requesteeble=1 AND col_ft.is_requestable=1)",
            title => "Requests",
        },
        dependson => {
            name  => "(SELECT ".$dbh->sql_group_concat('bugblockers.dependson', "','")." dependson FROM dependencies bugblockers WHERE bugblockers.blocked=bugs.bug_id)",
            title => "Bug dependencies",
        },
        blocked => {
            name  => "(SELECT ".$dbh->sql_group_concat('bugblocked.blocked', "','")." blocked FROM dependencies bugblocked WHERE bugblocked.dependson=bugs.bug_id)",
            title => "Bugs blocked",
        },
        deadline => {
            name => $dbh->sql_date_format('bugs.deadline', '%Y-%m-%d'),
        },
        dup_id => {
            name  => "duplicates.dupe_of",
            title => "Duplicate of",
            joins => [ "LEFT JOIN duplicates ON duplicates.dupe=bugs.bug_id" ],
        },
        comment0 => {
            title => "First Comment",
            noreports => 1,
        },
        lastcomment => {
            title => "Last Comment",
            noreports => 1,
        },
        lastcommenter => {
            title => "Last Commenter",
        },
        last_comment_time => {
            title => "Last Comment Time",
        },
        creation_ts_date => {
            nocharts => 1,
            title => "Creation Date",
            name => $dbh->sql_date_format('bugs.creation_ts', '%Y-%m-%d'),
        },
        'attachments.submitter' => {
            nobuglist => 1,
        },
    };

    # Search-only fields that were previously in fielddefs
    foreach my $col (qw(requestees.login_name setters.login_name longdescs.isprivate content commenter
        owner_idle_time attachments.submitter days_elapsed percentage_complete))
    {
        $columns->{$col}->{title} = Bugzilla->messages->{field_descs}->{$col};
        $columns->{$col}->{nobuglist} = 1;
    }

    # Fields that are email addresses
    foreach my $col (qw(assigned_to reporter qa_contact))
    {
        my $sql = "map_${col}.login_name";
        $columns->{$col}->{name} = $sql;
        $columns->{$col}->{trim_email} = 1;
        $columns->{$col.'_realname'}->{name} = "map_${col}.realname";
        $columns->{$col.'_short'}->{name} = $dbh->sql_string_until($sql, $dbh->quote('@'));
        # Only the qa_contact field can be NULL
        $columns->{$col}->{joins} =
        $columns->{$col.'_short'}->{joins} =
        $columns->{$col.'_realname'}->{joins} = [
            ($col eq 'qa_contact' ? 'LEFT' : 'INNER').
            " JOIN profiles AS map_$col ON bugs.$col = map_$col.userid"
        ];
    }

    # Other fields that are stored in the bugs table as an id, but
    # should be displayed using their name.
    foreach my $col (qw(product component classification))
    {
        $columns->{$col}->{name} = "map_${col}s.name";
        $columns->{$col}->{joins} = [
            "INNER JOIN ${col}s AS map_${col}s ON ".
            ($col eq 'classification' ? "map_products" : "bugs").
            ".${col}_id = map_${col}s.id"
        ];
        if ($col eq 'classification')
        {
            unshift @{$columns->{$col}->{joins}}, @{$columns->{product}->{joins}};
        }
    }

    # Do the actual column-getting from fielddefs, now.
    my $bug_columns = { map { $_ => 1 } Bugzilla::Bug->DB_COLUMNS };
    my @bugid_fields;
    foreach my $field (Bugzilla->get_fields)
    {
        my $id = $field->name;
        my $type = $field->value_type;
        $columns->{$id}->{title} = $field->description;
        # FIXME Maybe enable obsolete fields in search? Or do it optionally?
        $columns->{$id}->{nobuglist} = $field->obsolete || $id =~ /^attachments\.|^longdesc$/s;
        $columns->{$id}->{nocharts} = $field->obsolete;
        next if $id eq 'product' || $id eq 'component' || $id eq 'classification';
        if ($field->type == FIELD_TYPE_BUG_ID)
        {
            push @bugid_fields, $field;
            $columns->{$id}->{name} = "bugs.$id" if $id ne 'dup_id';
        }
        elsif ($field->type == FIELD_TYPE_BUG_ID_REV)
        {
            # FIXME: Если "обратных" (например, внутренних) багов несколько - join'енные поля по internal bugs работать не будут
            push @bugid_fields, $field;
            $columns->{$id}->{name} = "(SELECT ".
                $dbh->sql_group_concat("rev_$id.bug_id", "', '").
                " FROM bugs rev_$id WHERE rev_$id.".$field->value_field->name."=bugs.bug_id)";
        }
        elsif ($field->type == FIELD_TYPE_SINGLE_SELECT)
        {
            my $t = $type->DB_TABLE;
            $columns->{$id}->{name} = "$t.".$type->NAME_FIELD;
            $columns->{$id}->{joins} = [ "LEFT JOIN $t ON $t.".$type->ID_FIELD."=bugs.$id" ];
        }
        elsif ($field->type == FIELD_TYPE_MULTI_SELECT)
        {
            my $t = $type->DB_TABLE;
            $columns->{$id}->{name} = "(SELECT ".
                $dbh->sql_group_concat("$t.".$type->NAME_FIELD, "', '").
                " FROM ".$type->REL_TABLE.", $t WHERE $t.".$type->ID_FIELD."=".$type->REL_TABLE.".value_id".
                " AND ".$type->REL_TABLE.".bug_id=bugs.bug_id)";
        }
        elsif ($field->type == FIELD_TYPE_EAV_TEXTAREA)
        {
            my $t = "bug_".$field->name;
            $columns->{$id}->{name} = "$t.value";
            $columns->{$id}->{joins} = [ "LEFT JOIN $t ON $t.bug_id=bugs.bug_id" ];
        }
        elsif ($bug_columns->{$id})
        {
            $columns->{$id}->{name} ||= "bugs.$id";
            if ($field->type == FIELD_TYPE_NUMERIC)
            {
                $columns->{$id}->{numeric} = 1;
            }
        }
    }

    # Fields of bugs related to selected by some BUG_ID type field
    foreach my $field (@bugid_fields)
    {
        my $id = $field->name;
        my $join = [
            @{$columns->{$id}->{joins} || []},
            "LEFT JOIN bugs bugs_$id ON bugs_$id.bug_id=$columns->{$id}->{name}"
        ];
        my @subfields = Bugzilla->get_fields({ obsolete => 0 });
        @subfields = (
            (grep { $_->name eq 'product' } @subfields),
            (grep { $_->name ne 'product' } @subfields)
        );
        foreach my $subfield (@subfields)
        {
            my $subid = $subfield->name;
            if ($subid ne 'bug_id' && $columns->{$subid}->{name} && $columns->{$subid}->{name} eq "bugs.$subid")
            {
                $columns->{$id.'_'.$subid} = {
                    name  => "bugs_$id.".$subfield->name,
                    title => $field->description . ' ' . $subfield->description,
                    joins => $join,
                    subid => $subid,
                    sortkey => 1,
                };
            }
            elsif ($subid eq 'assigned_to' || $subid eq 'reporter' || $subid eq 'qa_contact')
            {
                $columns->{$id.'_'.$subid} = {
                    name => "map_${id}_${subid}.login_name",
                    title => $field->description . ' ' . $subfield->description,
                    subid => $subid,
                    sortkey => 1,
                    trim_email => 1,
                    joins => [ @$join, "LEFT JOIN profiles AS map_${id}_${subid} ON bugs_${id}.${subid}=map_${id}_${subid}.userid" ],
                };
            }
            elsif ($subid eq 'product' || $subid eq 'component' || $subid eq 'classification')
            {
                $columns->{$id.'_'.$subid} = {
                    name => "map_${id}_${subid}s.name",
                    title => $field->description . ' ' . $subfield->description,
                    subid => $subid,
                    sortkey => 1,
                    joins => [
                        ($subid eq 'classification' ? @{$columns->{$id.'_product'}->{joins}} : @$join),
                        "LEFT JOIN ${subid}s AS map_${id}_${subid}s ON ".
                        ($subid eq 'classification' ? "map_${id}_products" : "bugs_${id}").
                        ".${subid}_id = map_${id}_${subid}s.id"
                    ],
                };
            }
            elsif ($subid eq 'deadline')
            {
                $columns->{$id.'_'.$subid} = {
                    name => $dbh->sql_date_format("bugs_$id.deadline", '%Y-%m-%d'),
                    raw_name => "bugs_$id.deadline",
                    title => $field->description . ' ' . $subfield->description,
                    subid => $subid,
                    sortkey => 1,
                    joins => [ @$join ],
                };
            }
            elsif ($subfield->type == FIELD_TYPE_SINGLE_SELECT)
            {
                my $type = $subfield->value_type;
                my $t = $type->DB_TABLE;
                $columns->{$id.'_'.$subid} = {
                    name  => "bugs_$id"."_$t.".$type->NAME_FIELD,
                    title => $field->description . ' ' . $subfield->description,
                    joins => [ @$join, "LEFT JOIN $t bugs_$id"."_$t ON bugs_$id"."_$t.".$type->ID_FIELD."=bugs_$id.$subid" ],
                    subid => $subid,
                    sortkey => 1,
                };
            }
            elsif ($subfield->type == FIELD_TYPE_MULTI_SELECT)
            {
                my $type = $subfield->value_type;
                my $t = $type->DB_TABLE;
                $columns->{$id.'_'.$subid} = {
                    name  => "(SELECT ".
                        $dbh->sql_group_concat("$t.".$type->NAME_FIELD, "', '").
                        " FROM ".$type->REL_TABLE.", $t WHERE $t.".$type->ID_FIELD."=".$type->REL_TABLE.".value_id".
                        " AND ".$type->REL_TABLE.".bug_id=bugs_$id".".bug_id)",
                    title => $field->description . ' ' . $subfield->description,
                    joins => [ @$join ],
                    subid => $subid,
                    sortkey => 1,
                };
            }
            elsif ($subfield->type == FIELD_TYPE_MULTI_SELECT)
            {
                my $t = 'bug_'.$subfield->name;
                $columns->{$id.'_'.$subid} = {
                    name  => "bugs_$id"."_$t.value",
                    title => $field->description . ' ' . $subfield->description,
                    joins => [ @$join, "LEFT JOIN $t bugs_$id"."_$t ON bugs_$id"."_$t.bug_id=bugs_$id.bug_id" ],
                    subid => $subid,
                    sortkey => 1,
                };
            }
        }
    }

    for (qw(longdesc commenter work_time), grep { /\./ } keys %$columns)
    {
        $columns->{$_}->{may_be_correlated} = $columns->{$_}->{sortkey} = 1;
    }

    # short_short_desc is short_desc truncated to 60 characters
    # see template list/table.html.tmpl
    # FIXME move truncation away from templates
    $columns->{short_short_desc} = { %{ $columns->{short_desc} } };
    $columns->{short_short_desc}->{nocharts} = 1;
    $columns->{short_short_desc}->{noreports} = 1;

    # Needed for SuperWorkTime, would not be needed if buglist.cgi loaded bugs as objects
    $columns->{product_notimetracking} = {
        name => 'map_products.notimetracking',
        joins => $columns->{product}->{joins},
        nobuglist => 1,
        nocharts => 1,
    };

    Bugzilla::Hook::process('buglist_static_columns', { columns => $columns });

    $columns->{$_}->{id} = $_ for keys %$columns;

    $cache->{columns} = $columns;
    return $cache->{columns};
}

# Copy and modify STATIC_COLUMNS for current user / request
# Now only removes time-tracking fields
sub COLUMNS
{
    my ($self, $user) = @_;
    $user ||= Bugzilla->user;
    my $cache = Bugzilla->rc_cache_fields;
    return $cache->{columns}->{$user->id || ''} if $cache->{columns} && $cache->{columns}->{$user->id || ''};
    my $columns = { %{ STATIC_COLUMNS() } };

    # Non-timetrackers shouldn't see any time-tracking fields
    if (!$user->is_timetracker)
    {
        delete $columns->{$_} for keys %{TIMETRACKING_FIELDS()};
    }

    # Comment-related columns must honor current user's insider state
    my $hint = '';
    my $dbh = Bugzilla->dbh;
    if ($dbh->isa('Bugzilla::DB::Mysql'))
    {
        $hint = ' FORCE INDEX (longdescs_bug_id_idx)';
    }
    my $priv = ($user->is_insider ? "" : "AND ldc0.isprivate=0 ");
    # Not using JOIN (it could be joined on bug_when=creation_ts),
    # because it would require COALESCE to an 'isprivate' subquery
    # for private comments.
    $columns->{comment0} = {
        %{$columns->{comment0}},
        name => "(SELECT thetext FROM longdescs ldc0$hint WHERE ldc0.bug_id = bugs.bug_id $priv".
            " ORDER BY ldc0.bug_when LIMIT 1)",
    };
    $columns->{lastcomment} = {
        %{$columns->{lastcomment}},
        name => "(SELECT thetext FROM longdescs ldc0$hint WHERE ldc0.bug_id = bugs.bug_id $priv".
            " ORDER BY ldc0.bug_when DESC LIMIT 1)",
    };
    # Last commenter and last comment time
    my $login = 'ldp0.login_name';
    if (!$user->id)
    {
        $login = $dbh->sql_string_until($login, $dbh->quote('@'));
    }
    $columns->{lastcommenter} = {
        %{$columns->{lastcommenter}},
        name => "(SELECT $login FROM longdescs ldc0$hint".
            " INNER JOIN profiles ldp0 ON ldp0.userid=ldc0.who WHERE ldc0.bug_id = bugs.bug_id $priv".
            " ORDER BY ldc0.bug_when DESC LIMIT 1)",
    };
    $priv = ($user->is_insider ? "" : "AND lct.isprivate=0 ");
    $columns->{last_comment_time} = {
        %{$columns->{last_comment_time}},
        name => "(SELECT MAX(lct.bug_when) FROM longdescs lct$hint WHERE lct.bug_id = bugs.bug_id $priv)",
    };

    # Hide email domain for anonymous users
    $columns->{cc}->{name} = "(SELECT ".$dbh->sql_group_concat(($user->id
        ? 'profiles.login_name'
        : $dbh->sql_string_until('profiles.login_name', $dbh->quote('@'))), "','").
        " cc FROM cc, profiles WHERE cc.bug_id=bugs.bug_id AND cc.who=profiles.userid)";
    if (!$user->id)
    {
        foreach my $col (keys %$columns)
        {
            if ($columns->{$col}->{trim_email})
            {
                $columns->{$col} = {
                    %{$columns->{$col}},
                    name => $dbh->sql_string_until($columns->{$col}->{name}, $dbh->quote('@')),
                };
            }
        }
    }

    Bugzilla::Hook::process('buglist_columns', { columns => $columns });
    return $cache->{columns}->{$user->id || ''} = $columns;
}

sub REPORT_COLUMNS
{
    my ($self, $user) = @_;
    $user ||= Bugzilla->user;
    my $cache = Bugzilla->request_cache;
    return $cache->{report_columns}->{$user->id || ''} if $cache->{report_columns} && $cache->{report_columns}->{$user->id || ''};

    my $columns = { %{ $self->COLUMNS($user) } };

    # There's no reason to support reporting on unique fields.
    my @no_report_columns = qw(
        bug_id alias short_short_desc opendate changeddate delta_ts relevance
    );
    # Do not report on obsolete columns.
    push @no_report_columns, map { $_->name } Bugzilla->get_fields({ obsolete => 1 });
    # Subselect fields are also not supported.
    push @no_report_columns, grep {
        /\./ || $columns->{$_}->{noreports} ||
        $columns->{$_}->{nobuglist}
    } keys %$columns;
    # Unset non-reportable columns
    foreach my $name (@no_report_columns)
    {
        delete $columns->{$name};
    }

    foreach my $field (Bugzilla->get_fields)
    {
        if ($field->type == FIELD_TYPE_MULTI_SELECT)
        {
            my $type = $field->value_type;
            $columns->{$field->name} = {
                id    => $field->name,
                name  => $type->DB_TABLE.'.'.$type->NAME_FIELD,
                title => $field->description,
                joins => [
                    "LEFT JOIN ".$type->REL_TABLE." ON ".$type->REL_TABLE.".bug_id=bugs.bug_id",
                    "LEFT JOIN ".$type->DB_TABLE." ON ".$type->DB_TABLE.".".$type->ID_FIELD."=".$type->REL_TABLE.".value_id"
                ],
            };
        }
    }

    return $cache->{report_columns}->{$user->id || ''} = $columns;
}

# Fields that can be searched on for changes
# This is now used only by query.cgi
# Depends on current user
sub CHANGEDFROMTO_FIELDS
{
    # creation_ts, longdesc, longdescs.isprivate, commenter are treated specially
    my @fields = map { {
        id => $_->{name},
        name => $_->{description},
    } } Bugzilla->get_fields({ has_activity => 1 });
    @fields = grep { $_->{id} ne 'creation_ts' && $_->{id} ne 'longdesc' } @fields;
    push @fields, map { {
        id => $_,
        name => Bugzilla->messages->{field_descs}->{$_},
    } } ('creation_ts', 'longdesc', 'commenter', Bugzilla->user->is_insider ? 'longdescs.isprivate' : ());
    if (!Bugzilla->user->is_timetracker)
    {
        @fields = grep { !TIMETRACKING_FIELDS->{$_->{id}} } @fields;
    }
    return \@fields;
}

# Search operators
use constant OPERATORS => {
    equals          => \&_equals,
    casesubstring   => \&_casesubstring,
    substring       => \&_substring,
    substr          => \&_substring,
    regexp          => \&_regexp,
    matches         => sub { ThrowUserError('search_content_without_matches'); },
    lessthan        => \&_lessthan,
    lessthaneq      => \&_lessthaneq,
    anyexact        => \&_anyexact,
    anywordssubstr  => \&_anywordssubstr,
    allwordssubstr  => \&_allwordssubstr,
    anywords        => \&_anywords,
    allwords        => \&_allwords,
    changedbefore   => \&_changedbefore_changedafter,
    changedafter    => \&_changedbefore_changedafter,
    changedfrom     => \&_changedfrom_changedto,
    changedto       => \&_changedfrom_changedto,
    changedby       => \&_changedby,
    insearch        => \&_in_search_results,
};

# Search operators calculated as the negation of other ones
use constant NEGATE_OPERATORS => {
    noneexact     => 'anyexact',
    notequals     => 'equals',
    notsubstring  => 'substring',
    notregexp     => 'regexp',
    notmatches    => 'matches',
    nowordssubstr => 'anywordssubstr',
    nowords       => 'anywords',
    notinsearch   => 'insearch',
    greaterthaneq => 'lessthan',
    greaterthan   => 'lessthaneq',
};

use constant NEGATE_ALL_OPERATORS => {
    %{ NEGATE_OPERATORS() },
    reverse %{ NEGATE_OPERATORS() }
};

# These search operators are hidden in the description after searching,
# i.e. "A equals B" is displayed just as "A: B"
use constant SEARCH_HIDDEN_OPERATORS => {
    equals          => 1,
    casesubstring   => 1,
    substring       => 1,
    substr          => 1,
    matches         => 1,
    anywordssubstr  => 1,
    allwordssubstr  => 1,
    anywords        => 1,
    allwords        => 1,
    insearch        => 1,
};

# Search operators that accept multiple values for search
use constant SEARCH_MULTIVALUE_OPERATORS => {
    anyexact        => 1,
    anywordssubstr  => 1,
    allwordssubstr  => 1,
    nowordssubstr   => 1,
    anywords        => 1,
    allwords        => 1,
    nowords         => 1,
};

# Search operators used for searching in Boolean Charts
use constant CHART_OPERATORS_ORDER => [qw(
    noop
    equals notequals anyexact
    substring casesubstring notsubstring
    anywordssubstr allwordssubstr nowordssubstr
    regexp notregexp
    lessthan greaterthan
    lessthaneq greaterthaneq
    anywords allwords nowords
    changedbefore changedafter changedfrom changedto changedby
    matches notmatches
    insearch notinsearch
)];

# Search operators used for searching on text fields
use constant TEXT_OPERATORS_ORDER => [qw(
    allwordssubstr anywordssubstr
    substring casesubstring
    allwords anywords regexp notregexp
)];

# Search functions, i.e. search operator overrides for individual fields.
# '|' in hash keys is expanded as the "OR"-list.
my $FUNCTIONS;
sub FUNCTIONS
{
    return $FUNCTIONS if $FUNCTIONS;
    my $multi_fields = join '|', map { $_->name } Bugzilla->get_fields({
        type     => [ FIELD_TYPE_MULTI_SELECT ],
        obsolete => 0
    });
    my $bugid_rev_fields = join '|', map { $_->name } Bugzilla->get_fields({
        type     => FIELD_TYPE_BUG_ID_REV,
        obsolete => 0
    });
    my @bugid_fields = Bugzilla->get_fields({ type => FIELD_TYPE_BUG_ID });
    my $date_fields = join '|', ((map { $_->name } Bugzilla->get_fields({
        type     => FIELD_TYPE_DATETIME,
        obsolete => 0
    })), (map { $_->name.'_deadline' } @bugid_fields));
    $FUNCTIONS = {
        'blocked|dependson' => {
            '*' => \&_blocked_dependson,
        },
        'assigned_to|reporter|qa_contact' => {
            '*' => \&_contact,
        },
        'cc' => { '*' => \&_cc_nonchanged, },
        'longdesc|long_desc' => {
            'changedbefore|changedafter' => \&_long_desc_changedbefore_after,
            'changedfrom' => sub { $_[0]->{term} = $_[0]->{value} eq '' ? "1=1" : "1=0" },
            'changedby' => \&_long_desc_changedby,
            '*' => \&_long_desc,
        },
        'commenter' => {
            'changedbefore|changedafter' => \&_long_desc_changedbefore_after,
            'changedfrom' => sub { $_[0]->{term} = $_[0]->{value} eq '' ? "1=1" : "1=0" },
            'changedto' => \&_commenter_changedto,
            'changedby' => \&_long_desc_changedby,
            '*' => \&_commenter,
        },
        'longdescs.isprivate' => { '*' => \&_longdescs_isprivate, },
        'interval_time|work_time' => {
            'changedbefore|changedafter' => \&_work_time_changedbefore_after,
            # FIXME work_time changedfrom/changedto must match the sum,
            # but now changedfrom will only match empty strings,
            # and changedto will match individual work time items
            # This is not easily fixable, as the bugs_activity stores
            # individual work_time items, not the aggregated sum.
            'changedfrom|changedto' => \&_changedfrom_changedto,
            'changedby' => \&_work_time_changedby,
            'equals' => \&_work_time_equals_0,
        },
        'content' => {
            'matches' => \&_content_matches,
            '*' => sub { ThrowUserError('search_content_without_matches'); },
        },
        'changes' => {
            'changed' => \&changed,
            '*' => sub { ThrowUserError('search_changes_without_changed'); },
        },
        'deadline|creation_ts|delta_ts'.($date_fields ? '|'.$date_fields : '') => {
            'lessthan|lessthaneq|greaterthan|greaterthaneq|equals|notequals' => \&_timestamp_compare,
        },
        'days_elapsed' => {
            'lessthan|lessthaneq|greaterthan|greaterthaneq|equals|notequals' => \&_days_elapsed,
            '*' => sub { ThrowUserError('search_days_elapsed_non_numeric') },
        },
        'owner_idle_time' => {
            'lessthan' => \&_owner_idle_time_less,
            'lessthaneq' => \&_owner_idle_time_less,
            '*' => sub { ThrowUserError('search_owner_non_less') },
        },
        'bug_group'                 => { '*' => \&_bug_group_nonchanged },
        'attachments.submitter'     => { '*' => \&_attachments_submitter },
        'attachments.description|attachments.filename|'.
        'attachments.isobsolete|attachments.ispatch|'.
        'attachments.isprivate|attachments.mimetype' => { '*' => \&_attachments },
        'flagtypes.name'            => { '*' => \&_flagtypes_name_nonchanged, },
        'requestees.login_name'     => { '*' => \&_requestees_login_name },
        'setters.login_name'        => { '*' => \&_setters_login_name },
        $multi_fields               => { '*' => \&_multiselect_nonchanged },
        $bugid_rev_fields           => { '*' => \&_bugid_rev_nonchanged },
        'see_also'                  => { '*' => \&_see_also_nonchanged },
    };
    # Expand | or-lists in hash keys
    expand_hash($FUNCTIONS);
    # Add undefs to cancel override of changed*
    for my $k (keys %$FUNCTIONS)
    {
        $FUNCTIONS->{$k}->{"changed$_"} ||= undef for qw(before after from to by);
    }
    return $FUNCTIONS;
}

####################
## Object Methods ##
####################

# Create a new Bugzilla::Search object
sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $self = { @_ };
    bless($self, $class);

    $self->init();

    return $self;
}

sub clean_search_params
{
    shift if $_[0] eq __PACKAGE__;
    my ($params) = @_;

    # Delete any empty URL parameter.
    foreach my $key (keys %$params)
    {
        if (!defined $params->{$key} || $params->{$key} eq '')
        {
            delete $params->{$key};
            delete $params->{$key.'_type'};
        }
        elsif ($key =~ /\d-\d-\d/ && (!defined $params->{$key} || $params->{$key} eq 'noop'))
        {
            # Boolean Chart stuff is empty if it's "noop"
            delete $params->{$key};
        }
    }

    # Delete leftovers from the login form
    delete $params->{$_} for qw(Bugzilla_remember GoAheadAndLogIn);

    foreach my $num (1, 2)
    {
        # If there's no value in the email field, delete the related fields.
        if (!$params->{"email$num"})
        {
            foreach my $field (qw(type assigned_to reporter qa_contact cc longdesc))
            {
                delete $params->{"email$field$num"};
            }
        }
    }

    # chfieldto is set to "Now" by default in query.cgi.
    if (lc($params->{chfieldto} || '') eq 'now')
    {
        delete $params->{chfieldto};
    }

    # cmdtype "doit" is the default from query.cgi, but it's only meaningful
    # if there's a remtype parameter.
    if (defined $params->{cmdtype} && $params->{cmdtype} eq 'doit' && !defined $params->{remtype})
    {
        delete $params->{cmdtype};
    }

    # "Reuse same sort as last time" is actually the default, so we don't need it in the URL.
    if (($params->{order} || '') eq 'Reuse same sort as last time' ||
        ($params->{order} || '') eq '_reuse')
    {
        delete $params->{order};
    }

    # And now finally, if query_format is our only parameter, that
    # really means we have no parameters, so we should delete query_format.
    if ($params->{query_format} && scalar(keys %$params) == 1)
    {
        delete $params->{query_format};
    }

    return $params;
}

# The main Bugzilla::Search function - parses search
# parameters, builds search terms and SQL query
sub init
{
    my $self = shift;
    my @fields = @{ $self->{fields} || [] };

    my $H = $self->{params};

    # $self->{user} = User under which the search will be ran (current user by default)
    $self->{user} ||= Bugzilla->user;
    my $user = $self->{user};
    my $dbh = Bugzilla->dbh;
    my $columns = $self->{columns} = $self->COLUMNS($user);

    my @specialchart;

    ###################
    ## Bug selection ##
    ###################

    # First, deal with all the old hard-coded non-chart-based poop.
    my $minvotes;
    if ($H->{votes})
    {
        my $c = trim($H->{votes});
        if ($c ne "")
        {
            if ($c !~ /^\d+$/)
            {
                ThrowUserError("illegal_at_least_x_votes", { value => $c });
            }
            push @specialchart, ["votes", "greaterthan", $c - 1];
        }
    }

    # If the user has selected all of either status or resolution, change to
    # selecting none. This is functionally equivalent, but quite a lot faster.
    # Also, if the status is __open__ or __closed__, translate those
    # into their equivalent lists of open and closed statuses.
    # FIXME this should be done for all multi-select fields,
    # not only for bug_status and resolution
    if ($H->{bug_status})
    {
        my @bug_statuses = list $H->{bug_status};
        # Also include inactive bug statuses, as you can query them.
        my $legal = Bugzilla->get_field('bug_status')->legal_values;
        my %legal_hash = map { $_->name => 1 } @$legal;

        # Filter out any statuses that have been removed completely that are still
        # being used by the client
        my %statuses;
        foreach my $status (@bug_statuses)
        {
            if ($status eq '__all__')
            {
                %statuses = %legal_hash;
                last;
            }
            elsif ($status eq '__open__')
            {
                $statuses{$_->name} = 1 for grep { $_->is_open } @$legal;
            }
            elsif ($status eq '__closed__')
            {
                $statuses{$_->name} = 1 for grep { !$_->is_open } @$legal;
            }
            else
            {
                $statuses{$status} = 1 if $legal_hash{$status};
            }
        }
        if (keys %statuses == scalar @$legal)
        {
            delete $H->{bug_status};
        }
        else
        {
            $H->{bug_status} = [ keys %statuses ];
        }
    }

    if ($H->{resolution})
    {
        my %resolutions = map { $_ => 1 } list $H->{resolution};
        # Also include inactive resolutions and '---', as you can query them.
        my $legal_resolutions = Bugzilla->get_field('resolution')->legal_values;
        if (keys %resolutions == 1 + scalar @$legal_resolutions)
        {
            delete $H->{resolution};
        }
    }

    # All fields that don't have a . in their name should be specifyable
    # in the URL directly.
    my $legal_fields = { map { $_->name => 1 } grep { $_->name !~ /\./ } Bugzilla->get_fields };
    if (!$user->is_timetracker)
    {
        delete $legal_fields->{$_} for keys %{TIMETRACKING_FIELDS()};
    }

    if (exists $H->{bugidtype})
    {
        $H->{bug_id_type} = delete $H->{bugidtype} eq 'exclude' ? 'nowords' : 'anyexact';
    }

    # Extract <field> and <field>_type from parameters
    foreach (keys %$H)
    {
        my $field = $_;
        # respect aliases
        $field = COLUMN_ALIASES->{$field} || $field;
        # "votes" got special treatment, above.
        next if $field eq 'votes';
        my $type = $H->{$_.'_type'};
        if ($legal_fields->{$field} || FUNCTIONS->{$field} || $type)
        {
            my $values = [ list $H->{$_} ];
            next if !length join '', @$values;
            if ($field eq 'content')
            {
                $type = 'matches';
                $values = trim(join ' ', @$values);
            }
            elsif ($field eq 'bug_id')
            {
                $type = $type || $H->{bugidtype} || 'include';
                $type = 'anyexact' if $type eq 'include';
                $type = 'noneexact' if $type eq 'exclude';
                if (SEARCH_MULTIVALUE_OPERATORS->{$type ||= 'anyexact'})
                {
                    $values = [ map { /(\d+)/gso } @$values ];
                }
                else
                {
                    $values = $values->[0];
                }
            }
            elsif (!$type)
            {
                $type = 'anyexact';
                if ($field eq 'days_elapsed')
                {
                    $values = $values->[0];
                    $type = 'lessthan';
                }
            }
            elsif (!SEARCH_MULTIVALUE_OPERATORS->{$type})
            {
                $values = $values->[0];
            }
            push @specialchart, [ $field, $type, $values ];
        }
    }

    # Extract "email" form parts
    foreach my $id ("1", "2")
    {
        my $email = trim($H->{"email$id"});
        next if !defined $email || !length $email;

        my $type = $H->{"emailtype$id"};
        $type = "anyexact" if $type eq "exact";

        if ($type eq "anyexact")
        {
            my @guessed = split /,/, $email;
            foreach my $name (@guessed)
            {
                $name = trim($name);
                if ($name && lc $name ne '%user%' && !Bugzilla::User::login_to_id($name))
                {
                    # Do a match on user login or name
                    my $u = Bugzilla::User::match_name($name, 1)->[0];
                    if ($u)
                    {
                        $name = $u->login;
                    }
                    else
                    {
                        ThrowUserError('invalid_username', { name => $name });
                    }
                }
            }
            $email = join ',', @guessed;
        }

        my @clist;
        foreach my $field ("assigned_to", "reporter", "cc", "qa_contact")
        {
            push @clist, $field, $type, $email if $H->{"email$field$id"};
        }
        if ($H->{"emaillongdesc$id"})
        {
            push @clist, "commenter", $type, $email;
        }
        if (@clist)
        {
            push @specialchart, \@clist;
        }
        else
        {
            # No field is selected. Nothing to see here.
            next;
        }
    }

    # Setup interval_time column
    if ($self->{user}->is_timetracker)
    {
        my $override = $H->{period_from} || $H->{period_to} || $H->{period_who};
        $self->{interval_from} = $override ? $H->{period_from} : $H->{chfieldfrom};
        $self->{interval_to} = $override ? $H->{period_to} : $H->{chfieldto};
        $self->{interval_who} = $override ? $H->{period_who} : $H->{chfieldwho};
        for ($self->{interval_from}, $self->{interval_to})
        {
            $_ = $_ && lc $_ ne 'now' ? SqlifyDate($_) : undef;
        }
        for ($self->{interval_who})
        {
            $_ = $_ ? ($_ eq '%user%' ? $self->{user} : Bugzilla::User::match_name($_, 1)->[0]) : undef;
        }
        $columns->{interval_time}->{name} =
            "(SELECT COALESCE(SUM(ldtime.work_time),0) FROM longdescs ldtime".
            " WHERE ldtime.bug_id=bugs.bug_id".
            ($self->{interval_from} ? " AND ldtime.bug_when >= ".$dbh->quote($self->{interval_from}) : '').
            ($self->{interval_to} ? " AND ldtime.bug_when <= ".$dbh->quote($self->{interval_to}) : '').
            ($self->{interval_who} ? " AND ldtime.who = ".$self->{interval_who}->id : '').
            ")";
    }

    # Add "only bugs changed between..."
    my $chfieldfrom = trim(lc($H->{chfieldfrom} || ''));
    my $chfieldto = trim(lc($H->{chfieldto} || ''));
    $chfieldfrom = '' if $chfieldfrom eq 'now';
    $chfieldto = '' if $chfieldto eq 'now';
    if ($chfieldfrom ne '' || $chfieldto ne '')
    {
        my @chfield = map { COLUMN_ALIASES->{$_} || $_ } list $H->{chfield};
        push @specialchart, [ 'changes', 'changed', {
            fields  => \@chfield,
            after   => $chfieldfrom,
            before  => $chfieldto,
            who     => trim(lc($H->{chfieldwho} || '')),
            value   => trim($H->{chfieldvalue} || ''),
        } ];
    }

    if ($user->is_timetracker)
    {
        if ($H->{deadlinefrom})
        {
            push @specialchart, [ 'deadline', 'greaterthaneq', $H->{deadlinefrom} ];
        }
        if ($H->{deadlineto})
        {
            push @specialchart, [ 'deadline', 'lessthaneq', $H->{deadlineto} ];
        }
    }

    # Reset relevance column
    $columns->{relevance}->{bits} = [];
    $columns->{relevance}->{joins} = [];
    $columns->{relevance}->{name} = '(0)';

    # Read charts from form hash
    my @charts;
    for (keys %$H)
    {
        if (/^(field|type|value)(\d+)-(\d+)-(\d+)$/so)
        {
            $charts[1+$2]{rows}[$3][$4]{$1} = $H->{$_};
        }
        elsif (/^negate(\d+)$/so)
        {
            $charts[1+$1]{negate} = $H->{$_};
        }
    }

    # Add specialchart terms
    # There is no need to remove chart -1 from form hash
    my ($chart, $row, $col) = (0, 0, 0);
    foreach my $ref (@specialchart)
    {
        $col = 0;
        while (@$ref)
        {
            @{$charts[0]{rows}[$row][$col]}{'field', 'type', 'value'} = splice @$ref, 0, 3;
            $col++;
        }
        $row++;
    }

    # Run charts
    my $QUERY_OR = [ 'OR' ];
    my $OUTER_AND = [ 'AND', $QUERY_OR ];
    my $func;
    $self->{sequence} = 0;
    for $chart (0..$#charts)
    {
        my $CHART_AND = [ 'AND' ];
        for $row (0..$#{$charts[$chart]{rows}})
        {
            # OR_NE for special charts
            my $ROW_OR = [ $chart ? 'OR' : 'OR_NE' ];
            for $col (0..$#{$charts[$chart]{rows}[$row]})
            {
                my $term = $self->run_chart(
                    $charts[$chart]{rows}[$row][$col]{field},
                    $charts[$chart]{rows}[$row][$col]{type},
                    $charts[$chart]{rows}[$row][$col]{value},
                    $chart != 0
                );
                push @$ROW_OR, $term if $term;
                $self->{sequence}++;
            }
            push @$CHART_AND, $ROW_OR if @$ROW_OR > 1;
        }
        next if @$CHART_AND == 1; # empty query
        # Negate the whole $CHART_AND
        if ($charts[$chart]{negate})
        {
            $CHART_AND = negate_expression($CHART_AND);
        }
        if (!$chart)
        {
            # Special chart is ANDed at the outer level
            push @$OUTER_AND, $CHART_AND;
        }
        else
        {
            # Other charts are ORed
            push @$QUERY_OR, $CHART_AND;
        }
    }

    # Simplify and save expression without security terms
    $OUTER_AND = simplify_expression($OUTER_AND);
    $self->{terms_without_security} = $OUTER_AND;
    $OUTER_AND = expand_expression($OUTER_AND);

    # Check if the query is empty
    if (!$OUTER_AND)
    {
        # Not Bugzilla->cgi->send_header, because it respects e-mail/console usage
        Bugzilla->send_header(-refresh => '10; URL=query.cgi');
        ThrowUserError("buglist_parameters_required");
    }

    # Determine global equality operators
    $self->{equalities} = [];
    if (ref $OUTER_AND eq 'HASH' || substr($OUTER_AND->[0], 0, 3) eq 'AND')
    {
        foreach my $term (ref $OUTER_AND eq 'HASH' ? $OUTER_AND : @$OUTER_AND)
        {
            if (ref $term eq 'HASH' && ($term->{description}->[1] eq 'equals' ||
                $term->{description}->[1] eq 'anyexact' || $term->{description}->[1] eq 'anywords' ||
                $term->{description}->[1] eq 'allwords'))
            {
                push @{$self->{equalities}}, $term->{description};
            }
        }
    }

    if (!$self->{ignore_permissions})
    {
        # If there are some terms in the search, assume it's enough
        # to select bugs and attach security terms without UNION (OR_MANY).
        # Or in the special case, when the search does not contain any terms,
        # i.e., when it contains only the security restrictions, attach them
        # in normal efficient way, using UNIONs.
        $OUTER_AND = [ 'AND', $OUTER_AND,
            [ $OUTER_AND ? 'OR_MANY' : 'OR', {
                table => 'bug_group_map g',
                where => @{$user->groups} ? 'g.group_id NOT IN ('.$user->groups_as_string.')' : undef,
                bugid_field => 'g.bug_id',
                neg => 1,
            }, ($user->id ? ({
                table => 'cc',
                where => 'cc.who='.$user->id.' AND bugs.cclist_accessible=1 AND bugs.bug_id=cc.bug_id',
                notnull_field => 'cc.bug_id',
            }, {
                # We don't need to use UNION for this - even MySQL successfully
                # does index merge on such conditions
                term => '(bugs.reporter_accessible = 1 AND bugs.reporter='.$user->id.
                    ' OR bugs.assigned_to='.$user->id.
                    (Bugzilla->get_field('qa_contact')->enabled ? ' OR bugs.qa_contact='.$user->id : '').')'
            }) : ()) ]
        ];
    }

    # Simplify and save expression
    $OUTER_AND = simplify_expression($OUTER_AND);
    $self->{terms} = $OUTER_AND;
    $OUTER_AND = $self->auto_merge_correlated($OUTER_AND);

    $self->{sequence} = 0;
    $self->{bugid_query} = $self->get_expression_sql($OUTER_AND);

    my @supptables = " INNER JOIN ($self->{bugid_query}) bugids ON bugids.bug_id=bugs.bug_id";

    ###############################
    ## Bug fields and sort order ##
    ###############################

    my $special_order = SPECIAL_ORDER();
    my @inputorder = @{ $self->{order} || [] };
    my @orderby;

    for (@fields)
    {
        $_ = COLUMN_ALIASES->{$_} if COLUMN_ALIASES->{$_};
    }

    # All items that are in the ORDER BY must be in the SELECT.
    foreach my $orderitem (@inputorder)
    {
        my $column_name = split_order_term($orderitem);
        $column_name = COLUMN_ALIASES->{$column_name} if COLUMN_ALIASES->{$column_name};
        if (!grep($_ eq $column_name, @fields))
        {
            push @fields, $column_name;
        }
    }

    # The ORDER BY clause goes last, but can require modifications
    # to other parts of the query, so we want to create it before we
    # write the FROM clause.
    foreach my $orderitem (@inputorder)
    {
        $self->BuildOrderBy($special_order, $orderitem, \@orderby);
    }

    # Now JOIN the correct tables in the FROM clause.
    foreach my $orderitem (@inputorder)
    {
        # Grab the part without ASC or DESC.
        my $column_name = split_order_term($orderitem);
        for my $t (@{ $special_order->{$column_name}->{joins} || [] })
        {
            push @supptables, $t if !grep { $_ eq $t } @supptables;
        }
    }

    my @sql_fields;
    foreach my $field (@fields)
    {
        for my $t (@{ $columns->{$field}->{joins} || [] })
        {
            push @supptables, $t if !grep { $_ eq $t } @supptables;
        }
        if ($columns->{$field}->{name})
        {
            my $alias = $field;
            # Aliases cannot contain dots in them. We convert them to underscores.
            $alias =~ s/\./_/g;
            push @sql_fields, $columns->{$field}->{name} . " AS $alias";
        }
        else
        {
            push @sql_fields, $field;
        }
    }
    my $suppstring .= 'bugs'.join("\n", @supptables);
    my $query = "SELECT " . join(",\n", @sql_fields) . " FROM $suppstring";
    $query .= " ORDER BY " . join(', ', @orderby) if @orderby;

    $self->{sql} = $query;
}

sub get_columns
{
    my $class = shift;
    my ($params, $user) = @_;
    my $displaycolumns;

    if (defined $params->{columnlist} && $params->{columnlist} ne 'all')
    {
        $displaycolumns = [ split(/[ ,]+/, $params->{columnlist}) ];
    }
    elsif (defined Bugzilla->cookies->{COLUMNLIST})
    {
        $displaycolumns = [ split(/ /, Bugzilla->cookies->{COLUMNLIST}) ];
    }
    else
    {
        # Use the default list of columns.
        $displaycolumns = [ DEFAULT_COLUMN_LIST ];
    }

    # Figure out whether or not the user is doing a fulltext search.  If not,
    # we'll remove the relevance column from the lists of columns to display
    # and order by, since relevance only exists when doing a fulltext search.
    my $fulltext = $params->{content} ||
        grep { $params->{$_} eq 'content' && /^field(\d+-\d+-\d+)/ && $params->{"value$1"} } keys %$params;

    my $columns = $class->COLUMNS($user);
    $_ = $class->COLUMN_ALIASES->{$_} || $_ for @$displaycolumns;
    @$displaycolumns = grep($columns->{$_} && trick_taint($_), @$displaycolumns);
    if (!$user->is_timetracker)
    {
        @$displaycolumns = grep { !TIMETRACKING_FIELDS->{$_} } @$displaycolumns;
    }
    # Remove the relevance column if the user is not doing a fulltext search.
    if (grep('relevance', @$displaycolumns) && !$fulltext)
    {
        @$displaycolumns = grep($_ ne 'relevance', @$displaycolumns);
    }
    @$displaycolumns = grep($_ ne 'bug_id', @$displaycolumns);

    # The bug ID is always selected because bug IDs are always displayed.
    # Severity, priority, resolution and status are required for buglist
    # CSS classes.
    # Display columns are selected because otherwise we could not display them.
    my $selectcolumns = { map { $_ => 1 } (qw(bug_id bug_severity priority bug_status resolution product), @$displaycolumns) };

    # Make sure that the login_name version of a field is always also
    # requested if the realname version is requested, so that we can
    # display the login name when the realname is empty.
    my @realname_fields = grep(/_realname$|_short$/, @$displaycolumns);
    foreach my $item (@realname_fields)
    {
        my $login_field = $item;
        $login_field =~ s/_realname$|_short$//;
        $selectcolumns->{$login_field} = 1;
    }

    return ($displaycolumns, [ keys %$selectcolumns ]);
}

sub get_order
{
    my $class = shift;
    my ($params, $user) = @_;
    my $order = $params->{order} || "";

    # First check if we'll want to reuse the last sorting order; that happens if
    # the order is not defined or its value is "reuse last sort"
    if (!$order || $order =~ /^reuse/i)
    {
        if ($order = Bugzilla->cookies->{LASTORDER})
        {
            # Cookies from early versions of Specific Search included this text,
            # which is now invalid.
            $order =~ s/ LIMIT 200//;
        }
        else
        {
            $order = '';  # Remove possible "reuse" identifier as unnecessary
        }
    }

    my $columns = $class->COLUMNS($user);
    my $fulltext = $params->{content} ||
        grep { $params->{$_} eq 'content' && /^field(\d+-\d+-\d+)/ && $params->{"value$1"} } keys %$params;

    my $old_orders = {
        '' => 'bug_status,priority,assigned_to,bug_id', # Default
        'bug number' => 'bug_id',
        'importance' => 'priority,bug_severity,bug_id',
        'assignee' => 'assigned_to,bug_status,priority,bug_id',
        'last changed' => 'delta_ts,bug_status,priority,assigned_to,bug_id',
    };
    my @invalid_fragments;
    my @orderstrings;
    if ($order)
    {
        # Convert the value of the "order" form field into a list of columns
        # by which to sort the results.
        if ($old_orders->{lc $order})
        {
            @orderstrings = split /,/, $old_orders->{lc $order};
        }
        else
        {
            trick_taint($order);
            # A custom list of columns.  Make sure each column is valid.
            foreach my $fragment (split(/,/, $order))
            {
                $fragment = trim($fragment);
                next unless $fragment;
                my ($column_name, $direction) = Bugzilla::Search::split_order_term($fragment);
                $column_name = Bugzilla::Search::translate_old_column($column_name);

                # Special handlings for certain columns
                next if $column_name eq 'relevance' && !$fulltext;

                # If we are sorting by votes, sort in descending order if
                # no explicit sort order was given.
                if ($column_name eq 'votes' && !$direction)
                {
                    $direction = "DESC";
                }

                if (exists $columns->{$column_name})
                {
                    $direction = " $direction" if $direction;
                    push @orderstrings, "$column_name$direction";
                }
                else
                {
                    push @invalid_fragments, $fragment;
                }
            }
        }
    }
    $order = $old_orders->{''} if !$order;
    return (\@orderstrings, \@invalid_fragments);
}

# Return query-wide equality operators
sub get_equalities
{
    my $self = shift;
    return $self->{equalities};
}

# HTML quote a value and wrap it into a search_value span
sub sv_quote
{
    return '<span class="search_value">'.html_quote($_[0]).'</span>';
}

# HTML search description, moved here from templates
sub search_description_html
{
    my $self = shift;
    my ($exp, $debug, $inner) = @_;
    my $opdescs = Bugzilla->messages->{operator_descs};
    my $fdescs = Bugzilla->messages->{field_descs};
    $exp = $self->{terms_without_security} if !$exp;
    my $html = '';
    if (ref $exp eq 'ARRAY')
    {
        my $op = $exp->[0];
        $op =~ s/_.*$//so;
        $html = '<ul class="search_description _'.lc($op).'">';
        for my $i (1 .. $#$exp)
        {
            $html .= " <li class='_".lc($op)."'>$op</li>" if $i > 1;
            $html .= ' <li>'.$self->search_description_html($exp->[$i], $debug, 1).'</li>' if $exp->[$i];
        }
        $html .= '</ul>';
    }
    elsif (ref $exp)
    {
        # FIXME maybe output SQL code snippets when debug=1 ?
        # but, this will require interaction with get_expression_sql.
        my $d = $exp->{description};
        my $op = $d->[1];
        my $neg = $exp->{neg};
        if ($neg && NEGATE_ALL_OPERATORS->{$op})
        {
            $op = NEGATE_ALL_OPERATORS->{$op};
            $neg = 0;
        }
        if ($d->[0])
        {
            my $a = COLUMN_ALIASES->{$d->[0]} || $d->[0];
            $html .= '<span class="search_field">'.html_quote($self->{columns}->{$a}->{title} || $fdescs->{$a} || $a).':</span>';
        }
        $html .= ' '.$opdescs->{not} if $neg;
        $html .= ' '.$opdescs->{$d->[1]} if !SEARCH_HIDDEN_OPERATORS->{$d->[1]};
        if (!ref $d->[2] || ref $d->[2] eq 'ARRAY')
        {
            $html .= ' ' . join ', ', map { sv_quote($_) } list $d->[2];
        }
        else
        {
            my ($a, $b, $v, $f, $w) = @{$d->[2]}{qw(after before value fields who)};
            my $s;
            my @l;
            push @l, html_quote($v) if defined $v && $v ne '';
            if ($a || $b)
            {
                $s = $opdescs->{'desc_'.($a ? ($b ? 'between' : 'after') : 'before')};
                $s =~ s/\$1/sv_quote($a)/es;
                $s =~ s/\$2/sv_quote($b)/es;
                push @l, $s;
            }
            if ($w)
            {
                $s = $opdescs->{desc_by};
                $s =~ s/\$1/sv_quote($w)/es;
                push @l, $s;
            }
            if ($f && @$f)
            {
                $s = $opdescs->{desc_fields};
                $s =~ s/\$1/sv_quote(join(', ', map { $self->{columns}->{$_}->{title} || $_ } @$f))/es;
                push @l, $s;
            }
            $html .= join(', ', @l);
        }
        if (!$inner)
        {
            $html = "<div class='search_description _or'>$html</div>";
        }
    }
    return $html;
}

# Get full SQL query
sub getSQL
{
    my $self = shift;
    return $self->{sql};
}

# Get SQL query that just returns Bug IDs of found bugs
sub bugid_query
{
    my $self = shift;
    return $self->{bugid_query};
}

###############################################################################
# Helper functions for the init() method and search operators.
###############################################################################

sub SqlifyDate
{
    my ($str) = @_;
    $str = "" if !defined $str || lc $str eq 'now';
    if ($str eq "")
    {
        return DateTime->now->ymd . ' 00:00:00';
    }
    if ($str =~ /^(-|\+)?(\d+)([hHdDwWmMyY])$/)
    {
        # relative date
        my ($sign, $amount, $unit) = ($1, $2, lc $3);
        $amount = -$amount if $sign && $sign eq '+';
        my $dt = DateTime->now;
        if (!$amount)
        {
            # Special case 0 for beginning of this hour/day/week/month/year
            $dt->set(minute => 0, second => 0);
            if ($unit ne 'h')
            {
                $dt->set(hour => 0);
                if ($unit eq 'w')
                {
                    $dt->subtract(days => $dt->day_of_week-1);
                }
                elsif ($unit ne 'd')
                {
                    $dt->set(day => 1);
                    if ($unit ne 'm')
                    {
                        $dt->set(month => 1);
                    }
                }
            }
        }
        else
        {
            if ($unit ne 'h')
            {
                $dt->set(hour => 0, minute => 0, second => 0);
            }
            $unit = { h => 'hours', d => 'days', y => 'years', w => 'weeks', 'm' => 'months' }->{$unit};
            $dt->subtract($unit => $amount);
        }
        return $dt->ymd . ' ' . $dt->hms;
    }
    my $date = str2time($str);
    if (!defined($date))
    {
        ThrowUserError("illegal_date", { date => $str });
    }
    return time2str("%Y-%m-%d %H:%M:%S", $date);
}

# Support for word search comparisons
sub GetByWordList
{
    my ($field, $strs) = @_;
    my @list;
    my $dbh = Bugzilla->dbh;
    return [] unless defined $strs;

    foreach my $w (map { split /[\s,]+/ } list $strs)
    {
        my $word = $w;
        if ($word ne "")
        {
            $word =~ tr/A-Z/a-z/;
            $word = $dbh->quote('(^|[^a-z0-9])' . quotemeta($word) . '($|[^a-z0-9])');
            trick_taint($word);
            push @list, $dbh->sql_regexp($field, $word);
        }
    }

    return \@list;
}

# Support for "any/all/nowordssubstr" comparison type ("words as substrings")
sub GetByWordListSubstr
{
    my ($field, $strs) = @_;
    my @list;
    my $dbh = Bugzilla->dbh;
    my $sql_word;

    # Allow "exact phrases", not just single words
    my @words = map { /
        \"((?:[^\"\\]+|\\.)*)\" |
        \'((?:[^\'\\]+|\\.)*)\' |
        ([^\s,]+)
    /xgiso } list $strs;
    for (my $i = 0; $i < @words/3; $i++)
    {
        $words[$i] = $words[$i*3] || $words[$i*3+1] || $words[$i*3+2];
    }
    splice @words, @words/3, @words*2/3;

    foreach my $word (@words)
    {
        if ($word ne "")
        {
            $sql_word = $dbh->quote($word);
            trick_taint($sql_word);
            push @list, $dbh->sql_iposition($sql_word, $field) . " > 0";
        }
    }

    return \@list;
}

# Note: In Bugzilla 4 trunk, pronoun() and relative timestamp support is replaced by SPECIAL_PARSING
sub pronoun
{
    my $self = shift;
    my ($noun) = (@_);
    if ($noun eq "%user%")
    {
        if ($self->{user}->id)
        {
            return $self->{user}->id;
        }
        else
        {
            ThrowUserError('login_required_for_pronoun');
        }
    }
    if ($noun eq "%reporter%")
    {
        return "bugs.reporter";
    }
    if ($noun eq "%assignee%")
    {
        return "bugs.assigned_to";
    }
    if ($noun eq "%qacontact%")
    {
        return "bugs.qa_contact";
    }
    return 0;
}

# BuildOrderBy - Private Subroutine
# This function converts the input order to an "output" order,
# suitable for concatenation to form an ORDER BY clause. Basically,
# it just handles fields that have non-standard sort orders from
# %specialorder.
# Arguments:
#  $orderitem - A string. The next value to append to the ORDER BY clause,
#      in the format of an item in the 'order' parameter to
#      Bugzilla::Search.
#  $stringlist - A reference to the list of strings that will be join()'ed
#      to make ORDER BY. This is what the subroutine modifies.
#  $reverseorder - (Optional) A boolean. TRUE if we should reverse the order
#      of the field that we are given (from ASC to DESC or vice-versa).
#
# Explanation of $reverseorder
# ----------------------------
# The role of $reverseorder is to handle things like sorting by
# "target_milestone DESC".
# Let's say that we had a field "A" that normally translates to a sort
# order of "B ASC, C DESC". If we sort by "A DESC", what we really then
# mean is "B DESC, C ASC". So $reverseorder is only used if we call
# BuildOrderBy recursively, to let it know that we're "reversing" the
# order. That is, that we wanted "A DESC", not "A".
sub BuildOrderBy
{
    my $self = shift;
    my ($special_order, $orderitem, $stringlist, $reverseorder) = (@_);

    my ($orderfield, $orderdirection) = split_order_term($orderitem);

    if ($reverseorder)
    {
        # If orderdirection is empty or ASC...
        if (!$orderdirection || $orderdirection =~ m/asc/i)
        {
            $orderdirection = "DESC";
        }
        else
        {
            # This has the minor side-effect of making any reversed invalid
            # direction into ASC.
            $orderdirection = "ASC";
        }
    }

    # Handle fields that have non-standard sort orders, from $specialorder.
    if ($special_order->{$orderfield}->{fields})
    {
        foreach my $subitem (@{$special_order->{$orderfield}->{fields}})
        {
            # DESC on a field with non-standard sort order means
            # "reverse the normal order for each field that we map to."
            $self->BuildOrderBy($special_order, $subitem, $stringlist, $orderdirection =~ m/desc/i);
        }
    }
    else
    {
        # Aliases cannot contain dots in them. We convert them to underscores.
        $orderfield =~ s/\./_/g if exists $self->{columns}->{$orderfield};
        push @$stringlist, trim($orderfield . ' ' . $orderdirection);
    }
}

# Splits out "asc|desc" from a sort order item.
sub split_order_term
{
    my $fragment = shift;
    my ($col, $dir) = split /\s+/, $fragment, 2;
    $col = lc $col;
    $dir = uc($dir || '');
    $dir = '' if $dir ne 'DESC' && $dir ne 'ASC';
    return wantarray ? ($col, $dir) : $col;
}

# Used to translate old SQL fragments from buglist.cgi's "order" argument
# into our modern field IDs.
sub translate_old_column
{
    my ($column) = @_;
    return COLUMN_ALIASES->{$column} if COLUMN_ALIASES->{$column};

    # All old SQL fragments have a period in them somewhere.
    return $column if $column !~ /\./;

    if ($column =~ /\bAS\s+(\w+)$/i)
    {
        return $1;
    }
    # product, component, classification, assigned_to, qa_contact, reporter
    elsif ($column =~ /map_(\w+?)s?\.(login_)?name/i)
    {
        return $1;
    }

    # If it doesn't match the regexps above, check to see if the old
    # SQL fragment matches the SQL of an existing column
    my $rc = Bugzilla->request_cache;
    if (!$rc->{columns_by_sql_code})
    {
        my $col = Bugzilla::Search->COLUMNS;
        $rc->{columns_by_sql_code} = {
            map { $col->{$_}->{name} => $_ } grep { $col->{$_}->{name} } keys %$col
        };
    }

    return $rc->{columns_by_sql_code}->{$column} if $rc->{columns_by_sql_code}->{$column};

    return $column;
}

# Calls search operator specified by $self->{type}
# Similar to do_operator_function() in Bugzilla 4 trunk
sub call_op
{
    my $self = shift;
    my $f;
    # Call operator $self->{type}
    if ($f = OPERATORS->{$self->{type}})
    {
        $self->$f();
    }
    # There is no such operator
    else
    {
        ThrowUserError('search_operator_unknown', { type => $self->{type} });
    }
}

sub is_noop
{
    my ($f, $t, $v) = @_;
    $f ||= 'noop';
    $t ||= 'noop';
    $v = '' if !defined $v;
    return
        $f eq 'noop' || $t eq 'noop' ||
        $v eq '' && $t ne 'equals' && $t ne 'notequals' && $t ne 'exact';
}

# Construct a single search term from boolean charts
# Similar to do_search_function() in Bugzilla 4.0 trunk
sub run_chart
{
    my $self = shift;
    my ($f, $t, $v, $check_field_name) = @_;
    return undef if is_noop($f, $t, $v);
    local $self->{supptables} = [];
    local $self->{suppseen} = {};
    local $self->{field} = $f || 'noop';
    local $self->{type} = $t || 'noop';
    local $self->{value} = ref $v ? $v : trim(defined $v ? $v : "");
    local $self->{quoted};
    local $self->{fieldsql};
    local $self->{term} = undef;
    local $self->{negated};
    # If allow_null is left at false, LEFT joins are replaced with INNER in supptables
    local $self->{allow_null} = 0;
    my $func;
    if (!OPERATORS->{$self->{type}} && (my $t = NEGATE_OPERATORS->{$self->{type}}))
    {
        $self->{type} = $t;
        $self->{negated} = 1;
    }
    $self->{field} = COLUMN_ALIASES->{$self->{field}} if COLUMN_ALIASES->{$self->{field}};
    # chart -1 is generated by other code above, not from the user-
    # submitted form, so we'll blindly accept any values in chart -1
    if (!$self->{columns}->{$self->{field}} && $check_field_name)
    {
        ThrowUserError('invalid_field_name', { field => $self->{field} });
    }
    # FIXME (?) this is replaced by SPECIAL_PARSING() in Bugzilla 4.0 trunk
    if ($self->{type} eq 'equals' || $self->{type} eq 'anyexact')
    {
        # CustIS Bug 53836
        s/\%user\%/$self->{user}->login/isge for ref $self->{value} ? @{$self->{value}} : $self->{value};
    }
    # This is either from the internal chart (in which case we
    # already know about it), or it was in %chartfields, so it is
    # a valid field name, which means that it's ok.
    trick_taint($self->{field});
    if (!ref $self->{value} || ref $self->{value} eq 'ARRAY')
    {
        $self->{quoted} = Bugzilla->dbh->quote(ref $self->{value} ? $self->{value}->[0] : $self->{value});
        trick_taint($self->{quoted});
    }
    if ($self->{columns}->{$self->{field}}->{name})
    {
        $self->{fieldsql} = $self->{columns}->{$self->{field}}->{name};
        if (my $j = $self->{columns}->{$self->{field}}->{joins})
        {
            # Automatically adds table joins when converted to string
            $self->{fieldsql} = bless [ $self->{fieldsql}, $j, $self->{supptables}, $self->{suppseen} ], 'Bugzilla::Search::Code';
        }
    }
    elsif ($self->{field} !~ /\./)
    {
        $self->{fieldsql} = "bugs.$self->{field}";
    }
    else
    {
        $self->{fieldsql} = $self->{field};
    }
    # First, an exact match is checked
    if (defined($func = FUNCTIONS->{$self->{field}}->{$self->{type}}))
    {
        $self->$func();
    }
    # Then try catch-all '*' for a specific field,
    # only if there is no exact match with 'undef' value
    elsif (($func = FUNCTIONS->{$self->{field}}->{'*'}) &&
        !exists FUNCTIONS->{$self->{field}}->{$self->{type}})
    {
        $self->$func();
    }
    # Then, the standard behaviour for this operator is used
    else
    {
        $self->call_op;
    }
    if ($self->{term})
    {
        if (!ref $self->{term})
        {
            $self->{term} = {
                term => $self->{term},
                supp => [ @{$self->{supptables}} ],
                allow_null => $self->{allow_null},
            };
        }
        if (ref $self->{term} eq 'HASH')
        {
            my $op = $self->{type};
            $self->{term}->{description} ||= [ $f, $op, $self->{value} ];
        }
        negate_expression($self->{term}) if $self->{negated};
        return $self->{term};
    }
    else
    {
        # This field and this type don't work together.
        ThrowUserError('field_type_mismatch', {
            field => $f,
            type  => $t,
        });
    }
    return undef;
}

#####################################################################
# Search Functions
#####################################################################

# This function handles "Bug Changes" block from the form:
#
# creation_ts --> search on bugs.creation_ts
# longdesc, longdescs.isprivate, commenter --> search on longdescs
# other --> search on bugs_activity
#
# ---- vfilippov@custis.ru 2010-02-01
# Originally, "Changes" searched on bugs.delta_ts. This is not correct.
# It's "LAST changed in", not "changed in".
# http://wiki.office.custis.ru/Bugzilla_-_оптимизация_поиска_по_изменениям
sub changed
{
    my $self = shift;
    my $v = { %{$self->{value}} };
    my $dbh = Bugzilla->dbh;

    my $after  = $v->{after}  ? $dbh->quote(SqlifyDate($v->{after}))  : '';
    my $before = $v->{before} ? $dbh->quote(SqlifyDate($v->{before})) : '';
    my $added  = $v->{value}  ? $dbh->quote($v->{value})              : '';

    # do a match on user login or name
    my $who = $v->{who};
    if ($who)
    {
        $who = $who eq '%user%' ? $self->{user} : Bugzilla::User::match_name($who, 1)->[0];
        if ($who)
        {
            $v->{who} = $who->login;
            $v->{who} =~ s/\@.*$//so if !Bugzilla->user->id;
            $who = $who->id;
        }
    }

    my $cond = [];
    push @$cond, " .bug_when >= $after" if $after;
    push @$cond, " .bug_when <= $before" if $before;
    push @$cond, " .who = $who" if $who;
    $cond = join(" AND ", @$cond);

    # CustIS Bug 68921 - "interval worktime" column depends
    # on the time interval and user specified in "changes" search area
    my $c;
    my %f = map { $_ => 1 } @{$v->{fields}};
    if (!$self->{user}->is_timetracker)
    {
        # Non-timetrackers can't search on time tracking fields
        delete $f{$_} for keys %{TIMETRACKING_FIELDS()};
    }

    my $ld = "ld$self->{sequence}";
    my $ba = "ba$self->{sequence}";

    $c = $cond;
    $c =~ s/ \./$ld./gs;
    my $ld_term = {
        table => "longdescs $ld",
        where => $c,
        bugid_field => "$ld.bug_id",
        description => [ 'comment', 'changed', { %$v } ],
        many_rows => 1,
    };
    delete $ld_term->{description}->[2]->{fields};

    $c = $cond;
    $c =~ s/ \./$ba./gs;
    my $ba_term = {
        table => "bugs_activity $ba",
        where => $c.($added ? " AND $ba.added=$added" : ''),
        bugid_field => "$ba.bug_id",
        description => [ 'changes', 'changed', $v ],
        many_rows => 1,
    };

    my $creation_term = undef;
    my $any_fields = %f ? 1 : 0;
    if ($f{creation_ts})
    {
        # User is searching for bugs created by $who, between $before and $after
        $c = $cond;
        $c =~ s/ \.(bug_when|who)/$1 eq 'bug_when' ? 'bugs.creation_ts' : 'bugs.reporter'/ges;
        $creation_term = { term => $c, description => [ 'creation', 'changed', $v ] };
        delete $f{creation_ts};
    }
    if ($f{longdesc} || $f{'longdescs.isprivate'} || $f{commenter})
    {
        if ($added)
        {
            if ($f{longdesc})
            {
                # User is searching for a comment with specific text
                $ld_term->{where} .= ' AND '.$dbh->sql_iposition("$ld.thetext", $added);
            }
            elsif ($f{'longdescs.isprivate'} && $self->{user}->is_insider)
            {
                # Insider is searching for a comment with specific privacy
                $ld_term->{where} .= " AND $ld.isprivate = ".($v->{value} ? 1 : 0);
                $ld_term->{description}->[0] = 'longdescs.isprivate';
            }
            elsif ($f{commenter})
            {
                # User is searching for a comment from specific user
                $ld_term->{table} = "(longdescs $ld INNER JOIN profiles c$ld ON c$ld.userid=$ld.who)";
                $ld_term->{where} .= " AND c$ld.login_name = $added";
                $ld_term->{description}->[0] = 'commenter';
            }
        }
        delete $f{longdesc};
        delete $f{'longdescs.isprivate'};
        delete $f{commenter};
    }
    elsif ($any_fields)
    {
        # If there are some fields specified in the request,
        # but no comment-related ones, don't search on comments.
        $ld_term = undef;
    }
    if (%f)
    {
        $ba_term->{where} .= " AND $ba.fieldid IN (".join(",", map { Bugzilla->get_field($_)->id } keys %f).")";
        $v->{fields} = [ keys %f ];
    }
    elsif ($any_fields)
    {
        # Similarly, if there are some fields specified in the request,
        # but all of them are comment-related or creation timestamp,
        # don't search on bugs_activity.
        $ba_term = undef;
    }

    # Don't care about undefs possibly returned in this term,
    # simplify_expression will take care of them.
    $self->{term} = [ 'OR', $creation_term, $ld_term, $ba_term ];
}

sub _contact
{
    my $self = shift;
    # We only handle %user%, %reporter%, %assignee%, %qacontact%, %group.name%,
    # other values are handled by standard field matching code
    if (($self->{type} eq 'equals' || $self->{type} eq 'anyexact') &&
        $self->{value} =~ /^\%group\.([^\%]+)\%$/)
    {
        my $group = $1;
        my $groupid = Bugzilla::Group::ValidateGroupName($group, $self->{user});
        unless ($groupid && $self->{user}->in_group_id($groupid))
        {
            ThrowUserError('invalid_group_name', { name => $group });
        }
        my @childgroups = @{Bugzilla::Group->flatten_group_membership($groupid)};
        my $table = "user_group_map_".$self->{sequence};
        $self->{term} = {
            table => "user_group_map $table",
            where => "$table.user_id = bugs.$self->{field} AND $table.group_id IN (" . join(',', @childgroups) . ")" .
                " AND $table.isbless = 0 AND $table.grant_type IN (" . GRANT_DIRECT . "," . GRANT_REGEXP . ")",
            notnull_field => "$table.group_id",
        };
    }
    elsif (($self->{type} eq 'equals' || $self->{type} eq 'anyexact') &&
        $self->{value} =~ /^\%(user|reporter|assignee|qacontact)\%$/)
    {
        $self->{term} = "bugs.$self->{field} = " . $self->pronoun($self->{value});
    }
    else
    {
        $self->call_op;
    }
}

sub _blocked_dependson
{
    my $self = shift;
    my $t = "dep_".$self->{sequence};
    my $other = ($self->{field} eq 'blocked' ? 'dependson' : 'blocked');
    $self->{fieldsql} = $self->{field} = $t.'.'.$self->{field};
    my $neg = 0;
    if ($self->{value} eq '' &&
        ($self->{type} eq 'equals' || $self->{type} eq 'anyexact'))
    {
        $self->{term} = '1';
        $neg = 1;
    }
    else
    {
        $self->call_op;
    }
    if (ref $self->{term})
    {
        # FIXME move it to some function like combine_terms or so
        $self->{term}->{table} = "(".$self->{term}->{table}.
            ($self->{term}->{neg} ? " LEFT" : " INNER").
            " JOIN dependencies $t ON $self->{term}->{where})";
        delete $self->{term}->{where};
        if ($self->{term}->{neg})
        {
            $self->{term}->{where} = $self->{term}->{notnull_field}." IS NULL";
        }
        $self->{term}->{bugid_field} = "$t.$other";
        $self->{term}->{neg} = $neg;
    }
    else
    {
        $self->{term} = {
            table => "dependencies $t",
            where => $self->{term},
            bugid_field => $t.'.'.$other,
            neg => $neg,
        };
    }
}

sub _cc_nonchanged
{
    my $self = shift;
    my $t = "cc_".$self->{sequence};
    my $ut;
    if ($self->{value} =~ /^\%(user|reporter|assignee|qacontact)\%$/ &&
        ($self->{type} eq 'equals' || $self->{type} eq 'anyexact'))
    {
        $self->{term} = {
            table => "cc $t",
            where => "$t.who = ".$self->pronoun($self->{value}),
            notnull_field => "$t.bug_id",
        };
    }
    elsif ($self->{value} =~ /^\%group\.([^\%]+)\%$/ &&
        ($self->{type} eq 'equals' || $self->{type} eq 'anyexact'))
    {
        my $group = $1;
        my $groupid = Bugzilla::Group::ValidateGroupName($group, $self->{user});
        unless ($groupid && $self->{user}->in_group_id($groupid))
        {
            ThrowUserError('invalid_group_name', { name => $group });
        }
        my @childgroups = @{Bugzilla::Group->flatten_group_membership($groupid)};
        $ut = "user_group_map_".$self->{sequence};
        $self->{term} = {
            table => "(cc $t INNER JOIN user_group_map $ut ON $ut.user_id=$t.who AND $ut.group_id IN (" .
                join(',', @childgroups) . ") AND $ut.isbless=0 AND $ut.grant_type IN (".GRANT_DIRECT.",".GRANT_REGEXP."))",
            bugid_field => "$t.bug_id",
        };
    }
    else
    {
        $ut = "map_cc_".$self->{sequence};
        $self->{fieldsql} = $self->{field} = "$ut.login_name";
        $self->call_op;
        $self->{term} = {
            table => "(cc $t INNER JOIN profiles $ut ON $t.who=$ut.userid AND ($self->{term}))",
            bugid_field => "$t.bug_id",
        };
    }
}

sub _long_desc_changedby
{
    my $self = shift;
    my $id = Bugzilla::User::login_to_id($self->{value}, THROW_ERROR);
    my @priv = $self->{user}->is_insider ? () : "longdescs.isprivate=0";
    $self->{term} = {
        base_table => "longdescs",
        where => [ "longdescs.who = $id", @priv ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
}

sub _long_desc_changedbefore_after
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $operator = ($self->{type} =~ /before/) ? '<' : '>';
    my $table = "longdescs_".$self->{sequence};
    my @priv = $self->{user}->is_insider ? () : "longdescs.isprivate=0";
    $self->{term} = {
        base_table => "longdescs",
        where => [ "longdescs.bug_when $operator ".$dbh->quote(SqlifyDate($self->{value})), @priv ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
}

# "content" is an alias for columns containing text for which we
# can search a full-text index and retrieve results by relevance,
# currently bug comments and summaries.
# There's only one way to search a full-text index, so we only
# accept the "matches" operator, which is specific to full-text
# index searches.
sub _content_matches
{
    my $self = shift;

    my $dbh = Bugzilla->dbh;
    my $table = "bugs_fulltext_".$self->{sequence};
    my $text = $self->{value};

    if (my $index = Bugzilla->localconfig->{sphinx_index})
    {
        # Escape search query
        my $pattern_part = '\[\]:\(\)!@~&\/^$=';
        $text = trim($text);
        $text =~ s/^[|\-$pattern_part]+|[|\-$pattern_part]+$//gs; # erase special chars in the beginning and at the end of query
        if (($text =~ tr/"/"/) % 2)
        {
            # Close unclosed double quote
            $pattern_part .= '"';
        }
        $text =~ s/((?<!\\)(?:\\\\)*)([$pattern_part])/$1\\$2/gs;
        $text =~ s/(?<=[\s-])-(?=[\s-])/\\-/gso;
        $text =~ s/\s+$//so;
        if (!$text)
        {
            ThrowUserError('invalid_fulltext_query');
            return;
        }
        $text = ($self->{user}->is_insider ? '@(short_desc,comments,comments_private) ' : '@(short_desc,comments) ') . $text;
        if ($dbh->isa('Bugzilla::DB::Mysql') &&
            Bugzilla->localconfig->{sphinxse_port})
        {
            # Using SphinxSE
            $text =~ s/;/\\;/gso;
            $text =~ s/\\/\\\\/gso;
            # Space is needed after $text so Sphinx doesn't escape ";"
            my $maxm = Bugzilla->params->{sphinx_max_matches} || 1000;
            $text = "$text ;mode=extended;limit=$maxm;maxmatches=$maxm;fieldweights=short_desc,5,comments,1,comments_private,1";
            $self->{term} = {
                table => "bugs_fulltext_sphinx $table",
                where => "$table.query=".$dbh->quote($text),
                bugid_field => "$table.id",
            };
            if (!$self->{negated})
            {
                push @{$self->{columns}->{relevance}->{joins}}, "LEFT JOIN bugs_fulltext_sphinx $table ON $table.id=bugs.bug_id AND $table.query=".$dbh->quote($text);
                push @{$self->{columns}->{relevance}->{bits}}, "$table.weight";
                $self->{columns}->{relevance}->{name} = '('.join("+", @{$self->{columns}->{relevance}->{bits}}).')';
            }
        }
        else
        {
            # Using separate query to SphinxQL
            my $sph = Bugzilla->dbh_sphinx;
            my $query = 'SELECT `id`, WEIGHT() `weight` FROM '.$index.
                ' WHERE MATCH(?) LIMIT 1000 OPTION field_weights=(short_desc=5, comments=1, comments_private=1)';
            my $ids = $sph->selectall_arrayref($query, undef, $text) || [];
            $self->{term} = {
                term => @$ids ? 'bugs.bug_id IN ('.join(', ', map { $_->[0] } @$ids).')' : '1=0',
            };
            if (@$ids && !$self->{negated})
            {
                # Pass relevance (weight) values via an overlong (CASE ... END)
                push @{$self->{columns}->{relevance}->{bits}}, '(case'.join('', map { ' when bugs.bug_id='.$_->[0].' then '.$_->[1] } @$ids).' end)';
                $self->{columns}->{relevance}->{name} = '('.join("+", @{$self->{columns}->{relevance}->{bits}}).')';
            }
        }
        return;
    }

    # Create search terms to add to the SELECT and WHERE clauses.
    # These are (search term, rank term, search term, rank term, ...)
    my @terms = (
        $dbh->sql_fulltext_search("bugs_fulltext.short_desc", $text),
        $dbh->sql_fulltext_search("bugs_fulltext.comments", $text),
    );
    push @terms, $dbh->sql_fulltext_search("bugs_fulltext.comments_private", $text) if $self->{user}->is_insider;

    # Bug 46221 - Russian Stemming in Bugzilla fulltext search
    # MATCH(...) OR MATCH(...) is very slow in MySQL (and probably in other DBs):
    # -- it does no fulltext index merge optimization. So use JOIN to UNION.
    $self->{term} = {
        table => "(".join(" UNION ", map {
            "SELECT ".$dbh->FULLTEXT_ID_FIELD." bug_id FROM bugs_fulltext WHERE $terms[$_]"
        } grep { !($_&1) } 0..$#terms).") $table",
        bugid_field => "$table.bug_id",
    };

    # We build the relevance SQL by modifying the COLUMNS list directly,
    # which is kind of a hack but works.
    # In order to sort by relevance (in case the user requests it),
    # we SELECT the relevance value so we can add it to the ORDER BY
    # clause. Every time a new non-negated fulltext chart is added,
    # this adds more terms to the relevance sql.
    if (!$self->{negated})
    {
        push @{$self->{columns}->{relevance}->{bits}}, @terms[grep { $_&1 } 0..$#terms];
        $self->{columns}->{relevance}->{name} = $dbh->sql_fulltext_relevance_sum($self->{columns}->{relevance}->{bits});
    }
}

sub _timestamp_compare
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if ($self->{columns}->{$self->{field}}->{joins})
    {
        push @{$self->{supptables}}, @{$self->{columns}->{$self->{field}}->{joins}};
    }
    $self->{fieldsql} = $self->{columns}->{$self->{field}}->{raw_name} || 'bugs.'.$self->{field};
    if ($self->{value} =~ /^[+-]?\d+[dhwmy]$/is)
    {
        $self->{value} = SqlifyDate($self->{value});
        $self->{quoted} = $dbh->quote($self->{value});
    }
    $self->call_op;
}

sub _commenter
{
    my $self = shift;

    my $t = {
        base_table => "longdescs",
        where => [ $self->{user}->is_insider ? () : "longdescs.isprivate=0" ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
    if (($self->{type} eq 'equals' || $self->{type} eq 'anyexact') &&
        $self->{value} =~ /^(%\\w+%)$/)
    {
        push @{$t->{where}}, "longdescs.who=".$self->pronoun($self->{value});
    }
    else
    {
        $t->{base_joins} = [ [ 'INNER', 'profiles', 'map_commenter', 'map_commenter.userid=longdescs.who' ] ];
        $self->{fieldsql} = $self->{field} = "map_commenter.login_name";
        $self->call_op;
        push @{$t->{where}}, $self->{term};
    }
    $self->{term} = $t;
}

sub _long_desc
{
    my $self = shift;

    $self->{fieldsql} = $self->{field} = "longdescs.thetext";
    $self->call_op;

    $self->{term} = {
        base_table => "longdescs",
        where => [ $self->{term}, $self->{user}->is_insider ? () : "longdescs.isprivate < 1" ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
}

sub _longdescs_isprivate
{
    my $self = shift;

    if ($self->{user}->is_insider)
    {
        $self->{term} = {
            base_table => "longdescs",
            where => "longdescs.isprivate = ".($self->{value} ? 1 : 0),
            bugid_field => "longdescs.bug_id",
            many_rows => 1,
        };
    }
    else
    {
        # Non-insiders cannot search on this field
        $self->{term} = "1=1";
    }
}

sub _work_time_changedby
{
    my $self = shift;
    my $id = Bugzilla::User::login_to_id($self->{value}, THROW_ERROR);
    my @priv = $self->{user}->is_insider ? () : "longdescs.isprivate=0";
    $self->{term} = {
        base_table => "longdescs",
        where => [ "longdescs.who = $id", "longdescs.work_time != 0", @priv ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
}

sub _work_time_changedbefore_after
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $operator = ($self->{type} =~ /before/) ? '<' : '>';
    my @priv = $self->{user}->is_insider ? () : "longdescs.isprivate=0";
    $self->{term} = {
        base_table => "longdescs",
        where => [ "longdescs.work_time != 0", "longdescs.bug_when $operator".$dbh->quote(SqlifyDate($self->{value})), @priv ],
        bugid_field => "longdescs.bug_id",
        many_rows => 1,
    };
}

sub _work_time_equals_0
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if ($self->{type} eq 'equals' && (0+$self->{value}) eq '0')
    {
        my $table = "longdescs_".$self->{sequence};
        my $w = "$table.work_time != 0";
        if ($self->{field} eq 'interval_time')
        {
            $w .= " AND $table.bug_when >= ".$dbh->quote($self->{interval_from}) if $self->{interval_from};
            $w .= " AND $table.bug_when <= ".$dbh->quote($self->{interval_to}) if $self->{interval_to};
            $w .= " AND $table.who = ".$self->{interval_who}->id if $self->{interval_who};
        }
        $w .= " AND $table.isprivate = 0" if $self->{user}->is_insider;
        $self->{term} = {
            table => "longdescs $table",
            where => $w,
            neg => 1,
            bugid_field => "$table.bug_id",
            many_rows => 1,
        };
    }
    else
    {
        $self->call_op;
    }
}

sub _bug_group_nonchanged
{
    my $self = shift;

    my $t = "bug_group_map_".$self->{sequence};
    my $gt = "groups_".$self->{sequence};
    $self->{fieldsql} = $self->{field} = "$gt.name";
    $self->call_op;

    $self->{term} = {
        table => "(bug_group_map $t INNER JOIN groups $gt ON $gt.id = $t.group_id AND $self->{term})",
        bugid_field => "$t.bug_id",
        many_rows => 1,
    };
}

sub _attachments_submitter
{
    my $self = shift;

    $self->{fieldsql} = $self->{field} = 'map_submitter.login_name';
    $self->call_op;

    my @priv = $self->{user}->is_insider ? () : 'attachments.isprivate = 0';
    $self->{term} = {
        base_table => 'attachments',
        base_joins => [ [ 'INNER', 'profiles', 'map_submitter', 'attachments.submitter_id = map_submitter.userid' ] ],
        where => [ $self->{term}, @priv ],
        bugid_field => 'attachments.bug_id',
    };
}

sub _attachments
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $self->{field} =~ m/^attachments\.(.*)$/;
    my $field = $1;
    if ($field eq "ispatch" && $self->{value} ne "0" && $self->{value} ne "1")
    {
        ThrowUserError("illegal_attachment_is_patch");
    }
    elsif ($field eq "isobsolete" && $self->{value} ne "0" && $self->{value} ne "1")
    {
        ThrowUserError("illegal_is_obsolete");
    }
    $self->{fieldsql} = $self->{field};
    $self->call_op;
    my @priv = $self->{user}->is_insider ? () : 'attachments.isprivate = 0';
    $self->{term} = {
        base_table => 'attachments',
        where => [ $self->{term}, @priv ],
        bugid_field => 'attachments.bug_id',
    };
}

# Matches bugs by flag name/status.
# Note that - for the purposes of querying - a flag comprises
# its name plus its status (i.e. a flag named "review"
# with a status of "+" can be found by searching for "review+").
sub _flagtypes_name_nonchanged
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $self->{fieldsql} = $dbh->sql_string_concat('flagtypes.name', 'flags.status');
    $self->call_op;

    $self->{term} = {
        base_table => 'flags',
        base_joins => [ [ 'INNER', 'flagtypes', 'flagtypes', 'flags.type_id = flagtypes.id' ] ],
        where => $self->{term},
        bugid_field => 'flags.bug_id',
    };
}

# FIXME: filter flags on private attachments
sub _requestees_login_name
{
    my $self = shift;

    $self->{fieldsql} = $self->{field} = 'requestee_map.login_name';
    $self->call_op;

    $self->{term} = {
        base_table => 'flags',
        base_joins => [ [ 'INNER', 'profiles', 'requestee_map', 'flags.requestee_id = requestee_map.userid' ] ],
        where => $self->{term},
        bugid_field => 'flags.bug_id',
    };
}

# FIXME: filter flags on private attachments
sub _setters_login_name
{
    my $self = shift;

    $self->{fieldsql} = $self->{field} = 'map_setters.login_name';
    $self->call_op;

    $self->{term} = {
        base_table => 'flags',
        base_joins => [ [ 'INNER', 'profiles', 'map_setters', 'flags.setter_id = map_setters.userid' ] ],
        where => $self->{term},
        bugid_field => 'flags.bug_id',
    };
}

sub _days_elapsed
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    if ($self->{type} eq 'equals')
    {
        $self->{term} = "bugs.delta_ts >= '".time2str(
            '%Y-%m-%d 00:00:00', time - $self->{value}*86400).
            "' AND bugs.delta_ts < '".time2str(
            '%Y-%m-%d 00:00:00', time - ($self->{value}-1)*86400)."'";
    }
    else
    {
        my ($less, $eq) = split /than/, $self->{type}, 2;
        $less = $less eq 'less';
        $self->{term} = 'bugs.delta_ts '.($less ? ">='" : "<='").time2str(
            '%Y-%m-%d 00:00:00', time - ($self->{value}-($eq ? 0 : 1)*86400))."'";
    }
}

sub _owner_idle_time_less
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $table = "idle_".$self->{sequence};
    $self->{value} =~ /^(\d+)\s*([hHdDwWmMyY])?$/;
    my $quantity = $1;
    my $unit = lc $2;
    my $unitinterval = 'DAY';
    if ($unit eq 'h')
    {
        $unitinterval = 'HOUR';
    }
    elsif ($unit eq 'w')
    {
        $unitinterval = ' * 7 DAY';
    }
    elsif ($unit eq 'm')
    {
        $unitinterval = 'MONTH';
    }
    elsif ($unit eq 'y')
    {
        $unitinterval = 'YEAR';
    }

    my $cutoff = $dbh->sql_date_math('NOW()', '-', $quantity, $unitinterval);
    my $g = $self->{type} eq 'lessthaneq' ? ">=" : ">";
    $self->{term} = [
        'OR',
        {
            table => "longdescs c$table",
            where => "c$table.bug_id=bugs.bug_id AND c$table.who=bugs.assigned_to AND c$table.bug_when $g $cutoff",
            notnull_field => "c$table.bug_id",
            description => [ 'owner_commented', $self->{type}, $self->{value} ],
        },
        {
            table => "bugs_activity a$table",
            where => "a$table.bug_id=bugs.bug_id AND a$table.who=bugs.assigned_to AND a$table.bug_when $g $cutoff",
            notnull_field => "a$table.bug_id",
            description => [ 'owner_changed', $self->{type}, $self->{value} ],
        },
    ];
}

# FIXME Now, anywords/... is equivalent to anyexact/... for multi-select fields
sub _multiselect_nonchanged
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $type = Bugzilla->get_field($self->{field})->value_type;
    my $t = $type->REL_TABLE;
    my $ft = $type->DB_TABLE;
    my $ta = $t.'_'.$self->{sequence};
    my $fta = $ft.'_'.$self->{sequence};

    my @v = ref $self->{value} ? @{$self->{value}} : $self->{value};
    $self->{quoted} = join ', ', map { $dbh->quote($_) } @v;

    if ($self->{type} eq 'allwordssubstr')
    {
        $self->{term} = {
            table => "(SELECT bug_id FROM $t, $ft WHERE id=value_id AND ".$type->NAME_FIELD." IN ($self->{quoted})".
                " GROUP BY bug_id HAVING COUNT(bug_id) = ".@v.") $ta",
            bugid_field => "$ta.bug_id",
        };
    }
    else
    {
        if ($self->{type} eq 'anyexact' || $self->{type} eq 'anywordssubstr')
        {
            $self->{term} = "$fta.".$type->NAME_FIELD." IN ($self->{quoted})";
        }
        else
        {
            $self->{fieldsql} = $self->{field} = "$fta.".$type->NAME_FIELD;
            $self->{value} = $v[0];
            $self->call_op;
        }
        $self->{term} = {
            table => "($t $ta INNER JOIN $ft $fta ON $fta.id=$ta.value_id)",
            where => $self->{term},
            bugid_field => "$ta.bug_id",
        };
    }
}

sub _see_also_nonchanged
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $type = Bugzilla->get_field($self->{field})->value_type;
    my $t = "see".$self->{sequence};

    my @v = ref $self->{value} ? @{$self->{value}} : $self->{value};
    $self->{quoted} = join ', ', map { $dbh->quote($_) } @v;

    if ($self->{type} eq 'allwordssubstr')
    {
        $self->{term} = {
            table => "(SELECT bug_id FROM bug_see_also $t WHERE value IN ($self->{quoted})".
                " GROUP BY bug_id HAVING COUNT(bug_id) = ".@v.") a$t",
            bugid_field => "a$t.bug_id",
        };
    }
    else
    {
        if ($self->{type} eq 'anyexact' || $self->{type} eq 'anywordssubstr')
        {
            $self->{term} = "$t.value IN ($self->{quoted})";
        }
        else
        {
            $self->{fieldsql} = $self->{field} = "$t.value";
            $self->{value} = $v[0];
            $self->call_op;
        }
        $self->{term} = {
            table => "bug_see_also $t",
            where => $self->{term},
            bugid_field => "$t.bug_id",
        };
    }
}

sub _bugid_rev_nonchanged
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my $fn = Bugzilla->get_field($self->{field})->value_field->name;
    my $t = 'bugs_'.$self->{sequence};

    my @v = ref $self->{value} ? @{$self->{value}} : $self->{value};
    $self->{quoted} = join ', ', map { $dbh->quote($_) } @v;

    $self->{type} =~ s/^(all|any)wordssubstr$/$1words/so;
    if ($self->{type} eq 'anywords' || $self->{type} eq 'anyexact')
    {
        $self->{term} = {
            table => "bugs $t",
            where => "$t.bug_id IN ($self->{quoted})",
            bugid_field => "$t.$fn",
        };
    }
    elsif ($self->{type} eq 'allwords')
    {
        $self->{term} = {
            table => "(SELECT $fn FROM $t WHERE $t.bug_id IN ($self->{quoted})".
                " GROUP BY $fn HAVING COUNT($fn) = ".@v.") c_$t",
            bugid_field => "c_$t.bug_id",
        };
    }
    else
    {
        $self->{fieldsql} = $self->{field} = "$t.bug_id";
        $self->{value} = $v[0];
        $self->call_op;
        $self->{term} = {
            table => "bugs $t",
            where => $self->{term},
            bugid_field => "$t.$fn",
        };
    }
}

#####################################################################
# Search Operators
#####################################################################

sub _equals
{
    my $self = shift;
    if ($self->{value} eq '')
    {
        # FIXME Run UNION instead of OR?
        $self->{term} = "($self->{fieldsql} = $self->{quoted} OR $self->{fieldsql} IS NULL)";
        $self->{allow_null} = 1;
    }
    else
    {
        $self->{term} = "($self->{fieldsql} = $self->{quoted} AND $self->{fieldsql} IS NOT NULL)";
    }
}

sub _casesubstring
{
    my $self = shift;
    $self->{term} = Bugzilla->dbh->sql_position($self->{quoted}, "COALESCE($self->{fieldsql}, '')") . " > 0";
}

sub _substring
{
    my $self = shift;
    $self->{term} = Bugzilla->dbh->sql_iposition($self->{quoted}, "COALESCE($self->{fieldsql}, '')") . " > 0";
}

sub _regexp
{
    my $self = shift;
    $self->{allow_null} = 2;
    $self->{term} = Bugzilla->dbh->sql_regexp($self->{fieldsql}, $self->{quoted});
}

sub _notregexp
{
    my $self = shift;
    $self->{allow_null} = 2;
    $self->{term} = Bugzilla->dbh->sql_not_regexp($self->{fieldsql}, $self->{quoted});
}

sub _lessthan
{
    my $self = shift;
    $self->{term} = "$self->{fieldsql} < $self->{quoted}";
}

sub _greaterthan
{
    my $self = shift;
    $self->{term} = "$self->{fieldsql} > $self->{quoted}";
}

sub _lessthaneq
{
    my $self = shift;
    $self->{term} = "$self->{fieldsql} <= $self->{quoted}";
}

sub _greaterthaneq
{
    my $self = shift;
    $self->{term} = "$self->{fieldsql} >= $self->{quoted}";
}

sub _anyexact
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    my @list;
    my $nullable = Bugzilla->get_field($self->{field}) && Bugzilla->get_field($self->{field})->nullable;
    my $null = 0;
    my @v;
    foreach my $w (ref $self->{value} ? @{$self->{value}} : split /[\s,]+/, $self->{value}, -1)
    {
        if (defined $w && $w ne '')
        {
            push @v, $w;
        }
        if (!defined $w || $w eq '' || $w eq '---')
        {
            # --- was previously used as NULL surrogate, so be compatible with it
            # And in fact the search form now also uses it as NULL
            $null = 1;
        }
        $self->{quoted} = $dbh->quote($w);
        trick_taint($self->{quoted});
        push(@list, $self->{quoted});
    }
    if (@list || $null && $nullable)
    {
        # FIXME Run UNION instead of OR?
        $self->{allow_null} = 1 if $null && $nullable;
        $self->{term} = '('.join(' OR ',
            (@list ? $self->{fieldsql} . ' IN (' . join(',', @list) . ')' : ()),
            ($null && $nullable ? $self->{fieldsql} . ' IS NULL' : ()),
        ).')';
    }
}

sub _anywordssubstr
{
    my $self = shift;
    my @list = @{GetByWordListSubstr($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{term} = "(".join(" OR ", @list).")";
    }
}

sub _allwordssubstr
{
    my $self = shift;
    my @list = @{GetByWordListSubstr($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{term} = join(" AND ", @list);
    }
}

sub _nowordssubstr
{
    my $self = shift;
    my @list = @{GetByWordListSubstr($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{allow_null} = 1;
        $self->{term} = "NOT (" . join(" OR ", @list) . ")";
    }
}

sub _anywords
{
    my $self = shift;
    my @list = @{GetByWordList($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{term} = "(" . join(" OR ", @list) . ")";
    }
}

sub _allwords
{
    my $self = shift;
    my @list = @{GetByWordList($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{term} = join(" AND ", @list);
    }
}

sub _nowords
{
    my $self = shift;
    my @list = @{GetByWordList($self->{fieldsql}, $self->{value})};
    if (@list)
    {
        $self->{allow_null} = 1;
        $self->{term} = "NOT (" . join(" OR ", @list) . ")";
    }
}

sub _changedbefore_changedafter
{
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    my $operator = ($self->{type} =~ /before/) ? '<' : '>';
    $self->{field} = 'flagtypes.name' if $self->{field} eq 'flags';
    my $fieldid = Bugzilla->get_field($self->{field});
    if (!$fieldid)
    {
        ThrowUserError("invalid_activity_field", { field => $self->{field} });
    }
    $fieldid = $fieldid->id;
    $self->{term} = {
        base_table => 'bugs_activity',
        where => [ "bugs_activity.fieldid = $fieldid",
            "bugs_activity.bug_when $operator ".$dbh->quote(SqlifyDate($self->{value})) ],
        bugid_field => 'bugs_activity.bug_id',
        many_rows => 1,
    };
}

sub _changedfrom_changedto
{
    my $self = shift;
    my $operator = ($self->{type} =~ /from/) ? 'removed' : 'added';
    $self->{field} = 'flagtypes.name' if $self->{field} eq 'flags';
    my $fieldid = Bugzilla->get_field($self->{field});
    if (!$fieldid)
    {
        ThrowUserError("invalid_activity_field", { field => $self->{field} });
    }
    $fieldid = $fieldid->id;
    $self->{term} = {
        base_table => 'bugs_activity',
        where => [ "bugs_activity.fieldid = $fieldid",
            "bugs_activity.$operator = $self->{quoted}" ],
        bugid_field => 'bugs_activity.bug_id',
        many_rows => 1,
    };
}

sub _changedby
{
    my $self = shift;
    $self->{field} = 'flagtypes.name' if $self->{field} eq 'flags';
    my $fieldid = Bugzilla->get_field($self->{field});
    if (!$fieldid)
    {
        ThrowUserError("invalid_activity_field", { field => $self->{field} });
    }
    $fieldid = $fieldid->id;
    my $id = Bugzilla::User::login_to_id($self->{value}, THROW_ERROR);
    $self->{term} = {
        base_table => 'bugs_activity',
        where => [ "bugs_activity.fieldid = $fieldid",
            "bugs_activity.who = $id" ],
        bugid_field => 'bugs_activity.bug_id',
        many_rows => 1,
    };
}

sub _in_search_results
{
    my $self = shift;
    my $v = $self->{value};
    my $sharer = $self->{params}->{sharer_id} || $self->{user}->id;
    # Do not check permissions for sharer's queries
    my $m = 'new';
    if ($v =~ /^(.*)<([^>]*)>/so)
    {
        # Allow to match on shared searches via 'SearchName <user@domain.com>' syntax
        $v = $1;
        my $new_sharer = Bugzilla::User::login_to_id(trim($2), THROW_ERROR);
        # Check permissions if the specified user is not the query's sharer
        $m = 'check' if $new_sharer != $sharer;
        $sharer = $new_sharer;
    }
    my $query = Bugzilla::Search::Saved->$m({
        name => trim($v),
        user => $sharer,
        runner => $self->{user},
    });
    if (!$query)
    {
        ThrowUserError('object_does_not_exist', { name => trim($v), user => $sharer, class => 'Bugzilla::Search::Saved' });
    }
    $query = $query->query;
    my $search = new Bugzilla::Search(
        params => http_decode_query($query),
        fields => [ "bugs.bug_id" ],
        user   => $self->{user},
    );
    my $sqlquery = $search->bugid_query;
    my $t = "ins_".$self->{sequence};
    $self->{term} = { table => "($sqlquery) $t" };
    if ($self->{field} eq 'bug_id')
    {
        $self->{term}->{bugid_field} = "$t.bug_id";
    }
    else
    {
        my $f = Bugzilla->get_field($self->{field});
        if ($f && ($f->type == FIELD_TYPE_BUG_ID || $f->type == FIELD_TYPE_BUG_ID_REV) ||
            $self->{field} eq 'blocked' || $self->{field} eq 'dependson' || $self->{field} eq 'dup_id')
        {
            $self->{term}->{where} = "$self->{fieldsql} = $t.bug_id";
            $self->{term}->{notnull_field} = "$t.bug_id";
            $self->{term}->{supp} = [ @{$self->{supptables}} ];
        }
        else
        {
            ThrowUserError('in_search_needs_bugid_field', { field => $self->{field} });
        }
    }
}

##########################################################
## SQL Core of Bugzilla::Search: functions for building ##
## queries from structured expressions                  ##
##########################################################

# Does basic expression simplifications
# 1) Removes undefs and empty operands
# 2) OP(x) --> x
# 3) OP(x,OP(y,z)) --> OP(x,y,z)
sub simplify_expression
{
    my ($q) = @_;
    return $q if ref $q ne 'ARRAY';
    for (my $i = $#$q; $i > 0; $i--)
    {
        $q->[$i] = simplify_expression($q->[$i]);
        splice @$q, $i, 1 if !$q->[$i];
    }
    return undef if @$q == 1;
    # Check for single operand before checking op(op()),
    # as OR(OR_MANY()) must become OR_MANY, not OR.
    return $q->[1] if @$q == 2;
    my $op = substr($q->[0], 0, 2);
    for (my $i = $#$q; $i > 0; $i--)
    {
        if (ref $q->[$i] eq 'ARRAY' && substr($q->[$i]->[0], 0, 2) eq $op)
        {
            splice @$q, $i, 1, @{$q->[$i]}[1..$#{$q->[$i]}];
        }
    }
    return $q;
}

# Recursively negates an expression using DeMorgan rules
# NOT(a AND b) = NOT(a) OR NOT(b) and vice versa
sub negate_expression
{
    my ($q) = @_;
    if (ref $q eq 'HASH')
    {
        $q->{neg} = !$q->{neg};
        $q->{allow_null} = ($q->{allow_null} || 0) == 1 ? 0 : 1;
        $q->{description}->[1] = NEGATE_ALL_OPERATORS->{$q->{description}->[1]} || $q->{description}->[1];
    }
    elsif (!ref $q)
    {
        $q = { neg => 1, term => $q };
    }
    else
    {
        $q->[0] =~ s/^(AND)|^OR/$1 ? 'OR' : 'AND'/eso;
        $q->[$_] = negate_expression($q->[$_]) for 1..$#$q;
    }
    return $q;
}

# Expand all "brackets" inside an expression,
# making it simply OR(AND(...), AND(...), ...).
# The exception is: if the operation contains '_NE'
# (i.e. is OR_NE, AND_NE), it is not expanded.
# FIXME The usage is partially experimental by now: all user-specified
# boolean charts are expanded (i.e. @specialchart is not expanded).
# This allows to handle OR'ed parts of correlated search terms, for example
# "attachment submitter = ... AND (attachment type = ... OR attachment is patch = ...)".
# This also adds some optimisation for the case when there are "non-seeding" ORed parts.
sub expand_expression
{
    my ($q) = @_;
    my ($t, $i, $j, $k);
    if (ref $q ne 'ARRAY' || $q->[0] =~ /_NE/)
    {
        return $q;
    }
    elsif ($q->[0] =~ /^AND/)
    {
        my @r = ( [ 'AND' ] );
        for $i (1..$#$q)
        {
            if (ref $q->[$i] eq 'ARRAY' && $q->[$i]->[0] !~ /_NE/) # can be only OR after simplify
            {
                my @n;
                $t = expand_expression($q->[$i]);
                for $j (1..$#$t)
                {
                    for $k (0..$#r)
                    {
                        push @n, [ @{$r[$k]}, $t->[$j] ];
                    }
                }
                @r = @n;
            }
            else
            {
                for $j (0..$#r)
                {
                    push @{$r[$j]}, $q->[$i];
                }
            }
        }
        return $q if @r == 1;
        return [ 'OR', @r ];
    }
    elsif ($q->[0] =~ /^OR/)
    {
        my @r;
        for $i (1..$#$q)
        {
            if (ref $q->[$i] eq 'ARRAY') # can be only AND after simplify
            {
                $t = expand_expression($q->[$i]);
                if ($t->[0] eq 'OR')
                {
                    push @r, @$t[1..$#$t];
                }
                else
                {
                    push @r, $t;
                }
            }
            else
            {
                push @r, $q->[$i];
            }
        }
        return $q if @r == @$q - 1;
        return [ 'OR', @r ];
    }
    return undef; # can't happen
}

# Automatically merges AND series of positive correlated terms
# into a single term, and generates table aliases.
# Correlated terms are terms with same base_table.
sub auto_merge_correlated
{
    my $self = shift;
    my ($q) = @_;
    my ($new, $m, $b);
    if (ref $q ne 'ARRAY')
    {
        # Handle single AND terms with base_table
        if ($q->{base_table})
        {
            return $self->merge_base_series($q);
        }
        else
        {
            return $q;
        }
    }
    if ($q->[0] =~ /^OR/)
    {
        # Just auto-merge inner terms of OR
        for my $i (1..$#$q)
        {
            $m = $self->auto_merge_correlated($q->[$i]);
            $new = [ @$q[0..($i-1)] ] if !$new && $m ne $q->[$i];
            push @$new, $m if $new;
        }
        return $new || $q;
    }
    # The main part: find terms with base_table and merge them together
    $new = [ $q->[0] ];
    for my $i (1..$#$q)
    {
        if (ref $q->[$i] eq 'ARRAY')
        {
            $m = $self->auto_merge_correlated($q->[$i]);
            $b ||= {} if $m ne $q->[$i];
            push @$new, $m;
        }
        elsif (!$q->[$i]->{base_table})
        {
            push @$new, $q->[$i];
        }
        else
        {
            $b ||= {}; # $b also indicates if the resulting term was changed
            push @{$b->{$q->[$i]->{base_table}}}, $q->[$i];
        }
    }
    return $q if !$b;
    for (keys %$b)
    {
        my $all_neg = 1;
        $all_neg = $all_neg && $_->{neg} for @{$b->{$_}};
        if (!$all_neg)
        {
            push @$new, $self->merge_base_series($b->{$_});
        }
        else
        {
            # If all terms with some base_table are negated,
            # then the user wants to check "NONE & NONE & NONE ..."
            push @$new, $self->merge_base_series($_) for @{$b->{$_}};
        }
    }
    return $new;
}

# Merges several terms with same base_table into one
# with simply 'table' and 'where' parameters
sub merge_base_series
{
    my $self = shift;
    my ($terms) = @_;
    $terms = [ $terms ] if ref $terms ne 'ARRAY';
    my $single_neg = @$terms == 1 && $terms->[0]->{neg};
    my $base = $terms->[0]->{base_table};
    my $a = $base.'_'.$self->{sequence};
    my $t = $base.' '.$a;
    my @joins = values %{ {
        map { $_->[2] => $_ }
        map { @{$_->{base_joins} || []} }
        @$terms
    } };
    my @repl = ("$base." => "$a.");
    for (@joins)
    {
        push @repl, $_->[2].'.' => $_->[2].'_'.$self->{sequence}.'.';
        $t .= " $_->[0] JOIN $_->[1] $_->[2]_$self->{sequence}";
        $t .= " ON $_->[3]" if $_->[3];
    }
    $t = "($t)" if @joins;
    my $w = join(' AND ', keys %{ { map { $_ => 1 }
        map { $_->{neg} && !$single_neg ? map { "NOT($_)" } list $_->{where} : list $_->{where} }
        @$terms } });
    my $new = {
        table => $t,
        where => $w,
        bugid_field => $terms->[0]->{bugid_field},
        notnull_field => $terms->[0]->{notnull_field},
        neg => $single_neg,
    };
    $new->{$_} = replace_lit($new->{$_}, @repl) for keys %$new;
    $new->{many_rows} = $terms->[0]->{many_rows};
    $self->{sequence}++;
    return $new;
}

# Build SQL code from an expression
sub get_expression_sql
{
    my $self = shift;
    my ($q, $force_joins) = @_;
    my $r;
    if (!$q)
    {
        return undef;
    }
    elsif (ref $q ne 'ARRAY')
    {
        $r = $self->expression_sql_and([ 'AND', $q ]);
    }
    elsif ($force_joins)
    {
        # This means the whole query must be built in the "older way",
        # without UNIONs, only with joins. (OR_MANY/AND_MANY).
        # Really used only in Checkers.
        my $term = $self->expression_sql_many($q, $q->[0] =~ /^AND/ ? 1 : 0);
        $r = $self->expression_sql_and([ 'AND', $term ]);
    }
    elsif ($q->[0] =~ /^OR/)
    {
        $r = $self->expression_sql_or($q)->{table};
        $r =~ s/^\((.*)\)\s+\w+$/$1/so;
    }
    else
    {
        $r = $self->expression_sql_and($q);
    }
    return $r;
}

# Builds SQL code for AND(x,y,...) expression, using SQL JOINs
sub expression_sql_and
{
    my $self = shift;
    my ($query) = @_;
    my @q = @$query;
    shift @q;
    # If all terms are positive and joined on bug_id field,
    # there is no need for 'bugs' table. Check it.
    my $no_need_for_bugs;
    my $first_positive;
    my $or_many_count = scalar grep { ref $_ eq 'ARRAY' && $_->[0] eq 'OR_MANY' } @q;
    for my $i (0..$#q)
    {
        if (ref $q[$i] eq 'ARRAY') # Can be only OR after simplify
        {
            if ($q[$i][0] =~ /MANY$/ && @q > $or_many_count)
            {
                $q[$i] = $self->expression_sql_many($q[$i], 0);
            }
            else
            {
                $q[$i] = $self->expression_sql_or($q[$i]);
            }
        }
        if ($q[$i]{term} || !$q[$i]{bugid_field})
        {
            $no_need_for_bugs = 0;
        }
        elsif (!defined $no_need_for_bugs && !$q[$i]{neg})
        {
            $no_need_for_bugs = 1;
            $first_positive = $i;
        }
    }
    # All other terms are joined on $first_bugid_field
    my $first_bugid_field;
    my $many_rows = 0;
    my $seq = $self->{sequence}++;
    my ($tables, $where) = ('', []);
    if ($no_need_for_bugs)
    {
        my $p = splice @q, $first_positive, 1;
        $first_bugid_field = $p->{bugid_field};
        $tables = $p->{table};
        push @$where, $p->{where} if $p->{where};
    }
    else
    {
        $first_bugid_field = "bugs$seq.bug_id";
        $tables = "bugs bugs$seq";
    }
    # Append other terms
    my $supplist = [];
    my $suppseen = {};
    for my $t (@q)
    {
        for (@{$t->{supp}||[]})
        {
            push @$supplist, $_ if !exists $suppseen->{$_};
            $suppseen->{$_} ||= $t->{allow_null};
        }
    }
    $supplist = [ map { $suppseen->{$_} || s/^(\s*)LEFT/$1INNER/is; $_ } @$supplist ];
    $tables .= ' '.replace_lit(join(' ', @$supplist), 'bugs.', "bugs$seq.");
    for my $i (0..$#q)
    {
        my $t = $q[$i];
        if ($t->{term})
        {
            my $k = replace_lit($t->{term}, 'bugs.', "bugs$seq.");
            push @$where, $t->{neg} ? "NOT($k)" : $k;
        }
        else
        {
            # Do not change values in-place in $t!
            # Hash $t is linked to can also be linked to from other expressions!
            # (the reference can be copied by expand_expression())
            my $t_table = replace_lit($t->{table}, 'bugs.', "bugs$seq.");
            my $t_where = replace_lit($t->{where}, 'bugs.', "bugs$seq.");
            # The good way would be to select between these execution methods
            # on the fly, but it would require simulating DB query optimizer :(
            if ($t->{bugid_field} && !$t->{neg} && $t->{many_rows} &&
                ($many_rows++) > 0)
            {
                # Allow only one many_rows=1 term in a query,
                # wrap following into a SELECT DISTINCT
                my $gs = $self->{sequence}++;
                $tables .= "\nINNER JOIN (SELECT DISTINCT $t->{bugid_field} bug_id FROM $t_table";
                $tables .= " WHERE $t_where" if $t_where;
                $tables .= ") grp$gs ON $first_bugid_field=grp$gs.bug_id";
            }
            else
            {
                $tables .= ($t->{neg} ? "\nLEFT JOIN " : "\nINNER JOIN ") . $t_table;
                if ($t_where || $t->{bugid_field})
                {
                    $tables .= ' ON ' . ($t_where||'');
                    if ($t->{bugid_field})
                    {
                        $tables .= ' AND ' if $t_where;
                        $tables .= " $first_bugid_field=".$t->{bugid_field};
                    }
                }
                if ($t->{neg})
                {
                    push @$where, ($t->{bugid_field} || $t->{notnull_field}) . ' IS NULL';
                }
            }
        }
    }
    $tables = "SELECT DISTINCT $first_bugid_field bug_id FROM\n$tables";
    if (@$where)
    {
        $tables .= "\nWHERE ".join(" AND ", @$where);
    }
    $self->{sequence}++;
    return $tables;
}

# Builds SQL code for OR(x,y,...) expression, using SQL UNION
sub expression_sql_or
{
    my $self = shift;
    my ($query) = @_;
    my @q = @$query;
    shift @q;
    for my $i (0..$#q)
    {
        $q[$i] = $self->expression_sql_and(ref $q[$i] eq 'ARRAY' ? $q[$i] : [ 'AND', $q[$i] ]);
    }
    my $r = {
        table => "(".join("\nUNION\n", @q).") u".$self->{sequence},
        bugid_field => "u$self->{sequence}.bug_id",
    };
    $self->{sequence}++;
    return $r;
}

# Builds SQL code for OR_MANY(...), AND_MANY(...) expressions,
# using LEFT JOINs and simple SQL OR(...) without any UNIONs.
sub expression_sql_many
{
    my $self = shift;
    my ($query, $is_and, $nested) = @_;
    my @q = @$query;
    shift @q;
    my $term = [];
    my $supp = [];
    my $suppseen = {};
    for my $i (0..$#q)
    {
        my $t = $q[$i];
        $t = $self->expression_sql_many($t, !$is_and, 1) if ref $t eq 'ARRAY';
        if ($t->{term})
        {
            push @$term, $t->{neg} ? "NOT($t->{term})" : $t->{term};
            for (@{$t->{supp} || []})
            {
                s/^(\s*)LEFT/$1INNER/is if !$t->{allow_null};
                my $s = $_;
                $s =~ s/^\s*(LEFT|INNER)\s+//iso;
                if (exists $suppseen->{$s})
                {
                    # The same join may have come from several terms;
                    # Always use the LEFT if there is one.
                    $supp->[$suppseen->{$s}] = $_ if lc $1 eq 'left';
                    next;
                }
                $suppseen->{$s} = scalar @$supp;
                push @$supp, $_;
            }
        }
        else
        {
            # Even AND expressions must always use LEFT JOIN when nested into OR
            my $tab = ($t->{neg} || !$is_and || $nested ? "\nLEFT" : "\nINNER")." JOIN $t->{table}";
            if ($t->{where} || $t->{bugid_field})
            {
                $tab .= ' ON ' . ($t->{where}||'');
                if ($t->{bugid_field})
                {
                    $tab .= ' AND ' if $t->{where};
                    $tab .= " bugs.bug_id=".$t->{bugid_field};
                }
            }
            push @$supp, $tab;
            push @$term, ($t->{bugid_field} || $t->{notnull_field}) .
                ($t->{neg} ? ' IS NULL' : ' IS NOT NULL');
        }
    }
    my $r = {
        term => '('.join(($is_and ? ' AND ' : ' OR '), @$term).')',
        supp => $supp,
        allow_null => 1,
    };
    return $r;
}

#######################
## Utility functions ##
#######################

# Expand {'a|b|c' => v} to {a => v, b => v, c => v} inside a hashref
sub expand_hash
{
    my ($h) = @_;
    for my $k (keys %$h)
    {
        expand_hash($h->{$k}) if ref $h->{$k} eq 'HASH';
        if ($k =~ /\|/)
        {
            for (split /\|/, $k)
            {
                if ($h->{$_})
                {
                    $h->{$_} = { %{$h->{$_}}, %{$h->{$k}} };
                }
                else
                {
                    $h->{$_} = $h->{$k};
                }
            }
            delete $h->{$k};
        }
    }
    return $h;
}

# replace_lit($s, $search => $replace, $search2 => $replace2, ...)
# Replace substrings in $s, ignoring string literals.
sub replace_lit
{
    my ($s, @repl) = @_;
    return undef if !defined $s;
    my @s = split /(
        \"(?:[^\"\\]+|\\.)*\" | # "
        \'(?:[^\'\\]+|\\.)*\' | # '
        \`(?:[^\`\\]+|\\.)*\`   # `
    )/xs, $s, -1;
    my $i;
    for (@s)
    {
        if (!/^[\"\'\`]/) # "'`
        {
            for ($i = 0; $i < @repl; $i += 2)
            {
                s/\Q$repl[$i]\E/$repl[$i+1]/gs;
            }
        }
    }
    return join '', @s;
}

# Objects blessed to Bugzilla::Search::Code automatically
# append "supptables" when converted to string
package Bugzilla::Search::Code;

use overload '""' => sub
{
    my $self = shift;
    for my $t (@{$self->[1]})
    {
        if (!$self->[3]->{$t})
        {
            $self->[3]->{$t} = 1;
            push @{$self->[2]}, $t;
        }
    }
    return $self->[0];
};

1;
__END__
