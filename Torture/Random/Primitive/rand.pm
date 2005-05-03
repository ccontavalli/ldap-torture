#!/usr/bin/perl -w

package Torture::Random::Primitive::rand;

use strict;
use Check;

#use base qw(Torture::Random::Primitive);
our @ISA;
use Torture::Random::Primitive;
@ISA = ('Torture::Random::Primitive');

sub new() {
  my $name = shift;
  my $seed = shift;
  my $self = {};

  if($seed) {
    $self->{'seed'} = $seed;
    srand($seed);
  } else {
    srand();
    $self->{'seed'} = int(rand(~0));
    srand($self->{'seed'});
  }

  bless($self);
  return $self;
}

sub seed() {
  my $self = shift;
  my $seed = shift;

  if($seed) {
    srand($seed);
    $self->{'seed'}=$seed;
    return;
  }

  return $self->{'seed'};
}

sub number() {
  my $self = shift;
  my $min = shift;
  my $max = shift;

  Check::Natural($min);
  Check::Natural($max);
  return int($min+rand(($max - $min)+1));
}

1;
