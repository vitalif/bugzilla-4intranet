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
    my $img = Image::Magick->new(magick => 'bmp');

    # $data is a filehandle.
    if (ref $data) {
        $img->Read(file => \*$data);
        $img->set(magick => 'png');
    }
    # $data is a blob.
    else {
        $img->BlobToImage($data);
        $img->set(magick => 'png');
    }
    $data = $img->ImageToBlob();
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
    $args->{session_data}->{sent_attrs}->{convertedbmp} = $args->{vars}->{convertedbmp} = $args->{vars}->{attachment}->{convertedbmp};
    return 1;
}

1;
__END__
