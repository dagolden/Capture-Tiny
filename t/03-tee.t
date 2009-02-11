# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw/capture tee/;

plan tests => 4; 

my ($out, $err, $out2, $err2, $label);
sub _reset { $_ = '' for ($out, $err, $out2, $err2 ); 1};

# Basic test
_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    print __PACKAGE__; print STDERR __FILE__;
  };
};

$label = "tee: ";
is($out, __PACKAGE__, "$label captured stdout during tee");
is($err, __FILE__, "$label captured stderr during teed");
is($out2, __PACKAGE__, "$label captured stdout passed-through from tee");
is($err2, __FILE__, "$label captured stderr passed-through from tee");


