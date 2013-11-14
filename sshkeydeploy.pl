#!/usr/bin/perl
use strict;
use warnings;

# Usage:
# sshkeydeploy.pl hostname username


my $host = $ARGV[0];
my $user = $ARGV[1];
my $file = $ENV{"HOME"} . "/.ssh/id_rsa.pub";

&pubkey();
system("cat $file | ssh $user\@$host 'mkdir .ssh; cat >> .ssh/authorized_keys'");


sub pubkey
{
    if (-e $file) {
        print "id_rsa exists!\n";
    } else {
        print "id_rsa does not exist, creating now...\n";
        system("ssh-keygen");
    }
}
