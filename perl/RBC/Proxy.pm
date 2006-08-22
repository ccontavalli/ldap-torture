#!/usr/bin/perl -w

package RBC::Proxy;
use strict;
our $AUTOLOAD;

sub new() {
  my $self = {};
  my $name = shift;
  my @args = @_;

  foreach my $file (@args) {
    push(@{$self->{'instances'}}, $file);
  }

  bless($self);
  return $self;
}

sub add() {
  my $self = shift;
  my $class = shift;
 
  push(@{$self->{'instances'}}, $class);
  return;
}

sub AUTOLOAD {
  my $self = shift;
 
  return if($AUTOLOAD =~ /::DESTROY$/);

  foreach my $file (@{$self->{'instances'}}) {
    $AUTOLOAD =~ s/.*:://g;
    $file->$AUTOLOAD(@_);
  }
}

1;
