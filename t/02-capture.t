# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw/capture/;

plan tests => 12; 

my ($out, $err, $label);
sub _reset { $_ = undef for ($out, $err ); 1};

#--------------------------------------------------------------------------#
# Capture STDOUT from perl
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  print "Foo";
};

$label = "perl STDOUT: ";
is($out, 'Foo', "$label captured stdout");
is($err, '', "$label captured stderr");

#--------------------------------------------------------------------------#
# Capture STDERR from perl
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  print STDERR "Bar";
};

$label = "perl STDERR:";
is($out, '', "$label captured stdout");
is($err, 'Bar', "$label captured stderr");

#--------------------------------------------------------------------------#
# Capture STDOUT from perl
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  print "Foo"; print STDERR "Bar";
};

$label = "perl STDOUT/STDERR:";
is($out, "Foo", "$label captured stdout");
is($err, "Bar", "$label captured stderr");

#--------------------------------------------------------------------------#
# system -- STDOUT
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  system ($^X, '-e', 'print q{Foo}');
};

$label = "system STDOUT:";
is($out, "Foo", "$label captured stdout");
is($err, '', "$label captured stderr");

#--------------------------------------------------------------------------#
# system -- STDERR
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  system ($^X, '-e', 'print STDERR q{Bar}');
};

$label = "system STDERR:";
is($out, '', "$label captured stdout");
is($err, "Bar", "$label captured stderr");

#--------------------------------------------------------------------------#
# system -- STD
#--------------------------------------------------------------------------#

_reset;
($out, $err) = capture {
  system ($^X, '-e', 'print q{Foo}; print STDERR q{Bar}');
};

$label = "system STDOUT/STDERR:";
is($out, "Foo", "$label captured stdout");
is($err, "Bar", "$label captured stderr");

