#!/usr/bin/perl -w
#

package Torture::Server;

use Net::LDAP;
use Data::Dumper;
use strict;

sub new() {
  my $self = {};
  my $name = shift;
  my ($server, $binddn, $options, $bindauth) = @_;
 
  $server = 'localhost' if(!$server);
  $options = [ 'version' => 3 ] if(!$options);

  my $ldap = Net::LDAP->new($server, @{$options}) or 
	die "couldn't create object: $@";

    # Bind to the host
  my $conn;
  if($binddn) {
    $conn=$ldap->bind($binddn, @{$bindauth});
  } else {
    $conn=$ldap->bind;
  }

    # In case connection fails 
  if(!$conn || $conn->code) {
    die("couldn't bind: $@ -- " . $conn->error);
    return 1;
  }

  $self->{'ldap'} = $ldap;
  $self->{'conn'} = $conn;

  bless($self);
  return $self;
}

sub search(@) {
  my $self=shift;
  my $dn=shift;
  my @args=@_;

  #print STDERR Dumper('base', $dn, @args);
  return $self->{'ldap'}->search('base', $dn, @args);
}

sub idelete(@) {
  my $self=shift;
  my $dn=shift;
  my $children;

  #print STDERR "deleting: $dn\n";
  #print STDERR "parent: " . $self->{'child2parent'}->{$dn} . "\n";
  #print STDERR "peers: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

  delete($self->{'added'}->{$dn});
  delete($self->{'leaves'}->{$dn});
  delete($self->{'brenches'}->{$dn});

    # Ok, remove children from parent
  if($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}) {
    $self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}=
     	[grep(!/$dn/, @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}})];

    #print STDERR "peers 2: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

    if(!@{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) {
      #print STDERR "peers 3: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

      delete($self->{'parent2child'}->{$self->{'child2parent'}->{$dn}});
      
      $self->{'leaves'}->{$self->{'child2parent'}->{$dn}} = 
      	$self->{'brenches'}->{$self->{'child2parent'}->{$dn}};

      #print STDERR ' ' . $self->{'child2parent'}->{$dn} . '\n';

      $self->{'brenches'}->{$self->{'child2parent'}->{$dn}}=undef;
      delete($self->{'brenches'}->{$self->{'child2parent'}->{$dn}});
    }
  }

  delete($self->{'child2parent'}->{$dn});

  $children=$self->{'parent2child'}->{$dn};
  delete($self->{'parent2child'}->{$dn});
  if($children) {
    foreach my $child (@{$children}) {
      $self->idelete($child);
    }
  }

  return;
}

sub delete(@) {
  my $self=shift;
  my $dn=shift;
  my $retval;

  $retval=$self->{'ldap'}->delete($dn);
  return $retval if($retval->code);

  $self->idelete($dn);
  return $retval;
}

sub add(@) {
  my $self=shift;
  my $parent=shift;
  my $dn=shift;
  my @args = @_;
  my $retval;

  #print STDERR Dumper($dn, @args);
  $retval=$self->{'ldap'}->add($dn, @args);
  return $retval if($retval->code);

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

sub insertedleaf() {
  my $self=shift;
  my $key=shift;

  return keys(%{$self->{'leaves'}}) if(!$key);

  return $self->{'leaves'}->{$key};
}

sub insertedbrench() {
  my $self=shift;
  my $key=shift;

  return keys(%{$self->{'brenches'}}) if(!$key);

  return $self->{'brenches'}->{$key};
}

sub imove(@) {
  my $self=shift;
  my $old=shift;
  my $new=shift;
  my $parent;
  my $children;

    # Ok, if new name is relative,
    # make it absolute
  if($new !~ /,/) {
    $parent=($new =~ /^([^,]*)/)[0];
    $new=$new . ',' . $parent;
  } else {
    $parent=($new =~ /^([^,]*)/)[0];
  }

  #print STDERR "deleting: $dn\n";
  #print STDERR "parent: " . $self->{'child2parent'}->{$dn} . "\n";
  #print STDERR "peers: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

    # Update added list
  delete($self->{'added'}->{$old});
  $self->{'added'}->{$new}=$self->{'added'}->{$old};

    # Update leaves/brenches list
  if($self->{'leaves'}->{$old}) {
    $self->{'leaves'}->{$new}=$self->{'leaves'}->{$old};
    delete($self->{'leaves'}->{$old});
  } else {
    $self->{'brenches'}->{$new}=$self->{'brenches'}->{$old};
    delete($self->{'brenches'}->{$old});
  }

    # Ok, remove children from parent
  if($self->{'parent2child'}->{$self->{'child2parent'}->{$old}}) {
    $self->{'parent2child'}->{$self->{'child2parent'}->{$old}}=
     	[grep(!/$old/, @{$self->{'parent2child'}->{$self->{'child2parent'}->{$old}}})];

    #print STDERR "peers 2: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

    if(!@{$self->{'parent2child'}->{$self->{'child2parent'}->{$old}}}) {
      #print STDERR "peers 3: " . join(' ', @{$self->{'parent2child'}->{$self->{'child2parent'}->{$dn}}}) . "\n";

      delete($self->{'parent2child'}->{$self->{'child2parent'}->{$old}});
      
      $self->{'leaves'}->{$self->{'child2parent'}->{$old}} = 
      	$self->{'brenches'}->{$self->{'child2parent'}->{$old}};

      #print STDERR ' ' . $self->{'child2parent'}->{$dn} . '\n';

      $self->{'brenches'}->{$self->{'child2parent'}->{$old}}=undef;
      delete($self->{'brenches'}->{$self->{'child2parent'}->{$old}});
    }
  }

  delete($self->{'child2parent'}->{$old});

  $children=$self->{'parent2child'}->{$old};
  delete($self->{'parent2child'}->{$old});

  $self->{'parent2child'}->{$new}=$children;
  $self->{'child2parent'}->{$new}=$parent;
  push(@{$self->{'parent2child'}->{$parent}}, $parent);
  if($self->{'leaves'}->{$parent}) {
    $self->{'brenches'}->{$parent} = 
    		$self->{'leaves'}->{$parent};
    $self->{'leaves'}->{$parent}=undef;
    delete($self->{'leaves'}->{$parent});
  }

  return;
}


sub move() {
  my $self = shift;
  my $old = shift;
  my $new = shift;
  my $nchild;
  my $nparent;
  my $retval;

  ($nchild, $nparent)=($new =~ /([^,]*),(.*)/);

    # ok, move entry
  if($nparent && $nchild) {
    $retval=$self->{'ldap'}->moddn($old, 'newrdn' => $nchild,
    				 'newsuperior' => $nparent,
				 'deleteoldrdn' => 1); 
  } else {
    $retval=$self->{'ldap'}->moddn($old, 'newrdn' => $new, 'deleteoldrdn' => 1); 
  }
  return $retval if($retval->code);

  $self->imove($old, $new);
  return $retval;
}

sub inserted() {
  my $self=shift;
  my $key=shift;

  return keys(%{$self->{'added'}}) if(!$key);

  return $self->{'added'}->{$key};
}

sub ldap() {
  my $self = shift;

  return $self->{'ldap'};
}

1;
