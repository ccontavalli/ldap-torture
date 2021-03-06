#!/usr/bin/perl -w

use Data::Dumper;

use RBC::Check;
use strict;

package Torture::Operations;
my $dir = 'Torture/Operations';

our $ok = 0;
our $impossible = 1;
our $error = 2;

sub new {
  my $self = {};
  my $name = shift;
  my $config = shift;
  my $main = shift;
  my $refe = shift;

  my $random = shift;
  my $generator = shift;

  RBC::Check::Class('Torture::Random::Primitive.*', $random) if($random);
  RBC::Check::Class('Torture::Random::Generator.*', $generator) if($generator);
  RBC::Check::Hash($config);

  my $kind;

  $self->{'random'} = $random;
  $self->{'generator'} = $generator;

  $self->{'objects'} = [];

  $self->{'main'} = $main;
  $self->{'refe'} = $refe;
  $self->{'config'} = $config;
  $Data::Dumper::Indent=$config->{'op-dumpstyle'} || 0;
  $Data::Dumper::Purity=1;
  $Data::Dumper::Terse=1;

  bless($self);
  while(<$dir/*.pm>) {
    $self->load($_);
  }

  return $self;
}

sub o_prepare() {
  my $self = shift;
  my $context = shift;
  my $operation = shift;

  my (@args, $result);

  RBC::Check::Hash($operation);
  RBC::Check::Value($operation->{'aka'});
  RBC::Check::Value($operation->{'func'});
  RBC::Check::Array($operation->{'args'});

  RBC::Check::Class('Torture::Random::Primitive.*', $self->{'random'});
  RBC::Check::Class('Torture::Random::Generator.*', $self->{'generator'});

    # Ok, generate each and every of the required arguments 
  foreach my $arg (@{$operation->{'args'}}) {
    my @value=$self->{'generator'}->generate($self->{'random'}->context($context, $operation->{'aka'}, $arg), $arg, @args);
    Torture::Debug::message('operators/perform/args', "getting $arg -> " . ((@value && defined($value[0])) ? join(' ', @value) : '(undef)') . "\n");
    return undef if(!@value || !defined($value[0]));
    push(@args, @value);
  }

  if(ref($operation->{'func'}) eq 'ARRAY' && $#{$operation->{'func'}} >= 1) {
    @args=(@{$operation->{'func'}}[1 .. $#{$operation->{'func'}}], @args);
  }


  return @args;
}

sub o_perform() {
  my $self = shift;
  my $name = shift;
  my $context = shift;
  my $operation = shift;
  my @args = @_;

  my $result;

  RBC::Check::Hash($operation);
  RBC::Check::Value($operation->{'aka'});
  RBC::Check::Value($operation->{'func'});
  RBC::Check::Array($operation->{'args'});

    # Call function handler 
  Torture::Debug::message('operators/perform/function', 'function ' . $operation->{'aka'} . "\n");

#  print $operation->{'aka'} . ' - ' . "@args\n" if($self->{'config'}->{'op-verbose'});
#  print 'op' . sprintf('%06d', $self->{'stats'}) . '=' . Dumper([$operation->{'aka'}, @args]) . "\n" if($self->{'config'}->{'op-dump'});

  if(ref($operation->{'func'}) ne 'ARRAY') {
    $result=&{$operation->{'func'}}($self->{'main'}, $self->{'refe'}, @args);
  } elsif($#{$operation->{'func'}} < 1) {
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  } else {
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  }

  return $result;
}

sub o_verify() {
  my $self = shift;
  my $name = shift;
  my $operation = shift;

  my $result = shift;
  my @args = @_;

  RBC::Check::Hash($operation);
  RBC::Check::Value($operation->{'aka'});
  RBC::Check::Value($operation->{'func'});
  RBC::Check::Array($operation->{'args'});

    # Call result handler
  if(ref($operation->{'res'}) ne 'ARRAY') {
    $result=&{$operation->{'res'}}($self->{'main'}, $self->{'refe'}, $result, @args);
  } elsif($#{$operation->{'res'}} < 1) {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result, @args);
  } else {
    $result=&{$operation->{'res'}->[0]}($self->{'main'}, $self->{'refe'}, $result, @args,
    				@{$operation->{'res'}}[1 .. $#{$operation->{'res'}}]);
  }

    # Finally, return back to caller
  $operation->{'stats'}++;

  return $result;
}

sub index() {
  my $self = shift;
  my %retval;

  foreach my $operation (@{$self->{'generators'}}) {
    $retval{$operation->{'aka'}}=$operation;
  }

  return %retval;
}

sub perform() {
  my $self = shift;
  my $context = shift;
  my $operation = shift;

  my (@args, $result);

  RBC::Check::Hash($operation);
  RBC::Check::Value($operation->{'aka'});
  RBC::Check::Value($operation->{'func'});
  RBC::Check::Array($operation->{'args'});

  RBC::Check::Class('Torture::Random::Primitive.*', $self->{'random'});
  RBC::Check::Class('Torture::Random::Generator.*', $self->{'generator'});

    # Ok, generate each and every of the required arguments 
  foreach my $arg (@{$operation->{'args'}}) {
    my @value=$self->{'generator'}->generate($self->{'random'}->context($context, $operation->{'aka'}, $arg), $arg, @args);
    Torture::Debug::message('operators/perform/args', "getting $arg -> " . ((@value && defined($value[0])) ? join(' ', @value) : '(undef)') . "\n");
    return (wantarray ? ($impossible, "couldn't find any $arg") : $impossible) if(!@value || !defined($value[0]));

    push(@args, @value);
  }

    # Call function handler 
  Torture::Debug::message('operators/perform/function', 'function ' . $operation->{'aka'} . "\n");
  if(ref($operation->{'func'}) ne 'ARRAY') {
    print $operation->{'aka'} . ' - ' . "@args\n" if($self->{'config'}->{'op-verbose'});
    print 'op' . sprintf('%06d', $self->{'stats'}) . '=' . Dumper([$operation->{'aka'}, @args]) . "\n" if($self->{'config'}->{'op-dump'});
    $result=&{$operation->{'func'}}($self->{'main'}, $self->{'refe'}, @args);
  } elsif($#{$operation->{'func'}} < 1) {
    Torture::Debug::message('operators/perform/function', "function no args". $#{$operation->{'func'}} ."\n");
    print $operation->{'aka'} . ' - ' . "@args\n" if($self->{'config'}->{'op-verbose'});
    print 'op' . sprintf('%06d', $self->{'stats'}) . '=' . Dumper([$operation->{'aka'}, @args]) . "\n" if($self->{'config'}->{'op-dump'});
    $result=&{$operation->{'func'}->[0]}($self->{'main'}, $self->{'refe'}, @args);
  } else {
    @args=(@{$operation->{'func'}}[1 .. $#{$operation->{'func'}}], @args);
    print $operation->{'aka'} . ' - ' . "@args\n" if($self->{'config'}->{'op-verbose'});
    print 'op' . sprintf('%06d', $self->{'stats'}) . '=' . Dumper([$operation->{'aka'}, @args]) . "\n" if($self->{'config'}->{'op-dump'});
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
  $self->{'stats'}++;
  $operation->{'stats'}++;
  return ($result ? ($error, $operation->{'aka'} . ' - ' . $result . "\nfailed=" . Dumper(@args))  : ($ok, 'no error found'));
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

sub stats() {
  my $self = shift;
  my %retval;

  foreach my $operation (@{$self->{'generators'}}) {
    if($operation->{'stats'}) {
      $retval{$operation->{'aka'}}=$operation->{'stats'};
    }
  }

  return %retval;
}

sub action_server() {
  my $main=shift;
  my $refe=shift;
  my $action=shift;

  RBC::Check::Class('Torture::Server', $main);
  RBC::Check::Class('Torture::Server', $refe);
  RBC::Check::Value($action);

  my $result=$main->$action(@_);
  return $result;
}

sub ldap_code() {
  my $main=shift;
  my $refe=shift;
  my $result=shift;
  my $args=shift;
  my $action;
 
  RBC::Check::Class('Torture::Server', $main);
  RBC::Check::Class('Torture::Server', $refe);
  RBC::Check::Value($result);

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
