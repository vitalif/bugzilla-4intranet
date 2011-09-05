#!/usr/bin/perl -wT
# Bug 42133
# Интерфейс множественного импорта/обновления багов из Excel-файлов

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

# Подгружаются по необходимости: Spreadsheet::ParseExcel, Spreadsheet::XSLX;

# константы
use constant BUG_DAYS => 92;
use constant XLS_LISTNAME => 'Bugz';
use constant MANDATORY_FIELDS => qw(short_desc product component);

# начинаем-с
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $cgi = Bugzilla->cgi;
my $dbh = Bugzilla->dbh;
my $template = Bugzilla->template;
my $vars = {};

my $args = {};
for ($cgi->param)
{
    my $v = $_;
    utf8::decode($v) unless Encode::is_utf8($v);
    if ($v eq 'bug_id')
    {
        $args->{$v} = [ $cgi->param($_) ];
    }
    else
    {
        $args->{$v} = $cgi->param($_);
    }
    utf8::decode($args->{$v}) unless Encode::is_utf8($args->{$v});
}

# проверяем группу
$user->in_group('importxls') ||
    ThrowUserError('auth_failure', {
        group  => 'importxls',
        action => 'import',
        object => 'bugs',
    });

my $listname = $cgi->param('listname') || '';
my $bugdays = $cgi->param('bugdays') || '';
($bugdays) = $bugdays =~ /^(\d+)$/so;
$bugdays ||= BUG_DAYS;
trick_taint($listname);
trick_taint($bugdays);
$vars->{listname} = $listname || XLS_LISTNAME;
$vars->{bugdays} = $bugdays;

my $upload;
my $name_tr = {};
my $bug_tpl = {};

$bug_tpl->{platform} = Bugzilla->params->{defaultplatform} if Bugzilla->params->{defaultplatform};

for (keys %$args)
{
    if (/^f_/so && $args->{$_})
    {
        # шаблон для багов
        $bug_tpl->{$'} = $args->{$_};
    }
    elsif (/^t_/so && $args->{$_} ne $')
    {
        # переименования полей таблицы
        $name_tr->{$'} = $args->{$_};
    }
}

$vars->{bug_tpl} = $bug_tpl;
$vars->{name_tr} = $name_tr;

my $field_descs = { map { $_->name => $_->description } Bugzilla->get_fields({ obsolete => 0 }) };
$field_descs->{platform} = $field_descs->{rep_platform} if $field_descs->{rep_platform};
$field_descs->{comment} = $field_descs->{longdesc};
for ((grep { /\./ } keys %$field_descs), (qw/rep_platform longdesc bug_group changeddate commenter content opendate
    creation_ts delta_ts days_elapsed everconfirmed percentage_complete owner_idle_time work_time/))
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

# Функция угадывания поля
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

unless ($args->{commit})
{
    unless ($upload = $cgi->upload('xls'))
    {
        if (!defined $args->{result})
        {
            # показываем формочку выбора файла и заливки
            $vars->{form} = 1;
        }
        else
        {
            # показываем результат импорта
            $vars->{show_result} = 1;
            $vars->{result} = $args->{result};
            $vars->{bug_id} = $args->{bug_id};
            my $newcgi = new Bugzilla::CGI({
                listname => $listname,
                bugdays  => $bugdays,
                (map { ("f_$_" => $bug_tpl->{$_}) } keys %$bug_tpl),
                (map { ("t_$_" => $name_tr->{$_}) } keys %$name_tr),
            });
            $vars->{importnext} = 'importxls.cgi?'.$newcgi->query_string;
        }
    }
    else
    {
        # показываем интерфейс с распаршенной таблицей и галочками (или с обломом)
        my $table;
        if ($args->{xls} !~ /\.(xlsx?)$/iso)
        {
            # CSV
            $table = parse_csv($upload, $args->{xls}, $name_tr, $args->{csv_delimiter});
        }
        else
        {
            $table = parse_excel($upload, $args->{xls}, $listname, $name_tr);
        }
        if (!$table || $table->{error})
        {
            # ошибка
            $vars->{show_error} = 1;
            $vars->{error} = $table->{error} if $table;
        }
        else
        {
            # распарсилось
            my $i = 0;
            my $sth = $dbh->prepare("SELECT COUNT(*) FROM `bugs` WHERE `short_desc`=? AND `delta_ts`>=DATE_SUB(CURDATE(),INTERVAL ? DAY)");
            # номера и проверка
            for my $bug (@{$table->{data}})
            {
                # проверяем нет ли уже такого бага
                if ($bug->{short_desc})
                {
                    trick_taint($bug->{short_desc});
                    $sth->execute($bug->{short_desc}, $bugdays);
                    ($bug->{enabled}) = $sth->fetchrow_array;
                    $bug->{enabled} = !$bug->{enabled};
                }
                $bug->{num} = ++$i;
            }
            # угадываем имена полей
            my $g;
            for (@{$table->{fields}})
            {
                if (!exists $name_tr->{$_} && ($g = guess_field_name($_, $guess_field_descs)))
                {
                    $name_tr->{$_} = $g;
                }
            }
            # показываем табличку с багами
            $vars->{fields} = $table->{fields};
            $vars->{data} = $table->{data};
        }
    }
    $template->process("bug/import/importxls.html.tmpl", $vars)
        || ThrowTemplateError($template->error());
}
else
{
    # выполняем импорт и отдаём редирект на результаты
    my $bugs = {};
    for (keys %$args)
    {
        if (/^b_(.*?)_(\d+)$/so)
        {
            # поля багов
            $bugs->{$2}->{(exists $name_tr->{$1} ? $name_tr->{$1} : $1)} = $args->{$_};
        }
    }
    my $r = 0;
    my $ids = [];
    my $f = 0;
    my $bugmail = [];
    Bugzilla->dbh->bz_start_transaction;
    for my $bug (@$bugs{sort {$a <=> $b} keys %$bugs})
    {
        $bug->{$_} ||= $bug_tpl->{$_} for keys %$bug_tpl;
        if ($bug->{enabled})
        {
            my $id;
            if ($bug->{bug_id} && Bugzilla::Bug->new($bug->{bug_id}))
            {
                # если уже есть баг с таким ID - обновляем
                $id = process_bug($bug, $bugmail, $vars);
            }
            else
            {
                # если ещё нет - ставим новый
                $id = post_bug($bug, $bugmail, $vars);
            }
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
        my $newcgi = new Bugzilla::CGI({
            result   => $r,
            bug_id   => $ids,
            listname => $listname,
            bugdays  => $bugdays,
            (map { ("f_$_" => $bug_tpl->{$_}) } keys %$bug_tpl),
            (map { ("t_$_" => $name_tr->{$_}) } keys %$name_tr),
        });
        # и только теперь (по успешному завершению) рассылаем почту
        Bugzilla->cgi->delete('dontsendbugmail');
        send_results($_) for @$bugmail;
        Bugzilla->dbh->bz_commit_transaction;
        print $cgi->redirect(-location => 'importxls.cgi?'.$newcgi->query_string);
    }
}

# функция чтения CSV-файлов
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

# разобрать лист Excel или передать в parse_csv
sub parse_excel
{
    my ($upload, $name, $only_list, $name_tr) = @_;
    my $xls;
    if ($name =~ /\.xlsx$/iso)
    {
        # OOXML
        require Spreadsheet::XLSX;
        $xls = Spreadsheet::XLSX->new($upload->handle);
    }
    elsif ($name =~ /\.xls$/iso)
    {
        # Обычный формат
        require Spreadsheet::ParseExcel;
        $xls = Spreadsheet::ParseExcel->new->Parse($upload);
    }
    return { error => 'parse_error' } unless $xls;
    my $r = { data => [] };
    for my $page ($xls->worksheets())
    {
        # выбираем для обработки только лист с заданным именем
        next if $only_list && $page->{Name} ne $only_list;
        my ($row_min, $row_max) = $page->row_range;
        my ($col_min, $col_max) = $page->col_range;
        my $head = get_row($page, $row_min, $col_min, $col_max);
        $r->{fields} ||= $head;
        # обрабатываем саму таблицу
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

# Разобрать CSV-файл
# FIXME многострочное CSV не поддерживается
sub parse_csv
{
    my ($upload, $name, $name_tr, $delimiter) = @_;
    my $s = Bugzilla->user->settings->{csv_charset};
    my $r = { data => [] };
    my $row;
    while ($row = csv_read_record($upload, $s && $s->{value}, $delimiter))
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

# вернуть строчку из экселя
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

# TODO объединить post_bug и process_bug с ими же из email_in.pl и importxml.pl и вынести куда-то

# добавить баг
sub post_bug
{
    my ($fields_in, $bugmail, $vars) = @_;
    my $cgi = Bugzilla->cgi;
    # FIXME проверку обязательных полей можно куда-нибудь унести
    my @unexist;
    for (MANDATORY_FIELDS)
    {
        if (!exists $fields_in->{$_})
        {
            push @unexist, $vars->{import_field_descs}->{$_};
        }
    }
    if (@unexist)
    {
        ThrowUserError('import_fields_mandatory', { fields => \@unexist });
    }
    # имитируем почтовое использование с показом ошибок в браузер
    my $um = Bugzilla->usage_mode;
    Bugzilla->usage_mode(USAGE_MODE_EMAIL);
    Bugzilla->error_mode(ERROR_MODE_WEBPAGE);
    $Bugzilla::Error::IN_EVAL++;
    my $product = eval { Bugzilla::Product->check({ name => $fields_in->{product} }) };
    if (!$product)
    {
        return undef;
    }
    # добавляем дефолтные группы
    my @gids;
    my $controls = $product->group_controls;
    foreach my $gid (keys %$controls)
    {
        if ($controls->{$gid}->{membercontrol} == CONTROLMAPDEFAULT && Bugzilla->user->in_group_id($gid) ||
            $controls->{$gid}->{othercontrol} == CONTROLMAPDEFAULT && !Bugzilla->user->in_group_id($gid))
        {
            $fields_in->{"bit-$gid"} = 1;
        }
    }
    unless ($fields_in->{version})
    {
        # угадаем версию
        my $component;
        eval
        {
            $component = Bugzilla::Component->new({
                product => $product,
                name    => $fields_in->{component},
            });
        };
        # если нет дефолтной версии в компоненте
        if (!$component || !($fields_in->{version} = $component->default_version))
        {
            my $vers = [ map ($_->name, @{$product->versions}) ];
            my $v;
            if (($v = $cgi->cookie("VERSION-" . $product->name)) &&
                !grep { $_ eq $v } @$vers)
            {
                # возьмём из куки
                $fields_in->{version} = $v;
            }
            else
            {
                # или просто последнюю, как и в enter_bug.cgi
                $fields_in->{version} = $vers->[$#$vers];
            }
        }
    }
    # скармливаем параметры $cgi
    foreach my $field (keys %$fields_in)
    {
        $cgi->param(-name => $field, -value => $fields_in->{$field});
    }
    $cgi->param(-name => 'dontsendbugmail', -value => 1);
    # и дёргаем post_bug.cgi
    my $vars_out = do 'post_bug.cgi';
    $Bugzilla::Error::IN_EVAL--;
    Bugzilla->usage_mode($um);
    if ($vars_out)
    {
        my $bug_id = $vars_out->{bug}->id;
        push @$bugmail, @{$vars_out->{sentmail}};
        return $bug_id;
    }
    return undef;
}

sub process_bug
{
    my ($fields_in, $bugmail, $vars) = @_;

    my $um = Bugzilla->usage_mode;
    Bugzilla->usage_mode(USAGE_MODE_EMAIL);
    Bugzilla->error_mode(ERROR_MODE_WEBPAGE);
    Bugzilla->cgi->param(-name => 'dontsendbugmail', -value => 1);

    my %fields = %$fields_in;

    my $bug_id = $fields{'bug_id'};
    $fields{'id'} = $bug_id;
    delete $fields{'bug_id'};

    my $bug = Bugzilla::Bug->check($bug_id);

    # process_bug.cgi always "tries to set" these fields
    $fields{$_} ||= $bug->$_ for qw(product component target_milestone version);

    if (exists $fields{blocked} || exists $fields{dependson})
    {
        $fields{blocked} ||= join ',', @{ $bug->blocked };
        $fields{dependson} ||= join ',', @{ $bug->dependson };
    }

    if ($fields{'bug_status'}) {
        $fields{'knob'} = $fields{'bug_status'};
    }
    # If no status is given, then we only want to change the resolution.
    elsif ($fields{'resolution'}) {
        $fields{'knob'} = 'change_resolution';
        $fields{'resolution_knob_change_resolution'} = $fields{'resolution'};
    }
    if ($fields{'dup_id'}) {
        $fields{'knob'} = 'duplicate';
    }

    # Move @cc to @newcc as @cc is used by process_bug.cgi to remove
    # users from the CC list when @removecc is set.
    $fields{newcc} = delete $fields{cc} if $fields{cc};

    # Make it possible to remove CCs.
    if ($fields{'removecc'}) {
        $fields{'cc'} = [split(',', $fields{'removecc'})];
        $fields{'removecc'} = 1;
    }

    my $cgi = Bugzilla->cgi;
    foreach my $field (keys %fields) {
        $cgi->param(-name => $field, -value => $fields{$field});
    }
    $cgi->param('longdesclength', scalar @{ $bug->comments });
    $cgi->param('token', issue_hash_token([$bug->id, $bug->delta_ts]));

    # FIXME All this is an ugly hack. Bug::update() should call anything needed, not process_bug.cgi
    $Bugzilla::Error::IN_EVAL++;
    my $vars_out = do 'process_bug.cgi';
    $Bugzilla::Error::IN_EVAL--;
    Bugzilla->usage_mode($um);

    if ($vars_out)
    {
        push @$bugmail, @{$vars_out->{sentmail}};
        return $bug_id;
    }
    return undef;
}

1;
__END__

The contents of this file are subject to the Mozilla Public
License Version 1.1 (the "License"); you may not use this file
except in compliance with the License. You may obtain a copy of
the License at http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS
IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
implied. See the License for the specific language governing
rights and limitations under the License.

The Original Code is the Bugzilla Bug Tracking System.

The Initial Developer of the Original Code is Netscape Communications
Corporation. Portions created by Netscape are
Copyright (C) 1998 Netscape Communications Corporation. All
Rights Reserved.

Contributor(s): Terry Weissman <terry@mozilla.org>
                Dan Mosedale <dmose@mozilla.org>
                Joe Robins <jmrobins@tgix.com>
                Gervase Markham <gerv@gerv.net>
                Marc Schumann <wurblzap@gmail.com>
