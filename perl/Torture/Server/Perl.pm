#!/usr/bin/perl -w

package Torture::Server::Perl;

use RBC::Check;
use strict;

use Torture::Utils;
use Torture::Server;
use Torture::Tracker;

use Data::Dumper;

our (@ISA);
@ISA = ('Torture::Server', 'Torture::Tracker');

sub new() { 
  my $class=shift;
  my $config=shift;

  my $self=$class->SUPER::new(@_);

  RBC::Check::Hash($config);
  RBC::Check::Value($config->{'perl-rootdn'});

  $self->{'parent2child'} = {};
  $self->{'childdata'} = {};
  $self->{'rootdns'} = ();

  foreach my $rootdn (split(/\s+/, $config->{'perl-rootdn'})) {
    push(@{$self->{'rootdns'}}, $rootdn);
    $self->{'parent2child'}->{$rootdn}=();
    $self->{'childdata'}->{$rootdn}=[];

    $self->SUPER::add([$rootdn]);
  }

  bless($self, $class);
  return $self;
}

sub handle() {
  return undef;
}

sub search() {
  RBC::Check::value(undef);
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

  RBC::Check::Value($dn);

    # Ok, calculate parent of current node
  $parent=Torture::Utils::dnParent($dn);
  RBC::Check::Value($parent);

    # Remove reference to children from parent
  if($self->{'parent2child'}->{$parent}) {
    $self->{'parent2child'}->{$parent}=
     	[grep(!/\Q$dn\E/, @{$self->{'parent2child'}->{$parent}})];

      # If parent has no more children, remove 
      # parent from parent2child hash
    delete($self->{'parent2child'}->{$parent})
      if(!@{$self->{'parent2child'}->{$parent}});
  }

    # Ok, give a chance to tracker to 
    # update its own references
  $self->SUPER::delete($dn, $self->{'childdata'}->{$dn},
	$self->{'childdata'}->{$dn});
  delete($self->{'childdata'}->{$dn});
#  print 'deleting ' . $dn . "\n"; 

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
  my $array=shift;

#  print Data::Dumper::Dumper($array) . "\n";

  RBC::Check::Array($array);

  my $dn=${$array}[0];
  my @args = @{$array}[1 .. $#{$array}];

  RBC::Check::Value($dn);

    # Get name of current parent
  my $parent = Torture::Utils::dnParent($dn);
  RBC::Check::Value($parent);

    # Ok, give a chance to tracker to 
    # update its own references
  $self->SUPER::add($array);

    # Now, add node...
  push(@{$self->{'parent2child'}->{$parent}}, $dn);

#  print 'adding ' . $dn . "\n";
  $self->{'childdata'}->{$dn}=\@args;
  $self->{'parent2child'}->{$dn}=();

  return;
}

sub copy(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;

  RBC::Check::Value($old);
  RBC::Check::Value($new);

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
  RBC::Check::Value($parent_new);
  RBC::Check::Value($parent_old);

    # Now, walk this node and each of its own
    # children
  my @array = ($old);
  while(my $child = shift(@array)) {
      # Calculate new name of children
    my $child_new=($child =~ /(.*)\Q$old\E$/)[0] . $new;
    
      # Give tracker a chance to update its own 
      # references
    $self->SUPER::copy($child, $child_new, $self->{'childdata'}->{$child});

      # Ok, data of children must now be indexed under new name
#    $self->{'childdata'}->{$child_new}=$self->{'childdata'}->{$child};
    $self->{'childdata'}->{$child_new}=$self->replaceattr($child, $child_new, $self->{'childdata'}->{$child});
    delete($self->{'childdata'}->{$child}) if($child ne $child_new);

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
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c =~ /(.*)\Q$old\E$/)[0] . $new);
    }
  }

    # Ok, remove old dn from parent
  if(defined($self->{'parent2child'}->{$parent_old}) && @{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^\Q$old\E$/, @{$self->{'parent2child'}->{$parent_old}})];
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  return;
}

sub replaceattr($$$) {
  my $self = shift;
  my $old = shift;
  my $new = shift;
  my $data = shift;
  
  if(!$data) {
    print STDERR 'replacing: ' . $old . ' with ' . $new . "\n";
    print STDERR Data::Dumper::Dumper($self->{'childdata'});
  }

  RBC::Check::Value($old);
  RBC::Check::Value($new);
  RBC::Check::Array($data);

  $old=Torture::Utils::dnChild($old);
  $new=Torture::Utils::dnChild($new);
  return $data if($old eq $new);

  my $oattr=Torture::Utils::dnAttrib($old);
  my $ovalue=Torture::Utils::dnValue($old);

  my $nattr=Torture::Utils::dnAttrib($new);
  my $nvalue=Torture::Utils::dnValue($new); 

  my @result;
  my @array=@{${$data}[1]};
  while(my $uattr=shift(@array)) {
    my $uvalue=shift(@array);
    if($uattr eq $nattr && $uvalue eq Torture::Utils::attribUnescape($ovalue)) {
      push(@result, $uattr);
      push(@result, Torture::Utils::attribUnescape($nvalue));
      last;
    }
    push(@result, $uattr);
    push(@result, $uvalue);
  }

#  print 'RESULT: ' . "@result" . "\n";
  return ['attr', [ @result, @array ] ];
}


sub move(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;

  RBC::Check::Value($old);
  RBC::Check::Value($new);

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
  RBC::Check::Value($parent_new);
  RBC::Check::Value($parent_old);

    # Now, walk this node and each of its own
    # children
  my @array = ($old);
  while(my $child = shift(@array)) {
      # Calculate new name of children
    my $child_new=($child =~ /(.*)\Q$old\E$/)[0] . $new;
    
      # Give tracker a chance to update its own 
      # references
    $self->SUPER::move($child, $child_new, $self->{'childdata'}->{$child});

      # Ok, data of children must now be indexed under new name
    $self->{'childdata'}->{$child_new}=$self->replaceattr($child, $child_new, $self->{'childdata'}->{$child});
# ... rename attributes of the children!!!
#print '---' . Data::Dumper::Dumper($child, $child_new, $self->{'childdata'}->{$child_new}) . "\n";
    delete($self->{'childdata'}->{$child}) if($child ne $child_new);

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
      push(@{$self->{'parent2child'}->{$child_new}}, ($p2c =~ /(.*)\Q$old\E$/)[0] . $new);
    }
      # The old node has no more children now :)
    delete($self->{'parent2child'}->{$child});
  }

    # Ok, remove old dn from parent
  if(defined($self->{'parent2child'}->{$parent_old}) && @{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^\Q$old\E$/, @{$self->{'parent2child'}->{$parent_old}})];

    delete($self->{'parent2child'}->{$parent_old})
      if(!@{$self->{'parent2child'}->{$parent_old}});
  }

  push(@{$self->{'parent2child'}->{$parent_new}}, $new);
  return;
}

sub children() {
  my $self=shift;
  my $node=shift;

  return $self->{'parent2child'}->{$node} ? @{$self->{'parent2child'}->{$node}} : undef;
}

1;
