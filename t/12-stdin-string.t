# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use Config;
use t::lib::Utils qw/save_std restore_std/;
use t::lib::Tests qw(
  capture_tests           capture_count
  capture_merged_tests    capture_merged_count
  tee_tests               tee_count
  tee_merged_tests        tee_merged_count
);
use Capture::Tiny qw/capture/;

#--------------------------------------------------------------------------#

plan skip_all => "In memory files require Perl 5.8"
  if $] < 5.008;

plan tests => 3 + capture_count() + capture_merged_count() 
                + tee_count() + tee_merged_count(); 

my $no_fork = $^O ne 'MSWin32' && ! $Config{d_fork};

#--------------------------------------------------------------------------#

# pre-load PerlIO::scalar to avoid it opening on FD 0; c.f.
# http://www.nntp.perl.org/group/perl.perl5.porters/2008/07/msg138898.html
require PerlIO::scalar; 

save_std(qw/stdin/);
ok( close STDIN, "closed STDIN" );

ok( open( STDIN, "<", \(my $stdin_buf)), "reopened STDIN to string" ); 

select STDERR; $|++;
select STDOUT; $|++;

capture_tests();
capture_merged_tests();

SKIP: {
  skip tee_count() + tee_merged_count, "requires working fork()" if $no_fork;
  tee_tests();
  tee_merged_tests();
}

$stdin_buf = "Hello World\n";
my $out = capture {
  my $line = <STDIN>;
  print $line;
};
is( $out, "Hello World\n", "can still read from STDIN" );

restore_std(qw/stdout/);

