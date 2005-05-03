#!/usr/bin/perl -w

use strict;
use Torture::Server::LDAP;
use Torture::Schema::LDAP;
use Torture::Random::Attributes;
use Data::Dumper;

my $server=Torture::Server::LDAP->new();
my $schema=Torture::Schema::LDAP->new($server->handle());
my $attrib=Torture::Random::Attributes->new();

print Dumper($schema->prepare($attrib->known()));

