#!/usr/bin/perl -w

package Torture::Random::accumulator;

use strict;
use Torture::Check;
our $AUTOLOAD;

#our @ISA;
#use Torture::Random::Primitive;
#@ISA = ('Torture::Random::Primitive');

sub new() {
  my $name = shift;
  my $real = shift;

  my $self = {};

  Torture::Check::Class('Torture::Random::.*', $real); 
  $self->{'real'}=$real;

  bless($self);
  return $self;
}

sub seed() {
  my $self = shift;
  my $seed = shift;

  if($seed) {
    push(@{$self->{'methods'}}, $method);
    push(@{$self->{'arguments'}}, [$seed]);

    return $self->{'real'}->seed($seed);
  }
  
  my $retval;
  foreach (@{$self->{'methods'}}) {
    my $args = shift(@{$self->{'arguments'}});
    $retval .= $_ . ' ' . join(' ', @{$args}) . "\n";
  }

  return $retval;
}

sub AUTOLOAD() {
  my $self = shift;
  my $method = $AUTOLOAD;
  my @args = @_;

    # ignore call to the destructor
  return if($AUTOLOAD =~ /::DESTROY$/);
    
    # accumulate returned number and arguments
  $method =~ s/.*:://g;
  push(@{$self->{'methods'}}, $method);
  push(@{$self->{'arguments'}}, \@args);

    # return value as it would have been returned
    # by real method
  return $self->{'real'}->$method(@args);
}

1;
