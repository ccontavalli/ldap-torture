#!/usr/bin/perl -w 

use Torture::Random;
use Torture::Server;
use Data::Dumper;
use strict;

my $server = Torture::Server->new();
my $random = Torture::Random->new($server);
my $object;

print 'random number (1, 100): ' . $random->randomnumber(1, 100) . "\n";
print 'random number (1, 10): ' . $random->randomnumber(1, 10) . "\n";
print 'random number (1, 10): ' . $random->randomnumber(1, 10) . "\n";
print 'random text (1, 30): ' . $random->randomtext(1, 30) . "\n";
print 'random dn: ' . $random->randomdn('cn') . "\n";
print 'random dn: ' . $random->randomdn('cn', 'domain=pippo') . "\n";
print 'random class: ' . $random->randomclass . "\n";
print 'random object - ' . $random->randomobject . "\n" ;

$object=$random->randomobject('dc=nodomain');
#print STDERR Dumper(${$object}[0], %{${$object}[1]}) . "\n";
print STDERR Dumper(@{$object}) . "\n";
print STDERR Dumper('cn=test', 
		    attr => [ 
		      'cn' => 'test', 
		      'objectclass' => [ 'pippo', 'pluto' ] 
		    ]) . "\n";

my $result = $server->add(@{$object});
$result->code && warn "failed to add entry: ", $result->error;

exit(0);
