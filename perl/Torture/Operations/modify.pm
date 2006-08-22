#!/usr/bin/perl -w

use Data::Dumper;

use RBC::Check;
use strict;

package Torture::Operations::modify;

# missing:
#  modify/add/multi/one/ok
#  modify/add/multi/one/invalid
#  modify/add/multi/one/existing
#  modify/add/multi/more/invalid/all
#  modify/add/multi/more/invalid/one
#  modify/add/multi/more/existing
#  modify/add/multi/more/ok

#  modify/add/one/one/ok
#  modify/add/one/one/invalid
#  modify/add/one/one/existing
#  modify/add/one/more/invalid/all
#  modify/add/one/more/invalid/one
#  modify/add/one/more/existing
#  modify/add/one/more/ok

#  modify/add/invalid/one/ok
#  modify/add/invalid/more/ok
#  modify/add/nonexisting/one/ok
#  modify/add/nonexisting/more/ok

#  modify/delete/ok/attr/valid/missing
#  modify/delete/ok/attr/invalid/missing
#  modify/delete/ok/attr/nonmandatory
#  modify/delete/ok/attr/mandatory
#  modify/delete/invalid/attr
#  modify/delete/nonexisting/attr

#  modify/delete/ok/value/attrmissing
#  modify/delete/ok/value/valuemissing
#  modify/delete/ok/value/nonmandatory
#  modify/delete/ok/value/mandatory
#  modify/delete/invalid/value
#  modify/delete/nonexisting/value

#  modify/multiple/succed
#  modify/multiple/fail

my $operations = [ 
#  { aka => 'modify/delete/ok/attr/valid/missing',
#    name => 'remove a non-existing attribute from an object',
#    func => [ \&Torture::Operations::action_server, 'modify' ],
#    args => [ 'dn/inserted', 'dn/attribute/non-set' ],
#    res => [ \&Torture::Operations::ldap_code, 0 ]}, 
];

sub init() { return $operations; }

1;
