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

use Config;
my $no_fork = $^O ne 'MSWin32' && ! $Config{d_fork};

plan 'no_plan';

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

# XXX work around a bug in perl; this needs to be called early-ish
# to avoid some sort of filehandle leak when combined with Capture::Tiny
my $qm = quotemeta("\x{263a}");

save_std(qw/stdin/);
ok( close STDIN, "closed STDIN" );

my $fd = next_fd;

run_test($_) for qw(
  capture
  capture_scalar
  capture_stdout
  capture_stderr
  capture_merged
);

if ( ! $no_fork ) {
  # prior to 5.12, PERL_UNICODE=D causes problems when STDIN is closed
  # before capturing.  No idea why.  Documented as a known issue.
  if ( $] lt '5.012' && ${^UNICODE} & 24 ) {
    diag 'Skipping tee() tests because PERL_UNICODE=D not supported';
  }
  else {
    run_test($_) for qw(
      tee
      tee_scalar
      tee_stdout
      tee_stderr
      tee_merged
    );
  }
}

if ( $] lt '5.012' && ${^UNICODE} & 24 ) {
  diag 'Skipping leak test because PERL_UNICODE=D not supported';
}
else {
  is( next_fd, $fd, "no file descriptors leaked" );
}

restore_std(qw/stdin/);

exit 0;
