#!/usr/bin/perl -w

package Torture::Random::Generator;

use strict;
use Net::LDAP;

use Check;
use Torture::Debug;
use Torture::Random::Attributes;

my %g_bl_object = (
	"1.3.6.1.4.1.4203.1.4.1" => '65: objectClass "1.3.6.1.4.1.4203.1.4.1" only allowed in the root DSE' );
my %g_bl_attribute = ();

sub new() {
  my $self = {};
  my $name = shift;

  my $schema = shift;
  my $random = shift;
  my $attributes = shift;

  Check::Class('Torture::Schema::.*', $schema);
  Check::Class('Torture::Random::Primitive::.*', $random);

  $self->{'schema'} = $schema;
  $self->{'random'} = $random;
  if($attributes) {
    Check::Class('Torture::Random::Attributes.*', $attributes);
    $self->{'attribhdlr'} = $attributes;
  } else {
    $self->{'attribhdlr'} = Torture::Random::Attributes->new($random);
  }

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
  return $self->{'random'}->class();
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
  ($self->{'attributes'}, $self->{'structural'}, $self->{'auxiliary'}) =
  	$self->{'schema'}->prepare($self->{'attribhdlr'});
  $self->{'prepared'} = 1;

  delete($self->{'schema'});
  return;
}

sub parent() {
  my $self = shift;
  my $rootdn = shift;
  my $number;
  my $known;

    # Ok, return rootdn (or undef), if there are no entries
    # we can use as parents 
  $known=$self->{'server'}->inserted();
  return $rootdn if(!$known);

    # 70% of case return a random object
  $number=$self->{'random'}->number(0, 9);
  return ($self->{'server'}->inserted())[$self->{'random'}->number(0, $known - 1)] if($number <= 6);

    # Return rootdn in any other case
  return $rootdn;
}

sub dn(@) {
  my $self = shift;
  my ($parent, $attrib) = @_;

  $self->prepare() if(!$self->{'prepared'});
  $attrib=(keys(%{$self->{'attributes'}}))[$self->{'random'}->number(0, keys(%{$self->{'attributes'}})-1)] if(!$attrib);

  my $generated;
  $generated = $self->{'generators'}->{$self->{'attributes'}->{$attrib}}($self, $attrib);
  $generated =~ s/([,+"\\<>;#])/\\$1/g;
  $generated =~ s/^ /\\ /;
  $generated =~ s/ $/\\ /;

  return $attrib . '=' . $generated . ($parent ? ',' . $parent : '');
}

sub class() {
  my $self = shift;

  $self->prepare() if(!$self->{'prepared'});
  my $class=(keys(%{$self->{'structural'}}))[$self->{'random'}->number(0, scalar(keys(%{$self->{'structural'}}))-1)];

  return $class;
}

sub object() {
  my $self = shift;
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
    $class=$self->{'random'}->class();
    $object=$self->{'structural'}->{$class};
  }

    # TODO: we randomly choose to use a must, and, if no must,
    # we try with a may ...
  if(!$dnattr) {
#    print STDERR "object: " . join(' ', keys(%{$object->{'must'}})) . "\n";
    $dnattr=(keys(%{$object->{'must'}}))[$self->{'random'}->number(0, scalar(keys(%{$object->{'must'}}))-1)];
    if(!$dnattr) {
      $dnattr=(keys(%{$object->{'may'}}))[$self->{'random'}->number(0, scalar(keys(%{$object->{'may'}}))-1)];
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
    $dnvalue=$self->{'generators'}->{$dnprop}($self, $dnattr);
    if(!$dnvalue) {
      Torture::Debug::message('random/warning', "generator returned undefined value for: $dnattr\n");
      return undef;
    }
  }
  $return[0]=$dnattr . '=' . $dnvalue . ($parent ? ',' . $parent : '');
  $return[1]='attr';
  $return[2]=();
  #$return[1]->{'attr'}={};

  push(@{$return[2]}, $dnattr);
  push(@{$return[2]}, $dnvalue);

    # Add all must
  foreach my $must (keys(%{$object->{'must'}})) {
    next if($dnattr eq $must);
    my $value=$self->{'generators'}->{$object->{'must'}->{$must}}($self, $must);
    push(@{$return[2]}, $must);
    push(@{$return[2]}, $value);
    Torture::Debug::message('random/warning', "generator returned undefined value for: $must\n")
    		if(!$value);
  }

    # Add some may ## TODO: actually, single and multi value element are not 
    #   handled at all, and the ``randomization'' algorithm is quite dummy
  foreach my $may (keys(%{$object->{'may'}})) {
    next if($dnattr eq $may);

    if($self->{'random'}->number(0, 1)) {
      #print STDERR "dmay: $may " . $object->{'may'}->{$may} . "\n";
      next;
    }
    my $value=$self->{'generators'}->{$object->{'may'}->{$may}}($self, $may);

    #print STDERR "amay: $may " . $object->{'may'}->{$may} . "\n";
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
