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
use IO::File;
use File::Temp qw/tmpnam/;
use Utils qw/next_fd sig_num/;
use Capture::Tiny ':all';
use Config;

plan tests => 9;

local $ENV{PERL_CAPTURE_TINY_TIMEOUT} = 0; # no timeouts

my $builder = Test::More->builder;
binmode($builder->failure_output, ':utf8') if $] >= 5.008;

my $fd = next_fd;
my ($out, $err, $res, @res);

#--------------------------------------------------------------------------#
# capture to array
#--------------------------------------------------------------------------#

my $temp_out = tmpnam();
my $temp_err = tmpnam();

ok( !-e $temp_out, "Temp out '$temp_out' doesn't exist" );
ok( !-e $temp_err, "Temp out '$temp_err' doesn't exist" );

my $out_fh = IO::File->new($temp_out, "w+");
my $err_fh = IO::File->new($temp_err, "w+");

capture {
  print STDOUT "foo\n";
  print STDERR "bar\n";
} stdout => $out_fh, stderr => $err_fh;

$out_fh->close;
$err_fh->close;

is( scalar do {local (@ARGV,$/) = $temp_out; <>} , "foo\n",
  "captured STDOUT to custom handle (IO::File)"
);
is( scalar do {local (@ARGV,$/) = $temp_err; <>} , "bar\n",
  "captured STDERR to custom handle (IO::File)"
);

unlink $_ for $temp_out, $temp_err;

#--------------------------------------------------------------------------#

ok( !-e $temp_out, "Temp out '$temp_out' doesn't exist" );
ok( !-e $temp_err, "Temp out '$temp_err' doesn't exist" );

open $out_fh, "+>", $temp_out;
open $err_fh, "+>", $temp_err;

capture {
  print STDOUT "foo\n";
  print STDERR "bar\n";
} stdout => $out_fh, stderr => $err_fh;

$out_fh->close;
$err_fh->close;

is( scalar do {local (@ARGV,$/) = $temp_out; <>} , "foo\n",
  "captured STDOUT to custom handle (GLOB)"
);
is( scalar do {local (@ARGV,$/) = $temp_err; <>} , "bar\n",
  "captured STDERR to custom handle (GLOB)"
);

unlink $_ for $temp_out, $temp_err;

#--------------------------------------------------------------------------#
# finish
#--------------------------------------------------------------------------#

close ARGV; # opened by reading from <>
is( next_fd, $fd, "no file descriptors leaked" );

exit 0;

