#!/usr/bin/perl -w

use strict;
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


my %config = (
  'ldap_rootdn' => 'dc=test,dc=it',
  'ldap_server' => '127.0.0.1',
  'ldap_binddn' => '',
  'ldap_options' => '',
  'ldap_bindauth' => '',
  'perl_rootdn' => 'dc=test,dc=it',
  'gen_attempts' => 30,
  'op_verbose' => 0,
  'op_stats' => 1
  );

my %expand = (
	     );

my @args;

eval { @args=RBC::Parse::Cfg(\%expand, undef, 'config', 'torturer.conf', \%config); };
exit(&printhelp($@)) if($@);


  # Ok, connect to a real LDAP server...
my $server=Torture::Server::LDAP->new(\%config);
  # Load a schema, by connecting to the current LDAP Server...
my $schema=Torture::Schema::LDAP->new($server->handle()); 

  # Initialize a low level prng generator
my $random=Torture::Random::Primitive::rand->new($args[0]);  
  # Initialize an attribute generator
my $attrib=Torture::Random::Attributes->new($random);

  # Initialize another LDAP server .. in this case, use a 
  # reference perl ldap server
my $tnodes=Torture::Server::Perl->new(\%config);	

  # Initialize a random object generator... tnodes is used
  # to query the reference ldap server to ask for non-existant objects, ...
my $generator=Torture::Random::Generator->new(\%config, $schema, $random, $attrib, $tnodes);

my $operations=Torture::Operations->new(\%config, $random, $generator, $server, $tnodes);

my $killer=Torture::Killer->new($random, $operations);
$killer->start(undef, 10000);

if($config{'op_stats'}) {
  my $total;
  my %stats;

  %stats=$operations->stats();
  foreach (keys %stats) {
    print $_ . ': ' . $stats{$_} . "\n";
    $total+=$stats{$_};
  }

  print  $total . ' operations were performed.' . "\n";
}
