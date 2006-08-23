#!/usr/bin/perl -w
#

package Torture::Utils;

use RBC::Check;
use strict;

sub attribEscape($) {
  my $dn=shift;

  $dn =~ s/([,+"\\<>;#])/\\$1/g;
  $dn =~ s/^ /\\ /;
  $dn =~ s/ $/\\ /;

  return $dn; 
}

sub dnAbsolute($) {
  return !dnRelative(@_);
}

sub dnRelative($) {
  my $dn = shift;
  return !scalar($dn =~ /[^\\],/);
}

sub dnAttrib($) {
  my $dn = shift;
  RBC::Check::Value($dn);
  $dn=~/([^=]*)=/;
  return $1;
}

sub dnValue($) {
  my $dn = shift;
  RBC::Check::Value($dn);
  $dn=~/([^=]*)=(.*)/;
  return $2;
}

sub dnParent($) {
  my $dn=shift;
  RBC::Check::Value($dn);
  return ($dn =~ (/(\\,|[^,]*)*[^\\][,](.*)$/))[1];
}

sub dnChild($) {
  my $dn=shift;
  RBC::Check::Value($dn);
  return ($dn =~ (/((\\,|[^,]*)*[^\\])[,]/))[0];
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

1;
