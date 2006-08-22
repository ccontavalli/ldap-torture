#!/usr/bin/perl -w

use Data::Dumper;

use RBC::Check;
use strict;

package Torture::Operations::move;

#  -> move, moves under another parent
#	-> conserving same name
#	-> conserving same attribute as dn

#  'move/leaf/ok'
#  'move/leaf/tononexisting'
#  'move/leaf/nonexisting'
#  'move/leaf/changingattribute'

###  'move/leaf/toexisting'

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

my $operations = [ 
  { aka => 'move/leaf/ok',
    name => 'move a random object under another parent -- which could be itself, without changing the rdn',
    func => [ \&Torture::Operations::action_server, 'move' ],
    args => [ 'dn/inserted/parent(dn/inserted/leaf)' ],
    res => [ \&move_leaf_ok ]}, 
];


sub init() { return $operations; }

1;
