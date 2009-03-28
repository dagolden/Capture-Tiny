# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use Config;
use t::lib::Utils qw/save_std restore_std next_fd/;
use t::lib::Tests qw(
  capture_tests           capture_count
  capture_merged_tests    capture_merged_count
  tee_tests               tee_count
  tee_merged_tests        tee_merged_count
);
use t::lib::TieLC;
use Capture::Tiny qw/capture/;

#--------------------------------------------------------------------------#

#plan skip_all => "In memory files not supported before Perl 5.8"
#  if $] < 5.008;

plan tests => 4 + capture_count() + capture_merged_count() 
                + tee_count() + tee_merged_count(); 

my $no_fork = $^O ne 'MSWin32' && ! $Config{d_fork};

#--------------------------------------------------------------------------#

save_std(qw/stdin/);
tie *STDIN, 't::lib::TieLC', "<&=STDIN";
my $orig_tie = tied *STDIN;
ok( $orig_tie, "STDIN is tied" ); 

my $fd = next_fd;

select STDERR; $|++;
select STDOUT; $|++;

capture_tests();
capture_merged_tests();

SKIP: {
  skip tee_count() + tee_merged_count, "requires working fork()" if $no_fork;
  tee_tests();
  tee_merged_tests();
}

my $out = capture {
  my $line = <STDIN>;
  print $line;
};
is( $out, "hello world\n", "can still read from tied STDIN" );

is( next_fd, $fd, "no file descriptors leaked" );

is( tied *STDIN, $orig_tie, "STDIN is still tied" ); 
restore_std(qw/stdin/);

