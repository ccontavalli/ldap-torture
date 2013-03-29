#!/usr/bin/perl -w

use Data::Dumper;

use RBC::Check;
use strict;

package Torture::Operations::move;


#  'move/renaming/ok'
#  'move/renaming/changingattribute'

sub move_leaf_ok() {
  my $main = shift;
  my $refe = shift;
  my $result = shift;
  my $args = shift;

  RBC::Check::Array($args);

  my ($dnold, $dnnew) = (@{$args}[1 .. 2]);

  return ($result->code == 64 ? undef : $result->code . ' ' . $result->error) 
  	if(grep(/$dnold/, $dnnew));

  if($result->code == 0) {
    $refe->move($dnold, $dnnew);
    return undef;
  }

  return $result->code . ' ' . $result->error;
}

# missing:
#   move under a different parent changing the rdn 
#   move under a different parent changing the 
#      attribute used for the rdn

my $operations = [ 
  { aka => 'move/ok',
    name => 'move a random object under another parent, without changing the rdn',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/inserted', 'dn/alias/ok' ],
    res => [ \&move_leaf_ok ]}, 

  { aka => 'move/descendant',
    name => 'move a random object under one of its children (or itself), without changing the rdn',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/inserted', 'dn/alias/descendant' ],
    res => [ \&Torture::Operations::ldap_code, 32]}, 

  { aka => 'move/tononexisting',
    name => 'move a random object under a non-existing parent, without changing the rdn',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/inserted', 'dn/alias/noparent' ],
    res => [ \&Torture::Operations::ldap_code, 32]}, 

  { aka => 'move/nonexisting',
    name => 'move a non-existing object under another name',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/nonexisting', 'dn/alias/ok' ],
    res => [ \&Torture::Operations::ldap_code, 32]}, 

  { aka => 'rename/ok',
    name => 'changes name of an object under another name',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/inserted', 'dn/alias/sameparent/ok' ],
    res => [ \&move_leaf_ok ]}, 

  { aka => 'rename/attribute/ok',
    name => 'changes name of an object under another name',
    func => [ \&Torture::Operations::action_server, 'copy' ],
    args => [ 'dn/inserted', 'dn/attralias/sameparent/ok' ],
    res => [ \&move_leaf_ok ]}, 

];


sub init() { return $operations; }

1;
