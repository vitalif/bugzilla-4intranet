#!/usr/bin/perl -wT
# HTTP handler for incoming e-mail

use strict;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::InMail;

my $status;
if (!Bugzilla->params->{enable_inmail_cgi})
{
    $status = 'disabled';
}
else
{
    my $mail_text = Bugzilla->cgi->param('POSTDATA');
    if (!$mail_text)
    {
        $status = 'empty-message';
    }
    else
    {
        $status = Bugzilla::InMail::process_inmail($mail_text) == 1 ? 'success' : 'error';
    }
}

Bugzilla->cgi->send_header('application/json');
print '{"status":"'.$status.'"}';
exit;

__END__

Postfix configuration example:

1) If you want to log all incoming messages, create /etc/postfix/send-to-bugzilla script with the following content:

#!/bin/sh
echo '-----' >> /var/log/bugzilla-email-in.log
/usr/bin/tee -a /var/log/bugzilla-email-in.log | curl -X POST -H 'Content-Type: text/plain' --data-binary @- http://127.0.0.1:8157/email_in.cgi

2) If you don't want to log all incoming messages, create /etc/postfix/send-to-bugzilla script with the following content:

#!/bin/sh
curl -X POST -H 'Content-Type: text/plain' --data-binary @- http://127.0.0.1:8157/email_in.cgi

3) Make it executable:

chmod 755 /etc/postfix/send-to-bugzilla

4) Add the following to master.cf:

bugzilla unix - n n - - pipe
  flags=DRhu user=www-data:www-data argv=/etc/postfix/send-to-bugzilla

5) Add the following to your /etc/postfix/transport map:

daemon@your.bugzilla.url bugzilla:

Where `daemon@your.bugzilla.url` is the same as `mailfrom` Bugzilla parameter from Administration -> Config
This will make your Postfix feed all messages sent to `daemon@your.bugzilla.url` to email_in.cgi.

6) Run `postmap /etc/postfix/transport`

7) Ensure that other parts of your Postfix configuration do not prevent it from receiving mail to daemon@your.bugzilla.url

8) Turn `enable_inmail_cgi` parameter on in Administration -> Config

9) Deny access to `email_in.cgi` in your HTTP server. For example with nginx:

location /email_in.cgi {
    deny all;
}
