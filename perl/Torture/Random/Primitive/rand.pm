#!/usr/bin/perl -w

package Torture::Random::Primitive::rand;
require Exporter;

use strict;
use RBC::Check;

our (@ISA, @EXPORT);
use Torture::Random::Primitive;

@ISA = ('Torture::Random::Primitive', 'Exporter');

sub context(@) { 
  my $self = shift;
  my $context = shift;
  my @array = @_;
  my @retval = @{$context || []};

  push(@retval, (caller)[0], @_);
  return \@retval; 
}

sub new() {
  my $name = shift;
  my $seed = shift;
  my $self = $name->SUPER::new();

  if($seed) {
    $self->{'seed'} = $seed;
    srand($seed);
  } else {
    srand();
    $self->{'seed'} = int(rand(0xffffffff));
    srand($self->{'seed'});
  }

  bless($self, $name);
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
  my $context = shift;
  my $min = shift;
  my $max = shift;

  RBC::Check::Natural($min);
  RBC::Check::Natural($max);
  return int($min+rand(($max - $min)+1));
}

1;
