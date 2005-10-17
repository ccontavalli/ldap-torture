#!/usr/bin/perl -w

package Torture::Killer;
use strict;

use Data::Dumper;
use Torture::Operations;
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
 
  my ($count, $rand) = (0, undef);
  my @known = $self->{'operations'}->known();
  my @status = ($Torture::Operations::ok, undef);

  while($count != $limit) {
    $rand=$self->{'random'}->element($self->{'random'}->context($context, 'operation'), \@known);
    @status=$self->{'operations'}->perform($self->{'random'}->context($context, $count), $rand);
    next if($status[0] == $Torture::Operations::impossible);
    last if($status[0] != $Torture::Operations::ok);

    $count++;
  }

  print "SEED\n";
  print $self->{'random'}->seed() . "\n";
  print "===================\n";
  print ((($status[0] != $Torture::Operations::ok) ? ($status[0] . ':' . $status[1]) : 'all operations performed') . "\n");

  return;
}

1;
