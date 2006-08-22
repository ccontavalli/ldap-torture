#!/usr/bin/perl -w

package RBC::Accumulator;
use strict;
our $AUTOLOAD;

sub new() {
  my $self = {};
  my $name = shift;
  my $error = shift;

  $self->{'error'}=$error;

  bless($self);
  return $self;
}

sub empty($) {
  my $self = shift;
  my $class = shift;

  delete($self->{'methods'});
  delete($self->{'arguments'});
}

sub flush($) {
  my $self = shift;
  my $class = shift;

  return if(!$self->{'methods'});

  my @methods = @{$self->{'methods'}};
  my @arguments = @{$self->{'arguments'}};
  my $method;

  foreach $method (@methods) {
    my $args = shift @arguments;

    if($self->{'error'}) {
      $self->{'error'}($class, $method, $class->$method(@{$args}));
    } else {
#      Debug::message('accumulated', "$class / $method " . join(' ', (@{$args} > 0 ? @{$args} : ('(undef)'))));
      $class->$method(@{$args});
    }
  }

  return undef;
}

sub AUTOLOAD {
  my $self = shift;
  my $method = $AUTOLOAD;
  my @args = @_;
 
  return if($AUTOLOAD =~ /::DESTROY$/);

  $method =~ s/.*:://g;
  push(@{$self->{'methods'}}, $method);
  push(@{$self->{'arguments'}}, \@args);
}

1;
