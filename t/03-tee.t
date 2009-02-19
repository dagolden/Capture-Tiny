# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw/capture tee/;

use Config;
if ( $^O ne 'MSWin32' && ! $Config{d_fork} ) {
  plan skip_all => "OS unsupported: requires working fork()\n";
}

plan tests => 32; 

my ($out, $err, $out2, $err2, $label);
sub _reset { $_ = undef for ($out, $err, $out2, $err2 ); 1};

#--------------------------------------------------------------------------#
# Perl - Nothing
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    my $foo = 1 ; 
  };
};

$label = "perl NOP:";
is($out, '', "$label captured stdout during tee");
is($err, '', "$label captured stderr during tee");
is($out2, '', "$label captured stdout passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# Perl - STDOUT
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    print "Foo" ; 
  };
};

$label = "perl STDOUT:";
is($out, "Foo", "$label captured stdout during tee");
is($err, '', "$label captured stderr during tee");
is($out2, "Foo", "$label captured stdout passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# Perl - STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    print STDERR "Bar";
  };
};

$label = "perl STDERR:";
is($out, "", "$label captured stdout during tee");
is($err, "Bar", "$label captured stderr during tee");
is($out2, "", "$label captured stdout passed-through from tee");
is($err2, "Bar", "$label captured stderr passed-through from tee");

#--------------------------------------------------------------------------#
# Perl - STDOUT+STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    print "Foo"; print STDERR "Bar";
  };
};

$label = "perl STDOUT/STDERR:";
is($out, "Foo", "$label captured stdout during tee");
is($err, "Bar", "$label captured stderr during tee");
is($out2, "Foo", "$label captured stdout passed-through from tee");
is($err2, "Bar", "$label captured stderr passed-through from tee");

#--------------------------------------------------------------------------#
# system() - Nothing
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    system ($^X, '-e', 'my $foo = 1;');
  };
};

$label = "system NOP:";
is($out, '', "$label captured stdout during tee");
is($err, '', "$label captured stderr during tee");
is($out2, '', "$label captured stdout passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# system() - STDOUT
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    system ($^X, '-e', 'print STDOUT q{Foo};');
  };
};

$label = "system STDOUT:";
is($out, "Foo", "$label captured stdout during tee");
is($err, '', "$label captured stderr during tee");
is($out2, "Foo", "$label captured stdout passed-through from tee");
is($err2, '', "$label captured stderr passed-through from tee");


#--------------------------------------------------------------------------#
# system() - STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    system ($^X, '-e', 'print STDERR q{Bar}');
  };
};

$label = "system STDERR:";
is($out, "", "$label captured stdout during tee");
is($err, "Bar", "$label captured stderr during tee");
is($out2, "", "$label captured stdout passed-through from tee");
is($err2, "Bar", "$label captured stderr passed-through from tee");

#--------------------------------------------------------------------------#
# system() - STDOUT+STDERR
#--------------------------------------------------------------------------#

_reset;
($out2, $err2) = capture {
  ($out, $err) = tee {
    system ($^X, '-e', 'print STDOUT q{Foo}; print STDERR q{Bar}');
  };
};

$label = "system STDOUT/STDERR:";
is($out, "Foo", "$label captured stdout during tee");
is($err, "Bar", "$label captured stderr during tee");
is($out2, "Foo", "$label captured stdout passed-through from tee");
is($err2, "Bar", "$label captured stderr passed-through from tee");


