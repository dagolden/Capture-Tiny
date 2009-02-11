# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw/capture/;

plan tests => 2; 

my ($out, $err, $label);
sub _reset { $_ = '' for ($out, $err ); 1};

# Basic test
_reset;
($out, $err) = capture {
  print __PACKAGE__; print STDERR __FILE__;
};

$label = "capture: ";
is($out, __PACKAGE__, "$label captured stdout");
is($err, __FILE__, "$label captured stderr");


