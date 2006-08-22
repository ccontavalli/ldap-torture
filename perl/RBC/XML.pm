#!/usr/bin/perl -w

package RBC::XML;
use strict;

sub new(@) {
  my $self = {};
  my $name = shift;
  my $file = shift;
  my $encoding = shift;

  $self->{'file'}=$file;
  $self->{'encoding'}=($encoding ? $encoding : 'UTF-8');

  print $file '<?xml version="1.0" encoding="' . $self->{'encoding'} . '"?>' . "\n\n";
  select((select($file), $| = 1)[0]);  

  bless($self);
  return $self;
}

sub encode_element($) {
  my $self=shift;
  my $string=shift;

  return $string;
}

sub encode_attribute($) {
  my $self=shift;
  my $string=shift;

  return $string;
}

sub encode_value($) {
  my $self=shift;
  my $string=shift;

  return '' if(!defined($string));

  $string =~ s/&/&amp;/g;
  $string =~ s/'/&apos;/g;
  $string =~ s/"/&quot;/g;
  $string =~ s/</&lt;/g;
  $string =~ s/>/&gt;/g;

  return $string;
}

sub encode_data($) {
  my $self=shift;
  my $string=shift;

    # Now, escape all leftover entities
  $string =~ s/&/&amp;/ig;
  $string =~ s/</&lt;/ig;
  $string =~ s/>/&gt;/ig;

  return $string;
}

sub felement($$%) {
  my $self=shift;
  my $name=shift;
  my $value=shift;

  $self->open($name, @_);
  $self->data($value || '');
  $self->closenow();
}

sub element($$%) {
  my $self=shift;
  my $name=shift;
  my $value=shift;

  return if(!$value || $value =~ /^\s*$/);

  $self->open($name, @_);
  $self->data($value);
  $self->closenow();
}

sub xelement($$%) {
  my $self=shift;
  my $name=shift;
  my $value=shift;

  return if(!$value || $value =~ /^\s*$/);

  $self->open($name, @_);
  $self->xml($value);
  $self->closenow();
}



sub leaf($%) {
  my $self=shift;
  my $name=shift;
  my %attributes=@_;

  my $file=$self->{'file'};

  print $file '  ' x $#{$self->{'open'}};
  print $file '<' . $self->encode_element($name);
  foreach (keys %attributes) {
    print $file ' ' . $self->encode_attribute($_) . '="' . $self->encode_value($_) . '"';
  }
  print $file ' />';
}

sub open($%) {
  my $self=shift;
  my $name=shift;
  my %attributes=@_;

  my $file=$self->{'file'};

  print $file "\n" . '  ' x $#{$self->{'open'}};
  print $file '<' . $self->encode_element($name);
  foreach (keys %attributes) {
    print $file ' ' . $self->encode_attribute($_) . '="' . $self->encode_value($attributes{$_}) . '"';
  }
  print $file '>';

  push(@{$self->{'open'}}, $name);
}

sub xml($) {
  my $self=shift;
  my $data=shift;
  my $file=$self->{'file'};

  print $file $data;
}

sub data($) {
  my $self=shift;
  my $data=shift;
  my $file=$self->{'file'};

  print $file $self->encode_data($data);
}

sub close() {
  my $self=shift;
  my $toclose=shift;

  if($toclose) {
    my $p=1;
    for(my $i=$#{$self->{'open'}}; $i >= 0; $i --, $p++) {
      if($self->{'open'}->[$i] eq $toclose) {
        for(; $p > 0; $p--) {
          my $name=pop(@{$self->{'open'}});
          $self->oclose($name);
	}

	return;
      }
    }

    return;
  }

  my $name=pop(@{$self->{'open'}});
  return $self->oclose($name);
}

sub oclose() {
  my $self=shift;
  my $tag=shift;
  my $file=$self->{'file'};

  die 'empty tag to close' if(!$tag);
  print $file "\n" . ('  ' x ($#{$self->{'open'}}) );
  print $file '</' . $self->encode_element($tag) . ">";
}

sub closenow() {
  my $self=shift;
  my $file=$self->{'file'};
  print $file '</' . $self->encode_element(pop(@{$self->{'open'}})) . '>';
}

sub done($) {
  my $self=shift;
  my $file=$self->{'file'};

  while(my $element=pop(@{$self->{'open'}})) {
    print $file '  ' x ($#{$self->{'open'}}+1);
    print $file '</' . $self->encode_element($element) . ">\n";
  }
}

sub DESTROY() {
  my $self=shift;
  my $file=$self->{'file'};

  while(my $element=pop(@{$self->{'open'}})) {
    print $file '  ' x ($#{$self->{'open'}}+1);
    print $file '</' . $self->encode_element($element) . ">\n";
  }
}

1;
