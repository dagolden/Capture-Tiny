use Capture::Tiny qw[ capture ];

my ( $out, $err ) =
 eval { capture { print STDERR "hello\n"; print STDOUT "there\n"; die("foo\n" ) } };

print STDERR "STDERR:\nout=$out\nerr=$err\n\$@=$@";
print STDOUT "STDOUT:\nout=$out\nerr=$err\n\$@=$@";

open FILE, '>ttt.log' or die( "error opening logfile\n" );
print FILE "FILE:\nout=$out\nerr=$err\n\$@=$@\n";
close FILE;
