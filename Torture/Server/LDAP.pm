#!/usr/bin/perl -w
#

use Data::Dumper;

package Torture::Server::LDAP;

use Net::LDAP;
use Data::Dumper;
use Check;
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
  my ($rootdn, $server, $binddn, $options, $bindauth) = @_;

  my $connection;

    # Perform some checks 
  Check::Array($options) if($options);
  Check::Array($bindauth) if($bindauth);
 
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
  
  Check::Value($dn);
  Check::Enum(['base', 'one', 'sub'], $scope);

  return $self->{'ldap'}->search('base' => $dn, 'scope' => $scope, 'filter' => ($filter || '(objectclass=*)'));
}

sub delete(@) {
  my $self=shift;
  my $dn=shift;

  return $self->{'ldap'}->delete($dn);
}

sub add(@) {
  my $self=shift;
  my @args=@_;
  print Dumper(@args);
  foreach my $arg (@args) {
    print Dumper($arg)."\n";
  }
  return $self->{'ldap'}->add(@_);
}

sub copy() {
  my $self = shift;
  my $old = shift;
  my $new = shift;

  my $retval;

  Check::Value($new);
  Check::Value($old);

    # Ok, calculate all needed values
  my ($nchild, $nparent) = (Torture::Utils::dnChild($new), Torture::Utils::dnParent($new));
  my ($ochild, $oparent) = (Torture::Utils::dnChild($old), Torture::Utils::dnParent($old));

    # Now, if this is just a rename...
  if(!$nparent || $nparent eq $oparent) {
    return $self->{'ldap'}->moddn($old, 'newrdn' => $nchild, @_);
  }
    
    # Otherwise, tell LDAP we need to change the superior
  return $self->{'ldap'}->moddn($old, 'newrdn' => $new, 'newsuperior' => $nparent, @_); 
}

sub move() {
  my $self = shift;
  return $self->copy(@_, 'deleteoldrdn' => 1);
}

1;
