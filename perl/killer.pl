#!/usr/bin/perl -w

use strict;
use Carp;

use Torture::Server::LDAP;
use Torture::Server::Perl;
use Torture::Schema::LDAP;
use Torture::Random::Attributes;
use Torture::Random::Generator;
use Torture::Random::Primitive::rand;
use Torture::Operations;
use Torture::Killer;

use Data::Dumper;
use RBC::Parse;
use Pod::Usage;

=pod

=head1 NAME

killer.pl - LDAP server killer, stresser and squeezer

=head1 SYNOPSIS

killer.pl [OPTIONS] COMMAND ...

 Commands:
   test-random
     Options:
       --attempts -a
       --stats -t
       --dump -d
       --dumpstyle -S

   test-play

   dump-schema [OPTIONS] [FILE]
     Options:
       --mangle -m
       --style -s 
       --parsed -p

   dump-config

 Options:
   --ldap-rootdn -b
   --ldap-server -s
   --ldap-binddn -D
   --ldap-options -o
   --ldap-bindauth -u
   --config -c

=head1 OPTIONS

=cut

package Client;

sub new() {
  my $class = shift;
  my $config = shift;
  my $self = {};

  RBC::Check::Hash($config);

  # Ok, connect to a real LDAP server...
  $self->{'config'}=$config;
  $self->{'server'}=Torture::Server::LDAP->new($config);
  $self->{'schema'}=Torture::Schema::LDAP->new($self->{'server'}->handle()); 

  bless($self, $class);
  return $self;
}

sub cmd_test_random() {
  my $self=shift;
  my @known = (
   'attempts|a=i',
   'seed|s',
   'stats|t!',
   'dump|d!',
   'dumpstyle|S=i');
  my %config;

  eval { RBC::Parse::NewCmdLine(\%config, \@known, @_); };
  exit(&Pod::Usage::pod2usage($@)) if($@);

  my $random=Torture::Random::Primitive::rand->new($config{'seed'});  
  my $attrib=Torture::Random::Attributes->new($random);
  my $tnodes=Torture::Server::Perl->new($self->{'config'});	

  my $generator=Torture::Random::Generator->new($self->{'config'}, $self->{'schema'}, $random, $attrib, $tnodes);
  my $operations=Torture::Operations->new($self->{'config'}, $random, $generator, $self->{'server'}, $tnodes);

#my $killer=Torture::Killer->new($random, $operations);
#$killer->start(undef, 10000);
}

sub cmd_test_play() {
  my $self = shift;
}

sub cmd_dump_schema() {
  my $self = shift;

  my %config = ( 'mangle' => '1' );
  my @known = (
   'style|s=i',
   'parsed|p!',
   'mangle|m!');

  my @args;
  eval { @args=RBC::Parse::NewCmdLine(\%config, \@known, \@_); };
  exit(&Pod::Usage::pod2usage($@)) if($@);

    # Ok, set output style...
  if(defined($config{'style'})) {
    $Data::Dumper::Indent=$config{'style'};
  } elsif($args[0]) {
    $Data::Dumper::Indent=0;
  }

    # If output has to be parsed, parse it...
  if($config{'parsed'}) {
    my $attrib=Torture::Random::Attributes->new();
    $self->{'schema'}->prepare($attrib->known());
  }

    # Dump data out...
  $Data::Dumper::Varname='schema';
  if(!$args[0]) {
    my $output=&Data::Dumper::Dumper($self->{'schema'});
    $output =~ s/(\t|      )/ /gm if($config{'mangle'});
    print $output;
    return 0;
  }

  $Data::Dumper::Varname='schema';
  open(my $fd, '>', $args[0]) or die("unable to open $args[0] -- $!\n");
  print $fd '' . &Data::Dumper::Dumper($self->{'schema'});

  return 0;
}

sub cmd_dump_config() {
  my $self = shift;

  foreach my $key (keys(%{$self->{'config'}})) {
    print $key . '=' . $self->{'config'}->{$key} . "\n";
  }

  return 0;
}

my @known = (
  'ldap-rootdn|b=s',
  'ldap-server|s=s',
  'ldap-binddn|D=s',
  'ldap-options|o=s',
  'ldap-bindauth|u=s',
  'gen-attempts|a=i',
  'op-dump|d!',
  'op-stats|t!',
  'op-dumpstyle|S=i',
  'config|c=s');

my %config = (
  'ldap-rootdn' => 'dc=test,dc=it',
  'ldap-server' => '127.0.0.1',
  'ldap-binddn' => '',
  'ldap-options' => '',
  'ldap-bindauth' => '',
  'perl-rootdn' => 'dc=test,dc=it',
  'gen-attempts' => 30,
  'op-verbose' => 0,
  'op-dump' => 1,
  'op-stats' => 1,
  'op-dumpstyle' => 0,
  'config' => 'torturer.conf'
  );

my @args;
eval { @args=RBC::Parse::NewCfg(\@known, \%config, 'config', 'torturer.conf', \%config); };
exit(&Pod::Usage::pod2usage($@)) if($@);
my $command = shift(@args);

my %commands = (
  'test-random' => \&Client::cmd_test_random,
#  'test-play' => \&Client::cmd_test_play,
  'dump-schema' => \&Client::cmd_dump_schema,
  'dump-config' => \&Client::cmd_dump_config,
);

sub int() {
  Carp::confess("interrupt received");
}
$SIG{INT}=\&int;

exit(&Pod::Usage::pod2usage("no command provided!")) if(!$command);
exit(&Pod::Usage::pod2usage("unknown command: $command")) if(!$commands{$command});

my $client=Client->new(\%config);
my $status=&{$commands{$command}}($client, @args);

#if($config{'op-stats'}) {
#  my $total;
#  my %stats=$operations->stats();
#  foreach (keys %stats) {
#    print STDERR $_ . ': ' . $stats{$_} . "\n";
#    $total+=$stats{$_};
#  }
#
#  print  $total . ' operations were performed.' . "\n";
#}

exit($status);
