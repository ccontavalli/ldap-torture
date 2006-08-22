#!/usr/bin/perl -w
#

package Torture::Debug;
use strict;

my %errors = (
	'schema/object' => 0,
	'schema/attributes' => 0, 
	'schema/attribute' => 0,
	'schema/warning' => 0,
	'schema/index' => 0,
	'schema/syntax'=> 0,
	'schema/dump/attributes' => 0,
	'schema/dump/objects' => 0,
	'generator/making' => 0,
	'generator/parent/rootdn' => 0,
	'operators/perform/function' => 0,
	'operators/perform/result' => 0,
	'operators/perform/args' => 0,
	'LDAP/add' => 0,
	'LDAP/delete' => 0,
	'LDAP/move' => 0,
	'LDAP/rename' => 0
);

sub message($$) {
  my $name = shift;
  my (@message) = (@_);

  return if(!$errors{$name});
  print STDERR join(' ', @message);

  return;
}
