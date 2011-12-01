# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Utils qw/next_fd/;
use Cases qw/run_test/;

use Config;
my $no_fork = $^O ne 'MSWin32' && ! $Config{d_fork};
if ( $no_fork ) {
  plan skip_all => 'tee() requires fork';
}
else {
  plan 'no_plan';
}

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

my $fd = next_fd;

run_test('tee');
run_test('tee_scalar');
run_test('tee_stdout');
run_test('tee_stderr');
run_test('tee_merged');

is( next_fd, $fd, "no file descriptors leaked" );

exit 0;
