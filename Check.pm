#!/usr/bin/perl -w

use strict;
package Check;

sub Die(@) {
  Check::die([caller()], 'Die', 'suicided as requested by application');
}

sub die(@) {
  my ($caller, $check, @parameters) = @_;
  my $i;

  print STDERR "assertion failed: " . $caller->[0] . ':' . $caller->[1] . ':' . $caller->[2] . "\n    (" . $check . 
  	') ' . (@parameters ? join(' ', @parameters) : '(unknown)') . "\n";

  print STDERR "---------------\nstack trace follows:\n";
  for($i=1; $i < 10; $i++) {
    my ($package, $filename, $line, $sub)=caller($i);
    last if(!defined($package));
    print STDERR '   ' . $package . ':' . $filename . ':' . $line . ':' . $sub . "\n";
  }

  CORE::die 'Aborted.';
}

sub Enum($$) {
  my ($valid, $value) = @_;
  Check::Array($valid);
  return if(grep(/^\Q$value\E$/, @{$valid}));
  Check::die([caller()], 'enum', 'invalid value: ' . ($value ? $value : '(undef)'), keys(%{$valid}));
}

sub Hash($) {
  my $value = shift;
  return if(ref($value) eq 'HASH');
  Check::die([caller()], 'hash', 'value is not a hash ref: ' . (defined($value) ? $value : '(undef)'), (defined($value) ? ref($value) : '(undef)'));
}

sub Array($) {
  my $value = shift;
  return if($value && ref($value) eq 'ARRAY');
  Check::die([caller()], 'array', 'value is not an array ref ' . ($value ? $value . ' ' . ref($value) : '(undef)'));
}

sub Value($) {
  my $value = shift;
  return if(defined($value));
  Check::die([caller()], 'value', 'undefined value');
}

sub Hinerits($$) {
  my $class=shift;
  my $name=shift;
  return if($class && $name && $name->isa($class));
  Check::die([caller()], 'hinerits', ($name ? $name : '(unknown)') .
  	' does not hinerit from ' . ($class ? $class : '(unknown)'));
}

sub Class($$) {
  my $class = shift;
  my $name = shift;
  return if($name && $class && $name =~ /$class/);
  Check::die([caller()], 'class', ($class ? $class : '(unknown)') . ' !~ ' . ($name ? $name : '(unknown)'));
}

sub Natural($) {
  my $number = shift;
  return if(defined($number) && $number =~ /[0-9]+/);
  Check::die([caller()], 'natural', ($number ? $number : '(unknown)') . ' !~ /[0-9]+/');
}

sub Func($) {
  my $func = shift;
  return if(defined($func) && ref($func) eq 'CODE');
  Check::die([caller()], 'func', ($func ? $func . ' (' . ref($func) . ')' : '(undefined)') . ' is not a function');
}

1;
