# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw/capture tee_merged/;

# autoflush to try for correct output order in tests
select STDERR; $|++;
select STDOUT; $|++;

use Config;
if ( $^O ne 'MSWin32' && ! $Config{d_fork} ) {
  plan skip_all => "OS unsupported: requires working fork()\n";
}

plan tests => 18; 

my ($out, $err, $out2, $err2, $label);
sub _reset { $_ = undef for ($out, $err, $out2, $err2 ); 1};

#--------------------------------------------------------------------------#
# Perl - STDOUT
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  $out = tee_merged {
    print "Foo" ; 
  };
};

$label = "perl STDOUT:";
is($out, "Foo", "$label captured merged during tee");
is($out2, "Foo", "$label captured merged passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# Perl - STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee_merged {
    print STDERR "Bar";
  };
};

$label = "perl STDERR:";
is($out, "Bar", "$label captured merged during tee");
is($out2, "Bar", "$label captured merged passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");

#--------------------------------------------------------------------------#
# Perl - STDOUT+STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee_merged {
    print "Foo"; print STDERR "Bar";
  };
};

$label = "perl STDOUT/STDERR:";
is($out, "FooBar", "$label captured merged during tee");
is($out2, "FooBar", "$label captured merged passed-through from tee");
is($err2, "", "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# system() - STDOUT
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee_merged {
    system ($^X, '-e', 'print STDOUT q{Foo};');
  };
};

$label = "system STDOUT:";
is($out, "Foo", "$label captured merged during tee");
is($out2, "Foo", "$label captured merged passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# system() - STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee_merged {
    system ($^X, '-e', 'print STDERR q{Bar}');
  };
};

$label = "system STDERR:";
is($out, "Bar", "$label captured merged during tee");
is($out2, "Bar", "$label captured merged passed-through from tee");
is($err2, "", "$label captured stderr passed-through from tee");

#--------------------------------------------------------------------------#
# system() - STDOUT+STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee_merged {
    system ($^X, '-e', 'select STDERR; $|++; select STDOUT; $|++; print STDOUT q{Foo}; print STDERR q{Bar}');
  };
};

$label = "system STDOUT/STDERR:";
is($out, "FooBar", "$label captured merged during tee");
is($out2, "FooBar", "$label captured merged passed-through from tee");
is($err2, "", "$label captured stderr passed-through from tee");


