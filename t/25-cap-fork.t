# By Yary Hluchan with portions copied from David Golden
# Copyright (c) 2015 assigned by Yary Hluchan to David Golden.
# All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Utils qw/next_fd/;
use Capture::Tiny 'capture';

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


my ($stdout, $stderr, @result) = capture {
  if (!defined(my $child = fork)) { die "fork() failed" }
  elsif ($child == 0) {
    print "Happiness";
    print STDERR "Certainty\n";
    exit;
  }
  else {
    wait;
    print ", a parent-ly\n";
  }
  return qw(a b c);
};

is ( $stdout, "Happiness, a parent-ly\n", "got stdout");
is ( $stderr, "Certainty\n", "got stderr");
is ( "@result", "a b c" , "got result");
is ( next_fd, $fd, "no file descriptors leaked" );

exit 0;
