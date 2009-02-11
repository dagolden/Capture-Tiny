# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use Test::More;

my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

my $min_pc = 0.17;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my @modules = all_modules('lib');

plan tests => scalar @modules; 

for my $mod ( @modules ) {
    my $doc = "lib/$mod";
    $doc =~ s{::}{/}g;
    $doc = -f "$doc\.pod" ? "$doc\.pod" : "$doc\.pm" ;
    pod_coverage_ok( $mod, { pod_from => $doc } );
}

