#!/usr/bin/perl -w
# Adds 100 objects into the database

use Torture::Random;
use Torture::Server;
use Data::Dumper;
use strict;

my $server = Torture::Server->new();
my $random = Torture::Random->new($server);

my $rootdn='dc=nodomain';

  # 2 way of recording a test: 
  #   1 - record initial random seeds
  #   2 - register all operations
  #   3 - introduce an affinity concept for operations

sub mydie(@) {
  print STDERR "Seed: " . $random->seed() . "\n";
  print STDERR join(' ', @_);
  exit 1;
}

  # Have some sort of probability for each operation
sub op_insertnew() {
  my $object;
  my $parent;
  my $dn;

    # Verify this dn really does not exist
  do {
    $parent=$random->randomparent($rootdn);
    $object=$random->randomobject($parent);
    $dn=${$object}[0];
  } while($server->inserted($dn));
    
  print STDERR @{$object}[0] . "\n";
  my $mesg=$server->add($parent, @{$object});
  $mesg->code && mydie($mesg->code . ': unexpected add error -- ' . $mesg->error . ' -- ' . Dumper($object));
}

sub op_insertexisting() {
  my $object;
  my $dn;

  $dn=($server->inserted())[$random->randomnumber(0, $server->inserted()-1)];
  $object=$server->inserted($dn);

  my $mesg=$server->add(undef, $dn, @{$object});
  mydie(($mesg->code ? $mesg->code : 'unknown') . 
  	': already existing entry inserted, or unexpected error  -- ' . 
	($mesg->error ? $mesg->error : 'inserted')  . ' -- ' . Dumper($object)) if(!$mesg->code || $mesg->code != 68);

  return;
}

sub op_insertnoparent() {
  my ($object, $dn);
  my $parent;

    # Get a random parent
  $parent=$random->randomparent($rootdn);

    # Verify this dn really does not exist
  do {
    $dn=$random->randomdn($parent);
  } while($server->inserted($dn));

    # Construct an object below 
    # the invented parent
  $object=$random->randomobject($dn);
    
  my $mesg=$server->add(undef, @{$object});
  mydie($mesg->code . ': unexpected addnoparent error -- ' 
  	. $mesg->error . ' -- ' . Dumper($object)) if(!$mesg->code || $mesg->code != 32);

    # XXX Verify object was not really added
  $mesg=$server->search(${$object}[0], 'scope' => 'base', 'filter' => '(objectclass=*)');
  mydie($mesg->code . ': unexpected addnoparent error -- ' . $mesg->error) if(!$mesg->code || $mesg->code != 32);

  return;
}

sub op_deleteleaf() {
  my $dn;

  $dn=($server->insertedleaf())[$random->randomnumber(0, $server->insertedleaf()-1)];

  print STDERR "$dn\n";
  my $mesg=$server->delete($dn);
  $mesg->code && mydie($mesg->code . ': unexpected deleteleaf error -- ' . $mesg->error);

  return;
}

sub op_deletebrench() {
  my $dn;

  $dn=($server->insertedbrench())[$random->randomnumber(0, $server->insertedbrench()-1)];
  return if(!$dn);

  my $mesg=$server->delete($dn);
  print STDERR "$dn\n";
  $mesg->code && mydie($mesg->code . ': unexpected deletebrench error -- ' . $dn . ' ' . $mesg->error);

  return;
}

sub op_movebrench() {
  my $leaf;
  my $newdn;
  my $dn;
  my $i=0;

  do {
    return undef if($i++ >= 5);

      # Get a random leaf 
    $dn=($server->insertedbrench())[$random->randomnumber(0, $server->insertedbrench()-1)];
    return "no brench" if(!$dn);

    $newdn=$random->randomparent($rootdn);
  } while($newdn eq $dn);
  return "no dn" if(!$newdn);

  $newdn=$random->randomdn($newdn, ($dn =~ /([^=]*)/)[0]);
  my $mesg=$server->move($dn, $newdn);
  print STDERR "$dn -> $newdn\n";
  $mesg->code && mydie($mesg->code . ': unexpected movebrench error -- ' . $dn . ' ' . $mesg->error . "\n");

  return "ok";
}

sub op_moveleaf() {
  my $leaf;
  my $newdn;
  my $dn;
  my $i=0;

  do {
    return undef if($i++ >= 5);

      # Get a random leaf 
    $dn=($server->insertedleaf())[$random->randomnumber(0, $server->insertedleaf()-1)];
    return if(!$dn);

    $newdn=$random->randomparent($rootdn);
  } while($newdn eq $dn);
  return if(!$newdn);

  $newdn=$random->randomdn($newdn, ($dn =~ /([^=]*)/)[0]);
  my $mesg=$server->move($dn, $newdn);
  print STDERR "$dn -> $newdn\n";
  $mesg->code && mydie($mesg->code . ': unexpected moveleaf error -- ' . $dn . ' ' . $mesg->error . "\n");

  return;
}

sub op_deletenonexisting() {
  my $self = shift;
  my $dn;

  do {
    $dn=$random->randomparent($rootdn);
    $dn .= ',' . $random->randomdn($dn);
  } while($server->inserted($dn));

  my $mesg=$server->delete($dn);
  mydie($mesg->code . ': unexpected deleteleaf error -- ' . $dn . ' '. $mesg->error) 
  	if(!$mesg->code || $mesg->code != 32);

  return;
}

my %operations = (
# 	'parallelize' => '',
 	'insertnew' => \&op_insertnew,
 	'insertexisting' => \&op_insertexisting,
 	'insertnoparent' => \&op_insertnoparent,
 	'deleteleaf' => \&op_deleteleaf,
 	'deletenonexisting' => \&op_deletenonexisting,
 	'deletebrench' => \&op_deletebrench,
 	'moveleaf' => \&op_moveleaf,
# 	'movebrench' => \&op_movebrench,
# 	'movenonexisting' => '',
# 	'movetononexisting' => '',
# 	'modifyattradd' => '',
# 	'modifyattrdel' => '',
# 	'modifyattrchg' => '',
# 	'modifyauxadd' => '',
# 	'modifyauxdel' => '',
# 	'getexistingleaf' => '',
# 	'getnonexistingleaf' => '',
# 	'getexistingbrench' => '',
# 	'getnonexistingbrench' => '',
);

$|=1;

print STDERR "insertnew\n";
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();
print STDERR "insertex\n";
&op_insertexisting();
print STDERR "insertno\n";
&op_insertnoparent();
print STDERR "deleteleaf\n";
&op_deleteleaf();
print STDERR "deletenonexisting\n";
&op_deletenonexisting();
print STDERR "moveleaf\n";
#&op_deletebrench(); Not supported by openldap, cannot succed
&op_moveleaf();
print STDERR "movebrench\n";
my $err = &op_movebrench();
print STDERR "movebrench: $err\n";

