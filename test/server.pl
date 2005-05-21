#!/usr/bin/perl -w
#

use strict;
use Torture::Server::LDAP;

my $server=Torture::Server::LDAP->new();

$server->search('dc=nodomain', 'one'); 
