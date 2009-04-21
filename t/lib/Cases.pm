package t::lib::Cases;
use strict;
use warnings;
use Test::More;
use Capture::Tiny ':all';

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

sub _is_or_diff {
  my ($g,$e,$l) = @_;
  if ( $have_diff ) { eq_or_diff( $g, $e, $l ); }
  else { is( $g, $e, $l ); }
}

sub _binmode {
  my $text = shift;
  return $text eq 'unicode' ? 'binmode(STDOUT,q{:utf8}); binmode(STDERR,q{:utf8});' : '';
}

sub _set_utf8 {
  my $t = shift;
  return unless $t eq 'unicode';
  my %seen;
  my @orig_layers = grep {$_ ne 'unix' and $_ ne 'perlio' and $seen{$_}++} PerlIO::get_layers(\*STDOUT);
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
  multiline => 'First line\nSecond line\n',
  ( $] < 5.008 ? () : ( unicode => 'Hi! \x{263a}\n') ),
);

#--------------------------------------------------------------------------#
#  fcn($perl_code_string) => execute the perl in current process or subprocess
#--------------------------------------------------------------------------#

my %methods = (
  perl    => sub { eval $_[0] },
  sys  => sub { system($^X, '-e', $_[0]) },
);

#--------------------------------------------------------------------------#

my %channels = (
  stdout  => {
    output => sub { _binmode($_[0]) . "print STDOUT qq{STDOUT:$texts{$_[0]}}" },
    expect => sub { eval "qq{STDOUT:$texts{$_[0]}}", "" },
  },
  stderr  => {
    output => sub { _binmode($_[0]) . "print STDERR qq{STDERR:$texts{$_[0]}}" },
    expect => sub { "", eval "qq{STDERR:$texts{$_[0]}}" },
  },
  both    => {
    output => sub { _binmode($_[0]) . "print STDOUT qq{STDOUT:$texts{$_[0]}}; print STDERR qq{STDERR:$texts{$_[0]}}" },
    expect => sub { eval "qq{STDOUT:$texts{$_[0]}}", eval "qq{STDERR:$texts{$_[0]}}" },
  },
);

#--------------------------------------------------------------------------#

my %tests = (
  capture => {
    cnt   => 2,
    test  => sub {
      my ($m, $c, $t, $l) = @_;
      my ($got_out, $got_err) = capture {
        $methods{$m}->( $channels{$c}{output}->($t) );
      };
      my @expected = $channels{$c}{expect}->($t);
      _is_or_diff( $got_out, $expected[0], "$l|$m|$c|$t - got STDOUT" );
      _is_or_diff( $got_err, $expected[1], "$l|$m|$c|$t - got STDERR" );
    },
  },
  capture_scalar => {
    cnt   => 1,
    test  => sub {
      my ($m, $c, $t, $l) = @_;
      my $got_out = capture {
        $methods{$m}->( $channels{$c}{output}->($t) );
      };
      my @expected = $channels{$c}{expect}->($t);
      _is_or_diff( $got_out, $expected[0], "$l|$m|$c|$t - got STDOUT" );
    },
  },
  capture_merged => {
    cnt   => 2,
    test  => sub {
      my ($m, $c, $t, $l) = @_;
      my $got_out = capture_merged {
        $methods{$m}->( $channels{$c}{output}->($t) );
      };
      my @expected = $channels{$c}{expect}->($t);
      like( $got_out, qr/\Q$expected[0]\E/, "$l|$m|$c|$t - got STDOUT" );
      like( $got_out, qr/\Q$expected[1]\E/, "$l|$m|$c|$t - got STDERR" );
    },
  },
  tee => {
    cnt => 4,
    test => sub {
      my ($m, $c, $t, $l) = @_;
      my ($got_out, $got_err);
      my ($tee_out, $tee_err) = capture {
        ($got_out, $got_err) = tee {
          $methods{$m}->( $channels{$c}{output}->($t) );
        };
      };
      my @expected = $channels{$c}{expect}->($t);
      _is_or_diff( $got_out, $expected[0], "$l|$m|$c|$t - got STDOUT" );
      _is_or_diff( $tee_out, $expected[0], "$l|$m|$c|$t - tee STDOUT" );
      _is_or_diff( $got_err, $expected[1], "$l|$m|$c|$t - got STDERR" );
      _is_or_diff( $tee_err, $expected[1], "$l|$m|$c|$t - tee STDERR" );
    }
  },
  tee_scalar => {
    cnt => 3,
    test => sub {
      my ($m, $c, $t, $l) = @_;
      my ($got_out, $got_err);
      my ($tee_out, $tee_err) = capture {
        $got_out = tee {
          $methods{$m}->( $channels{$c}{output}->($t) );
        };
      };
      my @expected = $channels{$c}{expect}->($t);
      _is_or_diff( $got_out, $expected[0], "$l|$m|$c|$t - got STDOUT" );
      _is_or_diff( $tee_out, $expected[0], "$l|$m|$c|$t - tee STDOUT" );
      _is_or_diff( $tee_err, $expected[1], "$l|$m|$c|$t - tee STDERR" );
    }
  },
  tee_merged => {
    cnt => 5,
    test => sub {
      my ($m, $c, $t, $l) = @_;
      my ($got_out, $got_err);
      my ($tee_out, $tee_err) = capture {
        $got_out = tee_merged {
          $methods{$m}->( $channels{$c}{output}->($t) );
        };
      };
      my @expected = $channels{$c}{expect}->($t);
      like( $got_out, qr/\Q$expected[0]\E/, "$l|$m|$c|$t - got STDOUT" );
      like( $got_out, qr/\Q$expected[1]\E/, "$l|$m|$c|$t - got STDERR" );
      like( $tee_out, qr/\Q$expected[0]\E/, "$l|$m|$c|$t - tee STDOUT (STDOUT)" );
      like( $tee_out, qr/\Q$expected[1]\E/, "$l|$m|$c|$t - tee STDOUT (STDERR)" );
      _is_or_diff( $tee_err, '', "$l|$m|$c|$t - tee STDERR" );
    }
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
  my $todo = shift || '';
  for my $m ( keys %methods ) {
    for my $c ( keys %channels ) {
      for my $t ( keys %texts     ) {
        my @orig_layers = _set_utf8($t);
        local $TODO = "not yet supported"
          if $t eq $todo;
        $tests{$test_type}{test}->($m, $c, $t, $test_type);
        _restore_layers($t, @orig_layers);
      }
    }
  }
}

1;
