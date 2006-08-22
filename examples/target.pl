#!/usr/bin/perl -w
#

use strict;
use diagnostics;

use Torture::Config;
use Torture::Server;
use Torture::Random;
use Torture::Schema;

my $operator = Torture::Operations->new(Torture::Server, Torture::Random, Torture::Schema);

  # Load configuration
my $config=Torture::Config->new(@ARGV);

  # Connect to a real LDAP server
my $rserver=Torture::Server::LDAP->new();

  # Create a fake perl server
my $fserver=Torture::Server::Perl->new(Loader::LDAP->new($tserver));

  # Load schema data from LDAP server 
my $sdata=Torture::Schema::LDAP->new($rserver);

  # Ok, create torturer
my $torturer=Torture::Killer->new($rserver, $fserver, $sdata);

