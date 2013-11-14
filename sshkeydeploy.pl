#!/usr/bin/perl
use strict;
use warnings;

# Usage:
# sshkeydeploy.pl hostname username (port or blank for 22)


my $host = $ARGV[0];
my $user = $ARGV[1];
my $port;
my $file = $ENV{"HOME"} . "/.ssh/id_rsa.pub";

if ($ARGV[2]) {
    $port = $ARGV[2];
} else {
    $port = "22";
}


&pubkey();
system("cat $file | ssh -p $port $user\@$host 'mkdir -p .ssh; cat >> .ssh/authorized_keys'");


sub pubkey
{
    if (-e $file) {
        print "id_rsa exists!\n";
    } else {
        print "id_rsa does not exist, creating now...\n";
        system("ssh-keygen");
    }
}

