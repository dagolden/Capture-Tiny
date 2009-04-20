# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use t::lib::Utils qw/next_fd/;
use t::lib::Cases qw/run_test/;

plan 'no_plan';

my $fd = next_fd;

run_test('tee');

is( next_fd, $fd, "no file descriptors leaked" );
