#!/usr/bin/perl -w
# Email LDAP alias getter for email_in.pl mail handler
# Config file /etc/ldap/bugzilla-getusers.conf must be in the form of:
# {
#   LDAPserver   => "office.custis.ru",
#   LDAPport     => 636,
#   LDAPbinddn   => "cn=ldapuser,ou=bots,ou=custis,dc=office,dc=custis,dc=ru",
#   LDAPbindpass => "",
#   LDAPBaseDN   => "dc=office,dc=custis,dc=ru",
# }

use Cwd qw(abs_path);
use File::Basename qw(dirname);
BEGIN {
    my ($a) = abs_path($0) =~ /^(.*)$/iso;
    chdir dirname($a);
}

use utf8;
use strict;

use POSIX;
use Net::LDAPS;

use Bugzilla;
use Bugzilla::User;

BEGIN { setlocale(LC_ALL, "ru_RU.UTF-8") };

my $configfile = "/etc/ldap/bugzilla-get-aliases.conf";
my $verbose = 0;

while ($ARGV[0] && $ARGV[0] =~ /^-/so)
{
    my $key = shift @ARGV;
    if ($key eq '-v' || $key eq '--verbose')
    {
        $verbose++;
    }
    elsif ($key eq '--help')
    {
        print <<EOF;
Email LDAP alias getter for email_in.pl mail handler
USAGE: $0 [--verbose] [config.file]
config.file is $configfile by default.
EOF
        exit;
    }
}

$configfile = $ARGV[0] || $configfile;
my $config = require $configfile;

my $users = get_domain_users();
my $aliases = [];

my $dbh = Bugzilla->dbh;
my $sth = $dbh->prepare("REPLACE INTO emailin_aliases SET address=?, userid=?, fromldap=1, isprimary=?");
print "Clearing aliases having fromldap=1\n" if $verbose;
$dbh->do("DELETE FROM emailin_aliases WHERE fromldap=1");
my %a = ();
foreach (@$users)
{
    my $uid = [ map { login_to_id($_) } @$_ ];
    my ($realid, $reallogin);
    foreach my $i (0..$#$uid)
    {
        # user with minimal ID
        if ($uid->[$i] && (!$realid || $realid > $uid->[$i]))
        {
            $realid = $uid->[$i];
            $reallogin = $_->[$i];
        }
    }
    if ($realid)
    {
        # found user
        my $i = 0;
        for (@$_)
        {
            print "Adding alias $_ for user $realid ($reallogin)\n" if $verbose;
            $sth->execute($_, $realid, !($i++)) unless $a{$_}++;
        }
    }
}
exit;

sub get_domain_users
{
    my $LDAPconn = Net::LDAPS->new($config->{LDAPserver},
        port    => $config->{LDAPport},
        version => 3,
        cafile  => '/usr/share/ssl/certs/office.pem',
        capath  => '/usr/share/ssl/certs/'
    );

    my $mesg = $LDAPconn->bind($config->{LDAPbinddn}, password => $config->{LDAPbindpass});

    $mesg = $LDAPconn->search(
        base   => $config->{LDAPBaseDN},
        filter => '(&(&(proxyaddresses=*)(!(msExchHideFromAddressLists=TRUE))(objectclass=user)))',
        attrs  => "*",
    );

    my $user_entry;
    my $mail;
    my @smtp;
    my $users = [];
    my $entries = $mesg->count;

    for my $i (0..$entries-1)
    {
        $user_entry = $mesg->shift_entry;
        $mail = $user_entry->get_value("mail");
        @smtp = $user_entry->get_value("proxyAddresses");
        if ($mail)
        {
            $mail = [ $mail ];
            foreach my $y (@smtp)
            {
                if ($y =~ m/smtp/i)
                {
                    $y =~ s/^smtp://i;
                    push @$mail, $y;
                }
            }
            push @$users, $mail;
        }
    }

    return $users;
}
