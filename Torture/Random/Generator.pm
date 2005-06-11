#!/usr/bin/perl -w

package Torture::Random::Generator;

use strict;
use Net::LDAP;

use Check;
use Torture::Debug;
use Torture::Random::Attributes;
use Torture::Utils;

my %g_bl_object = (
	"1.3.6.1.4.1.4203.1.4.1" => '65: objectClass "1.3.6.1.4.1.4203.1.4.1" only allowed in the root DSE' );
my %g_bl_attribute = ();

sub new() {
  my $self = {};
  my $name = shift;

  my $schema = shift;
  my $random = shift;
  my $attributes = shift;
  my $nodes = shift;

  Check::Class('Torture::Schema::.*', $schema);
  Check::Class('Torture::Random::Primitive::.*', $random);
  Check::Hinerits('Torture::Tracker', $nodes);

  $self->{'schema'} = $schema;
  $self->{'random'} = $random;
  if($attributes) {
    Check::Class('Torture::Random::Attributes.*', $attributes);
    $self->{'attribhdlr'} = $attributes;
  } else {
    $self->{'attribhdlr'} = Torture::Random::Attributes->new($random);
  }
  $self->{'track'} = $nodes;


  $self->{'bl_object'} = \%g_bl_object;
  $self->{'bl_attributes'} = \%g_bl_attribute;

  while(my $key = shift) {
    my $value = shift;
    $self->{$key}=$value;
  }

  bless($self);
  $self->prepare();

  return $self;
}

sub g_random_objectclass($$) {
  my $self = shift;
  return $self->class();
}

#  "1.3.6.1.4.1.1466.115.121.1.37" => 'objectclass',

sub prepare($$) { 
  my $self = shift;
  my $bl_object = shift;
  my $bl_attributes = shift;

    # Ok, initialize blacklists 
  $bl_object = $bl_object || $self->{'bl_object'};
  $bl_attributes = $bl_attributes || $self->{'bl_attributes'};

    # Black list must be hash ref
  Check::Hash($bl_object);
  Check::Hash($bl_attributes);

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

sub parent() {
  my $self = shift;
  my $context = shift;
  my $rootdn = shift;
  my $number;
  my @known;

    # Ok, return rootdn (or undef), if there are no entries
    # we can use as parents 
  @known=$self->{'track'}->inserted();
  return $rootdn if(!@known);
  return $self->{'random'}->element($self->{'random'}->context($context), \@known); 
}

sub dn(@) {
  my $self = shift;
  my ($context, $parent, $attrib) = @_;

  $self->prepare() if(!$self->{'prepared'});

  $attrib=$self->{'random'}->element($self->{'random'}->context($context, 'type'), [keys(%{$self->{'attributes'}})]) if(!$attrib);

  my $generated = $self->{'attribhdlr'}->generate($self->{'random'}->context($context, 'value'), $self->{'attributes'}->{$attrib});
  return $attrib . '=' . Torture::Utils::attribEscape($generated) . ($parent ? ',' . $parent : '');
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
