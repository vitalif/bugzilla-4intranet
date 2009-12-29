#!/usr/bin/perl
# Bug 53254 - Синхронизация тест-плана с категорией MediaWiki

use utf8;
use strict;
use Bugzilla::Util;
use Bugzilla::User;
use Testopia::TestCase;

use Encode;
use URI;
use XML::Parser;
use HTML::Entities;
use HTTP::Request::Common;
use LWP::Simple qw($ua);

my $cgi = Bugzilla->cgi;
my $plan = Bugzilla->hook_args->{plan};
my $vars = Bugzilla->hook_args->{vars};

# Синхронизация по /tr_show_plan.cgi?wikisync=1
if ($cgi->param('wikisync'))
{
    my $wiki_url = $plan->product->wiki_url || Bugzilla->params->{wiki_url};
    if ($wiki_url && $plan->wiki)
    {
        my $xml = fetch_wiki_category_xml($wiki_url, $plan->wiki);
        my $p = XML::Parser->new(Handlers => {
            Start => \&wiki_sync_handle_start,
            End   => \&wiki_sync_handle_end,
            Char  => \&wiki_sync_handle_char,
        });
        $p->{_ws_wiki_url} = $wiki_url;
        $p->{_ws_plan} = $plan;
        $p->parse($xml);
    }
}

sub wiki_sync_handle_start
{
    my $self = shift;
    my $element = shift;
    my %attr = @_;
    if ($element eq 'page')
    {
        $self->{_ws_page} = {};
    }
    elsif ($self->{_ws_page})
    {
        if ($element eq 'revision')
        {
            $self->{_ws_in_revision} = 'revision_';
        }
        if ($self->{_ws_in_revision} && $element eq 'contributor')
        {
            $self->{_ws_in_contributor} = 'contributor_';
        }
        $self->{_ws_current} =
            $self->{_ws_in_revision} .
            $self->{_ws_in_contributor} .
            $element;
    }
}

sub wiki_sync_handle_end
{
    my $self = shift;
    my $element = shift;
    if ($element eq 'page')
    {
        unless ($self->{_ws_page}->{title} =~ /^(Шаблон:|Template:)/iso)
        {
            wiki_sync_case($self->{_ws_page}, $self->{_ws_wiki_url}, $self->{_ws_plan});
        }
        delete $self->{_ws_page};
        delete $self->{_ws_current};
    }
    elsif ($self->{_ws_page})
    {
        if ($element eq 'revision')
        {
            $self->{_ws_in_revision} = undef;
        }
        if ($self->{_ws_in_revision} && $element eq 'contributor')
        {
            $self->{_ws_in_contributor} = undef;
        }
        $self->{_ws_current} = '';
    }
}

sub wiki_sync_handle_char
{
    my $self = shift;
    my ($str) = @_;
    if ($self->{_ws_current})
    {
        $self->{_ws_page}->{$self->{_ws_current}} .= $str;
    }
}

sub url_quote_noslash
{
    my ($s) = (@_);
    $s = url_quote($s);
    $s =~ s/\%2F/\//gso;
    return $s;
}

sub wiki_sync_case
{
    my ($page, $wiki_url, $plan) = @_;
    my $dbh = Bugzilla->dbh;
    my ($case) = $dbh->selectrow_array(
        "SELECT c.case_id FROM test_case_plans cp, test_cases c WHERE cp.plan_id=? AND c.case_id=cp.case_id AND c.summary=?",
        undef, $plan->id, $page->{title}
    );
    return 1 if $case;
    my $tcaction = Bugzilla->params->{test_case_wiki_action_iframe};
    $tcaction =~ s!\$URL[^\?&\s\"\']*!$wiki_url.'/'.url_quote_noslash($page->{title})!gse;
    $case = {
        author_id   => Bugzilla->user->id || '',
        action      => $tcaction,
        effect      => '',
        setup       => '',
        breakdown   => '',
        plans       => [ $plan ],
        summary     => $page->{title},
    };
    my @fields = qw(tester alias estimated_time isautomated script arguments requirement dependson blocks tags bugs components status category priority);
    my $fre = '^\s*;\s*('.join('|', @fields).')\s*:([^\n]*)';
    while ($page->{revision_text} =~ /$fre/giso)
    {
        $case->{lc $1} = trim($2);
    }
    $case->{$_} ||= '' for @fields;
    if (lc($case->{isautomated}) eq 'on' ||
        lc($case->{isautomated}) eq 'true' ||
        $case->{isautomated} eq '1')
    {
        $case->{isautomated} = 1;
    }
    else
    {
        delete $case->{isautomated};
    }
    $case->{components} = [ split /[\s,]*,[\s,]*/, trim($case->{components}) ];
    $case->{default_tester_id} = login_to_id(trim($case->{tester})) || '';
    delete $case->{tester};
    $case->{case_status_id} = $case->{status} || 'PROPOSED';
    delete $case->{status};
    $case->{category_id} = $case->{category} || '--default--';
    delete $case->{category};
    $case->{priority_id} = $case->{priority} || 'P3';
    delete $case->{priority};
    return $case = Testopia::TestCase->create($case);
}

sub fetch_wiki_category_xml
{
    my ($wiki_url, $category) = @_;
    $wiki_url =~ s!(/*index\.php)?/*$!/index.php!so;
    $_[0] = $wiki_url;
    my $uri = URI->new($wiki_url . '?title=Special:Export&action=submit')->canonical;
    # Дёргаем Special:Export и вытаскиваем список страниц категории
    Encode::_utf8_off($category);
    my $response = $ua->request(POST $uri, [ addcat => "Добавить", catname => $category ]);
    if (!$response->is_success)
    {
        # TODO показать ошибку
        die "Could not POST $uri addcat=Добавить&catname=$category: ".$response->status_line;
    }
    my $text = $response->content;
    ($text) = $text =~ m!<textarea[^<>]*>(.*?)</textarea>!iso;
    decode_entities($text);
    # Дёргаем Special:Export и вытаскиваем саму XML-ку с последними ревизиями
    $response = $ua->request(POST $uri, [
        wpDownload => 1,
        curonly    => 1,
        pages      => $text,
    ]);
    if (!$response->is_success)
    {
        # TODO показать ошибку
        die "Could not retrieve export XML file: ".$response->status_line;
    }
    return $response->content;
}
