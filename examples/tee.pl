use strict;
use warnings;

use Capture::Tiny qw/capture tee/;

my ($out, $err) = tee {
    print "On STDOUT: " . __PACKAGE__ . "\n"; 
    print STDERR "On STDERR: " . __FILE__ . "\n";
  };

print "Captured STDOUT was '" . ( defined $out ? $out : 'undef' ) . "'\n"; 
print "Captured STDERR was '" . ( defined $err ? $err : 'undef' ) . "'\n"; 


