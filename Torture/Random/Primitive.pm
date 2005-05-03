#!/usr/bin/perl -w

package Torture::Random::Primitive;

use strict;
use Check;

sub new() {
  Check::Value(undef);
}

sub text() {
  my $self = shift;
  my ($min, $max, @allowed) = @_;

  Check::Natural($min);
  Check::Natural($max);

  my ($lenght) = $self->number($min, $max);
  my ($string);

  @allowed = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9') 
  	if(!@allowed);
  
  $string .= $allowed[$self->number(0, $#allowed)]  
 	while($lenght--);

  return $string;
}

sub element() {
  my $self = shift;
  my $array = shift; 

  Check::Array($array);
  return $array->[$self->number(0, $#{$array})];
}

1;
