# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use t::lib::Utils qw/next_fd sig_num/;
use Capture::Tiny qw/capture/;
use Config;

plan tests => 4;

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

my $fd = next_fd;

capture {
  system($^X, '-e', 'exit 42');
};
is( $? >> 8, 42, "exit code was 42" );

SKIP: {
  skip "alarm() not available", 1
    unless $Config{d_alarm};

  capture {
    system($^X, '-e', 'alarm 1; $now = time; 1 while (time - $now < 5)');
  };
  ok( $?, '$? is non-zero' );
  is( ($^O eq 'MSWin32' ? $? >> 8 : $? & 127), sig_num('ALRM'), "caught SIGALRM" );
}

is( next_fd, $fd, "no file descriptors leaked" );
