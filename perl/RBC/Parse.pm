#!/usr/bin/perl -w

package RBC::Parse;

use RBC::Check;
use File::Basename;
use strict;

our @INC;

sub Cfg($$$$;@) {
    # hash similar to c => command, h => help ...
  my $cl_expand = shift;
    # hash defining parameters expected in configuration file
  my $fc_known = shift;
    # string defining name of var containing conf file
  my $fc_param = shift;
    # default name of the fie
  my $fc_name = shift;
    # where to put read configurations...
  my $config = shift;

  RBC::Check::Hash($cl_expand);
  RBC::Check::Hash($fc_known) if($fc_known);
  RBC::Check::Value($fc_param);
  RBC::Check::Hash($config);

    # Ok, here, read command line ...
  my $cfg_cmdline = {};
  my @args=CmdLine($cl_expand, $cfg_cmdline, @ARGV);

    # Now, we might:
    #   - have the name of the configuration 
    #     file supplied from the command line 

  my $cfg_preandcmd = { %{$config}, %{$cfg_cmdline} };
  my $cfg_file = {};

  if($cfg_preandcmd->{$fc_param}) {
    CfgFile($fc_known, $cfg_file, $cfg_preandcmd->{$fc_param});
  } else {
    $cfg_file->{$fc_param}=(CfgPaths($fc_known, $cfg_file, $fc_name, @_))[0];
  }

  %{$config} = (%{$config}, %{$cfg_file}, %{$cfg_cmdline});
  return @args;
}

# Try to parse configuration options from a list
# of configuration files... configuration files coming
# later on the parameters list override previous values.
sub CfgFile($$@) {
  my ($known, $config, @flist) = @_;
  my @result;

  foreach my $fname (@flist) {
    my ($file, $filename);

    if(ref($fname) eq 'GLOB') {
      $file=$fname;
    } else {
      open($file, '<', $fname) or next;
      $filename=$fname;
      push(@result, $fname);
    }

      # Read one line at a time
    while(<$file>) {
      chomp;

        # Skip comments and empty lines
      next if(/^\s*#/ || /^\s*$/);

        # A configuration file is made by 
        # lines like var=value
      my ($var, $value) = (/([^=\s]*)\s*=\s*(.*)/);

        # Discard malformed lines
      die('malformed input at ' . ($filename ? $filename . ':' : 'line ') . $. . " -- '$_'.\n")
	      if(!$var || !$value);

      die('unknown parameter ' . $var . ' at ' . ($filename ? $filename . ':' : 'line ') . $. . " -- '$_'.\n" )
	      if($known && !defined($known->{$var}));

        # Skip lines where the ' or " in the value are unbalanced 
      die("unbalanced \"'\" or \"\"\" at " . ($filename ? $filename . ':' : 'line ') . $. . " -- '$_'.\n")
	      if($value =~ /^\s*'[^']*\s*$/ || $value =~ /^\s*"([^"]*|\\")*\s*$/);

        # values can be enclosed in simple or double quotes
      ($value =~ /^\s*'([^']*)'\s*$/) or 
	      ($value =~ /^\s*"([^"]*|\\")"\s*$/) or 
	      ($value =~ /^\s*(.*?)\s*$/);
      $value=$1;

        # Unquote \ escapes
      $value =~ s/\\(.)/$1/g;

        # Replace variables
      $value =~ s/\$([A-z0-9_]+)/$config->{$1}/eg;
      $value =~ s/\$\{([A-z0-9_]+)\}/$config->{$1}/eg;

        # Finally, store variable
      eval { $config->{$var}=$value; };
    }
  }

  return @result;
}

  # load configuration file
sub CfgPaths($$$@) {
  my ($known, $config, $filename, @paths) = @_;

  RBC::Check::Hash($known) if($known);
  RBC::Check::Hash($config);
  RBC::Check::Value($filename);

  my @files;

  if(!@paths || !$paths[0]) {
    @paths=(dirname($0), @INC);
    push(@files, $ENV{'HOME'} . '/.' . $filename);
  }

    # Try to open configuration file
  push(@files, ($_ =~ /^~$/ ? $ENV{'HOME'} . '/.' . $filename : $_ . '/' . $filename))
	 foreach(@paths);

  return CfgFile($known, $config, @files);
}

sub CmdLine($$@) {
  my $opts = shift;
  my $config = shift;
  my @args = (@_ ? @_ : @ARGV);
  my $known;

  RBC::Check::Hash($opts);
  RBC::Check::Hash($config);

  foreach (keys(%{$opts})) {
    $known->{$opts->{$_}}=$_;
  }
 
  while(my $arg=shift(@args)) {
    my $value;
    if($arg =~ s/^--//) {
      $arg=~s/=(.*)$//;
      $value=$1;

      die("unknown option: --$arg\n") if(!$known->{$arg});
      $config->{$arg}=($value ? $value : "");
    } elsif($arg =~ s/^-//) {
      $arg=~s/[ \t]+(.*)$// if(!($arg =~ s/=(.*)$//));
      if(defined($1)) {
        $value=$1;
      } elsif($args[0] && $args[0] !~ /^-/) {
        $value=shift(@args);
      } 

      foreach my $letter (split(//, $arg)) {
        die("unknown option: -$letter\n") if(!$opts->{$letter});
        $config->{$opts->{$letter}}=($value ? $value : "");
      }
    } else {
      return ($arg, @args);
    }
  }
}

1;
