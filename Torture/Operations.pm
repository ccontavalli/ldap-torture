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

  $self->{'objects'} = [];
  $self->{'random'} = $random;
  $self->{'generator'} = $generator;
  $self->{'main'} = $main;
  $self->{'refe'} = $refe;

  bless($self);
  while(<$dir/*>) {
    $self->load($_);
  }

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
  print "Function ".$operation->{'aka'}."\n";
  if(ref($operation->{'func'}) ne 'ARRAY') {
    $result=&{$operation->{'func'}}($self->{'main'}, $self->{'refe'}, @args);
  } elsif($#{$operation->{'func'}} < 1) {
    print "function no args". $#{$operation->{'func'}} ."\n";
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  } else {
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'},
    				@{$operation->{'func'}}[1 .. $#{$operation->{'func'}}], @args);
  }

    # Call result handler
  if(ref($operation->{'res'}) ne 'ARRAY') {
    $result=&{$operation->{'res'}}($self->{'main'}, $self->{'refe'}, $result, @args);
  } elsif($#{$operation->{'res'}} < 1) {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result, @args);
  } else {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result,
    				@{$operation->{'res'}}[1 .. $#{$operation->{'res'}}], @args);
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

sub action_server() {
#  my $self=shift;
  my $main=shift;
  my $refe=shift;
  my $action=shift;

  my $result=$main->$action(@{@_});
  return [$result, @_]; 
}
#my $var = { 'var' => 'val' };
#my $var = [ ];
#my %var = ( );
#my @var = ( );
#
#my $var = \%hash;
#my $var = \@array;
#$var{'variabile'}
#$var->{'variabile'}
#
#$var[0]
#$var->[0]
#
#${$var}{'variabile'}
#${$var}[0]

sub ldap_fail() {
#  my $self=shift;
  my $main=shift;
  my $refe=shift;
  my $result=shift;

  foreach my $err_expect (shift) {
    if(${$result}[0]->code==$err_expect) {
    #if(0==$err_expect) {
      return undef;
    }
  }
  return (${$result}[0]->code ? ${$result}[0]->code ." ". ${$result}[0]->error : ${$result}[0]->code." Operation Success");
}

sub ldap_succeed() {
#  my $self=shift;
  my $main=shift;
  my $refe=shift;
  my $result=shift;
  
  return ${$result}[0]->code ." ". ${$result}[0]->error if(${$result}[0]->code);
  
  print "operation ".${$result}[1][0]."\n";
  #$refe->${$result}[1][0](1 .. @{${$result}[1]});
  return undef;
}

1;
