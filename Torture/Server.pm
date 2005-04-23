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
  my $scope=shift;
  my @args=@_;

  if($scope ne "base" && $scope ne "one" && $scope ne "sub") {
    print STDERR 'Server->search error invalid scope' ."\n";
    $scope = 'base';
  }

#  print STDERR Dumper('base', $dn, 'scope' => $scope, 'filter' => '(objectclass=*)');
#  my $mesg=$self->{'ldap'}->search('base', $dn, @args);
  my $mesg=$self->{'ldap'}->search('base' => $dn, 'scope' => $scope, filter => '(objectclass=*)');

  return $mesg; 
}

sub objectscheck() {
  my $self=shift;
  my $entries=shift;

  foreach my $entry ($entries) {
    my $dn=$entry->dn();
    my $obj=$self->inserted($dn);
    return ('code' => 999, 'error' => "dn not found -- ". $dn) if(!$obj);

    my $attr;
    foreach my $elem (@{(@{$obj})[1]}) {
      if(!$attr) {
         $attr=$elem;
	 next;
      }
      my $values=$entry->get_value($attr);
      my %values_ash;
      foreach my $value (@{[$values]}) {
        $values_ash{$value}=1;
      }
      foreach my $value (@{[$elem]}) {
        return ('code' => 999, 'error' => "attrib values ($attr) in dn not found -- ".
		$dn ." -- ". Dumper($value). Dumper($elem)) if(!$values_ash{$value});

	undef $values_ash{$value};
      }
      return ('code' => 999, 'error' => "attrib values ($attr) in dn not found-- ".
	     $dn ." -- ". Dumper($obj). Dumper(%values_ash)) if(!%values_ash);

      undef $attr;
    }
  }
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

#  print STDERR Dumper($parent, $dn, @args);
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

  print STDERR "old: $old\n";
  print STDERR "parent_old: " . $parent_old . "\n";
  print STDERR ($parent_old ne $self->{'child2parent'}->{$old} ?
  		"wrong parent ($self->{'child2parent'}->{$old})\n" :
		"");
  print STDERR "peers: " . join(' ', @{$self->{'parent2child'}->{$parent_old}}) . "\n";
  print STDERR "child: " . (defined($self->{'parent2child'}->{$old}) ?
  				join(' ', @{$self->{'parent2child'}->{$old}}) : "none") . "\n";

  my @array = ($old);
#  if(defined(@{$self->{'parent2child'}->{$old}}) && @{$self->{'parent2child'}->{$old}}) {
#  }

  while(my $child = shift(@array)) {
    my $child_new=($child eq $old ? "" : ($child=~/(.*)$old$/)[0]) .$new;
    print STDERR "$child -> $child_new\n";

    $self->{'added'}->{$child_new}=$self->{'added'}->{$child};
    delete($self->{'added'}->{$child});

    $self->{'child2parent'}->{$child_new}=$parent_new;
    delete($self->{'child2parent'}->{$child});

    if(!defined(@{$self->{'parent2child'}->{$child}}) || !@{$self->{'parent2child'}->{$child}}) {
#      print STDERR Dumper($self->{'leaves'}->{$child});
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

#  return if($parent_old eq $parent_new);

    # Ok, remove old dn from parent
  if(@{$self->{'parent2child'}->{$parent_old}}) {
    $self->{'parent2child'}->{$parent_old}=
    	[grep(!/^$old$/, @{$self->{'parent2child'}->{$parent_old}})];

    print STDERR "ex peers: " . join(' ', @{$self->{'parent2child'}->{$parent_old}}) . "\n";

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
  print STDERR "new: $new\n";
  print STDERR "parent_new: $parent_new\n";
  print STDERR ($parent_new ne $self->{'child2parent'}->{$new} ?
  		"wrong parent ($self->{'child2parent'}->{$new})\n" :
		"");
  print STDERR "peers_new: " . join(' ', @{$self->{'parent2child'}->{$parent_new}}) . "\n";
  print STDERR "child: " . (defined($self->{'parent2child'}->{$new}) ?
  				join(' ', @{$self->{'parent2child'}->{$new}}) : "none") . "\n";
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

