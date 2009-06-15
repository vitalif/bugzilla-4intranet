#!/usr/bin/perl -wT
# Bug 42133
# Интерфейс множественного импорта багов из Excel-файлов

use utf8;
use Encode;
use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Bug;
use Bugzilla::User;

# Подгружаются по необходимости: Spreadsheet::ParseExcel, Spreadsheet::XSLX;

# константы
use constant BUG_DAYS => 92;
use constant XLS_LISTNAME => 'Bugz';
use constant MANDATORY_FIELDS => [qw(short_desc version platform product component)];

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
    $args->{$v} = $cgi->param($_);
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

for (keys %$args)
{
    if (/^f_/so && $args->{$_})
    {
        # шаблон для багов
        $bug_tpl->{$'} = $args->{$_};
    }
    elsif (/^t_/so && $args->{$_} && $args->{$_} ne $')
    {
        # переименования полей таблицы
        $name_tr->{$'} = $args->{$_};
    }
}

$vars->{bug_tpl} = $bug_tpl;
$vars->{name_tr} = $name_tr;

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
        my $table = parse_excel($upload, $args->{xls}, $listname, $name_tr);
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
            # показываем табличку с багами
            my %fhash = map { ($name_tr->{$_} || $_) => 1 } @{$table->{fields}};
            for (@{ MANDATORY_FIELDS() })
            {
                push @{$table->{fields}}, $_ unless $fhash{$_} || $bug_tpl->{$_};
            }
            $vars->{fields} = $table->{fields};
            $vars->{data} = $table->{data};
        }
    }
    print $cgi->header();
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
            $bugs->{$2}->{$name_tr->{$1} || $1} = $args->{$_};
        }
    }
    my $r = 0;
    my $ids = [];
    my $f = 0;
    Bugzilla->dbh->bz_start_transaction;
    for my $bug (values %$bugs)
    {
        $bug->{$_} ||= $bug_tpl->{$_} for keys %$bug_tpl;
        if ($bug->{enabled})
        {
            my $id = post_bug($bug);
            if ($id)
            {
                $r++;
                push @$ids, $id;
            }
            else
            {
                Bugzilla->dbh->bz_rollback_transaction;
                $f = 1;
                last;
            }
        }
    }
    unless ($f)
    {
        my $newcgi = new Bugzilla::CGI({
            result   => $r,
            listname => $listname,
            bugdays  => $bugdays,
            (map { ("f_$_" => $bug_tpl->{$_}) } keys %$bug_tpl),
            (map { ("t_$_" => $name_tr->{$_}) } keys %$name_tr),
        });
        Bugzilla->dbh->bz_commit_transaction;
        print $cgi->redirect(-location => 'importxls.cgi?'.$newcgi->query_string);
    }
}

# разобрать лист Excel
sub parse_excel
{
    my ($upload, $name, $only_list, $name_tr) = @_;
    my $xls;
    if ($name =~ /\.xlsx$/iso)
    {
        # OOXML
        require Spreadsheet::XLSX;
        $xls = Spreadsheet::XLSX->new($upload);
    }
    else
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
        $r->{fields} = $head;
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

# вернуть строчку из экселя
sub get_row
{
    my ($page, $row, $col_min, $col_max) = @_;
    return [ map { $_ = $page->get_cell($row, $_); $_ ? trim($_->value) : '' } ($col_min .. $col_max) ];
}

# добавить баг
sub post_bug
{
    my ($fields_in) = @_;
    my %fields = %$fields_in;
    my $cgi = Bugzilla->cgi;
    foreach my $field (keys %fields)
    {
        $cgi->param(-name => $field, -value => $fields{$field});
    }
    my $um = Bugzilla->usage_mode;
    Bugzilla->usage_mode(USAGE_MODE_EMAIL);
    Bugzilla->error_mode(ERROR_MODE_WEBPAGE);
    my $bug_id = do 'post_bug.cgi';
    Bugzilla->usage_mode($um);
    return $bug_id;
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
