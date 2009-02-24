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

#--------------------------------------------------------------------------#

plan tests => 1 + capture_count() + capture_merged_count() 
                + tee_count() + tee_merged_count(); 

#--------------------------------------------------------------------------#

save_std(qw/stdout/);
ok( close STDOUT, "closed STDOUT" );

capture_tests();
capture_merged_tests();

SKIP: {
  if ( $^O ne 'MSWin32' && ! $Config{d_fork} ) {
    skip tee_count() + tee_merged_count, "requires working fork()";
  }
  tee_tests();
  tee_merged_tests();
}

restore_std(qw/stdout/);

