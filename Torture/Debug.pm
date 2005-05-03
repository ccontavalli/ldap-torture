#!/usr/bin/perl -w
#

package Torture::Debug;
use strict;

my %errors = (
	'schema/object' => 1,
	'schema/attributes' => 1,
	'schema/attribute' => 1,
	'schema/warning' => 1,
	'schema/index' => 1,
	'schema/syntax'=> 1,
	'schema/dump/attributes' => 1,
	'schema/dump/objects' => 1 
);

sub message($$) {
  my $name = shift;
  my (@message) = (@_);

  return if(!$errors{$name});
  print STDERR join(' ', @message);

  return;
}
