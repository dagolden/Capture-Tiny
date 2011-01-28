# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Utils qw/next_fd sig_num/;
use Capture::Tiny qw/capture tee/;
use Config;

plan tests => 5;

local $ENV{PERL_CAPTURE_TINY_TIMEOUT} = 0; # no timeouts

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

my $fd = next_fd;
$@ = "initial error";
my ($out, $err) = capture { print "foo\n" };
is( $@, 'initial error', "Initial \$\@ not lost during capture" );


($out, $err) = capture {
  eval {
    tee {
      local $|=1;
      print STDOUT "foo\n";
      print STDERR "bar\n";
      die "Fatal error in capture\n";
    }
  };
};
my $error = $@;

is( $error, "Fatal error in capture\n", "\$\@ preserved after capture" );
is( $out, "foo\n", "STDOUT still captured" );
is( $err, "bar\n", "STDOUT still captured" );

is( next_fd, $fd, "no file descriptors leaked" );

exit 0;

