#!/usr/bin/perl -w
# Adds 100 objects into the database

use Torture::Random;
use Torture::Server;
use strict;

my $rootdn='dc=nodomain';

my $server = Torture::Server->new();
my $random = Torture::Random->new($server);
my $object;


print "SEED: " . $random->seed($ARGV[0]) . "\n";
for(my $i=0; $i < 100; $i++) {
  my $obj=$random->randomobject($rootdn);
  print STDERR "adding: " . ${$obj}[0] . "\n";

  my $mesg=$server->add(@{$obj});
  $mesg->code && print STDERR $mesg->code . ': ' . $mesg->error . "\n";
}

