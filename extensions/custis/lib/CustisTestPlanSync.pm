#!/usr/bin/perl
# Bug 53254 - Synchronizing test plan with MediaWiki

package CustisTestPlanSync;

use utf8;
use strict;
use Bugzilla::Util;
use Bugzilla::User;
use Testopia::TestCase;

use Encode;
use URI;
use URI::Escape;
use XML::Parser;
use HTML::Entities;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;

# Hook
sub tr_show_plan_after_fetch
{
    my ($args) = @_;
    my $cgi = Bugzilla->cgi;
    my $plan = $args->{plan};
    my $vars = $args->{vars};

    # When URL is /tr_show_plan.cgi?wikisync=1, download test cases from Wiki
    if ($cgi->param('wikisync'))
    {
        my $wiki_url = $plan->product->wiki_url || Bugzilla->params->{wiki_url};
        if ($wiki_url && $plan->wiki)
        {
            my $xml = fetch_wiki_category_xml($wiki_url, $plan->wiki);
            if ($xml)
            {
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
    my @fields = qw(
        tester alias estimated_time isautomated script arguments requirement
        dependson blocks tags bugs components status category priority
    );
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
    $case->{case_status_id} = $case->{status} || Bugzilla->params->{'default-test-case-status'} || 'CONFIRMED';
    delete $case->{status};
    $case->{category_id} = $case->{category} || '--default--';
    delete $case->{category};
    $case->{priority_id} = $case->{priority} || 'P3';
    delete $case->{priority};
    return $case = Testopia::TestCase->create($case);
}

sub check_r
{
    my ($response) = @_;
    if (!$response->is_success && $response->code !~ /^3/)
    {
        # TODO show error to user more friendly
        die 'Could not POST '.$response->request->uri.' '.$response->request->content.': '.$response->status_line;
    }
    return $response;
}

sub fetch_wiki_category_xml
{
    my ($wiki_url, $category) = @_;
    $wiki_url =~ s!(/*index\.php)?/*$!!so;
    $_[0] = $wiki_url;
    my $ua = LWP::UserAgent->new(cookie_jar => HTTP::Cookies->new);
    my ($uri, $r, $response);
    if (my $tcuser = Bugzilla->params->{testopia_sync_user})
    {
        # Try to login into wiki containing test cases
        # FIXME maybe we should respect user's rights, i.e. make redirect from his browser
        # to wiki, create a file with unique name containing test case data, then redirect
        # back passing its unique name back to Bugzilla, and download it from Bugzilla.
        # But this would require creating a separate MediaWiki extension, and I don't think
        # that somebody needs it at all (because Testopia is ugly).
        $uri = "$wiki_url/index.php?title=Special:UserLogin";
        $response = check_r($ua->get($uri));
        my ($token) = $response->content =~ /<input[^<>]*name=["']?wpLoginToken[^<>]*value=[\"\']?([^\"\'\s]+)/iso;
        $response = check_r($ua->request(POST "$uri&action=submitlogin&type=login", [
            wpLoginToken => $token,
            wpName       => $tcuser,
            wpPassword   => Bugzilla->params->{testopia_sync_password},
        ]));
    }
    $uri = "$wiki_url/index.php?title=Special:Export&action=submit";
    # Get category page list using Special:Export
    $r = POST "$uri", Content => "addcat=Add&catname=".url_quote($category)."&closure=1";
    $response = check_r($ua->request($r));
    my $text = $response->content;
    ($text) = $text =~ m!<textarea[^<>]*>(.*?)</textarea>!iso;
    utf8::decode($text);
    decode_entities($text);
    if (!$text)
    {
        # TODO show error to the user
        warn "No pages in category $category";
        return '';
    }
    # Get export XML from Special:Export
    $r = POST $uri, Content => "wpDownload=1&curonly=1&pages=".url_quote($text);
    $response = check_r($ua->request($r));
    my $xml = $response->content;
    if ($xml !~ /<\?\s*xml/so)
    {
        my ($line) = $xml =~ /^\s*([^\n]*)/so;
        # TODO show error to user
        die "Could not retrieve export XML file, got $line instead";
    }
    return $xml;
}

1;
__END__
