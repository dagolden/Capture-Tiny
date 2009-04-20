package t::lib::Cases;
use strict;
use warnings;
use Test::More;
use Capture::Tiny qw/capture/;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(
  run_test
);

my $have_diff = eval { 
  require Test::Differences; 
  Test::Differences->import;
  1;
};

sub _binmode {
  my $text = shift;
  return $text eq 'unicode' ? 'binmode(STDOUT,q{:utf8}); binmode(STDERR,q{:utf8});' : '';
}

sub _set_utf8 {
  my $t = shift;
  return unless $t eq 'unicode';
  my %seen;
  my @orig_layers = grep {$_ ne 'unix' and $seen{$_}++} PerlIO::get_layers(STDOUT);
  binmode(STDOUT, ":utf8") if fileno(STDOUT); 
  binmode(STDERR, ":utf8") if fileno(STDERR); 
  return @orig_layers;
}

sub _restore_layers {
  my ($t, @orig_layers) = @_;
  return unless $t eq 'unicode';
  binmode(STDOUT, join( ":", "", "raw", @orig_layers)) if fileno(STDOUT); 
  binmode(STDERR, join( ":", "", "raw", @orig_layers)) if fileno(STDERR); 
}

#--------------------------------------------------------------------------#

my %texts = (
  short => 'Hello World',
  multiline => "First line\nSecond line\n",
  ( $] < 5.008 ? () : ( unicode => "Hi! \x{263a}\n") ),
);

#--------------------------------------------------------------------------#
#  fcn($perl_code_string) => execute the perl in current process or subprocess
#--------------------------------------------------------------------------#

my %methods = (
  perl    => sub { eval $_[0] },
  sys  => sub { system($^X, '-e', "eval q{$_[0]}") },
);

#--------------------------------------------------------------------------#

my %channels = (
  stdout  => {
    output => sub { _binmode($_[0]) . "print STDOUT qq{STDOUT:$texts{$_[0]}}" },
    expect => sub { "STDOUT:$texts{$_[0]}", "" },
  },
  stderr  => {
    output => sub { _binmode($_[0]) . "print STDERR qq{STDERR:$texts{$_[0]}}" },
    expect => sub { "", "STDERR:$texts{$_[0]}" },
  },
  both    => {
    output => sub { _binmode($_[0]) . "print STDOUT qq{STDOUT:$texts{$_[0]}}; print STDERR qq{STDERR:$texts{$_[0]}}" },
    expect => sub { "STDOUT:$texts{$_[0]}", "STDERR:$texts{$_[0]}" },
  },
);

#--------------------------------------------------------------------------#

my %tests = (
  capture => {
    cnt   => 2,
    test  => sub {
      my ($m, $c, $t) = @_;
      my @orig_layers = _set_utf8($t);
      my ($got_out, $got_err) = capture {
        $methods{$m}->( $channels{$c}{output}->($t) );
      };
      my @expected = $channels{$c}{expect}->($t);
      if ( $have_diff ) {
        eq_or_diff( $got_out, $expected[0], "$m|$c|$t - got STDOUT" );
        eq_or_diff( $got_err, $expected[1], "$m|$c|$t - got STDERR" );
      }
      else {
        is( $got_out, $expected[0], "$m|$c|$t - got STDOUT" );
        is( $got_err, $expected[1], "$m|$c|$t - got STDERR" );
      }
      _restore_layers($t, @orig_layers);
    },
  },
);

#--------------------------------------------------------------------------#
# What I want to be able to do:
#
# test_it(
#   input => 'short',
#   channels => 'both',
#   method => 'perl'
# )

sub run_test {
  my $test_type = shift or return;
  for my $m ( keys %methods ) {
    for my $c ( keys %channels ) {
      for my $t ( keys %texts     ) {
        $tests{$test_type}{test}->($m, $c, $t);
      }
    }
  }
}

1;
