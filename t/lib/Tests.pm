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

my $have_diff = eval { 
  require Test::Differences; 
  Test::Differences->import;
  1;
};

#--------------------------------------------------------------------------#
# Fixtures
#--------------------------------------------------------------------------#

# autoflush to try for correct output order in tests
select STDERR; $|++;
select STDOUT; $|++;

# 'short' text
my $multiline = "First line\nSecond line\n";

# 'large' input file
my $readme = do { local *FH; open FH, '<README'; local $/; <FH> } ;

# unicode
my $unicode;
if ( $] >= 5.008 ) {
  $unicode = "Hi! \x{263A}\n";
}

my ($out, $err, $out2, $err2, $label);
sub _reset { $_ = undef for ($out, $err, $out2, $err2 ); 1};

#--------------------------------------------------------------------------#
# capture
#--------------------------------------------------------------------------#

sub capture_count { 25 }
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

  # Capture STDOUT/STDERR from perl -- multiline text
  _reset;
  ($out, $err) = capture {
    print $multiline; print STDERR $multiline;
  };

  $label ="[$sub] p-multi-STDOUT/STDERR:";
  if ( $have_diff ) {
    eq_or_diff($out, $multiline, "$label captured stdout"); 
    eq_or_diff($err, $multiline, "$label captured stderr");
  }
  else {
    is($out, $multiline, "$label captured stdout");
    is($err, $multiline, "$label captured stderr");
  }


  # Capture STDOUT/STDERR from perl -- unicode line
  SKIP: {
    skip "unicode support requires perl 5.8", 2 unless $] >= 5.008;
    _reset;
    my %seen;
    my @orig_layers = grep {$_ ne 'unix' and $seen{$_}++} PerlIO::get_layers(STDOUT);
    binmode(STDOUT, ":utf8") if fileno(STDOUT); 
    binmode(STDERR, ":utf8") if fileno(STDERR); 
    ($out, $err) = capture {
      print $unicode; print STDERR $unicode;
    };

    $label ="[$sub] p-unicode-STDOUT/STDERR:";
    if ( $have_diff ) {
      eq_or_diff($out, $unicode, "$label captured stdout"); 
      eq_or_diff($err, $unicode, "$label captured stderr");
    }
    else {
      is($out, $unicode, "$label captured stdout");
      is($err, $unicode, "$label captured stderr");
    }
    binmode(STDOUT, join( ":", "", "raw", @orig_layers)) if fileno(STDOUT); 
    binmode(STDERR, join( ":", "", "raw", @orig_layers)) if fileno(STDERR); 
  }


  # Capture STDOUT/STDERR from perl -- large text
  _reset;
  ($out, $err) = capture {
    print $readme; print STDERR $readme;
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  if ( $have_diff ) {
    eq_or_diff($out, $readme, "$label captured stdout"); 
    eq_or_diff($err, $readme, "$label captured stderr");
  }
  else {
    is($out, $readme, "$label captured stdout");
    is($err, $readme, "$label captured stderr");
  }

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

  # Capture STDOUT/STDERR from perl -- unicode line
  SKIP: {
    skip "unicode support requires perl 5.8", 2 unless $] >= 5.008;
    _reset;
    my %seen;
    my @orig_layers = grep {$_ ne 'unix' and $seen{$_}++} PerlIO::get_layers(STDOUT);
    binmode(STDOUT, ":utf8") if fileno(STDOUT); 
    binmode(STDERR, ":utf8") if fileno(STDERR); 
    ($out, $err) = capture {
      system ($^X, '-e', 'binmode(STDOUT,q{:utf8});binmode(STDERR,q{:utf8});print qq{Hi! \x{263a}\n}; print STDERR qq{Hi! \x{263a}\n}');
    };

    $label ="[$sub] s-unicode-STDOUT/STDERR:";
    if ( $have_diff ) {
      eq_or_diff($out, $unicode, "$label captured stdout"); 
      eq_or_diff($err, $unicode, "$label captured stderr");
    }
    else {
      is($out, $unicode, "$label captured stdout");
      is($err, $unicode, "$label captured stderr");
    }
    binmode(STDOUT, join( ":", "", "raw", @orig_layers)) if fileno(STDOUT); 
    binmode(STDERR, join( ":", "", "raw", @orig_layers)) if fileno(STDERR); 
  }

}

#--------------------------------------------------------------------------#
# capture_merged
#--------------------------------------------------------------------------#

sub capture_merged_count { 8 } 
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
  like($out, qr/Foo/, "$label captured merged STDOUT");
  like($out, qr/Bar/, "$label captured merged STDERR");

  # Capture STDOUT+STDERR from perl - large text
  _reset;
  $out = capture_merged {
    print $readme; print STDERR $readme;
  };

  $label ="[$sub] p-large-STDOUT/STDERR:";
  if ( $have_diff ) {
    eq_or_diff($out, $readme x2, "$label captured stdout"); 
  }
  else {
    is($out, $readme . $readme, "$label captured merged");
  }

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
  if ( $have_diff ) {
    eq_or_diff($out, $readme, "$label captured stdout during tee");
    eq_or_diff($err, $readme, "$label captured stderr during tee");
    eq_or_diff($out2, $readme, "$label captured stdout passed-through from tee");
    eq_or_diff($err2, $readme, "$label captured stderr passed-through from tee");
  }
  else {
    is($out, $readme, "$label captured stdout during tee");
    is($err, $readme, "$label captured stderr during tee");
    is($out2, $readme, "$label captured stdout passed-through from tee");
    is($err2, $readme, "$label captured stderr passed-through from tee");
  }

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
  if ( $have_diff ) {
    eq_or_diff($out, $readme . $readme, "$label captured merged during tee");
    eq_or_diff($out2, $readme . $readme, "$label captured merged passed-through from tee");
    eq_or_diff($err2, "", "$label captured stderr passed-through from tee");
  }
  else {
    is($out, $readme . $readme, "$label captured merged during tee");
    is($out2, $readme . $readme, "$label captured merged passed-through from tee");
    is($err2, "", "$label captured stderr passed-through from tee");
  }

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
