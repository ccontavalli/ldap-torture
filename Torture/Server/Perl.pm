#!/usr/bin/perl -w

package Torture::Server::Perl;

use Check;
use strict;

use Torture::Utils;
use Torture::Server;
use Torture::Tracker;

our (@ISA);
@ISA = ('Torture::Server', 'Torture::Tracker');

sub new() { 
  my $class=shift;
  my $self=$class->SUPER::new(@_);

  $self->{'parent2child'} = {};
  $self->{'childdata'} = {};
  $self->{'rootdns'} = ();

  foreach my $rootdn (@_) {
    push(@{$self->{'rootdns'}}, $rootdn);
    $self->{'parent2child'}->{$rootdn}=();
    $self->{'childdata'}->{$rootdn}=[];

    $self->SUPER::add($rootdn);
  }

  bless($self, $class);
  return $self;
}

sub handle() {
  return undef;
}

sub search() {
  Check::value(undef);
}

sub get() {
  my $self=shift;
  my $dn=shift;

  return $self->{'childdata'}->{$dn};
}

sub delete(@) {
  my $self=shift;
  my $children;

  my $dn=shift;
  my $parent;

  Check::Value($dn);

    # Ok, give a chance to tracker to 
    # update its own references
  $self->SUPER::delete($dn);

    # Ok, calculate parent of current node
  $parent=Torture::Utils::dnParent($dn);
  Check::Value($parent);

    # Remove reference to children from parent
  if($self->{'parent2child'}->{$parent}) {
    $self->{'parent2child'}->{$parent}=
     	[grep(!/$dn/, @{$self->{'parent2child'}->{$parent}})];

      # If parent has no more children, remove 
      # parent from parent2child hash
    delete($self->{'parent2child'}->{$parent})
      if(!@{$self->{'parent2child'}->{$parent}});
  }
  delete($self->{'childdata'}->{$dn});

    # Now, get the children of this node 
  $children=$self->{'parent2child'}->{$dn};

    # This operation should not be necessary
  delete($self->{'parent2child'}->{$dn}); 

    # Remove each children of the current node
  if($children) {
    foreach my $child (@{$children}) {
      $self->delete($child);
    }
  }

  return;
}

sub add(@) {
  my $self=shift;
  my $dn=shift;
  my @args = @_;

  Check::Value($dn);

    # Get name of current parent
  my $parent = Torture::Utils::dnParent($dn);
  Check::Value($dn);

    # Ok, give a chance to tracker to 
    # update its own references
  $self->SUPER::add($dn, @_);

    # Now, add node...
  push(@{$self->{'parent2child'}->{$parent}}, $dn);
  $self->{'childdata'}->{$dn}=\@args;
  $self->{'parent2child'}->{$dn}=();

  return;
}

sub copy(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;

  Check::Value($old);
  Check::Value($new);

  my $parent_old;
  my $parent_new;

    # Ok, if new name is relative,
    # make it absolute
  $parent_old=Torture::Utils::dnParent($old);
  if(Torture::Utils::dnRelative($new)) {
    $parent_new=Torture::Utils::dnParent($old);
    $new=$new . ',' . $parent_new;
  } else {
    $parent_new=Torture::Utils::dnParent($new);
  }

    # Ok, now we should have all needed data
  Check::Value($parent_new);
  Check::Value($parent_old);

    # Now, walk this node and each of its own
    # children
  my @array = ($old);
  while(my $child = shift(@array)) {
      # Calculate new name of children
    my $child_new=($child =~ /(.*)$old$/)[0] . $new;
    
      # Give tracker a chance to update its own 
      # references
    $self->SUPER::copy($child, $child_new);

      # Ok, data of children must now be indexed under new name
    $self->{'childdata'}->{$child_new}=$self->{'childdata'}->{$child};

      # If the children we are renaming is a leaf (eg, has no children), we are done
    if(!defined($self->{'parent2child'}->{$child}) || !@{$self->{'parent2child'}->{$child}}) {
      $self->{'parent2child'}->{$child_new}=[];
      next;
    }

      # Otherwise, just walk each children, and...
    $self->{'parent2child'}->{$child_new}=() if(!defined($self->{'parent2child'}->{$child_new}));
    foreach my $p2c (@{$self->{'parent2child'}->{$child}}) {
        # ... remember we have to update it
      push(@array, $p2c);
        # ... update the relations...
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c =~ /(.*)$old$/)[0] . $new);
    }
  }

    # Ok, remove old dn from parent
  if(defined($self->{'parent2child'}->{$parent_old}) && @{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^$old$/, @{$self->{'parent2child'}->{$parent_old}})];
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  return;
}

sub move(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;

  Check::Value($old);
  Check::Value($new);

  my $parent_old;
  my $parent_new;

    # Ok, if new name is relative,
    # make it absolute
  $parent_old=Torture::Utils::dnParent($old);
  if(Torture::Utils::dnRelative($new)) {
    $parent_new=Torture::Utils::dnParent($old);
    $new=$new . ',' . $parent_new;
  } else {
    $parent_new=Torture::Utils::dnParent($new);
  }

    # Ok, now we should have all needed data
  Check::Value($parent_new);
  Check::Value($parent_old);

    # Now, walk this node and each of its own
    # children
  my @array = ($old);
  while(my $child = shift(@array)) {
      # Calculate new name of children
    my $child_new=($child =~ /(.*)$old$/)[0] . $new;
    
      # Give tracker a chance to update its own 
      # references
    $self->SUPER::move($child, $child_new);

      # Ok, data of children must now be indexed under new name
    $self->{'childdata'}->{$child_new}=$self->{'childdata'}->{$child};
    delete($self->{'childdata'}->{$child});

      # If the children we are renaming is a leaf (eg, has no children), we are done
    if(!defined($self->{'parent2child'}->{$child}) || !@{$self->{'parent2child'}->{$child}}) {
      delete($self->{'parent2child'}->{$child});
      $self->{'parent2child'}->{$child_new}=[];

      next;
    }

      # Otherwise, just walk each children, and...
    $self->{'parent2child'}->{$child_new}=() if(!defined($self->{'parent2child'}->{$child_new}));
    foreach my $p2c (@{$self->{'parent2child'}->{$child}}) {
        # ... remember we have to update it
      push(@array, $p2c);
        # ... update the relations...
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c =~ /(.*)$old$/)[0] . $new);
    }
      # The old node has no more children now :)
    delete($self->{'parent2child'}->{$child});
  }

    # Ok, remove old dn from parent
  if(defined($self->{'parent2child'}->{$parent_old}) && @{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^$old$/, @{$self->{'parent2child'}->{$parent_old}})];

    delete($self->{'parent2child'}->{$parent_old})
      if(!@{$self->{'parent2child'}->{$parent_old}});
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  return;
}

1;
