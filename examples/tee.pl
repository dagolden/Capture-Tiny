use strict;
use warnings;

use Capture::Tiny qw/capture tee/;

print "Type some text.  Type 'exit' to quit\n";
my ($out, $err) = tee {
  while (<>) {
    last if /^exit$/;
    print "Echoing to STDOUT: $_";
    print STDERR "Echoing to STDERR: $_";
  }
};

print "\nCaptured STDOUT was:\n" . ( defined $out ? $out : 'undef' ); 
print "\nCaptured STDERR was:\n" . ( defined $err ? $err : 'undef' ); 


