#!/usr/bin/perl -w

package Torture::Server::Perl;

use Check;
use strict;

our (@ISA);
@ISA = ('Torture::Server', 'Torture::Tracker');

sub new() { 
  my $class=shift;
  my $self=$class->SUPER::new(@_);

  $self->{'child2parent'} = {};
  $self->{'parent2child'} = {};
  $self->{'childdata'} = {};
  $self->{'rootdns'} = ();

  foreach my $rootdn (@_) {
    push(@{$self->{'rootdns'}}, $rootdn);
    $self->{'child2parent'}->{$rootdn}='';
    $self->{'parent2child'}->{$rootdn}=();
    $self->{'childdata'}->{$rootdn}=[];
  }

  bless($self, $class);
  return;
}

sub handle() {
  return undef;
}

sub search() {
  Check::value(undef);
}

sub delete(@) {
  my $self=shift;
  my $dn=shift;
  my $children;

  Check::Value($dn);

    # Ok, tell tracker to forget about this 
    # node as well 
  $self->SUPER::delete($dn);

    # Ok, unlink dn from parent
  if($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}) {
    $self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}=
     	[grep(!/$dn/, @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}})];

    delete($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}});
      if(!@{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}});
  }
  delete($self->{'child2parent'}->{$dn});
  delete($self->{'childdata'}->{$dn});

  $children=$self->{'parent2child'}->{$dn};
  delete($self->{'parent2child'}->{$dn});
  if($children) {
    foreach my $child (@{$children}) {
      $self->delete($child);
    }
  }

  return;
}

sub handle() {
  return undef;
}

sub add(@) {
  my $self=shift;
  my $dn=shift;
  my @args = @_;
  my $retval;

  Check::Value($dn);

  my $parent = ($dn =~ /^([^,]*)/)[0];
  return undef
    if(!$parent || !defined($self->{'parent2child'}->{$parent}));

  $self->SUPER::add($dn, @_);
  push(@{$self->{'parent2child'}->{$parent}}, $dn);
  $self->{'child2parent'}->{$dn}=$parent;
  $self->{'childdata'}->{$dn}=\@args;
  $self->{'parent2child'}->{$dn}=();

  return $retval;
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
  $parent_old=($old =~ /,(.*)$/)[0];
  if($new !~ /,/) {
    $parent_new=$parent_old;
    $new=$new . ',' . $parent_new;
  } else {
    $parent_new=($new =~ /,(.*)$/)[0];
  }

  my @array = ($old);

  while(my $child = shift(@array)) {
    my $child_new=($child eq $old ? "" : ($child=~/(.*)$old$/)[0]) .$new;
    
      # Ok, data of children must be now indexed under new node
    $self->{'childdata'}->{$child_new}=$self->{'childdata'}->{$child};
    delete($self->{'childdata'}->{$child});

      # Link new children with parent, and unlink old children from old parent
    $self->{'child2parent'}->{$child_new}=$parent_new;
    delete($self->{'child2parent'}->{$child});

      # If the children we are renaming is a leaf (eg, has no children), we are done
    next if(!defined(@{$self->{'parent2child'}->{$child}}) || !@{$self->{'parent2child'}->{$child}});

      # Otherwise, just walk each children, and...
    $self->{'parent2child'}->{$child_new}=() if(!defined($self->{'parent2child'}->{$child_new}));
    foreach my $p2c (@{$self->{'parent2child'}->{$child}}) {
        # ... remember we have to update it
      push(@array, $p2c);
        # ... update the relations...
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c=~/(.*)$old$/)[0] . $new);
    }
      # The old node has no more children now :)
    delete($self->{'parent2child'}->{$child});
  }

    # Ok, remove old dn from parent
  if(@{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^$old$/, @{$self->{'parent2child'}->{$parent_old}})];

    delete($self->{'parent2child'}->{$parent_old})
      if(!@{$self->{'parent2child'}->{$parent_old}});
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  return;
}

1;
