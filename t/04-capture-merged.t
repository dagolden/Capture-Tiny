# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Capture::Tiny qw/capture_merged/;

# autoflush to try for correct output order in tests
select STDERR; $|++;
select STDOUT; $|++;

plan tests => 6; 

my ($out, $err, $label);
sub _reset { $_ = undef for ($out, $err ); 1};

#--------------------------------------------------------------------------#
# Capture STDOUT from perl
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  print "Foo";
};

$label = "perl STDOUT: ";
is($out, 'Foo', "$label captured merged");

#--------------------------------------------------------------------------#
# Capture STDERR from perl
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  print STDERR "Bar";
};

$label = "perl STDERR:";
is($out, 'Bar', "$label captured merged");

#--------------------------------------------------------------------------#
# Capture STDOUT from perl
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  print "Foo"; print STDERR "Bar";
};

$label = "perl STDOUT/STDERR:";
is($out, "FooBar", "$label captured merged");

#--------------------------------------------------------------------------#
# system -- STDOUT
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  system ($^X, '-e', 'print q{Foo}');
};

$label = "system STDOUT:";
is($out, 'Foo', "$label captured merged");

#--------------------------------------------------------------------------#
# system -- STDERR
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  system ($^X, '-e', 'print STDERR q{Bar}');
};

$label = "system STDERR:";
is($out, "Bar", "$label captured merged");

#--------------------------------------------------------------------------#
# system -- STDOUT/STDERR
#--------------------------------------------------------------------------#

_reset;
$out = capture_merged {
  system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print q{Foo}; print STDERR q{Bar}');
};

$label = "system STDOUT/STDERR:";
is($out, "FooBar", "$label captured merged");

