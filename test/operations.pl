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

  # Generic class that allows interfacing with a real LDAP server
my $server=Torture::Server::LDAP->new();
  # Generic class that provides a schema to be used to generate objects
my $schema=Torture::Schema::LDAP->new($server->handle()); # Contains known attributes and classes 
  # A generic rng -- generates mainly numbers, text and chooses among random elements
my $random=Torture::Random::Primitive::rand->new();	  # Contains random generator to be used
  # Class that holds all known attributes and generators for single attributes
my $attrib=Torture::Random::Attributes->new($random);	  # Contains attributes we are able to generate and corresponding generators
  # Generic class that represents an LDAP server implemented with
  # perl fucntion. This class hinerits from Torture::Tracker, which
  # means it is able to track data and to provide objects for the
  # complex generator
my $tnodes=Torture::Server::Perl->new("dc=test,dc=it");	  # Reference server to be used, with tracking abilities

  # The real LDAP generator. It generates complex object
  # classes and data types.
  #
  # A random LDAP generator needs to know 
  #   1 - the schema
  #   2 - which generic random generator to use
  #   3 - how to generate the various attributes
  #   4 - which objects have already been inserted, which have not and so on...
my $generator=Torture::Random::Generator->new($schema, $random, $attrib, $tnodes);
my $operations=Torture::Operations->new($random, $generator, $server, $tnodes);

my $killer=Torture::Killer->new($random, $operations);

$killer->start(undef, 10)
