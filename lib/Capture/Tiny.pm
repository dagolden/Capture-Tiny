# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

package Capture::Tiny;
use 5.006;
use strict;
use warnings;
use Exporter ();
use File::Temp ();
use IO::File;
use IO::Handle;
use IPC::Open3;
use Symbol qw/qualify_to_ref/;
use Fatal qw/pipe open close/;

our $VERSION = '0.01';
$VERSION = eval $VERSION; ## no critic
our @ISA = qw/Exporter/;
our @EXPORT = qw/capture tee/;

my $use_system = $^O eq 'MSWin32';

#--------------------------------------------------------------------------#
# bulk filehandle manipulation
#--------------------------------------------------------------------------#

sub _copy_std {
  my @std = map { IO::Handle->new } 0 .. 2;
  open $std[0], "<&STDIN";
  open $std[1], ">&STDOUT";
  open $std[2], ">&STDERR";
  return @std;
}

sub _open_std {
  open STDIN , "<&" . fileno( $_[0] );
  open STDOUT, ">&" . fileno( $_[1] );
  open STDERR, ">&" . fileno( $_[2] );
}

sub _autoflush {
  select((select($_), $|=1)[0]) for @_;
}

#--------------------------------------------------------------------------#
# _win32_wait_for_start
#--------------------------------------------------------------------------#

sub _win32_wait_for_start {
}
#  my @ ) = @_;
##  while (time - $now < 10) {
##    my ($out, $err) = _capture_tee( 
##      sub { print STDOUT "test STDOUT\n"; print STDERR "test STDERR\n" } 
##    );
##    $out ||= 'undef';
##    $err ||= 'undef';
###    print { $stderr } "Got '$out' and '$err'\n";
##    Win32::Sleep( 50 );
##    last if ($out eq "test STDOUT\n") && ($err eq "test STDERR\n");
##  }
#  # signal kid process ready to write to STDERR (the capture file) 
#  kill 1, $_ for ($out_kid, $err_kid);
#  return;
#}

#--------------------------------------------------------------------------#
# _capture_tee()
#
# kids for tee must always have cloned STD handle on STDOUT and capture 
# file on STDERR -- on Windows, need to ensure readiness before enabling
# tee to capture_file on STDERR.  See _win32_wait_for_start
#--------------------------------------------------------------------------#

# command to tee output
my @cmd = ($^X, '-e', 
  '$SIG{HUP}=sub{exit}; my $f=shift; open my $flag, qq{>$f}; print {$flag} $$; close $flag; ' .
  'my $buf; while (sysread(STDIN, $buf, 2048)) { ' .
  'syswrite(STDOUT, $buf); syswrite(STDERR, $buf)}' 
);

sub _capture_tee {
  my ($code, $tee) = @_;
  my (@pids, @tees);
  my @copy_of_std = _copy_std();
  
  my $stdout_capture = File::Temp::tempfile();
  my $stderr_capture = File::Temp::tempfile();
#  my $stdout_capture = IO::File->new( 'stdout.txt', '+>' );
#  my $stderr_capture = IO::File->new( 'stderr.txt', '+>' );
  my ($stdout_tee, $stdout_reader, $stderr_tee, $stderr_reader) =
    map { IO::Handle->new } 1 .. 4;

  # if teeing, direct output to teeing subprocesses
  if ($tee) {
    pipe $stdout_reader, $stdout_tee;
    pipe $stderr_reader, $stderr_tee;
    _autoflush( $stdout_tee, $stderr_tee );
    if ( $use_system ) {
      my @flag_files = map { scalar File::Temp::tmpnam() } 0 .. 1;
      # start STDOUT listener
      _open_std( $stdout_reader, $copy_of_std[1], $stdout_capture );
      my $out_kid = system(1, @cmd, $flag_files[0]);
      push @tees, $stdout_tee;
      # start STDERR listener
      _open_std( $stderr_reader, $stderr_capture, $copy_of_std[2] );
      my $err_kid = system(1, @cmd, $flag_files[1]);
      push @pids, $out_kid, $err_kid;
      push @tees, $stderr_tee;
      # wait for the OS get the processes set up
      _open_std( $copy_of_std[0], $stdout_tee, $stderr_tee );
      1 until -f $flag_files[0] && -f $flag_files[1];
      unlink $_ for @flag_files;
    }
    else {
      die "fork not implemented yet";
      _open_std( $copy_of_std[0], $stdout_tee, $stderr_tee );
    }
    $stdout_reader->close;
    $stderr_reader->close;
  }
  # otherwise redirect output to capture file
  else {
    _open_std( $copy_of_std[0], $stdout_capture, $stderr_capture );
  }

  # run code block
  $code->();

  # restore original handles
  _open_std( @copy_of_std );

  # shut down kids
  if ( $tee ) {
    close $_ for @tees;   # they should stop when input closes
    kill 1, $_ for @pids; # tell them to hang up if they haven't stopped
    if ( $^O ne 'MSWin32' ) {
      waitpid $_, 0 for @pids;
    }
  }

  # read back capture output
  my ($got_out, $got_err) = map { seek $_, 0, 0; do {local $/; <$_>} } 
                            $stdout_capture, $stderr_capture;

  return wantarray ? ($got_out, $got_err) : $got_out;
}

#--------------------------------------------------------------------------#
# capture()
#--------------------------------------------------------------------------#

sub capture(&) {
  $_[1] = 0; # no tee
  goto \&_capture_tee;
}

#--------------------------------------------------------------------------#
# tee()
#--------------------------------------------------------------------------#

sub tee(&) {
  $_[1] = 1; # tee
  goto \&_capture_tee;
}

1;

__END__

=begin wikidoc

= NAME

Capture::Tiny - Capture STDOUT and STDERR from perl, XS or system commands

= VERSION

This documentation describes version %%VERSION%%.

= SYNOPSIS

    use Capture::Tiny;
    
    ($stdout, $stderr) = capture {
      # your code here
    };

    ($stdout, $stderr) = tee {
      # your code here 
    };

= DESCRIPTION


= USAGE

== capture

  ($stdout, $stderr) = capture \&code_ref;

== tee

  ($stdout, $stderr) = capture \&code_ref;

= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted through the web interface at 
[http://rt.cpan.org/Dist/Display.html?Queue=Capture-Tiny]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= SEE ALSO


= AUTHOR

David A. Golden (DAGOLDEN)

= COPYRIGHT AND LICENSE

Copyright (c) 2009 by David A. Golden. All rights reserved.

Licensed under Apache License, Version 2.0 (the "License").
You may not use this file except in compliance with the License.
A copy of the License was distributed with this file or you may obtain a 
copy of the License from http://www.apache.org/licenses/LICENSE-2.0

Files produced as output though the use of this software, shall not be
considered Derivative Works, but shall be considered the original work of the
Licensor.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=end wikidoc

=cut

