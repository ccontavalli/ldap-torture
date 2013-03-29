#!/usr/bin/perl -w

use Data::Dumper;

use RBC::Check;
use strict;

package Torture::Operations::insert;

# missing:
#   insert/invalid

my $operations = [ 
  { aka => 'insert/new',
    name => 'insert a randomly generated entry into the database',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/new' ],
    res => [ \&Torture::Operations::ldap_code, 0 ]}, 

  { aka => 'insert/deleted',
    name => 'insert a randomly generated entry into the database',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/deleted' ],
    res => [ \&Torture::Operations::ldap_code, 0 ]}, 

  { aka => 'insert/existing',
    name => 'insert a dn which already exists, with the same object',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/existing' ],
    res => [ \&Torture::Operations::ldap_code, 68 ]},

  { aka => 'insert/noparent',
    name => 'insert an object whose parent dn does not exist',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/noparent' ],
    res => [ \&Torture::Operations::ldap_code, 32 ]}
];

sub init() { return $operations; }

1;
