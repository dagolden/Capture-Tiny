# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use IO::Handle;
use Utils qw/next_fd sig_num/;
use Capture::Tiny ':all';
use Config;

plan tests => 12;

local $ENV{PERL_CAPTURE_TINY_TIMEOUT} = 0; # no timeouts

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

my $fd = next_fd;
my ($out, $err, $res, @res);

#--------------------------------------------------------------------------#
# capture to array
#--------------------------------------------------------------------------#

($out, $err, @res) = capture {
  print STDOUT "foo\n";
  print STDERR "bar\n";
  return qw/one two three/;
};

is( $out, "foo\n", "capture -> STDOUT captured" );
is( $err, "bar\n", "capture -> STDERR captured" );
is_deeply( \@res, [qw/one two three/], "return values -> array" );

#--------------------------------------------------------------------------#
# capture to scalar
#--------------------------------------------------------------------------#

($out, $err, $res) = capture {
  print STDOUT "baz\n";
  print STDERR "bam\n";
  return qw/one two three/;
};

is( $out, "baz\n", "capture -> STDOUT captured" );
is( $err, "bam\n", "capture -> STDERR captured" );
is( $res, "one", "return value -> scalar" );

#--------------------------------------------------------------------------#
# capture_stdout to array
#--------------------------------------------------------------------------#

($out, @res) = capture_stdout {
  print STDOUT "foo\n";
  return qw/one two three/;
};

is( $out, "foo\n", "capture_stdout -> STDOUT captured" );
is_deeply( \@res, [qw/one two three/], "return values -> array" );

#--------------------------------------------------------------------------#
# capture_merged to array
#--------------------------------------------------------------------------#

($out, $res) = capture_merged {
  print STDOUT "baz\n";
  print STDERR "bam\n";
  return qw/one two three/;
};

like( $out, qr/baz/, "capture_merged -> STDOUT captured" );
like( $out, qr/bam/, "capture_merged -> STDERR captured" );
is( $res, "one", "return value -> scalar" );

#--------------------------------------------------------------------------#
# finish
#--------------------------------------------------------------------------#

is( next_fd, $fd, "no file descriptors leaked" );

exit 0;

