#!/usr/bin/perl -w

package Torture::Schema::LDAP;

use strict;

use Torture::Server;
use Data::Dumper;
use Torture::Debug;
use Check;

my %g_bl_object = (
        "1.3.6.1.4.1.4203.1.4.1" => '65: objectClass "1.3.6.1.4.1.4203.1.4.1" only allowed in the root DSE' );

sub load_add_object($$$$) {
  my $self = shift;
  my $attributes = shift;
  my $schemas = shift;
  my $result = shift;
  my $object = shift;

    # Skip objects without name
  if(!$object->{'name'}) {
    Torture::Debug::message('schema/object', '(no name)');
    return undef;
  }

    # leave now if object has been blacklisted
  if($object->{'oid'} && $self->{'object-blacklist'}->{$object->{'oid'}}) {
    Torture::Debug::message('schema/objects', '(blacklisted)');
    return undef;
  }

    # Skip abstract objects
  return 1 if(${$object}{'abstract'});
     
     # Parse object itself adn its parents
  if(${$object}{'structural'}) {
    return $self->load_add_structural($attributes, $schemas, $result, $object);
  } 

  if(${$object}{'auxiliary'}) {
    return $self->load_add_auxiliary($attributes, $schemas, $result, $object);
  }

  Torture::Debug::message('schema/objects', 'neither structural nor auxiliary');
  return undef;
}

sub load_add_attribute($$$$) {
  my $self = shift;
  my $attributes = shift;
  my $schemas = shift;
  my $result = shift;
  my $attr = shift;
  my $oattr = $attr;
  my @sups;

#  Torture::Debug::message('schema/attributes', "(parsing)");

    # leave now if the name of the attribute
    # is not clear
  if(!$attr->{'name'}) {
    Torture::Debug::message('schema/attributes', "(unnamed)");
    return undef;
  }

    # Leave now if the attribute has been blacklisted
  if($attr->{'oid'} && $self->{'attribute-blacklist'}->{$attr->{'oid'}}) {
    Torture::Debug::message('schema/attributes', '(blacklisted)');
    return undef;
  }

    # uhm .. I assume fields with the usage flag are operational
    # XXX  hope it is correct
  if($attr->{'usage'}) {
    Torture::Debug::message('schema/attributes', "(operational)");
    return undef;
  }

  my $name = $attr->{'name'};


    # Walk all superiors of this node
  push(@sups, @{$attr->{'sup'}}) if($attr->{'sup'});
  foreach my $sup (@sups) { 
    next if(!($attr = $attributes->{$sup}));
    last if($attr->{'syntax'});

    push(@sups, @{$attributes->{$sup}->{'sup'}}) 
    	if($attributes->{$sup} && $attributes->{$sup}->{'sup'} && @{$attributes->{$sup}->{'sup'}});
  }
  if(!$attr || !$attr->{'syntax'}) {
    Torture::Debug::message('schema/attributes', "(syntax)");
    return undef;
  }
  Torture::Debug::message('schema/syntax', "$name -- " . $attr->{'syntax'} . "\n");
  if($self->{'attribute-whitelist'}->{$attr->{'syntax'}}) {
    $result->{$name} = $attr->{'syntax'};
    $self->{'attributes'}->{$name} = $attr->{'syntax'};
  }

  return $result->{$name};
}

sub load_add_auxiliary($$$$) {
  my $self = shift;
  my $attributes = shift;
  my $schemas = shift;
  my $result = shift;
  my $object = shift;

    # Remember object class of current object
  #push(@{$result->{'attr'}->{'objectclass'}}, $object->{'name'});
  return $self->load_add_structural($attributes, $schemas, $result, $object);
}

sub load_add_structural($$$$) {
  my $self = shift;
  my $attributes = shift;
  my $schemas = shift;
  my $result = shift;
  my $object = shift;

  my ($must, $may, $sup);

  Torture::Debug::message('schema/object', "\nOBJECT: " . ( $object->{'name'} ? $object->{'name'} : "(unknown)" ) . "\n");
    # Walk all parents, in order to correctly build classes
  if($object->{'sup'}) {
    foreach $sup (@{$object->{'sup'}}) {
      next if($sup =~ /top/o);

      Torture::Debug::message('schema/object', "  SUP: $schemas / $sup - " . join(' ', keys(%{$schemas->{$sup}})));
      if(!$schemas->{$sup}) {
        Torture::Debug::message('schema/object', " not found. skipping\n");
	return undef;
      }
      if(!$self->load_add_object($attributes, $schemas, $result, $schemas->{$sup})) {
        Torture::Debug::message('schema/object', " add object failed. skipping\n");
	return undef;
      }
      Torture::Debug::message('schema/object', " ok\n");
    }
  }
  Torture::Debug::message('schema/object', " - done.\n");

    # Add all must fields
  foreach $must (@{$object->{'must'}}) {
    Torture::Debug::message('schema/attribute', "  MUST: $must - ");
    if(!$attributes->{$must}) {
      Torture::Debug::message('schema/attribute', " not found. skipping\n");
      return undef;
    }
    if(!$self->load_add_attribute($attributes, $schemas, $result->{'must'}, $attributes->{$must})) {
      Torture::Debug::message('schema/attribute', " add attribute failed. skipping\n");
      return undef;
    }

    if($result->{'must'}->{$must} && !$attributes->{$must}->{'single-value'}) {
      $result->{'multi'}->{$must} = $result->{'must'}->{$must};
    }

    Torture::Debug::message('schema/object', " ok.\n");
  }
  Torture::Debug::message('schema/object', " - done.\n");

    # Add all may fields
  foreach $may (@{$object->{'may'}}) {
    Torture::Debug::message('schema/attribute', "  MAY: $may - ");
    if(!$attributes->{$may}) {
      Torture::Debug::message('schema/attribte', " not found. ignoring\n");
      next;
    }
    if(!$self->load_add_attribute($attributes, $schemas, $result->{'may'}, $attributes->{$may})) {
      Torture::Debug::message('schema/attribute', " load failed. ignoring\n");
      next;
    }

    if($result->{'may'}->{$may} && !$attributes->{$may}->{'single-value'}) {
      $result->{'multi'}->{$may} = $result->{'may'}->{$may};
    }

    Torture::Debug::message('schema/object', " ok.\n");
  }
  Torture::Debug::message('schema/object', " - done.\n");

  return 1;
}

sub load_templates() {
  my $self = shift;
  my $schema = shift;
  my $attributes;
  my $schemas;
  my %objects; # Hash of object schemas (name => schema)
  my %values; # Hash of attributes (name => schema)
  my %structural;
  my %auxiliary;

    # Create an index of known attributes
  $attributes = [ $schema->all_attributes ];
  foreach my $obj (@{$attributes}) {
    next if(!${$obj}{'name'});
    Torture::Debug::message('schema/index', "adding: " . $obj->{'name'} . 
    	((@{$obj->{'aliases'}}) ? ( ' (' . join(' ', @{$obj->{'aliases'}} ) . ')' ) : '') . "\n");
    foreach my $dump (keys(%{$obj})) {
      if(ref($obj->{$dump}) eq "ARRAY") {
        Torture::Debug::message('schema/index', " $dump: " . join(' ', @{$obj->{$dump}}) . "\n");
      } else {
        Torture::Debug::message('schema/index', " $dump: " . $obj->{$dump} . "\n");
      }
    }

    $values{${$obj}{'name'}} = $obj;
    foreach my $attr (@{$obj->{'aliases'}}) {
      $values{$attr} = $obj;
      Torture::Debug::message('schema/index', "adding: " . $attr . "\n");
    }
  }

  Torture::Debug::message('schema/dump/attributes', Dumper(%values));

    # Create an index of known objects
  $schemas = [ $schema->all_objectclasses ];
  foreach my $obj (@{$schemas}) {
    next if(!${$obj}{'name'});
    Torture::Debug::message('schema/index', "object: " . $obj->{'name'} . 
    	((@{$obj->{'aliases'}}) ? ( ' (' . join(' ', @{$obj->{'aliases'}} ) . ')' ) : '') . "\n");

    $objects{${$obj}{'name'}} = $obj;
    foreach my $attr (@{$obj->{'aliases'}}) {
      $objects{$attr} = $obj;
      Torture::Debug::message('schema/index', "object: " . $attr . "\n");
    }
  }
  Torture::Debug::message('schema/dump/objects', Dumper($schemas));

  foreach my $obj (@{$schemas}) {
    my $object = {};
    $object->{'must'} = {};
    $object->{'may'} = {};
    $object->{'multi'} = {};
    $object->{'attr'} = {};

    if($self->load_add_object(\%values, \%objects, $object, $obj)) {
      push(@{$object->{'attr'}->{'objectclass'}}, $obj->{'name'});
      if(${$obj}{'auxiliary'}) {
        $auxiliary{$obj->{'name'}}=$object;
      } elsif(${$obj}{'structural'}) {
        $structural{$obj->{'name'}}=$object;
      }
      next;
    }

    Torture::Debug::message('schema/warning', '? unknown ' . ${$obj}{'name'} . "\n");
    foreach my $ele (keys(%{$obj})) {
      if(ref(${$obj}{$ele}) eq "ARRAY") {
        Torture::Debug::message('schema/warning', "  $ele -> (" . join(' ', @{${$obj}{$ele}}) . ")\n");
      } else {
        Torture::Debug::message('schema/warning', "  $ele -> " . ${$obj}{$ele} . "\n");
      }
    }
  }
  $self->{'structural'}=\%structural;
  $self->{'auxiliary'}=\%auxiliary;
}

sub prepare($$) {
  my $self = shift;
  my $wl_attribute = shift;
  my $bl_attribute = shift;
  my $bl_object = shift;

  $self->{'attribute-whitelist'}=$wl_attribute;
  $self->{'attribute-blacklist'}=$bl_attribute || {};
  $self->{'object-blacklist'}=$bl_object || \%g_bl_object;

    # Try to load schema templates
  $self->{'templates'}=$self->load_templates($self->{'schema'});
  return ($self->{'attributes'}, $self->{'structural'}, $self->{'auxiliary'});
}

sub new() {
  my $self = {};
  my $name = shift;
  my $server = shift;
  my $known = shift;
  my $ldap;

  Check::Class('Net::LDAP.*', $server);
  
    # Remember server
  while(my $key = shift) {
    my $value=shift;
    $self->{$key} = $value;
  }

    # Load schema file 
  $self->{'schema'}=$server->schema() 
  	if(!$self->{'schema'});
  bless($self);

    # Prepare, if we were given enough arguments 
  $self->prepare($known) if($known);
  return $self;
}

1;
