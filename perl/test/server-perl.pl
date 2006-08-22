#!/usr/bin/perl -w
#

use strict;
use Torture::Server::Perl;
use Data::Dumper;

my $server=Torture::Server::Perl->new('dc=foo,dc=bar');
$server->add('cn=pippo,dc=foo,dc=bar', 'ahahahahah');
$server->add('cn=foo,cn=pippo,dc=foo,dc=bar');
$server->move('cn=pippo,dc=foo,dc=bar', 'cn=pluto,dc=foo,dc=bar');

print STDERR Dumper($server);
