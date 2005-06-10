#!/usr/bin/perl -w

package Torture::Tracker;
use strict;

use Torture::Utils;
use Check;

sub new(@) {
  my $name = shift;
  my $self = {};

  $self->{'rootdns'} = \@_ ;
  $self->{'nodes'} = {};
  $self->{'leaves'} = {};
  $self->{'branches'} = {};
  $self->{'deleted'} = {};

  bless($self, $name);
  return $self;
}

sub add() {
  my $self = shift;
  my $dn = shift;
  my @args = @_;

  Check::Value($dn);

  my $parent = Torture::Utils::dnParent($dn);

    # If this object was previously removed,
    # now it's there again...
  delete($self->{'deleted'}->{$dn});

    # Ok, remember the dn was inserted
  $self->{'nodes'}->{$dn}++;
  $self->{'leaves'}->{$dn}++;

    # Try to stay on the safe side avoid adding any
    # rootdn parent on the branches tree
  return if(!$parent || grep(/,$parent$/, @{$self->{'rootdns'}}));

    # Ok, remember parent now has one more children
  $self->{'nodes'}->{$parent}++;
  delete($self->{'leaves'}->{$parent});
  $self->{'branches'}->{$parent}++;

  return;
}

sub delete() {
  my $self = shift;
  my $dn = shift;

  Check::Value($dn);

    # return immediately if this node had
    # not been tracked 
  return if(!defined($self->{'nodes'}->{$dn}));

    # Start by deleting any reference to the
    # node, remembering it was deleted
  $self->{'deleted'}->{$dn}++;
  delete($self->{'nodes'}->{$dn});
  delete($self->{'leaves'}->{$dn});
  delete($self->{'branches'}->{$dn});

    # Look for parent node
  my $parent = Torture::Utils::dnParent($dn);
  return if(!$parent || !$self->{'nodes'}->{$parent});

    # Now, tell parent he has one less 
    # children
  $self->{'nodes'}->{$parent}--;

    # If it has no more children, it
    # now is a leaf
  if($self->{'nodes'}->{$parent} <= 1) {
    delete($self->{'branches'}->{$parent});
    $self->{'leaves'}->{$parent}++;
  }

  return;
}

sub move(@) {
  my $self = shift;
  my $old = shift;
  my $new = shift;

  Check::Value($old);
  Check::Value($new);
  
    # Ok, make sure $new is an absolute dn
  if(Torture::Utils::dnRelative($new)) {
      # in case it is not, it is relative to
      # the parent dn of the old dn
    $new=$new . ',' . Torture::Utils::dnParent($old);
  } 

    # Now, just update references, without
    # caring about reentrancy
  $self->Torture::Tracker::delete($old);
  $self->Torture::Tracker::add($new);

  return;
}

sub copy(@) {
  my $self = shift;
  my $old = shift;
  my $new = shift;

  Check::Value($old);
  Check::Value($new);
  
    # Ok, make sure $new is an absolute dn
  if(Torture::Utils::dnRelative($new)) {
      # in case it is not, it is relative to
      # the parent dn of the old dn
    $new=$new . ',' . Torture::Utils::dnParent($old);
  } 

    # Now, just update references, without
    # caring about reentrancy
  $self->Torture::Tracker::add($new);

  return;
}


1;
