#!/usr/bin/perl -w
#

use Data::Dumper;

package Torture::Server::LDAP;

use Net::LDAP;
use Data::Dumper;
use RBC::Check;
use strict;

our (@ISA);
@ISA = ('Torture::Server');

=item new()

Creates a new Torture::Server object, connected to 
a real LDAP Server. Takes the following parameters:

=over 4

=item server

Either the name/ip address of the server, or undef (string).

=item binddn

If authentication has to be used, the dn to use to
bind to the server (string).

=item options

An array ref containing additional options to be 
passed as a second argument to Net::Ldap->new

=item bindauth

An array ref containing authentication options to
be passed to Net::Ldap->bind

=back

=cut

sub new() {
  my $self = {};
  my $name = shift;
  my $config = shift;

  RBC::Check::Hash($config);

  my ($rootdn, $server, $binddn) = 
	  ($config->{'ldap_rootdn'}, $config->{'ldap_server'}, $config->{'ldap_binddn'});

  my ($options, $bindauth);

  $options=[split(/\s+/, $config->{'ldap_options'})] if($config->{'ldap_options'});
  $bindauth=[split(/\s+/, $config->{'ldap_bindauth'})] if($config->{'ldap_bindauth'});
	  
  my $connection;
 
    # Provide default options
  $server = $server || 'localhost';
  $options = $options || [ 'version' => 3 ];

    # Create new LDAP object
  my $ldap = Net::LDAP->new($server, @{$options}) or 
	die "couldn't create object: $@";

    # Try to bind to the ldap server
  $connection=($binddn ? $ldap->bind : $ldap->bind($binddn, @{$bindauth}));
  die("couldn't bind: $@ -- " . $connection->error)
	  if(!$connection || $connection->code);

    # Ok, remember important objects
  $self->{'ldap'} = $ldap;
  $self->{'conn'} = $connection;

  bless($self);
  return $self;
}

sub handle() {
  my $self=shift;
  return $self->{'ldap'};
}

sub search(@) {
  my $self=shift;
  my $dn=shift;
  my $scope=shift;
  my $filter=shift;
  my @args=@{@_};
  
  RBC::Check::Value($dn);
  RBC::Check::Enum(['base', 'one', 'sub'], $scope);

  return $self->{'ldap'}->search('base' => $dn, 'scope' => $scope, 'filter' => ($filter || '(objectclass=*)'));
}

sub delete(@) {
  my $self=shift;
  my $dn=shift;

  Torture::Debug::message('LDAP/delete', 'delete ' . $dn . "\n");
  return $self->{'ldap'}->delete($dn);
}

sub add(@) {
  my $self=shift;
  my $object=shift;
  my @args=@_;

  Torture::Debug::message('LDAP/add', 'add ' . Dumper($object, @args));
  RBC::Check::Array($object);

  return $self->{'ldap'}->add(@{$object}, @args);
}

sub copy() {
  my $self = shift;
  my $old = shift;
  my $new = shift;

  my $retval;

  RBC::Check::Value($new);
  RBC::Check::Value($old);

    # Ok, calculate all needed values
  my ($nchild, $nparent) = (Torture::Utils::dnChild($new), Torture::Utils::dnParent($new));
  my ($ochild, $oparent) = (Torture::Utils::dnChild($old), Torture::Utils::dnParent($old));

    # Now, if this is just a rename...
  if(!$nparent || $nparent eq $oparent) {
    print "rename! $old, $nchild\n";
    Torture::Debug::message('LDAP/rename', 'rename ' . $old . ' ' . $nchild);
    return $self->{'ldap'}->moddn($old, 'newrdn' => $nchild, @_);
  }
    
    # Otherwise, tell LDAP we need to change the superior
  Torture::Debug::message('LDAP/move', 'move ' . $old . ' ' . $nchild . ',' . $nparent);
  return $self->{'ldap'}->moddn($old, 'newrdn' => $nchild, 'newsuperior' => $nparent, @_); 
}

sub move() {
  my $self = shift;

  return $self->copy(@_, 'deleteoldrdn' => 1);
}

1;
