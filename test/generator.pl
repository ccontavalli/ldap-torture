#!/usr/bin/perl -w

use strict;
use Torture::Server::LDAP;
use Torture::Schema::LDAP;
use Torture::Random::Attributes;
use Torture::Random::Generator;
use Torture::Random::Primitive::rand;
use Torture::Random::Nodes;

use Data::Dumper;

my $server=Torture::Server::LDAP->new();
my $schema=Torture::Schema::LDAP->new($server->handle()); # Contains known attributes and classes 
my $attrib=Torture::Random::Attributes->new();		  # Contains attributes we are able to generate and corresponding generators
my $random=Torture::Random::Primitive::rand->new();	  # Contains random generator to be used
my $tnodes=Torture::Random::Nodes->new($server);	  # Caches data to be used by random generator 

my $generator=Torture::Random::Generator->new($schema, $random, $attrib, $tnodes);

