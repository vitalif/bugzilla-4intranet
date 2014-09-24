# Make template mtime dependent on i18n messages mtime
# License: Dual-license MPL 1.1+ or GPL 3.0+
# Author(s): Vitaliy Filippov <vitalif@mail.ru>

package Bugzilla::Template::Provider;

use strict;
use base 'Template::Provider';

sub _template_modified
{
    my $self = shift;
    my $template = shift || return;
    my $mtime = (stat $template)[9];
    if ($mtime)
    {
        my $msgmtime = Bugzilla->i18n->template_messages_mtime($Bugzilla::Template::COMPILE_LANGUAGE);
        $mtime = $msgmtime if $msgmtime > $mtime;
    }
    return $mtime;
}

1;
__END__
