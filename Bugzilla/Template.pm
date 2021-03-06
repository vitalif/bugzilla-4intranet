# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Christopher Aillon <christopher@aillon.com>
#                 Tobias Burnus <burnus@net-b.de>
#                 Myk Melez <myk@mozilla.org>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Frédéric Buclin <LpSolit@gmail.com>
#                 Greg Hendricks <ghendricks@novell.com>
#                 David D. Kilzer <ddkilzer@kilzer.net>


package Bugzilla::Template;

use utf8;
use strict;

use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Hook;
use Bugzilla::Install::Requirements;
use Bugzilla::Install::Util qw(install_string template_include_path include_languages);
use Bugzilla::Keyword;
use Bugzilla::Util;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Status;
use Bugzilla::Token;
use Bugzilla::Template::Plugin::Bugzilla;

use Cwd qw(abs_path);
use MIME::Base64;
use MIME::QuotedPrint qw(encode_qp);
use Encode qw(encode);
use Date::Format ();
use File::Basename qw(basename dirname);
use File::Find;
use File::Path qw(rmtree mkpath);
use File::Spec;
use IO::Dir;
use Scalar::Util qw(blessed);

use base qw(Template);

my ($custom_proto, $custom_proto_regex, $custom_proto_cached, $custom_wiki_urls, $custom_wiki_proto);

# Convert the constants in the Bugzilla::Constants module into a hash we can
# pass to the template object for reflection into its "constants" namespace
# (which is like its "variables" namespace, but for constants).  To do so, we
# traverse the arrays of exported and exportable symbols and ignoring the rest
# (which, if Constants.pm exports only constants, as it should, will be nothing else).
sub _load_constants
{
    my %constants;
    foreach my $constant (@Bugzilla::Constants::EXPORT, @Bugzilla::Constants::EXPORT_OK)
    {
        if (ref Bugzilla::Constants->$constant)
        {
            $constants{$constant} = Bugzilla::Constants->$constant;
        }
        else
        {
            my @list = (Bugzilla::Constants->$constant);
            $constants{$constant} = (scalar(@list) == 1) ? $list[0] : \@list;
        }
    }
    return \%constants;
}

# Returns the path to the templates based on the Accept-Language
# settings of the user and of the available languages
# If no Accept-Language is present it uses the defined default
# Templates may also be found in the extensions/ tree
sub getTemplateIncludePath
{
    my $cache = Bugzilla->request_cache;
    my $lang  = $cache->{language} || '';
    $cache->{"template_include_path_$lang"} ||= template_include_path({
        use_languages => Bugzilla->languages,
        only_language => $lang,
    });
    return $cache->{"template_include_path_$lang"};
}

sub get_format
{
    my $self = shift;
    my ($template, $format, $ctype) = @_;

    $ctype ||= 'html';
    $format ||= '';

    # Security - allow letters and a hyphen only
    $ctype =~ s/[^a-zA-Z\-]//g;
    $format =~ s/[^a-zA-Z\-]//g;
    trick_taint($ctype);
    trick_taint($format);

    $template .= ($format ? "-$format" : "");
    $template .= ".$ctype.tmpl";

    # Now check that the template actually exists. We only want to check
    # if the template exists; any other errors (eg parse errors) will
    # end up being detected later.
    eval
    {
        $self->context->template($template);
    };
    # This parsing may seem fragile, but it's OK:
    # http://lists.template-toolkit.org/pipermail/templates/2003-March/004370.html
    # Even if it is wrong, any sort of error is going to cause a failure
    # eventually, so the only issue would be an incorrect error message
    if ($@ && $@->info =~ /: not found$/)
    {
        ThrowUserError('format_not_found', { format => $format, ctype => $ctype });
    }

    # Else, just return the info
    return
    {
        'template'    => $template,
        'extension'   => $ctype,
        'ctype'       => Bugzilla::Constants::contenttypes->{$ctype}
    };
}

# check whether a template exists
sub template_exists
{
    my $self = shift;
    my $file = shift or return;
    my $include_path = $self->context->load_templates->[0]->include_path;
    return unless ref $include_path eq 'ARRAY';
    foreach my $path (@$include_path)
    {
        return $path if -e "$path/$file";
    }
    return undef;
}

sub makeTables
{
    my ($comment) = @_;
    my $wrappedcomment = "";
    my $table;
    foreach my $line (split /\r\n?|\n/, $comment)
    {
        if ($line =~ /^\s*[│─┌┐└┘├┴┬┤┼]+\s*$/so)
        {
            next;
        }
        if ($table)
        {
            if (scalar($line =~ s/(\t+|│+)/$1/gso) > 0)
            {
                $line =~ /[─┌┐└┘├┴┬┤┼]+/gso; # legacy ascii tables
                $line =~ s/^\s*│\s*//s;
                $line =~ s/\s*│\s*$//s;
                $line = [ split /\t+\s*|\s*│+\s*/, $line ];
                $line = '<tr><td>'.join('</td><td>', @$line).'</td></tr>';
                $table .= "\n".$line;
                next;
            }
            else
            {
                $wrappedcomment .= "<table class='bz_fmt_table'>$table</table>\n";
                $table = undef;
            }
        }
        my $n = scalar($line =~ s/(\t+|│+)/$1/gso);
        if ($n > 1 && length($line) < MAX_TABLE_COLS)
        {
            # Table
            $line =~ /[─┌┐└┘├┴┬┤┼]+/gso; # legacy ascii tables
            $line =~ s/^\s*│\s*//s;
            $line =~ s/\s*│\s*$//s;
            $line = [ split /\t+\s*|\s*│+\s*/, $line ];
            $table = "<tr><td>".join('</td><td>', @$line)."</td></tr>\n";
            next;
        }
        $line =~ s/\t/    /gso;
        $wrappedcomment .= $line . "\n";
    }
    if ($table)
    {
        $wrappedcomment .= "<table class='bz_fmt_table'>$table</table>\n";
    }
    return $wrappedcomment;
}

# This routine quoteUrls contains inspirations from the HTML::FromText CPAN
# module by Gareth Rees <garethr@cre.canon.co.uk>.  It has been heavily hacked,
# all that is really recognizable from the original is bits of the regular
# expressions.
# This has been rewritten to be faster, mainly by substituting 'as we go'.
# If you want to modify this routine, read the comments carefully
sub quoteUrls
{
    my ($text, $bug, $comment) = (@_);
    return $text unless $text;

    # We use /g for speed, but uris can have other things inside them
    # (http://foo/bug#3 for example). Filtering that out filters valid
    # bug refs out, so we have to do replacements.
    # mailto can't contain space or #, so we don't have to bother for that
    # Do this by escaping \0 to \1\0, and replacing matches with \0\0$count\0\0
    # \0 is used because it's unlikely to occur in the text, so the cost of
    # doing this should be very small

    # escape the 2nd escape char we're using
    my $chr1 = chr(1);
    $text =~ s/\0/$chr1\0/g;

    # However, note that adding the title (for buglinks) can affect things
    # In particular, attachment matches go before bug titles, so that titles
    # with 'attachment 1' don't double match.
    # Dupe checks go afterwards, because that uses ^ and \Z, which won't occur
    # if it was substituted as a bug title (since that always involve leading
    # and trailing text)

    # Because of entities, it's easier (and quicker) to do this before escaping

    my @things;
    my $count = 0;
    my $tmp;

    Bugzilla::Hook::process('bug_format_comment', {
        text => \$text,
        bug => $bug,
        comment => $comment,
    });

    # Provide tooltips for full bug links (Bug 74355)
    my $urlbase_re = '(' . join('|', map { qr/$_/ }
        grep($_, Bugzilla->params->{urlbase}, Bugzilla->params->{sslbase})
    ) . ')';
    $text =~ s~\b($urlbase_re\Qshow_bug.cgi?id=\E([0-9]+)(\#c([0-9]+))?)\b
        ~($things[$count++] = get_bug_link($3, $1, { comment_num => $5 })) && ("\0\0" . ($count-1) . "\0\0")
        ~egox;

    if (!$custom_proto || $custom_proto_cached < Bugzilla->params_modified)
    {
        # initialize custom protocols
        $custom_proto_cached = time;
        $custom_proto = {};
        $custom_wiki_urls = [];
        $custom_wiki_proto = {};
        # MediaWiki link integration
        for (split /\n/, Bugzilla->params->{mediawiki_urls})
        {
            my ($wiki, $url) = split /\s+/, trim($_), 2;
            $custom_proto->{$wiki} = sub { quote_wiki_url($url, @_) } if $wiki && $url;
            push @$custom_wiki_urls, lc "\Q$url\E";
            $custom_wiki_proto->{lc $url} = $wiki;
        }
        Bugzilla::Hook::process('quote_urls-custom_proto', { custom_proto => $custom_proto });
        $custom_wiki_urls = join '|', @$custom_wiki_urls;
        $custom_wiki_urls = qr~\b($custom_wiki_urls)([^\s<>\"]+[\w/])~si if $custom_wiki_urls ne '';
        $custom_proto_regex = join '|', keys %$custom_proto;
    }

    # non-mailto protocols
    my $safe_protocols = join('|', SAFE_PROTOCOLS);

    # unquote known MediaWiki URLs and show them nicely
    if ($custom_wiki_urls ne '')
    {
        $text =~ s~$custom_wiki_urls~
                ($things[$count++] = unquote_wiki_url($1, $2)) &&
                ("\0\0" . ($count-1) . "\0\0")
            ~gesix;
    }

    # the protocol + non-whitespace + recursive braces + ending in [\w/~=)]
    $text =~ s/\b((?:$safe_protocols):((?>[^\s<>\"\(\)]+|\((?:(?2)|\")*\)))+(?<=[\w\/~=)]))/
            ($tmp = html_quote($1)) &&
            ($things[$count++] = "<a href=\"$tmp\">$tmp<\/a>") &&
            ("\0\0" . ($count-1) . "\0\0")
        /gesox;

    if ($custom_proto && %$custom_proto)
    {
        my @text = split /\b(($custom_proto_regex):(?:\[\[(.*?)(?:\#(.*?))?\]\]|([^\s<>\#]+)(?:\#([^\s<>\"\#]+))?))/is, $text;
        $text = shift @text;
        my $link;
        while (@text)
        {
            my ($linktext, $proto, $verb_url, $verb_anchor, $url, $anchor) = splice @text, 0, 6;
            if (my $sub = $custom_proto->{lc $proto})
            {
                if ($verb_url = trim($verb_url))
                {
                    # remove line feeds and reply markers as the comment is already wrapped
                    s/\n(>\s*)*/ /gso for $verb_url, $verb_anchor;
                    $verb_anchor = trim($verb_anchor);
                    $link = &$sub($verb_url, $verb_anchor);
                }
                else
                {
                    $link = &$sub($url, $anchor);
                }
            }
            else
            {
                $text .= $linktext;
                next;
            }
            $things[$count] = "<a href=\"$link\">$linktext</a>";
            $text .= "\0\0$count\0\0";
            $text .= shift @text;
            $count++;
        }
    }

    # We have to quote now, otherwise the html itself is escaped
    # THIS MEANS THAT A LITERAL ", <, >, ' MUST BE ESCAPED FOR A MATCH

    # Allow some HTML without attributes, escape everything else
    my $q = { '<' => '&lt;', '>' => '&gt;', '&' => '&amp;', '"' => '&quot;' };
    my $safe_tags = '(?:b|i|u|hr|marquee|s|strike|strong|small|big|sub|sup|tt|em|cite|font(?:\s+color=["\']?(?:#[0-9a-f]{3,6}|[a-z]+)["\']?)?)';
    my $block_tags = '(?:h[1-6]|center|ol|ul|li)';
    $text =~ s/<pre>((?:(?>.+?)(?:<pre>(?1)<\/pre>)?)+)?<\/pre>|\s*(<\/?$block_tags>)\s*|(<\/?$safe_tags>)|([<>&\"])/$4 ? $q->{$4} : ($1 eq '' ? lc($2 eq '' ? $3 : $2) : html_quote($1))/geiso;

    # Replace nowrap markers (\1\0\1)
    $text =~ s/\x01\x00\x01(.*?)\x01\x00\x01/<div style="white-space: nowrap">$1<\/div>/gso;

    # Replace tables
    $text = makeTables($text);

    # Color quoted text
    $text = makeCitations($text);

    # mailto:
    $text =~ s~\b((mailto:)?)([\w\.\-\+\=]+\@[\w\-]+(?:\.[\w\-]+)+)\b
        ~<a href=\"mailto:$3\">$1$3</a>~igx;

    # attachment links
    $text =~ s~\b(attachment\s*\#?\s*(\d+)(?:\s+\[details\])?)
        ~($things[$count++] = get_attachment_link($2, $1, $comment)) && ("\0\0" . ($count-1) . "\0\0")
        ~egsxi;

    # Current bug ID this comment belongs to
    $bug = $bug->id if ref $bug;
    my $current_bugurl = $bug ? "show_bug.cgi?id=$bug" : "";

    # This handles bug a, comment b type stuff. Because we're using /g
    # we have to do this in one pattern, and so this is semi-messy.
    # Also, we can't use $bug_re?$comment_re? because that will match the
    # empty string
    my $bug_word = Bugzilla->messages->{terms}->{bug};
    my $bug_re = qr/\Q$bug_word\E\s*\#?\s*(\d+)/i;
    my $comment_re = qr/comment\s*\#?\s*(\d+)/i;
    $text =~ s~\b($bug_re(?:\s*,?\s*$comment_re)?|$comment_re)~
        # We have several choices. $1 here is the link, and $2-4 are set
        # depending on which part matched
        (defined($2) ? get_bug_link($2, $1, { comment_num => $3 }) : "<a href=\"$current_bugurl#c$4\">$1</a>")
        ~egsox;

    # Old duplicate markers. These don't use $bug_word because they are old
    # and were never customizable.
    $text =~ s~(^\*\*\*\ This\ bug\ has\ been\ marked\ as\ a\ duplicate\ of\ )(\d+)(\ \*\*\*\Z)
        ~$1.get_bug_link($2, $2).$3~egmx;

    # Now remove the encoding hacks
    $text =~ s/\0\0(\d+)\0\0/$things[$1]/eg;
    $text =~ s/$chr1\0/\0/g;

    return $text;
}

# MediaWiki page anchor encoding
sub quote_wiki_anchor
{
    my ($anchor) = (@_);
    return "" unless $anchor;
    $anchor =~ tr/ /_/;
    $anchor = url_quote($anchor);
    $anchor =~ s/\%3A/:/giso;
    $anchor =~ tr/%/./;
    return '#'.$anchor;
}

# Convert MediaWiki page titles to URLs
sub quote_wiki_url
{
    my ($base, $url, $anchor) = @_;
    $url = trim($url);
    $url =~ s/\s+/_/gso;
    # Use url_quote without converting / to %2F
    $url = url_quote_noslash($url);
    return $base . $url . quote_wiki_anchor($anchor);
}

# Decode and link MediaWiki URL
sub unquote_wiki_url
{
    my ($wikiurl, $linkurl) = @_;
    my $wikiname = $custom_wiki_proto->{$wikiurl};
    if ($wikiname)
    {
        Encode::_utf8_off($linkurl);
        my $article = $linkurl;
        $article =~ s/^\/+//so;
        my $anchor = '';
        if ($article =~ s/#(.*)$//so)
        {
            my $a;
            $anchor = $1;
            # decode MediaWiki page section name (only correct UTF8 sequences)
            $anchor =~ s/((?:
                \.[0-7][A-F0-9]|
                \.[CD][A-F0-9]\.[89AB][A-F0-9]|
                \.E[A-F0-9](?:\.[89AB][A-F0-9]){2}|
                \.F[0-7](?:\.[89AB][A-F0-9]){3}
            )+)/($a = $1), ($a =~ tr!.!\%!), (url_decode($a))/gesx;
            $anchor =~ tr/_/ /;
        }
        $article =~ s/&.*$//so if $wikiurl =~ /title=$/so;
        $article = url_decode($article);
        $article =~ tr/_/ /;
        Encode::_utf8_on($linkurl);
        Encode::_utf8_on($article);
        Encode::_utf8_on($anchor);
        if (utf8::valid($article) && utf8::valid($anchor))
        {
            $linkurl = '<a href="'.html_quote($wikiurl.$linkurl).'">'.$wikiname.':[['.$article.($anchor eq '' ? '' : '#'.$anchor).']]</a>';
            return $linkurl;
        }
    }
    $linkurl = html_quote($wikiurl.$linkurl);
    return "<a href=\"$linkurl\">$linkurl</a>";
}

# Creates a link to an attachment, including its title.
sub get_attachment_link
{
    my ($attachid, $link_text, $comment) = @_;
    my $dbh = Bugzilla->dbh;

    my $attachment = new Bugzilla::Attachment($attachid);
    if ($attachment)
    {
        my $title = "";
        my $className = "";
        if (Bugzilla->user->can_see_bug($attachment->bug_id))
        {
            $title = $attachment->description;
        }
        if ($attachment->isobsolete)
        {
            $className = "bz_obsolete";
        }
        # Prevent code injection in the title.
        $title = html_quote(clean_text($title));

        $link_text =~ s/ \[details\]$//;
        my $linkval = correct_urlbase()."attachment.cgi?id=$attachid";

        # If the attachment is a patch, try to link to the diff rather
        # than the text, by default.
        my $patchlink = "";
        if ($attachment->ispatch && Bugzilla->feature('patch_viewer'))
        {
            $patchlink = '&amp;action=diff';
        }

        # Custis Bug 126991
        # Show non-obsolete attachment images inline in comments in which they were created
        my $attachment_view = '';
        if ($comment && $comment->type == CMT_ATTACHMENT_CREATED &&
            $attachment->id == $comment->extra_data &&
            !$attachment->isobsolete &&
            $attachment->contenttype =~ /^image\//s)
        {
            $attachment_view .= '<br /><a href="'.$linkval.'" name="attach_'.$attachid.
                '" title="'.$title.'" target="_blank"><img src="'.$linkval.'" alt="'.$title.
                '" title="'.$title.'" class="attachment_image" /></a><br />';
        }

        # Custis Bug 129398
        if ($attachment->isOfficeDocument())
        {
            $attachment_view .= ' <a href="'.$linkval.'&amp;action=online_view" title="$title" target="_blank">[Online-view]</a>';
        }

        # Whitespace matters here because these links are in <pre> tags.
        return "<span class=\"$className\">".
            "<a href=\"${linkval}${patchlink}\" name=\"attach_${attachid}\" title=\"$title\" target=\"_blank\">$link_text</a>".
            " <a href=\"${linkval}&amp;action=edit\" title=\"$title\" target=\"_blank\">[details]</a>".
            " $attachment_view</span>";
    }
    else
    {
        return qq{$link_text};
    }
}

# Creates a link to a bug, including its title.
# It takes either two or three parameters:
#  - The bug number
#  - The link text, to place between the <a>..</a>
#  - An optional comment number, for linking to a particular
#    comment in the bug

sub get_bug_link
{
    my ($bug, $link_text, $options) = @_;
    my $dbh = Bugzilla->dbh;

    if (!$bug)
    {
        return html_quote('<missing bug number>');
    }

    $bug = blessed($bug) ? $bug : new Bugzilla::Bug($bug);
    return $link_text if !$bug;

    my $title = get_text('get_status', { status => $bug->bug_status_obj->name });
    if ($bug->resolution)
    {
        $title .= ' ' . get_text('get_resolution', { resolution => $bug->resolution_obj->name });
    }
    my $cansee = Bugzilla->user->can_see_bug($bug);
    if (Bugzilla->params->{unauth_bug_details} || $cansee)
    {
        $title .= ' - ' . $bug->product;
    }
    if ($cansee)
    {
        $title .= '/' . $bug->component . ' - ' . $bug->short_desc;
        if (!Bugzilla->get_field('alias')->obsolete && $options->{use_alias} && $link_text =~ /^\d+$/ && $bug->alias)
        {
            $link_text = $bug->alias;
        }
    }
    # Prevent code injection in the title.
    $title = html_quote(clean_text($title));

    my $linkval = correct_urlbase()."show_bug.cgi?id=".$bug->id;
    if (defined $options->{comment_num})
    {
        $linkval .= "#c" . $options->{comment_num};
    }
    # CustIS Bug 53691 - Styles for bug states
    return "<span class=\"bz_st_".$bug->bug_status_obj->name."\"><a href=\"$linkval\" title=\"$title\">$link_text</a></span>";
}

###############################################################################
# Templatization Code

use Template::Directive;
use Template::Stash;
use Template::Exception;

# The Template Toolkit throws an error if a loop iterates >1000 times.
# We want to raise that limit.
# NOTE: If you change this number, you MUST RE-RUN checksetup.pl!!!
# If you do not re-run checksetup.pl, the change you make will not apply
$Template::Directive::WHILE_MAX = 1000000;

# Allow keys to start with an underscore or a dot.
$Template::Stash::PRIVATE = undef;

# Add "contains***" methods to list variables that search for one or more
# items in a list and return boolean values representing whether or not
# one/all/any item(s) were found.
$Template::Stash::LIST_OPS->{contains} = sub
{
    my ($list, $item) = @_;
    return grep($_ eq $item, @$list);
};

$Template::Stash::LIST_OPS->{containsany} = sub
{
    my ($list, $items) = @_;
    foreach my $item (@$items)
    {
        return 1 if grep($_ eq $item, @$list);
    }
    return 0;
};

# Allow us to still get the scalar if we use the list operation ".0" on it,
# as we often do for defaults in query.cgi and other places.
$Template::Stash::SCALAR_OPS->{0} = sub { $_[0] };

# Add a "truncate" method to the Template Toolkit's "scalar" object
# that truncates a string to a certain length.
$Template::Stash::SCALAR_OPS->{truncate} = sub
{
    my ($string, $length, $ellipsis) = @_;
    $ellipsis ||= "";

    return $string if !$length || length($string) <= $length;

    my $strlen = $length - length($ellipsis);
    my $newstr = substr($string, 0, $strlen) . $ellipsis;
    return $newstr;
};

# Install Template Toolkit error handler with stack traces
no warnings 'redefine';
*Template::Exception::new = sub
{
    my ($class, $type, $info, $textref) = @_;
    bless [
        $type, $info, $textref,
        $Bugzilla::Error::HAVE_DEVEL_STACKTRACE ? Devel::StackTrace->new->as_string : ''
    ], $class;
};

# Create the template object that processes templates and specify
# configuration parameters that apply to all templates.

###############################################################################

# Construct the Template object

# Note that all of the failure cases here can't use templateable errors,
# since we won't have a template to use...

sub create
{
    my $class = shift;
    my %opts = @_;

    # IMPORTANT - If you make any FILTER changes here, make sure to
    # make them in t/004.template.t also, if required.

    my $config = {
        # Colon-separated list of directories containing templates.
        INCLUDE_PATH => $opts{include_path} || getTemplateIncludePath(),

        # Remove white-space before template directives (PRE_CHOMP) and at the
        # beginning and end of templates and template blocks (TRIM) for better
        # looking, more compact content.  Use the plus sign at the beginning
        # of directives to maintain white space (i.e. [%+ DIRECTIVE %]).
        PRE_CHOMP => 1,
        TRIM => 1,

        # Bugzilla::Template::Plugin::Hook uses the absolute (in mod_perl)
        # or relative (in mod_cgi) paths of hook files to explicitly compile
        # a specific file. Also, these paths may be absolute at any time
        # if a packager has modified bz_locations() to contain absolute
        # paths.
        ABSOLUTE => 1,
        RELATIVE => $ENV{MOD_PERL} ? 0 : 1,

        COMPILE_DIR => bz_locations()->{datadir} . "/template",

        # Initialize templates (f.e. by loading plugins like Hook).
        PRE_PROCESS => ["global/initialize.none.tmpl"],

        ENCODING => Bugzilla->params->{utf8} ? 'UTF-8' : undef,

        # Functions for processing text within templates in various ways.
        # IMPORTANT!  When adding a filter here that does not override a
        # built-in filter, please also add a stub filter to t/004template.t.
        FILTERS => {

            # Timestamped URL to force refresh of JavaScript/CSS
            ts_url => sub
            {
                my ($file) = @_;
                my $mtime = (stat(bz_locations()->{libpath}.'/'.$file))[9];
                if (!defined $mtime)
                {
                    return $file;
                }
                return "$file?$mtime";
            },

            # Returns the text with backslashes, single/double quotes,
            # and newlines/carriage returns escaped for use in JS strings.
            js => sub
            {
                my ($var) = @_;
                $var =~ s/([\\\'\"\/])/\\$1/g;
                $var =~ s/\n/\\n/g;
                $var =~ s/\r/\\r/g;
                $var =~ s/\@/\\x40/g; # anti-spam for email addresses
                $var =~ s/</\\x3c/g;
                return $var;
            },

            # Converts data to base64
            base64 => sub
            {
                my ($data) = @_;
                return encode_base64($data);
            },

            # Converts data to quoted-printable
            quoted_printable => sub
            {
                my ($data) = @_;
                return encode_qp(encode("UTF-8", $data));
            },

            # HTML collapses newlines in element attributes to a single space,
            # so form elements which may have whitespace (ie comments) need
            # to be encoded using &#013;
            # See bugs 4928, 22983 and 32000 for more details
            html_linebreak => sub
            {
                my ($var) = @_;
                $var =~ s/\r\n/\&#013;/g;
                $var =~ s/\n\r/\&#013;/g;
                $var =~ s/\r/\&#013;/g;
                $var =~ s/\n/\&#013;/g;
                return $var;
            },

            # Prevents line break on hyphens and whitespaces.
            no_break => sub
            {
                my ($var) = @_;
                $var =~ s/ /\&nbsp;/g;
                $var =~ s/-/\&#8209;/g;
                return $var;
            },

            xml => \&Bugzilla::Util::xml_quote,

            # This filter escapes characters in a variable or value string for
            # use in a query string.  It escapes all characters NOT in the
            # regex set: [a-zA-Z0-9_\-.].  The 'uri' filter should be used for
            # a full URL that may have characters that need encoding.
            url_quote => \&Bugzilla::Util::url_quote,

            url_quote_ns => \&Bugzilla::Util::url_quote_noslash,

            # This filter is similar to url_quote but used a \ instead of a %
            # as prefix. In addition it replaces a ' ' by a '_'.
            css_class_quote => \&Bugzilla::Util::css_class_quote,

            # Removes control characters and trims extra whitespace.
            clean_text => \&Bugzilla::Util::clean_text,

            quoteUrls => [
                sub
                {
                    my ($context, $bug, $comment) = @_;
                    return sub
                    {
                        my $text = shift;
                        return quoteUrls($text, $bug, $comment);
                    };
                }, 1
            ],

            bug_link => [
                sub
                {
                    my ($context, $bug, $options) = @_;
                    return sub
                    {
                        my $text = shift;
                        return get_bug_link($bug, $text, $options);
                    };
                }, 1
            ],

            # "Dynamic" [% PROCESS ... %]
            # FYI "process" and "block_exists" are filters because only filters have access to context
            process => [ sub { my ($context, $vars) = @_; return sub { $context->process($_[0], $vars) } }, 1 ],

            # Check if a named block of the current template exists
            block_exists => [
                sub
                {
                    my ($context) = @_;
                    return sub
                    {
                        my ($blk) = @_;
                        return 1 if $context->{BLOCKS}->{$blk};
                        for (@{$context->{BLKSTACK}})
                        {
                            return 1 if $_->{$blk};
                        }
                        return 0;
                    }
                }, 1
            ],

            bug_list_link => sub
            {
                my $buglist = shift;
                return join(", ", map(get_bug_link($_, $_), split(/ *, */, $buglist)));
            },

            # In CSV, quotes are doubled, and any value containing a quote or a
            # comma is enclosed in quotes.
            csv => sub
            {
                my ($var) = @_;
                $var =~ s/\"/\"\"/g;
                if ($var !~ /^-?(\d+\.)?\d*$/)
                {
                    $var = "\"$var\"";
                }
                return $var;
            },

            # Format a filesize in bytes to a human readable value
            # FIXME: i18n
            unitconvert => sub
            {
                my ($data) = @_;
                my $retval = "";
                my %units = (
                    'KB' => 1024,
                    'MB' => 1024 * 1024,
                    'GB' => 1024 * 1024 * 1024,
                );
                if ($data < 1024)
                {
                    return "$data bytes";
                }
                else
                {
                    my $u;
                    foreach $u ('GB', 'MB', 'KB')
                    {
                        if ($data >= $units{$u})
                        {
                            return sprintf("%.2f %s", $data/$units{$u}, $u);
                        }
                    }
                }
            },

            links_targetblank => sub
            {
                my ($data) = @_;
                my $sub = sub
                {
                    if ($_[0] =~ /target=[\"\']?[^<>]*/iso)
                    {
                        return $_[0];
                    }
                    return $_[0] . ' target="_blank"';
                };
                $data =~ s/<a(\s+[^<>]*)>/ '<a'.&$sub($1).'>' /egiso;
                return $data;
            },

            # Format a time for display (more info in Bugzilla::Util)
            time => [
                sub
                {
                    my ($context, $format, $timezone) = @_;
                    return sub
                    {
                        my $time = shift;
                        return format_time($time, $format, $timezone);
                    };
                }, 1
            ],

            html => \&Bugzilla::Util::html_quote,

            html_light => \&Bugzilla::Util::html_light_quote,

            email => \&Bugzilla::Util::email_filter,

            # iCalendar contentline filter
            ics => [
                sub
                {
                     my ($context, @args) = @_;
                     return sub
                     {
                         my ($var) = shift;
                         my ($par) = shift @args;
                         my ($output) = "";
                         $var =~ s/[\r\n]/ /g;
                         $var =~ s/([;\\\",])/\\$1/g;
                         if ($par)
                         {
                             $output = sprintf("%s:%s", $par, $var);
                         }
                         else
                         {
                             $output = $var;
                         }
                         $output =~ s/(.{75,75})/$1\n /g;
                         return $output;
                     };
                }, 1
            ],

            # Note that using this filter is even more dangerous than
            # using "none," and you should only use it when you're SURE
            # the output won't be displayed directly to a web browser.
            txt => \&html_strip,

            # Wrap a displayed comment to the appropriate length
            wrap_comment => [
                sub
                {
                    my ($context, $cols) = @_;
                    return sub { wrap_comment($_[0], $cols) }
                }, 1
            ],

            absolute_uris => sub
            {
                my $b = Bugzilla->params->{urlbase};
                $b =~ s/\/*$/\//so;
                $_[0] =~ s/(<a[^<>]*href\s*=\s*[\"\']\s*)(?![a-z]+:\/\/|mailto:)([^\"\'<>]+[\"\'][^<>]*>)/$1$b$2/giso;
                $_[0];
            },

            timestamp => sub
            {
                $_[0] =~ s/\D+//gso;
                $_[0];
            },

            # We force filtering of every variable in key security-critical
            # places; we have a none filter for people to use when they
            # really, really don't want a variable to be changed.
            none => sub { return $_[0]; },
        },

        PLUGIN_BASE => 'Bugzilla::Template::Plugin',

        CONSTANTS => _load_constants(),

        # Default variables for all templates
        VARIABLES => {
            terms => Bugzilla->messages->{terms},
            field_descs => Bugzilla->messages->{field_descs},
            lc_messages => Bugzilla->messages,
            Bugzilla => Bugzilla::Template::Plugin::Bugzilla->new,

            # html_quote in the form of a function
            html => \&html_quote,

            # escape regular expression characters
            regex_escape => sub
            {
                my ($s) = @_;
                return "\Q$s\E";
            },

            # escape regular expression replacement characters
            replacement_escape => sub
            {
                my ($s) = @_;
                $s =~ s/([\\\$])/\\$1/gso;
                return $s;
            },

            # HTML <select>
            # html_select(name, <selected value>, <values>, [<value names>], [<attr_hash>])
            #   <values> may be one of:
            #     [ { id => <option value>, name => <option text> }, ... ]
            #     { <option value> => <option text>, ... } # will be sorted on text
            #     [ <option value>, ... ]
            #   in the last case, <value names> may be { <option value> => <option text>, ... }
            html_select => sub
            {
                my ($name, $selected, $values, $valuenames, $attrs) = @_;
                $selected = '' if !defined $selected;
                $selected = { map { $_ => 1 } list $selected };
                $name = html_quote($name);
                my $html = '<select name="'.$name.'" id="'.$name.'"';
                if ($attrs)
                {
                    $html .= ' '.html_quote($_).'="'.html_quote($attrs->{$_}).'"' for keys %$attrs;
                }
                $html .= '>';
                if (ref $values eq 'HASH')
                {
                    $valuenames = $values;
                    $values = [ sort { $values->{$a} cmp $values->{$b} } keys %$values ];
                }
                if (!$values || !@$values)
                {
                }
                elsif (!ref $values->[0])
                {
                    for (@$values)
                    {
                        $html .= '<option value="'.html_quote($_).'"';
                        $html .= ' selected="selected"' if $selected->{$_};
                        $html .= '>'.html_quote($valuenames && $valuenames->{$_} || $_).'</option>';
                    }
                }
                else
                {
                    for (@$values)
                    {
                        $html .= '<option value="'.html_quote($_->{id}).'"';
                        $html .= ' selected="selected"' if $selected->{$_->{id}};
                        $html .= '>'.html_quote($_->{name}).'</option>';
                    }
                }
                $html .= '</select>';
                return $html;
            },

            blessed => \&Scalar::Util::blessed,

            # Function for retrieving global parameters.
            Param => sub { return Bugzilla->params->{$_[0]}; },

            # Function to create date strings
            time2str => \&Date::Format::time2str,

            # Generic linear search function
            lsearch => \&Bugzilla::Util::lsearch,

            # Currently logged in user, if any
            # If an sudo session is in progress, this is the user we're faking
            user => sub { return Bugzilla->user; },

            # Currenly active language
            # FIXME Eventually this should probably be replaced with something like Bugzilla->language.
            current_language => sub
            {
                my ($language) = include_languages();
                return $language;
            },

            # If an sudo session is in progress, this is the user who
            # started the session.
            sudoer => sub { return Bugzilla->sudoer; },

            # Allow templates to access the "corect" URLBase value
            urlbase => sub { return Bugzilla::Util::correct_urlbase(); },

            # Allow templates to access docs url with users' preferred language
            docs_urlbase => sub {
                my ($language) = include_languages();
                my $docs_urlbase = Bugzilla->params->{docs_urlbase};
                $docs_urlbase =~ s/\%lang\%/$language/;
                return $docs_urlbase;
            },

            # Check whether the URL is safe.
            is_safe_url => sub
            {
                my $url = shift;
                return 0 unless $url;

                my $safe_protocols = join('|', SAFE_PROTOCOLS);
                return 1 if $url =~ /^($safe_protocols):[^\s<>\"]+$/i;
                # Pointing to a local file with no colon in its name is fine.
                return 1 if $url =~ /^[^\s<>\":]+[\w\/]$/i;
                # If we come here, then we cannot guarantee it's safe.
                return 0;
            },

            # Allow templates to generate a token themselves.
            issue_hash_token => \&Bugzilla::Token::issue_hash_token,

            json => \&Bugzilla::Util::bz_encode_json,

            feature_enabled => sub { return Bugzilla->feature(@_); },

            install_string => \&Bugzilla::Install::Util::install_string,

            # These don't work as normal constants.
            DB_MODULE        => \&Bugzilla::Constants::DB_MODULE,
            REQUIRED_MODULES => \&Bugzilla::Install::Requirements::REQUIRED_MODULES,
            OPTIONAL_MODULES => sub
            {
                my @optional = @{OPTIONAL_MODULES()};
                foreach my $item (@optional)
                {
                    my @features;
                    my $feat = $item->{feature};
                    ref $feat or $feat = [ $feat ];
                    foreach my $feat_id (@$feat)
                    {
                        push @features, install_string("feature_$feat_id");
                    }
                    $item->{feature} = \@features;
                }
                return \@optional;
            },
        },
    };

    local $Template::Config::CONTEXT = 'Bugzilla::Template::Context';

    Bugzilla::Hook::process('template_before_create', { config => $config });
    my $template = $class->new($config)
        || die("Template creation failed: " . $class->error());
    return $template;
}

# Used as part of the two subroutines below.
our %_templates_to_precompile;
sub precompile_templates
{
    my ($output) = @_;

    # Remove the compiled templates.
    my $datadir = bz_locations()->{datadir};
    if (-e "$datadir/template")
    {
        print install_string('template_removing_dir') . "\n" if $output;

        # This frequently fails if the webserver made the files, because
        # then the webserver owns the directories.
        rmtree("$datadir/template");

        # Check that the directory was really removed, and if not, move it
        # into data/deleteme/.
        if (-e "$datadir/template")
        {
            print STDERR "\n\n", install_string('template_removal_failed', { datadir => $datadir }), "\n\n";
            mkpath("$datadir/deleteme");
            my $random = generate_random_password();
            rename("$datadir/template", "$datadir/deleteme/$random")
                or die "move failed: $!";
        }
    }

    print install_string('template_precompile') if $output;

    my $paths = template_include_path({
        use_languages => Bugzilla->languages,
        only_language => Bugzilla->languages,
    });
    foreach my $dir (@$paths)
    {
        my $template = Bugzilla::Template->create(include_path => [$dir]);
        %_templates_to_precompile = ();
        # Traverse the template hierarchy.
        find({ wanted => \&_precompile_push, no_chdir => 1 }, $dir);
        # The sort isn't totally necessary, but it makes debugging easier
        # by making the templates always be compiled in the same order.
        foreach my $file (sort keys %_templates_to_precompile)
        {
            $file =~ s{^\Q$dir\E/}{};
            # Compile the template but throw away the result. This has the side-
            # effect of writing the compiled version to disk.
            $template->context->template($file);
        }
    }

    # Under mod_perl, we look for templates using the absolute path of the
    # template directory, which causes Template Toolkit to look for their
    # *compiled* versions using the full absolute path under the data/template
    # directory. (Like data/template/var/www/html/bugzilla/.) To avoid
    # re-compiling templates under mod_perl, we symlink to the
    # already-compiled templates. This doesn't work on Windows.
    if (!ON_WINDOWS)
    {
        # We do these separately in case they're in different locations.
        _do_template_symlink(bz_locations()->{templatedir});
        _do_template_symlink(bz_locations()->{extensionsdir});
    }

    # If anything created a Template object before now, clear it out.
    delete Bugzilla->request_cache->{template};

    print install_string('done') . "\n" if $output;
}

# Helper for precompile_templates
sub _precompile_push
{
    my $name = $File::Find::name;
    return if -d $name;
    return if $name =~ /\/(CVS|\.svn|\.git|\.hg|\.bzr)\//;
    return if $name !~ /\.tmpl$/;
    $_templates_to_precompile{$name} = 1;
}

# Helper for precompile_templates
sub _do_template_symlink
{
    my $dir_to_symlink = shift;

    my $abs_path = abs_path($dir_to_symlink);

    # If $dir_to_symlink is already an absolute path (as might happen
    # with packagers who set $libpath to an absolute path), then we don't
    # need to do this symlink.
    return if ($abs_path eq $dir_to_symlink);

    my $abs_root  = dirname($abs_path);
    my $dir_name  = basename($abs_path);
    my $datadir   = bz_locations()->{datadir};
    my $container = "$datadir/template$abs_root";
    mkpath($container);
    my $target = "$datadir/template/$dir_name";
    # Check if the directory exists, because if there are no extensions,
    # there won't be an "data/template/extensions" directory to link to.
    if (-d $target)
    {
        # We use abs2rel so that the symlink will look like
        # "../../../../template" which works, while just
        # "data/template/template/" doesn't work.
        my $relative_target = File::Spec->abs2rel($target, $container);

        my $link_name = "$container/$dir_name";
        symlink($relative_target, $link_name)
            or warn "Could not make $link_name a symlink to $relative_target: $!";
    }
}

# Helper for $template->process()
# Automatically sends CGI header
sub process
{
    my $self = shift;
    my ($template, $vars, $output) = @_;
    if (!$output)
    {
        # If outputting via print(), send headers
        # FIXME: now sends even if usage_mode is not USAGE_MODE_BROWSER
        # This is needed for importxls.cgi and should be removed when
        # process_bug()/post_bug() routines will be refactored to not call *.cgi
        Bugzilla->cgi->send_header;
    }
    return $self->SUPER::process(@_);
}

1;
__END__

=head1 NAME

Bugzilla::Template - Wrapper around the Template Toolkit C<Template> object

=head1 SYNOPSIS

  my $template = Bugzilla::Template->create;
  my $format = $template->get_format("foo/bar", $ARGS->{format}, $ARGS->{ctype});

=head1 DESCRIPTION

This is basically a wrapper so that the correct arguments get passed into
the C<Template> constructor.

It should not be used directly by scripts or modules - instead, use
C<Bugzilla-E<gt>instance-E<gt>template> to get an already created module.

=head1 SUBROUTINES

=over

=item C<precompile_templates($output)>

Description: Compiles all of Bugzilla's templates in every language.
             Used mostly by F<checksetup.pl>.

Params:      C<$output> - C<true> if you want the function to print
               out information about what it's doing.

Returns:     nothing

=back

=head1 METHODS

=over

=item C<get_format($file, $format, $ctype)>

 Description: Construct a format object from URL parameters.

 Params:      $file   - Name of the template to display.
              $format - When the template exists under several formats
                        (e.g. table or graph), specify the one to choose.
              $ctype  - Content type, see Bugzilla::Constants::contenttypes.

 Returns:     A format object.

=back

=head1 SEE ALSO

L<Bugzilla>, L<Template>
