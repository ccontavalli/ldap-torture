#!/usr/bin/perl -w

use strict;
use Torture::Server::LDAP;
use Torture::Server::Perl;
use Torture::Schema::LDAP;
use Torture::Random::Attributes;
use Torture::Random::Generator;
use Torture::Random::Primitive::rand;

use Data::Dumper;

my $server=Torture::Server::LDAP->new();
my $schema=Torture::Schema::LDAP->new($server->handle()); # Contains known attributes and classes 
my $random=Torture::Random::Primitive::rand->new();	  # Contains random generator to be used
my $attrib=Torture::Random::Attributes->new($random);	  # Contains attributes we are able to generate and corresponding generators
my $tnodes=Torture::Server::Perl->new("dc=test,dc=it");	  # Caches data to be used by random generator 

my $generator=Torture::Random::Generator->new($schema, $random, $attrib, $tnodes);

print Dumper($generator->parent($random->context()));
print Dumper($generator->dn($random->context()));
print Dumper($generator->class($random->context()));
print Dumper($generator->object($random->context()));


