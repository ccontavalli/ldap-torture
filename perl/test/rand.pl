#!/usr/bin/perl -w 

use strict;
use Torture::Random::Primitive::rand;
use Data::Dumper;

my $seed = $ARGV[0] || "(none)";
print STDERR "ARGV: $seed\n";

my $random = Torture::Random::Primitive::rand->new($ARGV[0]);
my $context;

print 'random number (1, 100): ' . $random->number($random->context(), 1, 100) . "\n";
print 'random number (1, 10): ' . $random->number($random->context(), 1, 10) . "\n";
print 'random number (1, 10): ' . $random->number($random->context(), 1, 10) . "\n";
print 'random text (1, 30): ' . $random->text($random->context(), 1, 30) . "\n";
print 'random element(1, 30): ' . $random->element($random->context(), ['pippo', 'pluto', 'topolino']) . "\n";
print 'SEED: ' . $random->seed() . "\n";
