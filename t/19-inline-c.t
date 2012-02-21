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
use Capture::Tiny ':all';
use Config;

if ( eval { require Inline; 1 } ) {
  Inline->bind( C => << 'CCODE' );
void test_inline() {
  (void)fprintf (stdout, "OUTPUT");
  (void)fprintf (stderr, "ERROR");
  (void)fflush  (NULL);
}
CCODE
}
else {
  plan skip_all => "Inline module required";
}

plan tests => 3;

local $ENV{PERL_CAPTURE_TINY_TIMEOUT} = 0; # no timeout

my $fd = next_fd;
my ($out, $err);

#--------------------------------------------------------------------------#
# Test capturing from STDERR via Inline::C
#
# c.f. https://rt.cpan.org/Public/Bug/Display.html?id=71701
#--------------------------------------------------------------------------#

($out, $err) = capture { test_inline() };
is ($out, "OUTPUT", "STDOUT from Inline::C sub");
is ($err, "ERROR",  "STDERR from Inline::C sub");

#--------------------------------------------------------------------------#
# finish
#--------------------------------------------------------------------------#

close ARGV; # opened by reading from <>
is( next_fd, $fd, "no file descriptors leaked" );

exit 0;
