#!/usr/bin/perl -w

package Torture::Random;

use strict;
use Net::LDAP;
use Torture::Debug;
use Torture::Server;
use Data::Dumper;

my %bl_object = (
	"1.3.6.1.4.1.4203.1.4.1" => '65: objectClass "1.3.6.1.4.1.4203.1.4.1" only allowed in the root DSE' );
my %bl_attribute = ();

# TODO:
#   - handle auxiliary classes independently, and 
#     eventually decide how to use them
#   - complete the class generation functions

sub g_random_cn($$) {
  my $self = shift;

  return $self->randomtext(2, 30);
}

sub g_random_phone($$) {
  my $self = shift;
    # +390331508920
  return '+' . $self->randomnumber(100000, 999999) . $self->randomnumber(100000, 999999);
}

sub g_random_string($$) {
  my $self = shift;
  return $self->randomtext(2, 127);
}

sub g_random_number($$) {
  my $self = shift;
  return $self->randomnumber(0, 4000000000);
}

sub g_random_objectclass($$) {
  my $self = shift;
  return $self->randomclass();
}

sub g_random_password($$) {
  my $self = shift;
  return $self->randomtext(2, 32);
}

my %g_random = (
  'commonname' => \&g_random_cn,
  'phonenumber' => \&g_random_phone,
  'string' => \&g_random_string,
  'sysuid' => \&g_random_number,
  'objectclass' => \&g_random_objectclass,
  'password' => \&g_random_password
);

my %generators = (
"1.3.6.1.1.1.0.0" => undef,
"1.3.6.1.1.1.0.1" => undef,
"1.3.6.1.4.1.1466.115.121.1.10" => undef,
"1.3.6.1.4.1.1466.115.121.1.12" => undef,
"1.3.6.1.4.1.1466.115.121.1.14" => undef,
"1.3.6.1.4.1.1466.115.121.1.15" => 'commonname',
"1.3.6.1.4.1.1466.115.121.1.22" => 'phonenumber',
"1.3.6.1.4.1.1466.115.121.1.23" => undef,
"1.3.6.1.4.1.1466.115.121.1.25" => undef,
"1.3.6.1.4.1.1466.115.121.1.26" => 'string',
"1.3.6.1.4.1.1466.115.121.1.27" => 'sysuid',
"1.3.6.1.4.1.1466.115.121.1.28" => undef, 
"1.3.6.1.4.1.1466.115.121.1.3" => undef,
"1.3.6.1.4.1.1466.115.121.1.30" => undef,
"1.3.6.1.4.1.1466.115.121.1.31" => undef,
"1.3.6.1.4.1.1466.115.121.1.34" => undef,
"1.3.6.1.4.1.1466.115.121.1.36" => undef,
"1.3.6.1.4.1.1466.115.121.1.37" => 'objectclass',
"1.3.6.1.4.1.1466.115.121.1.38" => undef,
"1.3.6.1.4.1.1466.115.121.1.39" => undef,
"1.3.6.1.4.1.1466.115.121.1.4" => undef,
"1.3.6.1.4.1.1466.115.121.1.40" => 'password',
"1.3.6.1.4.1.1466.115.121.1.41" => undef,
"1.3.6.1.4.1.1466.115.121.1.43" => undef,
"1.3.6.1.4.1.1466.115.121.1.44" => undef,
"1.3.6.1.4.1.1466.115.121.1.49" => undef,
"1.3.6.1.4.1.1466.115.121.1.5" => undef,
"1.3.6.1.4.1.1466.115.121.1.50" => 'phonenumber',
"1.3.6.1.4.1.1466.115.121.1.51" => undef,
"1.3.6.1.4.1.1466.115.121.1.52" => undef,
"1.3.6.1.4.1.1466.115.121.1.8" => undef,
"1.3.6.1.4.1.1466.115.121.1.9" => undef,
);

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
  if($generators{$attr->{'syntax'}}) {
    $result->{$name} = $generators{$attr->{'syntax'}};
    $self->{'attributes'}->{$name} = $generators{$attr->{'syntax'}};
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
  push(@{$result->{'attr'}->{'objectclass'}}, $object->{'name'});
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
        Torture::Debug::message('schema/object', " load failed. skipping\n");
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
      Torture::Debug::message('schema/attribute', " load failed. skipping\n");
      return undef;
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

sub new() {
  my $self = {};
  my $name = shift;
  my $server = shift;
  my (%attrs) = @_;
  my $ldap;

    # Remember server
  $self->{'server'}=$server;
  $ldap=$server->ldap();
  $self->{'ldap'}=$ldap;

  foreach (keys(%attrs)) {
    $self->{$_} = $attrs{$_};
  }

    # Load schema file 
  $self->{'schema'}=$self->{'ldap'}->schema() 
    if(!$self->{'schema'});

  bless($self);

  $self->{'attribute-blacklist'}=\%bl_attribute;
  $self->{'object-blacklist'}=\%bl_object;

    # Try to load schema templates
  $self->{'templates'}=$self->load_templates($self->{'schema'});
  $self->{'generators'}=\%g_random;

    # Initialize default values
#  $self->{'dn_len_min'} = 1 if(!$self->{'dn_len_min'});
#  $self->{'dn_len_max'} = 37 if(!$self->{'dn_len_max'});
  if(!$self->{'random_seed'}) {
    srand();
    $self->{'random_seed'} = rand();
  }

  return $self;
}

sub seed() {
  my $self = shift;
  my $arg = shift;

  if($arg) {
    $self->{'random_seed'} = $arg;
    srand($arg);
  }

  return $self->{'random_seed'};
}

sub randomnumber($$$) {
  my $self = shift;
  my ($min, $max) = @_;
  my $number = rand(($max-$min)+1);

  return int($min+$number);
}

sub randomtext($$$@) {
  my $self = shift;
  my ($min, $max, @allowed) = @_;
  my ($lenght) = $self->randomnumber($min, $max);
  my ($string);

  @allowed = ( 'a' .. 'z', '0' .. '9') 
  	if(!@allowed);
  
 $string .= $allowed[$self->randomnumber(0, $#allowed)]  
 	while($lenght--);

  return $string;
}

sub randomparent() {
  my $self = shift;
  my $rootdn = shift;
  my $number;
  my $known;

    # Ok, return rootdn (or undef), if there are no entries
    # we can use as parents 
  $known=$self->{'server'}->inserted();
  return $rootdn if(!$known);

    # 70% of case return a random object
  $number=$self->randomnumber(0, 9);
  return ($self->{'server'}->inserted())[$self->randomnumber(0, $known - 1)] if($number <= 6);

    # Return rootdn in any other case
  return $rootdn;
}

sub randomdn(@) {
  my $self = shift;
  my ($parent, $attrib) = @_;

  $attrib=(keys(%{$self->{'attributes'}}))[$self->randomnumber(0, keys(%{$self->{'attributes'}})-1)] if(!$attrib);

  my $generated;
  $generated = $self->{'generators'}->{$self->{'attributes'}->{$attrib}}($self, $attrib);
  $generated =~ s/([,+"\\<>;#])/\\$1/g;
  $generated =~ s/^ /\\ /;
  $generated =~ s/ $/\\ /;

  return $attrib . '=' . $generated . ($parent ? ',' . $parent : '');
}

sub randomclass() {
  my $self = shift;

  my $class=(keys(%{$self->{'structural'}}))[$self->randomnumber(0, scalar(keys(%{$self->{'structural'}}))-1)];

  return $class;
}

sub randomobject() {
  my $self = shift;
  my $parent = shift;
  my $dnattr = shift;
  my $dnvalue = shift;
  my $class = shift;

  my $dnprop;
  my @return;
  my $object;
 
    # Get a random class
  if($class) {
    $object=$self->{'structural'}->{$class};
    if(!$object) {
      Torture::Debug::message('random/warning', "unknown user supplied class: $class\n");
      return undef;
    }
  } else {
    $class=$self->randomclass();
    $object=$self->{'structural'}->{$class};
  }

    # TODO: we randomly choose to use a must, and, if no must,
    # we try with a may ...
  if(!$dnattr) {
#    print STDERR "object: " . join(' ', keys(%{$object->{'must'}})) . "\n";
    $dnattr=(keys(%{$object->{'must'}}))[$self->randomnumber(0, scalar(keys(%{$object->{'must'}}))-1)];
    if(!$dnattr) {
      $dnattr=(keys(%{$object->{'may'}}))[$self->randomnumber(0, scalar(keys(%{$object->{'may'}}))-1)];
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

    if($self->randomnumber(0, 1)) {
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

#sub randomobject() {
#  my $self = shift;
#  my $parent = shift;
#  my $dnattr = shift;
#  my $dnvalue = shift;
#  my $class = shift;
#  my @object;
#  my %values;
#
#    # Get class name 
#  if($class) {
#    $class=$self->{'schema'}->objectclass($class);
#  } else {
#    $class=$self->randomclass();
#
#    while(1) {
#      my $value;
#      my $toadd;
#
#      if(!$dnattr) {
#        my $hash = ($class->{'must'} || $class->{'may'});
#        $dnattr=${$hash}[$self->randomnumber(0, $#{$hash})];
#      }
#
#      if($dnattr) {
#	  # Ok, once we have choosen an object, verify
#	  # we can add all must attributes
#        foreach (@{$class->{'must'}}) {
#	  my $loo=$_;
#	  my $name=$loo;
#	  my $syn;
#
#            # Ok, get the syntax that should be 
#	    # used for the entry
#	  while(1) {
#	    my $att;
#	    my $oid;
#	    my $sup;
#	   
#	    $att=$self->{'schema'}->attribute($loo);
#	    $syn=undef and last if(!$att);
#	  
#	    $loo=$att->{'sup'};
#	    if($loo) {
#	      $loo=${$loo}[0];
#	      next;
#	    } 
#	    $syn=$att->{'syntax'};
#	    last;
#	  }
#
#	  last if(!$syn);
#        }
#	last if($toadd);
#      }
#
#      last if($dnattr && $toadd);
#
#      $class=$self->randomclass();
#      $dnattr=undef;
#    }
#  }
#
#  if(!$dnvalue) {
#    $dnvalue=$self->randomdn($dnattr, $parent) 
#  } else {
#    $dnvalue=$dnattr . '=' . $dnvalue . ',' . $parent;
#  }
#  $object[0] = $dnvalue;
#  
#  return undef if(!$class);
#}
#


1;
