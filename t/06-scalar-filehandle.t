# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use Capture::Tiny qw/capture capture_merged tee tee_merged/;
use Config;
use t::lib::Utils qw/save_std restore_std/;

my $skip_tee = $^O ne 'MSWin32' && ! $Config{d_fork};

if ( $] < 5.008 ) {
  plan skip_all => "requires Perl 5.8.8 or later";
}
else {
  plan tests => 32; 
}

my ($out, $err, $out2, $err2, $label, $stdout, $stderr);
sub _reset { $_ = undef for ($out, $err, $out2, $err2, $stdout, $stderr ); 1};

#--------------------------------------------------------------------------#
# reopen STDOUT and STDERR to scalar filehandles
#--------------------------------------------------------------------------#

my @std = save_std();
open STDOUT, ">", \$stdout;
open STDERR, ">", \$stderr;
END { restore_std(@std) }

#--------------------------------------------------------------------------#
# capture perl STDOUT/STDERR
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  print "Foo"; print STDERR "Bar";
};

$label = "capture perl:";
is($out, "Foo", "$label captured stdout");
is($err, "Bar", "$label captured stderr");
is($stdout, undef, "$label scalar STDOUT filehandle");
is($stderr, undef, "$label scalar STDERR filehandle");

#--------------------------------------------------------------------------#
# capture system STDOUT/STDERR
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  system ($^X, '-e', 'print q{Foo}; print STDERR q{Bar}');
};

$label = "capture system:";
is($out, "Foo", "$label captured stdout");
is($err, "Bar", "$label captured stderr");
is($stdout, undef, "$label scalar STDOUT filehandle");
is($stderr, undef, "$label scalar STDERR filehandle");

#--------------------------------------------------------------------------#
# tee perl STDOUT+STDERR
#--------------------------------------------------------------------------#

SKIP: {
  skip 6 => "fork() not available" if $skip_tee;

  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      print "Foo"; print STDERR "Bar";
    };
  };

  $label = "tee perl:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");
  is($stdout, "Foo", "$label scalar STDOUT filehandle");
  is($stderr, "Bar", "$label scalar STDERR filehandle");
}

#--------------------------------------------------------------------------#
# tee system() STDOUT+STDERR
#--------------------------------------------------------------------------#

SKIP: {
  skip 6 => "fork() not available" if $skip_tee;

  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee {
      system ($^X, '-e', 'print STDOUT q{Foo}; print STDERR q{Bar}');
    };
  };

  $label = "tee system:";
  is($out, "Foo", "$label captured stdout during tee");
  is($err, "Bar", "$label captured stderr during tee");
  is($out2, "Foo", "$label captured stdout passed-through from tee");
  is($err2, "Bar", "$label captured stderr passed-through from tee");
  is($stdout, "Foo", "$label scalar STDOUT filehandle");
  is($stderr, "Bar", "$label scalar STDERR filehandle");
}

#--------------------------------------------------------------------------#
# capture_merged perl STDOUT/STDERR
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  print "Foo"; print STDERR "Bar";
};

$label = "capture_merged perl:";
is($out, "FooBar", "$label captured merged");
is($stdout, "FooBar", "$label scalar STDOUT filehandle");
is($stderr, "FooBar", "$label scalar STDERR filehandle");

#--------------------------------------------------------------------------#
# capture_merged system -- STDOUT/STDERR
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print q{Foo}; print STDERR q{Bar}');
};

$label = "capture_merged system:";
is($out, "FooBar", "$label captured merged");
is($stdout, "FooBar", "$label scalar STDOUT filehandle");
is($stderr, "FooBar", "$label scalar STDERR filehandle");

#--------------------------------------------------------------------------#
# tee_merged Perl - STDOUT+STDERR
#--------------------------------------------------------------------------#

SKIP: {
  skip 5 => "fork() not available" if $skip_tee;

  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      print "Foo"; print STDERR "Bar";
    };
  };

  $label = "tee_merged perl";
  is($out, "FooBar", "$label captured merged during tee");
  is($out2, "FooBar", "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");
  is($stdout, "FooBar", "$label scalar STDOUT filehandle");
  is($stderr, undef, "$label scalar STDERR filehandle");
}

#--------------------------------------------------------------------------#
# tee_merged system() - STDOUT+STDERR
#--------------------------------------------------------------------------#

SKIP: {
  skip 5 => "fork() not available" if $skip_tee;

  _reset;
  ($out2, $err2) = capture {
    ($out, $err) = tee_merged {
      system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print STDOUT q{Foo}; print STDERR q{Bar}');
    };
  };

  $label = "tee_merged system";
  is($out, "FooBar", "$label captured merged during tee");
  is($out2, "FooBar", "$label captured merged passed-through from tee");
  is($err2, "", "$label captured stderr passed-through from tee");
  is($stdout, "FooBar", "$label scalar STDOUT filehandle");
  is($stderr, undef, "$label scalar STDERR filehandle");
}



