#! /usr/bin/perl -w
#

use Net::LDAP;

my $ldap = Net::LDAP->new('localhost', 'version', 3) or
  die "couldn't create object: $@";

$ldap->bind;
