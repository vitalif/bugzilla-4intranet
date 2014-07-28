#!/usr/bin/perl

package BmpConvert;

use strict;
use Image::Magick;

my $convertedbmp;

sub attachment_process_data
{
    my ($args) = @_;
    $convertedbmp = 0;
    return 1 unless $args->{attributes}->{mimetype} eq 'image/bmp';

    my $data = ${$args->{data}};
    my $img = Image::Magick->new(magick => 'bmp', verbose => 1);

    my $x;
    # $data is a filehandle.
    if (ref $data) {
        local $/ = undef;
        $data = <$data>;
    }
    # $data is a blob.
    $x = $img->BlobToImage($data);
    warn __PACKAGE__.": Image::Magick said '$x' while reading BMP image" if "$x";

    $img->set(magick => 'png');
    if (!($data = $img->ImageToBlob()))
    {
        # Some failure
        warn __PACKAGE__.": Image::Magick::ImageToBlob() failed";
        return 1;
    }
    undef $img;

    ${$args->{data}} = $data;
    $args->{attributes}->{mimetype} = 'image/png';
    $args->{attributes}->{filename} =~ s/^(.+)\.bmp$/$1.png/i;
    $convertedbmp = 1;
    return 1;
}

sub attachment_post_create
{
    my ($args) = @_;
    $args->{attachment}->{convertedbmp} = 1 if $convertedbmp;
    return 1;
}

sub attachment_post_create_result
{
    my ($args) = @_;
    my $r = Bugzilla->result_messages;
    $r->[$#$r]->{convertedbmp} = $args->{vars}->{convertedbmp} = $args->{vars}->{attachment}->{convertedbmp};
    return 1;
}

1;
__END__
