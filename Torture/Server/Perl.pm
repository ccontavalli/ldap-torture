#!/usr/bin/perl -w

package Torture::Server::Perl;

use Net::LDAP;
use Check;
use strict;

sub new() { 
  my $self={};
  bless($self);

  return;
}

sub search() {
  Check::value(undef);
}

sub delete(@) {
  my $self=shift;
  my $dn=shift;
  my $children;

  delete($self->{'added'}->{$dn});
  delete($self->{'leaves'}->{$dn});
  delete($self->{'brenches'}->{$dn});

    # Ok, remove children from parent
  if($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}) {
    $self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}=
     	[grep(!/$dn/, @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}})];

    if(!@{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) {
      delete($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}});
      
      $self->{'leaves'}->{$self->{'child2parent'}->{$dn}} = 
      	$self->{'brenches'}->{$self->{'child2parent'}->{$dn}};

      $self->{'brenches'}->{$self->{'child2parent'}->{$dn}}=undef;
      delete($self->{'brenches'}->{$self->{'child2parent'}->{$dn}});
    }
  }

  delete($self->{'child2parent'}->{$dn});

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
  my $parent=shift;
  my $dn=shift;
  my @args = @_;
  my $retval;

  $self->{'added'}->{$dn} = \@args;
  $self->{'leaves'}->{$dn} = \@args;
  if($parent) {
    push(@{$self->{'parent2child'}->{$parent}}, $dn);
    $self->{'child2parent'}->{$dn}=$parent;
  }

  if($self->{'leaves'}->{$parent}) {
    $self->{'brenches'}->{$parent}=$self->{'leaves'}->{$parent};
    $self->{'leaves'}->{$parent}=undef;
    delete($self->{'leaves'}->{$parent});
  }

  return $retval;
}

sub move(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;
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
    print STDERR "$child -> $child_new\n";

    $self->{'added'}->{$child_new}=$self->{'added'}->{$child};
    delete($self->{'added'}->{$child});

    $self->{'child2parent'}->{$child_new}=$parent_new;
    delete($self->{'child2parent'}->{$child});

    if(!defined(@{$self->{'parent2child'}->{$child}}) || !@{$self->{'parent2child'}->{$child}}) {
      $self->{'leaves'}->{$child_new} = $self->{'leaves'}->{$child};
      $self->{'leaves'}->{$child}=undef;
      delete($self->{'leaves'}->{$child});
      next;
    }

    $self->{'parent2child'}->{$child_new}=() if(!defined($self->{'parent2child'}->{$child_new}));
    foreach my $p2c (@{$self->{'parent2child'}->{$child}}) {
      push(@array, $p2c);
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c=~/(.*)$old$/)[0] . $new);
    }
    delete($self->{'parent2child'}->{$child});

    $self->{'brenches'}->{$child_new} = $self->{'brenches'}->{$child};
    $self->{'brenches'}->{$child}=undef;
    delete($self->{'brenches'}->{$child});
  }

    # Ok, remove old dn from parent
  if(@{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^$old$/, @{$self->{'parent2child'}->{$parent_old}})];
    if(!@{$self->{'parent2child'}->{$parent_old}}) {
      $self->{'leaves'}->{$parent_old}=$self->{'brenches'}->{$parent_old};
      $self->{'brenches'}->{$parent_old}=undef;
      delete($self->{'brenches'}->{$parent_old});

      delete($self->{'parent2child'}->{$parent_old});
    }
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  if($self->{'leaves'}->{$parent_new}) {
    $self->{'brenches'}->{$parent_new}=$self->{'leaves'}->{$parent_new};
    $self->{'leaves'}->{$parent_new}=undef;
    delete($self->{'leaves'}->{$parent_new});
  }

  return;
}

1;
