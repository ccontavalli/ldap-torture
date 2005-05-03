#!/usr/bin/perl -w

package Torture::Random::Attributes;

use strict;
use Net::LDAP;

use Torture::Debug;
use Check;

sub g_random_cn($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->text(2, 30);
}

sub g_random_phone($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return '+' . $self->{'random'}->number(100000, 999999) . $self->{'random'}->number(100000, 999999);
}

sub g_random_string($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->text(2, 127);
}

sub g_random_number($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->number(0, 4000000000);
}

sub g_random_password($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->text(2, 32);
}

sub g_random_boolean($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->number(0, 1) ? 'FALSE' : 'TRUE';
}

sub g_random_int($$) {
  my $self = shift;
  Check::Class('Torture::Random::Generator.*', $self->{'random'});
  return $self->{'random'}->number(0, 10000);
}

my %gname = (
  'commonname' => \&g_random_cn,
  'phonenumber' => \&g_random_phone,
  'string' => \&g_random_string,
  'sysuid' => \&g_random_number,
  'password' => \&g_random_password,
  'boolean' => \&g_random_boolean,
  'number' => \&g_random_int
);

my %generators = (
"1.3.6.1.1.1.0.0" => undef,
"1.3.6.1.1.1.0.1" => undef,
"1.3.6.1.4.1.1466.115.121.1.10" => undef,
"1.3.6.1.4.1.1466.115.121.1.12" => undef,
"1.3.6.1.4.1.1466.115.121.1.14" => undef,
"1.3.6.1.4.1.1466.115.121.1.15" => 'commonname',
"1.3.6.1.4.1.1466.115.121.1.22" => 'phonenumber',
"1.3.6.1.4.1.1466.115.121.1.23" => undef,
"1.3.6.1.4.1.1466.115.121.1.25" => undef,
"1.3.6.1.4.1.1466.115.121.1.26" => 'string',
"1.3.6.1.4.1.1466.115.121.1.27" => 'sysuid',
"1.3.6.1.4.1.1466.115.121.1.28" => undef, 
"1.3.6.1.4.1.1466.115.121.1.3" => undef,
"1.3.6.1.4.1.1466.115.121.1.30" => undef,
"1.3.6.1.4.1.1466.115.121.1.31" => undef,
"1.3.6.1.4.1.1466.115.121.1.34" => undef,
"1.3.6.1.4.1.1466.115.121.1.36" => 'number',
"1.3.6.1.4.1.1466.115.121.1.37" => undef, # was objectclass
"1.3.6.1.4.1.1466.115.121.1.38" => undef,
"1.3.6.1.4.1.1466.115.121.1.39" => undef,
"1.3.6.1.4.1.1466.115.121.1.4" => undef,
"1.3.6.1.4.1.1466.115.121.1.40" => 'password',
"1.3.6.1.4.1.1466.115.121.1.41" => undef,
"1.3.6.1.4.1.1466.115.121.1.43" => undef,
"1.3.6.1.4.1.1466.115.121.1.44" => undef,
"1.3.6.1.4.1.1466.115.121.1.49" => undef,
"1.3.6.1.4.1.1466.115.121.1.5" => undef,
"1.3.6.1.4.1.1466.115.121.1.50" => 'phonenumber',
"1.3.6.1.4.1.1466.115.121.1.51" => undef,
"1.3.6.1.4.1.1466.115.121.1.52" => undef,
"1.3.6.1.4.1.1466.115.121.1.7" => 'boolean',
"1.3.6.1.4.1.1466.115.121.1.8" => undef,
"1.3.6.1.4.1.1466.115.121.1.9" => undef,
);

sub new($) {
  my $name = shift;
  my $random = shift;

  my $self = {};

  if($random) {
    Check::Class('Torture::Random::Generator.*', $random);
    $self->{'random'} = $random;
  }

  while (my ($key, $value) = each(%generators)) {
    $self->{'attrib'}->{$key} = $value;
  }

  while (my ($key, $value) = each(%gname)) {
    $self->{'gname'}->{$key} = $value;
  }

  bless($self);
  return $self;
}

sub random() {
  my $self = shift;
  my $random = shift;

  Check::Class('Torture::Random::Generator.*', $random);
  $self->{'random'} = $random;
}

sub register() {
  my $self = shift;
  my $oid = shift;
  my $gname = shift;
  my $context = shift;
  my $func = shift;

  Check::Value($oid);
  Check::Value($gname);
  Check::Func($func);

  $self->{'attrib'}{$oid}=$gname;
  $self->{'context'}{$gname}=$context;
  $self->{'gname'}{$gname}=$func;
}

sub unregister() {
  my $self = shift;
  my $oid = shift;
  my $gname = shift;

  Check::Value($oid);
  Check::Value($gname);

  delete($self->{'attrib'}{$oid});
  delete($self->{'gname'}{$gname});
}

sub known() {
  my $self = shift;
  my $oid = shift;

  return $self->{'attrib'} if(!$oid);
  return 1 if($self->{'attrib'}{$oid});
  return 1 if($self->{'gname'}{$oid});
  return undef;
}

sub generate() {
  my $self = shift;
  my $oid = shift;
  my $context = $self;
  my $gname = $oid;

  Check::Value($oid);
  
  $gname=$self->{'attrib'}{$oid} 
  	if($self->{'attrib'}{$oid});

  $context=$self->{'context'}
  	if($self->{'context'}{$gname});

  return &{$self->{'gname'}{$gname}}($context, @_)
  		if($self->{'gname'}{$gname});

  Check::Die();
}

1;
