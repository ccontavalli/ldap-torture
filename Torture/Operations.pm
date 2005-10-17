#!/usr/bin/perl -w

use Data::Dumper;

use Check;
use strict;

package Torture::Operations;
my $dir = 'Torture/Operations';

our $ok = 0;
our $impossible = 1;
our $error = 2;

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
    my @value=$self->{'generator'}->generate($self->{'random'}->context($context, $operation->{'aka'}, $arg), $arg);
    Torture::Debug::message('operators/perform/args', "getting $arg -> " . ((@value && defined($value[0])) ? join(' ', @value) : '(undef)') . "\n");
    return (wantarray ? ($impossible, "couldn't find any $arg") : $impossible) if(!@value || !defined($value[0]));

    push(@args, @value);
  }

    # Call function handler 
  Torture::Debug::message('operators/perform/function', 'function ' . $operation->{'aka'} . "\n");
  if(ref($operation->{'func'}) ne 'ARRAY') {
    $result=&{$operation->{'func'}}($self->{'main'}, $self->{'refe'}, @args);
  } elsif($#{$operation->{'func'}} < 1) {
    Torture::Debug::message('operators/perform/function', "function no args". $#{$operation->{'func'}} ."\n");
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  } else {
    @args=(@{$operation->{'func'}}[1 .. $#{$operation->{'func'}}], @args);
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  }

    # Call result handler
  if(ref($operation->{'res'}) ne 'ARRAY') {
    $result=&{$operation->{'res'}}($self->{'main'}, $self->{'refe'}, $result, \@args);
  } elsif($#{$operation->{'res'}} < 1) {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result, \@args);
  } else {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result, \@args,
    				@{$operation->{'res'}}[1 .. $#{$operation->{'res'}}]);
  }

    # Finally, return back to caller
  return ($result ? ($error, $operation->{'aka'} . ' - ' . $result . "\n" . Dumper(@args))  : ($ok, 'no error found'));
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
  my $main=shift;
  my $refe=shift;
  my $action=shift;

  Check::Class('Torture::Server', $main);
  Check::Class('Torture::Server', $refe);
  Check::Value($action);

  my $result=$main->$action(@_);
  return $result;
}

sub ldap_code() {
  my $main=shift;
  my $refe=shift;
  my $result=shift;
  my $args=shift;
  my $action;
 
  Check::Class('Torture::Server', $main);
  Check::Class('Torture::Server', $refe);
  Check::Value($result);

  foreach my $err_expect (@_) {
    if($result->code == $err_expect) {
      if($result->code == 0) {
        $action=${$args}[0];
        $refe->$action(@{$args}[1 .. $#{$args}]);
      }

      return undef;
    }
  }

  return ($result->code ? $result->code . ' ' . $result->error : $result->code . ' Success');
}

1;
