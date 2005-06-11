#!/usr/bin/perl -w

use Data::Dumper;

use Check;
use strict;

package Torture::Operations::insert;

my $operations = [ 
  { aka => 'insert/new',
    name => 'insert a randomly generated entry into the database',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/ok' ],
    res => [ \&Torture::Operations::ldap_succeed ]}, 

  { aka => 'insert/existing',
    name => 'insert a dn which already exists, with a different object',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/existing' ],
    res => [ \&Torture::Operations::ldap_fail, '68' ]},

  { aka => 'insert/noparent',
    name => 'insert an object whose parent dn does not exist',
    func => [ \&Torture::Operations::action_server, 'add' ],
    args => [ 'object/noparent' ],
    res => [ \&Torture::Operations::ldap_fail, '32' ]}
];

sub init() { return $operations; }

1;
