#!/usr/bin/perl -w 

use strict;
use Torture::Random::Primitive::rand;
use Data::Dumper;

print STDERR "ARGV: $ARGV[0]\n";
my $random = Torture::Random::Primitive::rand->new($ARGV[0]);

print 'random number (1, 100): ' . $random->number(1, 100) . "\n";
print 'random number (1, 10): ' . $random->number(1, 10) . "\n";
print 'random number (1, 10): ' . $random->number(1, 10) . "\n";
print 'random text (1, 30): ' . $random->text(1, 30) . "\n";
print 'SEED: ' . $random->seed() . "\n";
