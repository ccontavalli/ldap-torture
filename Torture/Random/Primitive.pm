#!/usr/bin/perl -w

package Torture::Random::Primitive;

use strict;
no strict 'refs';

use Check;
our @ISA;


sub new() {
  my $name = shift;
  my $self = {};

  $self->{'parent'}=$name;

  bless($self, $name);
  return $self;
}

sub text() {
  my $self = shift;
  my $context = shift;
  my ($min, $max, @allowed) = @_;
  my $name=$self->{'parent'};

  Check::Natural($min);
  Check::Natural($max);

  print "$name\n";
  my ($lenght) = $self->number(&{$name . '::context'}($context, 'lenght'), $min, $max);
  my ($string);

  @allowed = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9') 
  	if(!@allowed);
  
  $string .= $allowed[$self->number(&{$name . '::context'}($context, 'char', $lenght), 0, $#allowed)]  
 	while($lenght--);

  return $string;
}

sub element() {
  my $self = shift;
  my $context = shift;
  my $array = shift; 

  Check::Array($array);
  return $array->[$self->number(context($context), 0, $#{$array})];
}

1;
