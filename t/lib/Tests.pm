package t::lib::Tests;
use strict;
use warnings;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw(
  capture_tests         capture_count
  capture_merged_tests  capture_merged_count
  tee_tests             tee_count
  tee_merged_tests      tee_merged_count
);

use Test::More;
use Capture::Tiny qw/capture capture_merged tee tee_merged/;

#--------------------------------------------------------------------------#
# Fixtures
#--------------------------------------------------------------------------#

# autoflush to try for correct output order in tests
select STDERR; $|++;
select STDOUT; $|++;

# 'large' input file
my $readme = do { local(@ARGV,$/)=qw/README/; <> } x 5;

my ($out, $err, $out2, $err2, $label);
sub _reset { $_ = undef for ($out, $err, $out2, $err2 ); 1};

#--------------------------------------------------------------------------#
# capture
#--------------------------------------------------------------------------#

sub capture_count { 19 }
sub capture_tests {
  my $sub = 'capture';

  # Capture nothing from perl
  _reset;
  ($out, $err) = capture {
    my $foo = 1;
  };

  $label = "[$sub] p-NOP:";
  is($out, '', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # Capture STDOUT from perl
  _reset;
  ($out, $err) = capture {
    print "Foo";
  };

  $label ="[$sub] p-STDOUT: ";
  is($out, 'Foo', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # Capture STDERR from perl
  _reset;
  ($out, $err) = capture {
    print STDERR "Bar";
  };

  $label ="[$sub] p-STDERR:";
  is($out, '', "$label captured stdout");
  is($err, 'Bar', "$label captured stderr");

  # Capture STDOUT/STDERR from perl
  _reset;
  ($out, $err) = capture {
    print "Foo"; print STDERR "Bar";
  };

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

  # Capture STDOUT/STDERR from perl -- large text
  _reset;
  ($out, $err) = capture {
    print $readme; print STDERR $readme;
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  is($out, $readme, "$label captured stdout");
  is($err, $readme, "$label captured stderr");

  # Capture STDOUT/STDERR from perl
  _reset;
  $out = capture {
    print "Foo"; print STDERR "Bar";
  };

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout (scalar)");

  # system -- nothing
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'my $foo = 1');
  };

  $label ="[$sub] s-NOP:";
  is($out, '', "$label captured stdout");
  is($err, '', "$label captured stderr");

  # system -- STDOUT
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print q{Foo}');
  };

  $label ="[$sub] s-STDOUT:";
  is($out, "Foo", "$label captured stdout");
  is($err, '', "$label captured stderr");

  # system -- STDERR
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print STDERR q{Bar}');
  };

  $label ="[$sub] s-STDERR:";
  is($out, '', "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

  # system -- STDOUT/STDERR
  _reset;
  ($out, $err) = capture {
    system ($^X, '-e', 'print q{Foo}; print STDERR q{Bar}');
  };

  $label ="[$sub] s-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout");
  is($err, "Bar", "$label captured stderr");

}

#--------------------------------------------------------------------------#
# capture_merged
#--------------------------------------------------------------------------#

sub capture_merged_count { 7 } 
sub capture_merged_tests {
  my $sub = 'capture_merged';

  # Capture STDOUT from perl
  _reset;
  $out = capture_merged {
    print "Foo";
  };

  $label ="[$sub] p-STDOUT: ";
  is($out, 'Foo', "$label captured merged");

  # Capture STDERR from perl
  _reset;
  $out = capture_merged {
    print STDERR "Bar";
  };

  $label ="[$sub] p-STDERR:";
  is($out, 'Bar', "$label captured merged");

  # Capture STDOUT+STDERR from perl
  _reset;
  $out = capture_merged {
    print "Foo"; print STDERR "Bar";
  };

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "FooBar", "$label captured merged");

  # Capture STDOUT+STDERR from perl - large text
  _reset;
  $out = capture_merged {
    print $readme; print STDERR $readme;
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  is($out, $readme . $readme, "$label captured merged");

  # system -- STDOUT
  _reset;
  $out = capture_merged {
    system ($^X, '-e', 'print q{Foo}');
  };

  $label ="[$sub] s-STDOUT:";
  is($out, 'Foo', "$label captured merged");

  # system -- STDERR
  _reset;
  $out = capture_merged {
    system ($^X, '-e', 'print STDERR q{Bar}');
  };

  $label ="[$sub] s-STDERR:";
  is($out, "Bar", "$label captured merged");

  # system -- STDOUT/STDERR
  _reset;
  $out = capture_merged {
    system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print q{Foo}; print STDERR q{Bar}');
  };

  $label ="[$sub] s-STDOUT/STDERR:";
  is($out, "FooBar", "$label captured merged");
}

#--------------------------------------------------------------------------#
# tee
#--------------------------------------------------------------------------#

sub tee_count { 39 }
sub tee_tests {
  my $sub = 'tee';
  # Perl - Nothing
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      my $foo = 1 ; 
    };
  };

  $label ="[$sub] p-NOP:";
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

  $label ="[$sub] p-STDOUT:";
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

  $label ="[$sub] p-STDERR:";
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

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");

  # Perl - STDOUT+STDERR - large text
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      print $readme; print STDERR $readme;
    };
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  is($out, $readme, "$label captured stdout during tee");
  is($err, $readme, "$label captured stderr during tee");
  is($out2, $readme, "$label captured stdout passed-through from tee");
  is($err2, $readme, "$label captured stderr passed-through from tee");

  # Perl - STDOUT+STDERR
  _reset;
  ($out2, $err2) = capture {
    $out = tee {
      print "Foo"; print STDERR "Bar";
    };
  };

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout during tee (scalar)");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");

  # system() - Nothing
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'my $foo = 1;');
    };
  };

  $label ="[$sub] s-NOP:";
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

  $label ="[$sub] s-STDOUT:";
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

  $label ="[$sub] s-STDERR:";
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

  $label ="[$sub] s-STDOUT/STDERR:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");
}

#--------------------------------------------------------------------------#
# tee_merged
#--------------------------------------------------------------------------#

sub tee_merged_count { 21 }
sub tee_merged_tests {
  my $sub = 'tee_merged';

  # Perl - STDOUT
  _reset;
  ($out2, $err2) = capture {
    $out = tee_merged {
      print "Foo" ; 
    };
  };

  $label ="[$sub] p-STDOUT:";
  is($out, "Foo", "$label captured merged during tee");
  is($out2, "Foo", "$label captured merged passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");


  # Perl - STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      print STDERR "Bar";
    };
  };

  $label ="[$sub] p-STDERR:";
  is($out, "Bar", "$label captured merged during tee");
  is($out2, "Bar", "$label captured merged passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");

  # Perl - STDOUT+STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      print "Foo"; print STDERR "Bar";
    };
  };

  $label ="[$sub] p-STDOUT/STDERR:";
  is($out, "FooBar", "$label captured merged during tee");
  is($out2, "FooBar", "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");

  # Perl - STDOUT+STDERR - large
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      print $readme; print STDERR $readme;
    };
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  is($out, $readme . $readme, "$label captured merged during tee");
  is($out2, $readme . $readme, "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");

  # system() - STDOUT
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      system ($^X, '-e', 'print STDOUT q{Foo};');
    };
  };

  $label ="[$sub] s-STDOUT:";
  is($out, "Foo", "$label captured merged during tee");
  is($out2, "Foo", "$label captured merged passed-through from tee");
  is($err2, '', "$label captured stderr passed-through from tee");

  # system() - STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      system ($^X, '-e', 'print STDERR q{Bar}');
    };
  };

  $label ="[$sub] s-STDERR:";
  is($out, "Bar", "$label captured merged during tee");
  is($out2, "Bar", "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");

  # system() - STDOUT+STDERR
  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print STDOUT q{Foo}; print STDERR q{Bar}');
    };
  };

  $label ="[$sub] s-STDOUT/STDERR:";
  is($out, "FooBar", "$label captured merged during tee");
  is($out2, "FooBar", "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");

}

1;
