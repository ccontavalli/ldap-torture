#!/usr/bin/perl -w
# Adds 100 objects into the database

use Torture::Random;
use Torture::Server;
use strict;

my $rootdn='dc=nodomain';

$|=1;

my $pid;
my $i;
for($i=0; $i < 20; $i++) {
  $pid=fork();
  if(!$pid) {
    last;
  }
}

if($pid) {
  print STDERR "dad waiting..";
  while(wait() >= 0) {}
  exit 0;
}

my $server = Torture::Server->new();
my $random = Torture::Random->new($server);
my $object;


print "[$pid] SEED: " . $random->seed($ARGV[$i]) . "\n";
for(my $i=0; $i < 100; $i++) {
  my $obj=$random->randomobject($rootdn);
  print '.';

  my $mesg=$server->add(@{$obj});
  $mesg->code && print 'A ' . ${$obj}[0] . ': ' . $mesg->code . ': ' . $mesg->error . "\n";
}

foreach my $dn ($server->inserted()) {
  print 'o';

  my $mesg=$server->search($dn, 'scope' => 'one', 'filter' => '(objectclass=*)');
  $mesg->code && print 'V ' . $dn . ': ' . $mesg->code . ': ' . $mesg->error . "\n";
}

