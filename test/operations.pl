#!/usr/bin/perl -w
use Torture::Random;
use Torture::Server;
use Data::Dumper;
use strict;

my $server = Torture::Server->new();
my $random = Torture::Random->new($server);

my $rootdn='dc=masobit,dc=net';

  # 2 way of recording a test: 
  #   1 - record initial random seeds
  #   2 - register all operations
  #   3 - introduce an affinity concept for operations

sub mydie(@) {
  print STDERR "Seed: " . $random->seed() . "\n";
  print STDERR join(' ', @_, "\n");
  exit 1;
}

sub myskip(@) {
  print STDERR "\tskipped: ".join(' ', @_)."\n";
  return -1;
}

sub mydesc(@) {
  my $desc=shift;
  print STDERR "\t$desc\n";
  return;
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

  mydesc(${$object}[0]);
  #print Dumper(@{$object});
  my $mesg=$server->add($parent, @{$object});
  $mesg->code && mydie($mesg->code . ': unexpected add error -- ' . $mesg->error . ' -- ' . Dumper($object));
}

sub op_insertexisting() {
  my $dn=dn_existing();
  return myskip("no dn") if(!$dn);
  my $object=$server->inserted($dn);
  return myskip("no object") if(!$object);

  mydesc($dn);
  #print Dumper(@{[$dn, @{$object}]});
  my $mesg=$server->add(dn_parent($dn), $dn, @{$object});
  mydie($mesg->code . ': unexpected error  -- ' . 
	$mesg->error . ' -- ' . Dumper($object)) if($mesg->code != 68);

  return;
}

sub op_insertnoparent() {
    # Construct an object below 
    # the invented parent
  my $dn=dn_nonexisting();
  my $object=$random->randomobject($dn);
    
  mydesc(${$object}[0]);
  my $mesg=$server->add($dn, @{$object});
  mydie($mesg->code . ': unexpected addnoparent error -- ' .
  	$mesg->error . ' -- ' . Dumper($object)) if($mesg->code != 32);

#    # XXX Verify object was not really added
#  $mesg=$server->search(${$object}[0], 'scope' => 'base', 'filter' => '(objectclass=*)');
#  mydie($mesg->code . ': unexpected addnoparent error -- ' . $mesg->error) if(!$mesg->code || $mesg->code != 32);

  return;
}

sub op_deleteleaf() {
  my $dn=dn_existing_leaf();
  return myskip("no dn") if(!$dn);

  mydesc($dn);
  my $mesg=$server->delete($dn);
  $mesg->code && mydie($mesg->code . ': unexpected deleteleaf error -- ' . $mesg->error);

  return;
}

sub op_deletebrench() {
  my $dn=dn_existing_brench();
  return myskip("no dn") if(!$dn);

  mydesc($dn);
  my $mesg=$server->delete($dn);
  $mesg->code && mydie($mesg->code . ': unexpected deletebrench error -- ' . $dn . ' ' . $mesg->error);

  return;
}

sub op_movebrench() {
  mydesc("not yet implemented");
  return;
}

sub op_moverenamebrench() {
  my $dn=dn_existing_brench();
  return myskip("no dn") if(!$dn);
  my $newdn=dn_nonexisting(dn_existing(), dn_attr($dn));
  return myskip("no newdn") if(!$newdn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  $mesg->code && mydie($mesg->code . ': unexpected movebrench error -- ' . $dn . ' ' . $mesg->error);

  return;
}

sub op_renamebrench() {
  my $dn=dn_existing_brench();
  return myskip("no dn") if(!$dn);
  my $newdn=dn_nonexisting(dn_parent($dn), dn_attr($dn));
  return myskip("no newdn") if(!$newdn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  $mesg->code && mydie($mesg->code . ': unexpected movebrench error -- ' . $dn . ' ' . $mesg->error);

  return;
}

sub op_moveleaf() {
  mydesc("not yet implemented");
  return;
}

sub op_moverenameleaf() {
  my $dn=dn_existing_leaf();
  return myskip("no dn") if(!$dn);
  my $newdn=dn_nonexisting(dn_existing(), dn_attr($dn));
  return myskip("no newdn") if(!$newdn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  $mesg->code && mydie($mesg->code . ': unexpected renameleaf error -- ' . $dn . ' ' . $mesg->error . "\n");

  return;
}

sub op_renameleaf() {
  my $dn=dn_existing_leaf();
  return myskip("no dn") if(!$dn);
  my $newdn=dn_nonexisting(dn_parent($dn), dn_attr($dn));
  return myskip("no newdn") if(!$newdn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  $mesg->code && mydie($mesg->code . ': unexpected moveleaf error -- ' . $dn . ' ' . $mesg->error . "\n");

  return;
}

sub op_deletenonexisting() {
  my $dn=dn_nonexisting();
  return myskip("no dn") if(!$dn);

  mydesc($dn);
  my $mesg=$server->delete($dn);
  mydie($mesg->code . ': unexpected deleteleaf error -- ' . $dn . ' '. $mesg->error) 
  	if(!$mesg->code || $mesg->code != 32);

  return;
}

##### Yet implemented ######
sub op_movenonexisting() {
  my $newdn=dn_existing();
  return myskip('no newdn') if(!$newdn);
  my $dn=dn_nonexisting("", dn_attr($newdn));
  return myskip('no dn') if(!$dn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  if($mesg->code != 32) {
    mydie($mesg->code . ': unexpected movenonexisting error  -- ' . $mesg->error);
  }

  return;
}

sub op_movetononexisting() {
  my $dn=dn_existing();
  my $newdn=dn_nonexisting(dn_nonexisting(), dn_attr($dn));
  return myskip('no dn') if(!$dn);
  return myskip('no newdn') if(!$newdn);

  mydesc("$dn -> $newdn");
  my $mesg=$server->move($dn, $newdn);
  if($mesg->code != 80) {
    mydie($mesg->code . ': unexpected movenonexisting error -- ' . $mesg->error);
  }

  return;
}

sub op_getexistingentry() {
  my $dn=dn_existing();
  return if(!$dn);

  mydesc($dn);
  my $mesg=$server->search($dn, 'base');

  if($mesg->code) {
    mydie($mesg->code . ': unexpected getexistingentry error -- ' . $mesg->error);
  }

  return;
}

sub op_getexistingdn() {
  my $dn=shift;
  return if(!$dn);

  mydesc($dn);
  my $mesg=$server->search($dn, 'one');

  print Dumper($mesg->entries());
  if($mesg->code) {
    mydie($mesg->code .': unexpected getexistingone error -- '. $mesg->error);
  }

  return;
}

sub op_getexistingone() {
  my $dn=dn_existing();
  return if(!$dn);

  mydesc($dn);
  my $mesg=$server->search($dn, 'one');

  if($mesg->code) {
    mydie($mesg->code .': unexpected getexistingone error -- '. $mesg->error);
  }

  return;
}

sub op_getexistingsub() {
  my $dn=dn_existing();
  return if(!$dn);

  mydesc($dn);
  my $mesg=$server->search($dn, 'sub');

  if($mesg->code) {
    mydie($mesg->code . ': unexpected getexistingsub error -- ' . $mesg->error);
  }

  return;
}

sub op_getnonexisting() {
  my $dn;
  
  do {
    my $parent=$random->randomparent($rootdn);
    my $object=$random->randomobject($parent);
    $dn=${$object}[0];
  } while($server->inserted($dn));
  return if(!$dn);

  mydesc($dn);
  my $mesg=$server->search($dn, 'sub');
  
  if($mesg->code != 32) {
    mydie($mesg->code . ': unexpected getnonexisting error -- ' . $mesg->error);
  }
}

my $dn_maxtry=1000;
sub dn_existing() {
  return ($server->inserted())[$random->randomnumber(0, $server->inserted()-1)];
}

sub dn_existing_leaf() {
  return ($server->insertedleaf())[$random->randomnumber(0, $server->insertedleaf()-1)];
}

sub dn_existing_brench() {
  return ($server->insertedbrench())[$random->randomnumber(0, $server->insertedbrench()-1)];
}

sub dn_nonexisting(@) {
  my $i=$dn_maxtry;
  my $dn;
  my ($parent, $attr)=@_;

  do {
    $dn=$random->randomdn(($parent ? $parent : dn_existing()), $attr);

    if($i-- < 0) {
      print STDERR 'dn_nonexisting: to much try';
      return;
    }
  } while($server->inserted($dn));

  return $dn;
}

sub dn_nonexisting_child_leaf() {
  my $i=$dn_maxtry;
  my $dn;

  do {
    my $parent=dn_existing_leaf();
    my $object=$random->randomobject($parent);
    $dn=${$object}[0];

    if($i-- < 0) {
      print STDERR 'dn_nonexisting_child_leaf: to much try';
      return;
    }
  } while($server->inserted($dn));

  return $dn;
}

sub dn_nonexisting_child_brench() {
  my $i=$dn_maxtry;
  my $dn;
  
  do {
    my $parent=dn_existing_brench();
    my $object=$random->randomdn($parent);
    $dn=${$object}[0];

    if($i-- < 0) {
      print STDERR 'dn_nonexisting_child_brench: to much try';
      return;
    }
  } while($server->inserted($dn));

  return $dn;
}

sub dn_child() {
  mydesc("not yet implemented");
  return;
}

sub dn_parent() {
  my $dn = shift;
  return ($dn =~ /,(.*)$/);
}

sub dn_anchestor() {
  mydesc("not yet implemented");
  return;
}

sub dn_attr() {
  my $dn = shift;
  return ($dn =~ /([^=]*)/)[0];
}

# 	ok	ok		no	waited success	moveleaf, movebrench
#	ok	ok		ok	waited error	movetoexisting
# 	ok	no		no	waited error	movetononexisting
# 	no	ok		ok	waited error	movenonexisting, movetoexisting
# 	no	ok		no	waited error	movenonexisting
# 	no	no		no	waited error	movenonexisting, movetononexisting
# 	ok	no		ok	impossible	-
# 	no	no		ok	impossible	-
#

my %operations = (
### 	'parallelize' => '',						
 	'insertnew' => \&op_insertnew,
# 	'insertexisting' => \&op_insertexisting,
 	'insertnoparent' => \&op_insertnoparent,
	'deleteleaf' => \&op_deleteleaf,
	'deletenonexisting' => \&op_deletenonexisting,
## 	'deletebrench' => \&op_deletebrench,
## 	'moveleaf' => \&op_moveleaf,
 	'renameleaf' => \&op_renameleaf,
 	'moverenameleaf' => \&op_moverenameleaf,
# 	'movebrench' => \&op_movebrench,
 	'renamebrench' => \&op_renamebrench,
## 	'moverenamebrench' => \&op_moverenamebrench,
### 	'movetoexisting' => '',	
 	'movenonexisting' => \&op_movenonexisting,
 	'movetononexisting' => \&op_movetononexisting,
### 	'modifyattradd' => '',
### 	'modifyattrdel' => '',
### 	'modifyattrchg' => '',
### 	'modifyauxadd' => '',
### 	'modifyauxdel' => '',
# 	'getexistingentry' => \&op_getexistingentry,
# 	'getexistingone' => \&op_getexistingone,
# 	'getexistingsub' => \&op_getexistingsub,
# 	'getnonexisting' => \&op_getnonexisting,
# 	'getexistingdn' => \&op_getexistingdn,
);

$|=1;

print STDERR "--- insertnew ---\n";
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();
&op_insertnew();

my $op_num=10000;
for(my $i=1; $i <= $op_num; $i++) {
  my $op = (keys(%operations))[$random->randomnumber(0, keys(%operations)-1)];
  print STDERR "$i --- $op ---\n";
  $operations{$op}();
}

print STDERR "--- deleteleaf ---\n";
while(!defined(&op_deleteleaf())) {};
