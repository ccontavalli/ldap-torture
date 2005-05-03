

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
