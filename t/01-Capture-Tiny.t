# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;

use Test::More 0.62;

my @api = qw(
  capture
  capture_stdout
  capture_stderr
  capture_merged
  tee
  tee_stdout
  tee_stderr
  tee_merged
);

plan tests => 2 + 2 * @api;

if ( $] eq '5.008' ) {
  BAIL_OUT("OS unsupported: Perl 5.8.0 is too buggy for Capture::Tiny");
}

require_ok( 'Capture::Tiny' );

can_ok('Capture::Tiny', $_) for @api;

ok( eval "package Foo; use Capture::Tiny ':all'; 1", "import ':all' to Foo" );

can_ok('Foo', $_) for @api;

exit 0;
