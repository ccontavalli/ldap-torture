#!/usr/bin/perl -w
#

use Data::Dumper;
use strict;

print STDERR Dumper('base' => 'pippo', filter => 'pluto');
