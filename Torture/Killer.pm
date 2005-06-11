#!/usr/bin/perl -w

package Torture::Killer;
use strict;

use Check;

sub new() {
  my $name = shift;
  my $self = {};

  my $random = shift;
  my $operations = shift;

  Check::Class('Torture::Random::Primitive::.*', $random);
  Check::Class('Torture::Operations.*', $operations);

  $self->{'random'} = $random;
  $self->{'operations'} = $operations;

  bless($self, $name);
  return $self;
}

sub start() {
  my $self = shift;
  my $context = shift;
  my $limit = shift || -1;
 
  my ($count = 0, $rand, $status = undef);
  my %known = $self->{'operations'}->known();

  for(; !$status && $count != $limit; $count ++) {
    $rand=$self->{'random'}->element($self->{'random'}->context($context, 'operation'), [keys(%known)]);
    $status=$self->{'operations'}->perform($self->{'random'}->context($context, $count), $rand);
  }

  print "SEED\n";
  print $self->{'random'}->seed() . "\n";
  print "===================\n";
  print ($status ? $status : 'maximum number of operations performed') . "\n";

  return;
}

1;
