#!/usr/bin/perl -w

use strict;
use Carp;

use Torture::Server::LDAP;
use Torture::Server::Perl;
use Torture::Schema::LDAP;
use Torture::Random::Attributes;
use Torture::Random::Generator;
use Torture::Random::Primitive::rand;
use Torture::Operations;
use Torture::Killer;

use Data::Dumper;
use RBC::Parse;
use Pod::Usage;

=pod

=head1 NAME

killer.pl - LDAP server killer, stresser and squeezer

=head1 SYNOPSIS

killer.pl [OPTIONS] COMMAND ...

 Commands:
   test-random
     Options:
       --attempts -a ATTEMPTS
       --seed -e SEED
       --stats -t
       --dump -d [DUMPFILE]
       --style -s STYLE
       --iterations -i ITERATIONS

   test-play

   dump-schema [OPTIONS] [FILE]
     Options:
       --mangle -m
       --style -s STYLE
       --parsed -p

   dump-config

 Options:
   --ldap-rootdn -b
   --ldap-server -s
   --ldap-binddn -D
   --ldap-options -o
   --ldap-bindauth -u
   --config -c

=head1 OPTIONS

=cut

package Client;

sub new() {
  my $class = shift;
  my $config = shift;
  my $self = {};

  RBC::Check::Hash($config);

  # Ok, connect to a real LDAP server...
  $self->{'config'}=$config;
  $self->{'server'}=Torture::Server::LDAP->new($config);
  $self->{'schema'}=Torture::Schema::LDAP->new($self->{'server'}->handle()); 

  bless($self, $class);
  return $self;
}

sub cmd_test_random() {
  my $self=shift;
  my @known = (
   'attempts|a=i', # implemented
   'seed|e=i', # implemented
   'stats|t!', # implemented
   'dump|d:s', # implemented
   'style|s=i', # implemented
   'iterations|i=i' # implemented
   ); 
  my %config=('iterations' => '0');
  my $missed=0;

  eval { RBC::Parse::NewCmdLine(\%config, \@known, \@_); };
  exit(&Pod::Usage::pod2usage($@)) if($@);

    # Ok, set output style...
  if(defined($config{'style'})) {
    $Data::Dumper::Indent=$config{'style'};
  } else {
    $Data::Dumper::Indent=0;
  }

  my $random=Torture::Random::Primitive::rand->new($config{'seed'});  
  my $attrib=Torture::Random::Attributes->new($random);
  my $tnodes=Torture::Server::Perl->new($self->{'config'});	

    # Set maximum number of attempts, heither from here or configuration file
  $self->{'config'}->{'gen-attempts'} = $config{'attempts'} || $self->{'config'}->{'attempts'} ||
                        $self->{'config'}->{'gen_attempts'} || 10;

  my $generator=Torture::Random::Generator->new($self->{'config'}, $self->{'schema'}, $random, $attrib, $tnodes);
  my $operations=Torture::Operations->new($self->{'config'}, $self->{'server'}, $tnodes, $random, $generator);

#  my $killer=Torture::Killer->new($random, $operations);
  if(!$config{'dump'} && exists($config{'dump'})) {
    $config{'dump'}=*STDOUT;
  } elsif($config{'dump'}) {
    my $file;
    open($file, '>', $config{'dump'}) or
       die("couldn't open " . $config{'dump'} . " -- $!\n");
    $config{'dump'}=$file;
  }

  my ($context, $status);
  my @ops=$operations->known();
  for(my $i=0; $i < $config{'iterations'};) {
    my $rand=$random->element($random->context($context, 'operation'), \@ops);

    my @args=$operations->o_prepare($random->context($context, $i), $rand);
    if(!@args || !$args[0]) {
      $missed++;
      next;
    }

    print {$config{'dump'}} '$op{' . $i . '}=' . 
      &Data::Dumper::Dumper([$rand->{'aka'}, @args]) . ";\n" if($config{'dump'});

    my $result=$operations->o_perform($random->context($context, $i), $rand, @args);
    $status=$operations->o_verify($rand, $result, \@args);

    if($status) {
      print "status=\"error\"\n";
      print "error=\"$status\"\n";
      print "operation=\"". $rand->{'aka'} . "\"\n";
      print "failed=" . &Data::Dumper::Dumper(\@args) . "\n";
      last;
    }
    $i++;
  }


  print 'Hint: maybe you forgot to specify the -i parameter?' . "\n" if(!$config{'iterations'});
  print "status=\"completed\"\n" if(!$status);
  print 'seed="' . $random->seed() . "\"\n";

  if($config{'stats'}) {
    print '========= Statistics' . "\n";
    my $total;
    my %stats=$operations->stats();
    foreach (keys %stats) {
      print STDERR $_ . ': ' . $stats{$_} . "\n";
      $total+=$stats{$_};
    }
    print '======' . "\n";
  
    print  $total . ' operations were performed.' . "\n";
    print  $missed . ' operations were missed.' . "\n";
  }

  return $status ? 0 : 3;
}

sub cmd_test_play() {
  my $self=shift;
  my @known = (
   'stats|t!', # implemented
   'dump|d:s', # implemented
   'style|s=i', # implemented
   ); 
  my %config=('iterations' => '0');
  my $missed=0;

    # parse command line arguments
  my @args;
  eval { @args=RBC::Parse::NewCmdLine(\%config, \@known, \@_); };
  exit(&Pod::Usage::pod2usage($@)) if($@);

    # try to load a simple script
  my $data;
  if($args[0]) {
    my $file;
    open($file, '<', $args[0]) or
	   die("couldn't open file $args[0] -- $!\n");
    local $/; # enable localized slurp mode
    $data = <$file>;
  } else {
    print STDERR 'WARNING: reading from STDIN ... press ctrl+c to abort' . "\n";
    local $/; # enable localized slurp mode
    $data = <STDIN>;
  }
    # try to eval data...
  my %op;
  eval "$data";
  die($@) if($@);

    # Ok, set output style...
  if(defined($config{'style'})) {
    $Data::Dumper::Indent=$config{'style'};
  } else {
    $Data::Dumper::Indent=0;
  }

    # Prepare ldap server...
  my $tnodes=Torture::Server::Perl->new($self->{'config'});	
  my $operations=Torture::Operations->new($self->{'config'}, $self->{'server'}, $tnodes);

    # prepare to dump operations
  if(!$config{'dump'} && exists($config{'dump'})) {
    $config{'dump'}=*STDOUT;
  } elsif($config{'dump'}) {
    my $file;
    open($file, '>', $config{'dump'}) or
       die("couldn't open " . $config{'dump'} . " -- $!\n");
    $config{'dump'}=$file;
  }

  my ($status, $i) = (undef, 0);
  my %index=$operations->index();
  foreach (sort {$a <=> $b} (keys(%op))) {
    my $operation=$index{${$op{$_}}[0]};

    if(!$operation) {
      print "status=\"error\"\n";
      print "error=\"unknown operation " . $op{$_} . "\"\n";
      last;
    }

    my @args=@{$op{$_}}[1 .. $#{$op{$_}}];
    print {$config{'dump'}} '$op{' . $i++ . '}=' . 
      &Data::Dumper::Dumper([$operation->{'aka'}, @args]) . ";\n" if($config{'dump'});

    my $result=$operations->o_perform(undef, $operation, @args);
    $status=$operations->o_verify($operation, $result, \@args);

    if($status) {
      print "status=\"error\"\n";
      print "error=\"$status\"\n";
      print "operation=\"". $operation->{'aka'} . "\"\n";
      print "failed=" . &Data::Dumper::Dumper([@args]) . "\n";
      last;
    }
  }


  print "status=\"completed\"\n" if(!$status);
  if($config{'stats'}) {
    print '========= Statistics' . "\n";
    my $total=0;
    my %stats=$operations->stats();
    foreach (keys %stats) {
      print STDERR $_ . ': ' . $stats{$_} . "\n";
      $total+=$stats{$_};
    }
    print '======' . "\n";
  
    print  $total . ' operations were performed.' . "\n";
  }

  return $status ? 0 : 3;
}

sub cmd_dump_schema() {
  my $self = shift;

  my %config = ( 'mangle' => '1' );
  my @known = (
   'style|s=i',
   'parsed|p!',
   'mangle|m!');

  my @args;
  eval { @args=RBC::Parse::NewCmdLine(\%config, \@known, \@_); };
  exit(&Pod::Usage::pod2usage($@)) if($@);

    # Ok, set output style...
  if(defined($config{'style'})) {
    $Data::Dumper::Indent=$config{'style'};
  } elsif($args[0]) {
    $Data::Dumper::Indent=0;
  }

    # If output has to be parsed, parse it...
  if($config{'parsed'}) {
    my $attrib=Torture::Random::Attributes->new();
    $self->{'schema'}->prepare($attrib->known());
  }

    # Dump data out...
  $Data::Dumper::Varname='schema';
  if(!$args[0]) {
    my $output=&Data::Dumper::Dumper($self->{'schema'});
    $output =~ s/(\t|      )/ /gm if($config{'mangle'});
    print $output;
    return 0;
  }

  $Data::Dumper::Varname='schema';
  open(my $fd, '>', $args[0]) or die("unable to open $args[0] -- $!\n");
  print $fd '' . &Data::Dumper::Dumper($self->{'schema'});

  return 0;
}

sub cmd_dump_config() {
  my $self = shift;

  foreach my $key (keys(%{$self->{'config'}})) {
    print $key . '=' . $self->{'config'}->{$key} . "\n";
  }

  return 0;
}

my @known = (
  'ldap-rootdn|b=s',
  'ldap-server|s=s',
  'ldap-binddn|D=s',
  'ldap-options|o=s',
  'ldap-bindauth|u=s',
  'gen-attempts|a=i',
  'op-dump|d!',
  'op-stats|t!',
  'op-dumpstyle|S=i',
  'config|c=s');

my %config = (
  'ldap-rootdn' => 'dc=test,dc=it',
  'ldap-server' => '127.0.0.1',
  'ldap-binddn' => '',
  'ldap-options' => '',
  'ldap-bindauth' => '',
  'perl-rootdn' => 'dc=test,dc=it',
  'gen-attempts' => 30,
  'op-verbose' => 0,
  'op-dump' => 1,
  'op-stats' => 1,
  'op-dumpstyle' => 0,
  'config' => 'torturer.conf'
  );

my @args;
eval { @args=RBC::Parse::NewCfg(\@known, \%config, 'config', 'torturer.conf', \%config); };
exit(&Pod::Usage::pod2usage($@)) if($@);
my $command = shift(@args);

my %commands = (
  'test-random' => \&Client::cmd_test_random,
  'test-play' => \&Client::cmd_test_play,
  'dump-schema' => \&Client::cmd_dump_schema,
  'dump-config' => \&Client::cmd_dump_config,
);

sub int() {
  Carp::confess("interrupt received");
}
$SIG{INT}=\&int;

exit(&Pod::Usage::pod2usage("no command provided!")) if(!$command);
exit(&Pod::Usage::pod2usage("unknown command: $command")) if(!$commands{$command});

my $client=Client->new(\%config);
my $status=&{$commands{$command}}($client, @args);


exit($status);
