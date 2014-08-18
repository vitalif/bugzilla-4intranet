#!/usr/bin/perl

package BmpConvert;

use strict;
use Bugzilla;
use Image::Magick;

sub attachment_process_data
{
    my ($args) = @_;
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
    Bugzilla->add_result_message({ message => 'attachment_convertedbmp' });
    return 1;
}

sub attachment_post_create_result
{
    # Move last attachment_convertedbmp to the end of result_messages
    my $rm = Bugzilla->result_messages;
    my $l = @$rm;
    for (my $i = $l-1; $i >= 0; $i--)
    {
        if ($rm->[$i]->{message} eq 'attachment_convertedbmp' && $i != $l-1)
        {
            push @$rm, splice @$rm, $i, 1;
            last;
        }
    }
    return 1;
}

1;
__END__
