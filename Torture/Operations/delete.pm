#!/usr/bin/perl -w

use Data::Dumper;

use Check;
use strict;

package Torture::Operations::delete;

my $operations = [
  { aka => 'delete/leaf',
    name => 'delete a leaf from the ldap tree',
    func => [ \&Torture::Operations::action_server, 'delete'],
    args => [ 'dn/inserted/leaf' ],
    res => [ \&Torture::Operations::ldap_code, 0]},

  { aka => 'delete/rootdn',
    name => 'try to delete the rootdn of the tree',
    func => [ \&Torture::Operations::action_server, 'delete'],
    args => [ 'dn/rootdn' ],
    res => [ \&Torture::Operations::ldap_code, 50 ]},

#  { aka => 'delete/brench',
#    name => 'delete a brench from the ldap tree',
#    func => [ \&Torture::Operations::action_server, 'delete'],
#    args => [ 'dn/inserted/brench' ],
#    res => [ \&Torture::Operations::ldap_succeed, 'hdb' ]},

  { aka => 'delete/invented',
    name => 'delete something invented, which does not' .
            ' exist in the tree and has never been removed',
    func => [ \&Torture::Operations::action_server, 'delete'],
    args => [ 'dn/invented' ],
    res => [ \&Torture::Operations::ldap_code, 32 ]},

  { aka => 'delete/deleted',
    name => 'delete something which has already been deleted',
    func => [ \&Torture::Operations::action_server, 'delete'],
    args => [ 'dn/deleted' ],
    res => [ \&Torture::Operations::ldap_code, 32 ]}
];

sub init() { return $operations; }

1;
