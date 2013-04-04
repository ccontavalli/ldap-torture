#!/usr/bin/perl -w

package Torture::Random::Generator;

use strict;
use Net::LDAP;

use RBC::Check;
use Torture::Debug;
use Torture::Random::Attributes;
use Torture::Utils;

use Data::Dumper;

sub g_dn_invented() {
  my $self=shift;
  my $context=shift;

  my $parent;

  $parent=$self->parent($context);
  return undef if(!$parent);

  return ($self->dn($context, $parent));
}

sub g_dn_inserted_brench() {
  my $self=shift;
  my $context=shift;

  return ($self->{'random'}->element($context, [$self->{'track'}->branches()]));
}

sub g_dn_inserted_leaf() {
  my $self=shift;
  my $context=shift;

  my $obj=$self->{'random'}->element($context, [$self->{'track'}->leaves()]);

  return ($obj ? ($obj) : undef);
}

sub g_dn_inserted() {
  my $self=shift;
  my $context=shift;

  return ($self->{'random'}->element($context, [$self->{'track'}->branches(), $self->{'track'}->leaves()]));
}

sub g_dn_root() {
  my $self=shift;
  my $context=shift;
  my $root;

  $root=$self->{'random'}->element($context, [$self->{'track'}->roots()]);
  return ($root ? ($root) : undef);
}

sub g_dn_deleted() {
  my $self=shift;
  my $context=shift;


  my $obj=$self->{'random'}->element($context, [$self->{'track'}->deleted()]);
  return ($obj ? ($obj) : undef);
}

sub g_object_deleted() {
  my $self=shift;
  my $context=shift;

    # Create a random object under this non-existing child
  my $obj;
  for(my $i=0; $i < $self->{'config'}->{'gen-attempts'}; $i++) {
    $obj=$self->{'random'}->element($context, [$self->{'track'}->deleted()]);
    last if(!$obj);

    my $parent=&Torture::Utils::dnParent($obj);
    return [ $obj, @{$self->{'track'}->{'deleted'}->{$obj}} ]
	    if($self->{'track'}->exist($parent));
  }

  return undef;
}


sub g_object_noparent() {
  my $self=shift;
  my $context=shift;

  my $parent;

    # Choose a random parent
  $parent=$self->parent($context);
  return undef if(!$parent);

    # Invent a random child
  $parent=$self->dn($context, $parent);
  return undef if(!$parent);

    # Create a random object under this non-existing child
  return ($self->object($context, $parent));
}

sub g_object_new() {
  my $self=shift;
  my $context=shift;

  my $parent;
  my $object;

    # Choose a random parent
  $parent=$self->parent($context);
  return undef if(!$parent);

    # Create a random object under this non-existing child
  for(my $i=0; $i < $self->{'config'}->{'gen-attempts'}; $i++) {
    $object=$self->object($context, $parent);
    return undef if(!$object);

    return ($object) if(!$self->{'track'}->exist($object->[0]));
  }

  return undef;
}

sub g_dn_nonexisting() {
  my $self=shift;
  my $context=shift;

    # Choose a random parent
  my $parent=$self->parent($context);
  return undef if(!$parent);

    # Invent a random child
  $parent=$self->dn($context, $parent);
  return undef if(!$parent);

  return ($parent);
}


sub g_dn_alias_noparent() {
  my $self=shift;
  my $context=shift;
  my $leaf=shift;

    # Get the relative dn of the entry
  my $rela=Torture::Utils::dnChild($leaf);

    # Choose a random parent
  my $parent=$self->remote_parent($context, $rela, $leaf);
  return undef if(!$parent);

    # Invent a random child
  $parent=$self->dn($context, $parent);
  return undef if(!$parent);

  return ($rela . ',' . $parent) 
}

sub g_dn_alias_descendant() {
  my $self=shift;
  my $context=shift;
  my $leaf=shift;

    # Get the relative dn of the entry
  my $rela=Torture::Utils::dnChild($leaf);

    # Get a random parent
  my $parent=$self->descendant($context, $leaf);
  $parent=$leaf if(!$parent);
  return ($rela . ',' . $parent);
}

sub g_dn_alias_ok() {
  my $self=shift;
  my $context=shift;
  my $leaf=shift;

    # Get the relative dn of the entry
  my $rela=Torture::Utils::dnChild($leaf);
  my $parent=$self->remote_parent($context, $rela, $leaf);
  return undef if(!$parent);

  return undef;
}

sub g_dn_attralias_sameparent_ok() {
  my $self=shift;
  my $context=shift;
  my $dn=shift;

  my $node=[$dn, @{$self->{'track'}->get($dn)}];
  my $parent=&Torture::Utils::dnParent(${$node}[0]);
  my $child=&Torture::Utils::dnChild(${$node}[0]);
  my $attr=&Torture::Utils::dnAttrib($child);
  my %attrs;

  return undef if(!${$node}[2]);

  my @parse=@{${$node}[2]};
  while($_=shift(@parse)) {
#    print 'considering: ' . $_ . "\n";
    if($_ =~ /^\Q$attr\E$/ || $_ =~ /^objectclass$/i) {
      shift(@parse);
      next;
    }
    $attrs{$_}=shift(@parse);
  }

  return undef if(keys(%attrs) < 1);

  for(my $i=0; $i < $self->{'config'}->{'gen-attempts'}; $i++) {
    my $touse=$self->{'random'}->element($self->{'random'}->context($context), [ keys(%attrs) ]); 
  #  print $touse . '=' . $attrs{$touse} . ',' . $parent;
    my $retval=$touse . '=' . Torture::Utils::attribEscape($attrs{$touse}) . ',' . $parent;
    return $retval if(!$self->{'track'}->exist($retval));
  }

  return undef;
}

sub g_dn_alias_sameparent_ok() {
  my $self=shift;
  my $context=shift;
  my $leaf=shift;

    # Get the relative dn of the entry
  my $parent=Torture::Utils::dnParent($leaf);
  my $child=Torture::Utils::dnChild($leaf);
  my $attrib=Torture::Utils::dnAttrib($child);
	  
  return $self->dn($context, $parent, $attrib);
}

sub g_object_ok() {
  my $self=shift;
  my $context=shift;

  my $parent;

    # Choose a random parent
  $parent=$self->parent($context);
  return undef if(!$parent);

    # Create a random object under this non-existing child
  return ($self->object($context, $parent));
}

sub g_object_existing() {
  my $self=shift;
  my $context=shift;

  my $parent;
  my $retval;

    # Choose a random parent
  $parent=$self->parent($context);
  return undef if(!$parent);

    # Try to fetch object and return it
  $retval=$self->{'track'}->get($parent);
  return ([$parent, @{$retval}]) if(@{$retval});
  return undef;
}


my %generators = (
  'dn/alias/ok' => \&g_dn_alias_ok,
  'dn/alias/descendant' => \&g_dn_alias_descendant,
  'dn/alias/noparent' => \&g_dn_alias_noparent,
  'dn/alias/sameparent/ok' => \&g_dn_alias_sameparent_ok,
  'dn/attralias/sameparent/ok' => \&g_dn_attralias_sameparent_ok,
  'dn/invented' => \&g_dn_invented,
  'dn/inserted' => \&g_dn_inserted,
  'dn/inserted/brench' => \&g_dn_inserted_brench,
  'dn/inserted/leaf' => \&g_dn_inserted_leaf,
  'dn/deleted' => \&g_dn_deleted,
  'dn/rootdn' => \&g_dn_root,
  'dn/nonexisting' => \&g_dn_nonexisting,
  'object/noparent' => \&g_object_noparent,
  'object/ok' => \&g_object_ok,
  'object/new' => \&g_object_new,
  'object/deleted' => \&g_object_deleted,
  'object/existing' => \&g_object_existing
);

sub new() {
  my $self = {};
  my $name = shift;

  my $config = shift;
  my $schema = shift;
  my $random = shift;
  my $attributes = shift;
  my $nodes = shift;

  RBC::Check::Hash($config);
  RBC::Check::Class('Torture::Schema::.*', $schema);
  RBC::Check::Class('Torture::Random::Primitive::.*', $random);
  RBC::Check::Hinerits('Torture::Tracker', $nodes);

  $self->{'config'} = $config;
  $self->{'schema'} = $schema;
  $self->{'random'} = $random;
  if($attributes) {
    RBC::Check::Class('Torture::Random::Attributes.*', $attributes);
    $self->{'attribhdlr'} = $attributes;
  } else {
    $self->{'attribhdlr'} = Torture::Random::Attributes->new($random);
  }
  $self->{'track'} = $nodes;
  $self->{'generators'} = \%generators;

  while(my $key = shift) {
    my $value = shift;
    $self->{$key}=$value;
  }

  bless($self);
  $self->prepare();

  return $self;
}

sub generate()  {
  my $self = shift;
  my $context = shift;
  my $what = shift;

  RBC::Check::Value($what);
  RBC::Check::Value($self->{'generators'}->{$what});

  Torture::Debug::message('generator/making', join(':', caller()) . " generating $what\n");
  return &{$self->{'generators'}->{$what}}($self, $context, @_);
}

sub g_random_objectclass($$) {
  my $self = shift;
  return ($self->class());
}

#  "1.3.6.1.4.1.1466.115.121.1.37" => 'objectclass',

sub prepare($$) { 
  my $self = shift;

    # Register locally handled attributes
  $self->{'attribhdlr'}->register('1.3.6.1.4.1.1466.115.121.1.37', 
  			'objectclass', $self, \&g_random_objectclass);

  # self->attributes = list of attributes
  # self->structural = list of structural objects
  # self->auxiliary = list of auxiliary object classes
  ($self->{'attributes'}, $self->{'structural'}, $self->{'auxiliary'}) 
  	= $self->{'schema'}->prepare($self->{'attribhdlr'}->known());
  $self->{'prepared'} = 1;

  delete($self->{'schema'});
  return;
}

sub descendant() {
  my $self = shift;
  my $context = shift;
  my $dn = shift;

    # Ok, return rootdn (or undef), if there are no entries
    # we can use as parents 
  my @known=$self->{'track'}->children($dn);
  return $dn if(!@known);

  return $self->{'random'}->element($self->{'random'}->context($context), [ $dn, @known ]); 
}


# Returns a valid and usable parent, any possible node in the ldap tree.
sub parent() {
  my $self = shift;
  my $context = shift;
  my $rootdn = shift;
  my $number;
  my @known;

    # Ok, return rootdn (or undef), if there are no entries
    # we can use as parents 
  @known=$self->{'track'}->inserted();
  if(!@known) {
    Torture::Debug::message('generator/parent/rootdn', 'returning rootdn instead of random entry');
  }

  return $self->{'random'}->element($self->{'random'}->context($context), [ $rootdn, @known ]); 
}

# Returns a valid and usable parent that is not a child of the specified node or the node itself.
sub remote_parent() {
  my $self = shift;
  my $context = shift;
  my $rela = shift;
  my $leaf = shift;

    # Get a random parent
  for(my $i=0; $i < $self->{'config'}->{'gen-attempts'}; $i++) {
    my $parent=$self->parent($context);
    return undef if(!$parent);
    if(!$self->{'track'}->exist($rela . ',' . $parent) && $parent !~ /\Q$leaf\E$/) {
      return ($rela . ',' . $parent) 
    }
  }
}

sub dn(@) {
  my $self = shift;
  my ($context, $parent, $oattrib) = @_;
  my $attrib = $oattrib;
  my $retval;

  $self->prepare() if(!$self->{'prepared'});
  $attrib=$self->{'random'}->element($self->{'random'}->context($context, 'type'), [keys(%{$self->{'attributes'}})]) if(!$oattrib);

  for(my $i=0; $i < $self->{'config'}->{'gen-attempts'}; $i++) {
    my $generated = $self->{'attribhdlr'}->generate($self->{'random'}->context($context, 'value'), $self->{'attributes'}->{$attrib});
    $retval = $attrib . '=' . Torture::Utils::attribEscape($generated) . ($parent ? ',' . $parent : '');

    return $retval if(!$self->{'track'}->exist($retval));
    $attrib=$self->{'random'}->element($self->{'random'}->context($context, 'type'), [keys(%{$self->{'attributes'}})]) if(!$oattrib);
  }
  
  return undef;
}

sub class() {
  my $self = shift;
  my $context = shift;

  $self->prepare() if(!$self->{'prepared'});
  my $class=$self->{'random'}->element($self->{'random'}->context($context), [keys(%{$self->{'structural'}})]);

  return $class;
}

sub object() {
  my $self = shift;
  my $context = shift;
  my $parent = shift;
  my $dnattr = shift;
  my $dnvalue = shift;
  my $class = shift;

  my $dnprop;
  my @return;
  my $object;
 
  $self->prepare() if(!$self->{'prepared'});

    # Get a random class
  if($class) {
    $object=$self->{'structural'}->{$class};
    if(!$object) {
      Torture::Debug::message('random/warning', "unknown user supplied class: $class\n");
      return undef;
    }
  } else {
    $class=$self->class();
    $object=$self->{'structural'}->{$class};
  }

    # TODO: we randomly choose to use a must, and, if no must,
    # we try with a may ...
  if(!$dnattr) {
    $dnattr=$self->{'random'}->element($self->{'random'}->context($context, 'dnkind/must'), [keys(%{$object->{'must'}})]);

    if(!$dnattr) {
      $dnattr=$self->{'random'}->element($self->{'random'}->context($context, 'dnkind/may'), [keys(%{$object->{'may'}})]);
      $dnprop=$object->{'may'}->{$dnattr};
    } else {
      $dnprop=$object->{'must'}->{$dnattr};
    }
    Torture::Debug::message('random/object', 
    		"$class -- object: (must: " . join(' ', keys(%{$object->{'must'}})) . ") (may: " .
		join(' ', keys(%{$object->{'may'}})) . ") -- choosen: $dnattr/$dnprop\n");
  } 

  if(!$dnvalue) {
    if(!$dnprop) {
      Torture::Debug::message('random/warning', "unknown generator for: $dnattr\n");
      return undef;
    }
    $dnvalue=$self->{'attribhdlr'}->generate($self->{'random'}->context($context, 'dnvalue'), $self->{'attributes'}->{$dnattr});
    if(!$dnvalue) {
      Torture::Debug::message('random/warning', "generator returned undefined value for: $dnattr\n");
      return undef;
    }
  }
  $return[0]=$dnattr . '=' . $dnvalue . ($parent ? ',' . $parent : '');
  $return[1]='attr';
  $return[2]=();

  push(@{$return[2]}, $dnattr);
  push(@{$return[2]}, $dnvalue);

    # Add all must
  foreach my $must (keys(%{$object->{'must'}})) {
    next if($dnattr eq $must);
    my $value=$self->{'attribhdlr'}->generate($self->{'random'}->context($context, 'must/value/' . $must), $self->{'attributes'}->{$must});
    push(@{$return[2]}, $must);
    push(@{$return[2]}, $value);
    Torture::Debug::message('random/warning', "generator returned undefined value for: $must\n")
    		if(!$value);
  }

    # Add some may ## TODO: actually, single and multi value element are not 
    #   handled at all, and the ``randomization'' algorithm is quite dummy
  foreach my $may (keys(%{$object->{'may'}})) {
    next if($dnattr eq $may);

    next if($self->{'random'}->number($self->{'random'}->context($context, 'may'), 0, 1));
    my $value=$self->{'attribhdlr'}->generate($self->{'random'}->context($context, 'may/value/' . $may), $self->{'attributes'}->{$may});

    push(@{$return[2]}, $may);
    push(@{$return[2]}, $value);
    Torture::Debug::message('random/warning', "generator returned undefined value for: $may\n")
    		if(!$value);
  }

    # Add necessary elements
  foreach my $attr (keys(%{$object->{'attr'}})) {
    push(@{$return[2]}, $attr);
    push(@{$return[2]}, $object->{'attr'}->{$attr});
  }

  return \@return;
}

1;
