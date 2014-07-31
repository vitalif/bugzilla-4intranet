#!/usr/bin/perl -wT
# Mass bug import/update from Excel/CSV files (originally CustIS Bug 42133)
# License: Dual-license GPL 3.0+ or MPL 1.1+
# Contributor(s): Vitaliy Filippov <vitalif@mail.ru>

use utf8;
use Encode;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Util;
use Bugzilla::Token;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::BugMail;
use Bugzilla::User;

use IO::File;

# Also loaded on demand: Spreadsheet::ParseExcel, Spreadsheet::XSLX

# Constants
use constant BUG_DAYS => 92;
use constant XLS_LISTNAME => '';

my $user = Bugzilla->login(LOGIN_REQUIRED);
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};
my $ARGS = Bugzilla->input_params;

# Check permissions
$user->in_group('importxls') ||
    ThrowUserError('auth_failure', {
        group  => 'importxls',
        action => 'import',
        object => 'bugs',
    });

my $listname = $ARGS->{listname} || '';
my $bugdays = $ARGS->{bugdays} || '';
($bugdays) = $bugdays =~ /^(\d+)$/so;
$bugdays ||= BUG_DAYS;
trick_taint($listname);
trick_taint($bugdays);
$vars->{listname} = $listname || XLS_LISTNAME;
$vars->{bugdays} = $bugdays;

my $upload;
my $name_tr = {};
my $bug_tpl = {};

$bug_tpl->{platform} = Bugzilla->params->{defaultplatform}
    if Bugzilla->params->{defaultplatform} && Bugzilla->params->{useplatform};

for (keys %$ARGS)
{
    if (/^f_/so && $ARGS->{$_})
    {
        # Default field values for bugs
        $bug_tpl->{$'} = $ARGS->{$_};
    }
    elsif (/^t_/so && $ARGS->{$_} ne $')
    {
        # Field mapping
        $name_tr->{$'} = $ARGS->{$_};
    }
}

$vars->{bug_tpl} = $bug_tpl;
$vars->{name_tr} = $name_tr;

my $field_descs = { map { $_->name => $_->description } Bugzilla->get_fields({ obsolete => 0 }) };
$field_descs->{platform} = $field_descs->{rep_platform} if $field_descs->{rep_platform};
$field_descs->{comment} = $field_descs->{longdesc};
for ((grep { /\./ } keys %$field_descs), (qw/rep_platform longdesc bug_group changeddate commenter content opendate
    creation_ts delta_ts days_elapsed everconfirmed percentage_complete work_time/))
{
    delete $field_descs->{$_};
}

$vars->{import_field_descs} = $field_descs;
$vars->{import_fields} = [ sort { $field_descs->{$a} cmp $field_descs->{$b} } keys %$field_descs ];

my $guess_field_descs = [
    map { $_ => $field_descs->{$_} }
    sort { length($field_descs->{$b}) <=> length($field_descs->{$a}) }
    keys %$field_descs
];

# Field guesser
sub guess_field_name
{
    my ($name, $guess_field_descs) = @_;
    my ($r, $k, $v);
    for (my $i = 0; $i < @$guess_field_descs; $i+=2)
    {
        ($k, $v) = ($guess_field_descs->[$i], $guess_field_descs->[$i+1]);
        ($r = $k), last if $name =~ /\Q$v\E/is || $name eq $k;
    }
    return $r;
}

unless ($ARGS->{commit})
{
    unless (my $upload = $ARGS->{xls})
    {
        if (!defined $ARGS->{result})
        {
            # Show file upload form
            $vars->{form} = 1;
        }
        else
        {
            # Show import result
            $vars->{show_result} = 1;
            $vars->{result} = $ARGS->{result};
            $vars->{bug_id} = $ARGS->{bug_id};
            $vars->{importnext} = 'importxls.cgi?'.http_build_query({
                listname => $listname,
                bugdays  => $bugdays,
                (map { ("f_$_" => $bug_tpl->{$_}) } keys %$bug_tpl),
                (map { ("t_$_" => $name_tr->{$_}) } keys %$name_tr),
            });
        }
    }
    else
    {
        # Show parsed spreadsheet with checkboxes for selection
        my $table;
        if ($ARGS->{xls} !~ /\.(xlsx?)$/iso)
        {
            # CSV
            $table = parse_csv($upload, $ARGS->{xls}, $name_tr, $ARGS->{csv_delimiter});
        }
        else
        {
            $table = parse_excel($upload, $ARGS->{xls}, $listname, $name_tr);
        }
        if (!$table || $table->{error})
        {
            # Parse error
            $vars->{show_error} = 1;
            $vars->{error} = $table->{error} if $table;
        }
        else
        {
            my $i = 0;
            my $sth = $dbh->prepare("SELECT COUNT(*) FROM `bugs` WHERE `short_desc`=? AND `delta_ts`>=DATE_SUB(CURDATE(),INTERVAL ? DAY)");
            for my $bug (@{$table->{data}})
            {
                # Check if this bug is already added
                if ($bug->{short_desc})
                {
                    trick_taint($bug->{short_desc});
                    $sth->execute($bug->{short_desc}, $bugdays);
                    ($bug->{enabled}) = $sth->fetchrow_array;
                    $bug->{enabled} = !$bug->{enabled};
                }
                $bug->{num} = ++$i;
            }
            # Guess fields based on their names
            my $g;
            for (@{$table->{fields}})
            {
                if (!exists $name_tr->{$_} && ($g = guess_field_name($_, $guess_field_descs)))
                {
                    $name_tr->{$_} = $g;
                }
            }
            # Show bug table
            $vars->{fields} = $table->{fields};
            $vars->{data} = $table->{data};
            $vars->{token} = issue_session_token('importxls');
        }
    }
    $template->process("bug/import/importxls.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
    exit;
}
else
{
    check_token_data($ARGS->{token}, 'importxls', 'importxls.cgi');
    # Run import and redirect to result page
    my $bugs = {};
    for (keys %$ARGS)
    {
        if (/^b_(.*?)_(\d+)$/so)
        {
            # bug fields
            my $k = (exists $name_tr->{$1} ? $name_tr->{$1} : $1);
            $bugs->{$2}->{$k} = $ARGS->{$_} if $k;
        }
    }
    my $r = 0;
    my $ids = [];
    my $f = 0;
    my $bugmail = [];
    Bugzilla->dbh->bz_start_transaction;
    my $custom_fields = {};
    foreach my $field (Bugzilla->get_fields({custom => 1}))
    {
        $custom_fields->{ $field->{name} } = $field;
    }
    for my $bug (@$bugs{sort {$a <=> $b} keys %$bugs})
    {
        $bug->{$_} ||= $bug_tpl->{$_} for keys %$bug_tpl;
        if ($bug->{enabled})
        {
            # If bug with this ID exists - update it, else - post new bug
            my $id = Bugzilla::Bug::create_or_update($bug)->id;
            if ($id)
            {
                $r++;
                push @$ids, $id;
            }
            else
            {
                Bugzilla->dbh->bz_in_transaction and Bugzilla->dbh->bz_rollback_transaction;
                $f = 1;
                last;
            }
        }
    }
    unless ($f)
    {
        # Send bugmail only after successful completion
        Bugzilla->send_mail;
        Bugzilla->dbh->bz_commit_transaction;
        print Bugzilla->cgi->redirect(-location => 'importxls.cgi?'.http_build_query({
            result   => $r,
            bug_id   => $ids,
            listname => $listname,
            bugdays  => $bugdays,
            (map { ("f_$_" => $bug_tpl->{$_}) } keys %$bug_tpl),
            (map { ("t_$_" => $name_tr->{$_}) } keys %$name_tr),
        }));
    }
    exit;
}

# CSV file reader
# Multiline CSV compatible!
sub csv_read_record
{
    my ($fh, $enc, $s, $q) = @_;
    $q ||= '"';
    $s ||= ',';
    my $re_field = qr/^\s*(?:$q((?:[^$q]|$q$q)*)$q|([^$q$s]*))\s*($s)?/s;
    my @parts = ();
    my $line = "";
    my $num_lines = 0;
    my $l;
    my $i;
    while (<$fh>)
    {
        trick_taint($_);
        $l = $_;
        if ($enc && $enc ne 'utf-8')
        {
            Encode::from_to($l, $enc, 'utf-8');
        }
        Encode::_utf8_on($l);
        $line .= $l;
        while ($line =~ s/$re_field//)
        {
            $l = $1 || $2;
            $l =~ s/$q$q/$q/gs;
            push @parts, $l;
            return \@parts if !$3;
        }
    }
    if (length $line)
    {
        warn "eol before last field end\n";
        warn "-->$line<--\n";
    }
    return @parts ? \@parts : undef;
}

# Parse Excel file, or call parse_csv for CSV file
sub parse_excel
{
    my ($fd, $name, $only_list, $name_tr) = @_;
    my $xls;
    if ($name =~ /\.xlsx$/iso)
    {
        # OOXML
        require Spreadsheet::XLSX;
        $xls = Spreadsheet::XLSX->new(IO::File->new_from_fd(fileno $fd, 'r'));
    }
    elsif ($name =~ /\.xls$/iso)
    {
        # Excel binary
        require Spreadsheet::ParseExcel;
        $xls = Spreadsheet::ParseExcel->new;
        $xls = ($xls->parse($fd) or return { error => $xls->error });
    }
    return { error => 'parse_error' } unless $xls;
    my $r = { data => [] };
    for my $page ($xls->worksheets())
    {
        # Just select one sheet?
        next if $only_list && $page->{Name} ne $only_list;
        my ($row_min, $row_max) = $page->row_range;
        my ($col_min, $col_max) = $page->col_range;
        my $head = get_row($page, $row_min, $col_min, $col_max);
        $r->{fields} ||= $head;
        # Handle the table
        for my $row (($row_min+1) .. $row_max)
        {
            $row = get_row($page, $row, $col_min, $col_max) || next;
            $row = { map { ($head->[$_] => $row->[$_]) } (0..$#$head) };
            push @{$r->{data}}, $row;
        }
    }
    return { error => 'empty' } unless @{$r->{data}};
    return $r;
}

# Parse CSV file
sub parse_csv
{
    my ($fd, $name, $name_tr, $delimiter) = @_;
    my $s = Bugzilla->user->settings->{csv_charset};
    my $r = { data => [] };
    my $row;
    while ($row = csv_read_record($fd, $s && $s->{value}, $delimiter))
    {
        if (!$r->{fields})
        {
            $_ = trim($_) for @$row;
            $r->{fields} = $row;
        }
        else
        {
            $row = { map { ($r->{fields}->[$_] => $row->[$_]) } (0..$#{$r->{fields}}) };
            push @{$r->{data}}, $row;
        }
    }
    return { error => 'parse_error' } if !$r->{fields} || !@{$r->{fields}};
    return $r;
}

# Extract row from Excel
sub get_row
{
    my ($page, $row, $col_min, $col_max) = @_;
    return [ map {
        $_ = $page->get_cell($row, $_);
        $_ = $_ ? $_->value : '';
        Encode::_utf8_on($_);
        tr/‒–—/---/;
        tr/―‑/--/;
        trim($_);
    } ($col_min .. $col_max) ];
}

1;
__END__
