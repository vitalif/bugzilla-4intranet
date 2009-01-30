#!/usr/bin/perl
# Lingua::Stem::Ru - UTF-8 ������

package Lingua::Stem::RuUTF8;

use utf8;
use strict;
use Exporter;
use Carp;
use vars qw (@ISA @EXPORT_OK @EXPORT %EXPORT_TAGS $VERSION);

BEGIN {
    @ISA         = qw (Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw (stem stem_word clear_stem_cache stem_caching);
    %EXPORT_TAGS = ();
}
$VERSION = "0.01";

my $Stem_Caching  = 0;
my $Stem_Cache    = {};

my $VOWEL        = qr/аеиоуыэюя/;
my $PERFECTIVEGROUND = qr/((ив|ивши|ившись|ыв|ывши|ывшись)|((?<=[ая])(в|вши|вшись)))$/;
my $REFLEXIVE    = qr/(с[яь])$/;
my $ADJECTIVE    = qr/(ее|ие|ые|ое|ими|ыми|ей|ий|ый|ой|ем|им|ым|ом|его|ого|ему|ому|их|ых|ую|юю|ая|яя|ою|ею)$/;
my $PARTICIPLE   = qr/((ивш|ывш|ующ)|((?<=[ая])(ем|нн|вш|ющ|щ)))$/;
my $VERB         = qr/((ила|ыла|ена|ейте|уйте|ите|или|ыли|ей|уй|ил|ыл|им|ым|ен|ило|ыло|ено|ят|ует|уют|ит|ыт|ены|ить|ыть|ишь|ую|ю)|((?<=[ая])(ла|на|ете|йте|ли|й|л|ем|н|ло|но|ет|ют|ны|ть|ешь|нно)))$/;
my $NOUN         = qr/(а|ев|ов|ие|ье|е|иями|ями|ами|еи|ии|и|ией|ей|ой|ий|й|иям|ям|ием|ем|ам|ом|о|у|ах|иях|ях|ы|ь|ию|ью|ю|ия|ья|я)$/;
my $RVRE         = qr/^(.*?[$VOWEL])(.*)$/;
my $DERIVATIONAL = qr/[^$VOWEL][$VOWEL]+[^$VOWEL]+[$VOWEL].*(?<=о)сть?$/;

sub stem {
    return [] if ($#_ == -1);
    my $parm_ref;
    if (ref $_[0]) {
        $parm_ref = shift;
    } else {
        $parm_ref = { @_ };
    }

    my $words      = [];
    my $locale     = 'ru';
    my $exceptions = {};
    foreach (keys %$parm_ref) {
        my $key = lc ($_);
        if ($key eq '-words') {
            @$words = @{$parm_ref->{$key}};
        } elsif ($key eq '-exceptions') {
            $exceptions = $parm_ref->{$key};
        } elsif ($key eq '-locale') {
            $locale = $parm_ref->{$key};
        } else {
            croak (__PACKAGE__ . "::stem() - Unknown parameter '$key' with value '$parm_ref->{$key}'\n");
        }
    }

    local( $_ );
    foreach (@$words) {
        # Flatten case
        $_ = lc $_;

        # Check against exceptions list
        if (exists $exceptions->{$_}) {
            $_ = $exceptions->{$_};
            next;
        }

        # Check against cache of stemmed words
        my $original_word = $_;
        if ($Stem_Caching && exists $Stem_Cache->{$original_word}) {
            $_ = $Stem_Cache->{$original_word};
            next;
        }

        $_ = stem_word($_);

        $Stem_Cache->{$original_word} = $_ if $Stem_Caching;
    }
    $Stem_Cache = {} if ($Stem_Caching < 2);

    return $words;
}

sub stem_word {
    my $word = lc shift;

    # Check against cache of stemmed words
    if ($Stem_Caching && exists $Stem_Cache->{$word}) {
        return $Stem_Cache->{$word};
    }

     my ($start, $RV) = $word =~ /$RVRE/;
     return $word unless $RV;

     # Step 1
     unless ($RV =~ s/$PERFECTIVEGROUND//) {
         $RV =~ s/$REFLEXIVE//;

         if ($RV =~ s/$ADJECTIVE//) {
             $RV =~ s/$PARTICIPLE//;
         } else {
             $RV =~ s/$NOUN// unless $RV =~ s/$VERB//;
         }
     }

     # Step 2
     $RV =~ s/и$//;

     # Step 3
     $RV =~ s/ость?$// if $RV =~ /$DERIVATIONAL/;

     # Step 4
     unless ($RV =~ s/ь$//) {
         $RV =~ s/ейше?//;
         $RV =~ s/нн$/н/;	
     }

     return $start.$RV;
}

sub stem_caching {
    my $parm_ref;
    if (ref $_[0]) {
        $parm_ref = shift;
    } else {
        $parm_ref = { @_ };
    }
    my $caching_level = $parm_ref->{-level};
    if (defined $caching_level) {
        if ($caching_level !~ m/^[012]$/) {
            croak(__PACKAGE__ . "::stem_caching() - Legal values are '0','1' or '2'. '$caching_level' is not a legal value");
        }
        $Stem_Caching = $caching_level;
    }
    return $Stem_Caching;
}

sub clear_stem_cache {
    $Stem_Cache = {};
}

1;
__END__

=head1 NAME

Lingua::Stem::RuUTF8 - Porter's stemming algorithm for Russian (UTF-8 only)

=head1 SYNOPSIS

    use Lingua::Stem::RuUTF8;
    my $stems = Lingua::Stem::RuUTF8::stem({
        -words => $word_list_reference,
        -locale => 'ru',
        -exceptions => $exceptions_hash,
    });

    my $stem = Lingua::Stem::RuUTF8::stem_word( $word );

=head1 DESCRIPTION

This module applies the Porter Stemming Algorithm to its parameters,
returning the stemmed words.

The algorithm is implemented exactly as described in:

    http://snowball.tartarus.org/russian/stemmer.html

The code is carefully crafted to work in conjunction with the L<Lingua::Stem>
module by Benjamin Franz. This stemmer is also based 
on the work of Aldo Capini, see L<Lingua::Stem::It>.

=head1 METHODS

=over 4

=item stem({ -words => \@words, -locale => 'ru', -exceptions => \%exceptions });

Stems a list of passed words. Returns an anonymous list reference to the stemmed
words.

Example:

  my $stemmed_words = Lingua::Stem::RuUTF8::stem({
      -words => \@words,
      -locale => 'ru',
      -exceptions => \%exceptions,
  });

=item stem_word( $word );

Stems a single word and returns the stem directly.

Example:

  my $stem = Lingua::Stem::RuUTF8::stem_word( $word );

=item stem_caching({ -level => 0|1|2 });

Sets the level of stem caching.

'0' means 'no caching'. This is the default level.

'1' means 'cache per run'. This caches stemming results during a single
    call to 'stem'.

'2' means 'cache indefinitely'. This caches stemming results until
    either the process exits or the 'clear_stem_cache' method is called.

=item clear_stem_cache;

Clears the cache of stemmed words

=back

=cut

=head2 EXPORT

None by default.

=head1 HISTORY

=over 8

=item *

0.01 (2004-05-21)

=back

=head1 AUTHOR

Aleksandr Guidrevitch <pillgrim@mail.ru>

=head1 SEE ALSO

 Lingua::Stem

=head1 COPYRIGHT

Copyright (C) 2003 by Aldo Calpini <dada@perl.it>

Copyright (C) 2004 by Aleksandr Guidrevitch <pillgrim@mail.ru>

This software may be freely copied and distributed under the same
terms and conditions as Perl itself, either Perl version 5.8.3
or, at your option, any later version of Perl 5 you may
have available..

=cut
