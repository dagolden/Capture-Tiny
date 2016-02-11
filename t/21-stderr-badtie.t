# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Utils qw/save_std restore_std next_fd/;
use Cases qw/run_test/;
use TieEvil;

use Config;
my $no_fork = ($^O ne 'MSWin32' || $^O ne 'Cygwin') && ! $Config{d_fork};

plan skip_all => "capture needs Perl 5.8 for tied STDERR"
  if $] < 5.008;

plan 'no_plan';

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;
binmode($builder->todo_output, ':utf8') if $] >= 5.008;

tie *STDERR, 'TieEvil';
my $orig_tie = tied *STDERR;
ok( $orig_tie, "STDERR is tied" );

my $fd = next_fd;

run_test($_, '', 'skip_utf8') for qw(
  capture
  capture_scalar
  capture_stdout
  capture_stderr
  capture_merged
);

if ( ! $no_fork ) {
  run_test($_, '', 'skip_utf8') for qw(
    tee
    tee_scalar
    tee_stdout
    tee_stderr
    tee_merged
  );
}

is( next_fd, $fd, "no file descriptors leaked" );
is( tied *STDERR, $orig_tie, "STDERR is still tied" );

exit 0;
