#!/usr/bin/perl -w

use strict;
package Check;

sub Die(@) {
  Check::die([caller()], 'Die', 'suicided as requested by application');
}

sub die(@) {
  my ($caller, $check, @parameters) = @_;
  die $caller->[0] . ':' . $caller->[1] . ':' . $caller->[2] . ' (' . $check . 
  	') assertion failed: ' . (@parameters ? join(' ', @parameters) : '(unknown)') . "\n";
}

sub Enum($$) {
  my ($valid, $value) = @_;
  Check::Array($valid);
  return if(grep(/^\Q$value\E$/, @{$valid}));
  Check::die([caller()], 'enum', 'invalid value: ' . ($value ? '(undef)' : $value), keys(%{$valid}));
}

sub Hash($) {
  my $value = shift;
  return if(ref($value) eq 'HASH');
  Check::die([caller()], 'hash', 'value is not a hash ref: ' . ($value ? '(undef)' : $value), ref($value));
}

sub Array($) {
  my $value = shift;
  return if(ref($value) eq 'ARRAY');
  Check::die([caller()], 'hash', 'value is not a hash ref: ' . ($value ? '(undef)' : $value), ref($value));
}

sub Value($) {
  my $value = shift;
  return if(defined($value));
  Check::die([caller()], 'value', 'undefined value');
}

sub Hinerits($$) {
  my $class=shift;
  my $name=shift;
  return if($class && $name && $class->isa($name));
  Check::die([caller()], 'hinerits', ($class ? $class : '(unknown)') .
  	' does not hinerit from ' . ($name ? $name : '(unknown)'));
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
