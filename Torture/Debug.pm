#!/usr/bin/perl -w
#

package Torture::Debug;
use strict;

my %errors = (
	'schema/object' => 0,
	'schema/attributes' => 0,
	'schema/warning' => 0,
	'schema/index' => 0,
	'schema/syntax'=> 0,
	'schema/dump/attributes' => 0,
	'schema/dump/objects' => 0
);

sub message($$) {
  my $name = shift;
  my (@message) = (@_);

  return if(!$errors{$name});
  print STDERR join(' ', @message);

  return;
}
