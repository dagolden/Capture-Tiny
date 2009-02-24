package t::lib::Tests;
use strict;
use warnings;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw(
  capture_tests capture_test_count
  tee_tests     tee_test_count
);

use Test::More;
use Capture::Tiny qw/capture tee/;

my ($out, $err, $out2, $err2);
sub _reset { $_ = undef for ($out, $err, $out2, $err2 ); 1};

sub capture_test_count { 16 }

sub capture_tests {
  my $label;

  # Capture nothing from perl
  _reset;
  ($out, $err) = capture {
    my $foo = 1;
  };

  $label = "perl NOP: ";
  is($out, '', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # Capture STDOUT from perl
  _reset;
  ($out, $err) = capture {
    print "Foo";
  };

  $label = "perl STDOUT: ";
  is($out, 'Foo', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # Capture STDERR from perl
  _reset;
  ($out, $err) = capture {
    print STDERR "Bar";
  };

  $label = "perl STDERR:";
  is($out, '', "$label captured stdout");
  is($err, 'Bar', "$label captured stderr");

  # Capture STDOUT/STDERR from perl
  _reset;
  ($out, $err) = capture {
    print "Foo"; print STDERR "Bar";
  };

  $label = "perl STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

  # system -- nothing
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'my $foo = 1');
  };

  $label = "system NOP:";
  is($out, '', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # system -- STDOUT
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print q{Foo}');
  };

  $label = "system STDOUT:";
  is($out, "Foo", "$label captured stdout");
  is($err, '', "$label captured stderr");

  # system -- STDERR
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print STDERR q{Bar}');
  };

  $label = "system STDERR:";
  is($out, '', "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

  # system -- STDOUT/STDERR
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print q{Foo}; print STDERR q{Bar}');
  };

  $label = "system STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

}

sub tee_test_count { 32 }
sub tee_tests {
  my $label;
  # Perl - Nothing
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      my $foo = 1 ; 
    };
  };

  $label = "perl NOP:";
  is($out, '', "$label captured stdout during tee");
  is($err, '', "$label captured stderr during tee");
  is($out2, '', "$label captured stdout passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");

  # Perl - STDOUT
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      print "Foo" ; 
    };
  };

  $label = "perl STDOUT:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, '', "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");

  # Perl - STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      print STDERR "Bar";
    };
  };

  $label = "perl STDERR:";
  is($out, "", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");

  # Perl - STDOUT+STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      print "Foo"; print STDERR "Bar";
    };
  };

  $label = "perl STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");

  # system() - Nothing
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'my $foo = 1;');
    };
  };

  $label = "system NOP:";
  is($out, '', "$label captured stdout during tee");
  is($err, '', "$label captured stderr during tee");
  is($out2, '', "$label captured stdout passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");


  # system() - STDOUT
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'print STDOUT q{Foo};');
    };
  };

  $label = "system STDOUT:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, '', "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");


  # system() - STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'print STDERR q{Bar}');
    };
  };

  $label = "system STDERR:";
  is($out, "", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");

  # system() - STDOUT+STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'print STDOUT q{Foo}; print STDERR q{Bar}');
    };
  };

  $label = "system STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");
}


1;
