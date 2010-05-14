#!/usr/bin/perl

package BmpConvert;

use strict;
use Image::Magick;

sub attachment_process_data
{
    my ($args) = @_;
    return 1 unless $args->{attributes}->{mimetype} eq 'image/bmp';

    my $data = ${$args->{data}};
    my $img = Image::Magick->new(magick => 'bmp');

    # $data is a filehandle.
    if (ref $data) {
        $img->Read(file => \*$data);
        $img->set(magick => 'png');
        $img->Write(file => \*$data);
    }
    # $data is a blob.
    else {
        $img->BlobToImage($data);
        $img->set(magick => 'png');
        $data = $img->ImageToBlob();
    }
    undef $img;

    ${$args->{data}} = $data;
    $args->{attributes}->{mimetype} = 'image/png';
    $args->{attributes}->{filename} =~ s/^(.+)\.bmp$/$1.png/i;
    return 1;
}

1;
__END__
