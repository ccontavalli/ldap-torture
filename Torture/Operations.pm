#!/usr/bin/perl -w

use Data::Dumper;

use Check;
use strict;

package Torture::Operations;
my $dir = 'Torture/Operations';

sub new {
  my $self = {};
  my $name = shift;
  my $random = shift;
  my $generator = shift;

  my $main = shift;
  my $refe = shift;

  Check::Class('Torture::Random::Primitive.*', $random);
  Check::Class('Torture::Random::Generator.*', $generator);

  my $kind;

  bless($self);
  while(<$dir/*>) {
    $self->load($_);
  }

  $self->{'objects'} = [];
  $self->{'random'} = $random;
  $self->{'generator'} = $generator;
  $self->{'main'} = $main;
  $self->{'refe'} = $refe;

  return $self;
}

sub perform() {
  my $self = shift;
  my $context = shift;
  my $operation = shift;

  my (@args, $result);

  Check::Hash($operation);
  Check::Value($operation->{'aka'});
  Check::Value($operation->{'func'});

    # Ok, generate each and every of the required arguments 
  foreach my $arg (@{$operation->{'args'}}) {
    my $value=$self->{'generator'}->generate($self->{'random'}->context($context, $operation->{'aka'}, $arg), $arg);
    return undef if(!$value);

    push(@args, $value);
  }

    # Call function handler 
  if(ref($operation->{'func'}) eq 'ARRAY') {
    $result=&{$operation->{'func'}->[0]}(@{$operation->{'func'}}[1 .. @{$operation->{'func'}}], @args);
  } else {
    $result=&{$operation->{'func'}}(@args);
  }

    # Call result handler
  if(ref($operation->{'res'}) == 'ARRAY') {
    $result=&{$operation->{'res'}[0]}($self, $result, $operation->{'func'}->[1 .. $#{$operation->{'func'}}]);
  } else {
    $result=&{$operation->{'res'}}($self, $result);
  }

    # Finally, return back to caller
  return $result;
}

sub load {
  my $self = shift;
  my $kind = shift;

  require $kind;

  $kind =~ s/(\.\/|\.pm)//g;
  $kind =~ s/\//::/g;
  $kind->import();

  push(@{$self->{'objects'}}, $kind);
  foreach my $element (@{$kind->init}) {
    push(@{$self->{'generators'}}, $element);
  }
}

sub disable {
  my $self=shift;
  my @black=@_;
  my @second;

  foreach my $generator (@{$self->{'generators'}}) {
    foreach my $expr (@black) {
      push(@second, $generator) if($generator->{'aka'} && $generator->{'aka'} !~ /$expr/);
    }
  }

  $self->{'generators'}=\@second;
  return;
}

sub known() {
  my $self=shift;
  return @{$self->{'generators'}};
}

1;
