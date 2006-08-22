#!/usr/bin/perl -w

package Torture::Random::logger;

use strict;
use Torture::RBC::Check;
our $AUTOLOAD;

#our @ISA;
#use Torture::Random::Primitive;
#@ISA = ('Torture::Random::Primitive');

sub new() {
  my $name = shift;
  my $real = shift;
  my $output = shift;

  my $self = {};

  Torture::RBC::Check::Class('Torture::Random::.*', $real); 
  Torture::RBC::Check::Glob($output); 

  $self->{'real'}=$real;
  $self->{'output'}=$output;

  bless($self);
  return $self;
}

sub AUTOLOAD() {
  my $self = shift;
  my $method = $AUTOLOAD;
  my @args = @_;

    # ignore call to the destructor
  return if($AUTOLOAD =~ /::DESTROY$/);
    
    # print on logfile the called method and arguments
  $method =~ s/.*:://g;
  print $self->{'output'} $method . ' ' . join(' ', @args);

    # return value as it would have been returned
    # by real method
  return $self->{'real'}->$method(@args);
}

1;
