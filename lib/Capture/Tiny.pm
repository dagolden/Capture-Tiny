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
use IO::Handle ();
use File::Temp qw/tempfile tmpnam/;

our $VERSION = '0.03';
$VERSION = eval $VERSION; ## no critic
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/capture tee/;

my $use_system = $^O eq 'MSWin32';

#--------------------------------------------------------------------------#
# Error messages
#--------------------------------------------------------------------------#

sub _redirect_err { return "Error redirecting $_[0]: $!" }

#--------------------------------------------------------------------------#
# bulk filehandle manipulation
#--------------------------------------------------------------------------#

sub _copy_std {
  my @std = map { IO::Handle->new } 0 .. 2;
  open $std[0], "<&STDIN"   or die _redirect_err("STDIN" );
  open $std[1], ">&STDOUT"  or die _redirect_err("STDOUT");
  open $std[2], ">&STDERR"  or die _redirect_err("STDERR");
  return @std;
}

sub _open_std {
  open STDIN , "<&" . fileno( $_[0] ) or die _redirect_err("STDIN" );
  open STDOUT, ">&" . fileno( $_[1] ) or die _redirect_err("STDOUT");
  open STDERR, ">&" . fileno( $_[2] ) or die _redirect_err("STDERR");
}

sub _autoflush {
  select((select($_), $|=1)[0]) for @_;
}

#--------------------------------------------------------------------------#
# _fork_exec
#--------------------------------------------------------------------------#

sub _fork_exec {
  my ($tee, $in, $out, $err, @cmd) = @_;
  my $pid = fork; # XXX needs error handling
  if ( not defined $pid ) {
    die "Couldn't fork(): $!";
  }
  elsif ($pid == 0) { # child
    untie *STDIN;
    untie *STDOUT;
    untie *STDOUT;
    close $tee;
    _open_std( $in, $out, $err );
    exec @cmd;
  }
  return $pid
}

#--------------------------------------------------------------------------#
# command to tee output -- the argument is a filename that must
# be opened to signal that the process is ready to receive input.
# This is annoying, but seems to be the best that can be done on Win32
# so I use it as a simple, portable IPC technique
#--------------------------------------------------------------------------#
my @cmd = ($^X, '-e', '$SIG{HUP}=sub{exit}; ' 
  . 'if( my $fn=shift ){ open my $fh, qq{>$fn}; print {$fh} $$; close $fh;} '
  . 'my $buf; while (sysread(STDIN, $buf, 2048)) { '
  . 'syswrite(STDOUT, $buf); syswrite(STDERR, $buf)}' 
);

#--------------------------------------------------------------------------#
# _capture_tee()
#--------------------------------------------------------------------------#

sub _capture_tee {
  my ($code, $tee) = @_;
  
  my @copy_of_std = _copy_std();
  my @captures    = ( undef, scalar tempfile(), scalar tempfile() );
  my @readers     = ( undef, IO::Handle->new, IO::Handle->new );
  my @tees        = ( undef, IO::Handle->new, IO::Handle->new );
  my @pids;

  # if teeing, redirect output to teeing subprocesses
  if ($tee) {
    pipe $readers[1], $tees[1];
    pipe $readers[2], $tees[2];
    _autoflush( @tees[1,2] );
    my @out_handles = ($readers[1], $copy_of_std[1], $captures[1]);
    my @err_handles = ($readers[2], $copy_of_std[2], $captures[2]);
    my @flag_files = ( scalar tmpnam(), scalar tmpnam() );
    if ( $use_system ) {
      _open_std( @out_handles );
      push @pids, system(1, @cmd, $flag_files[0]);
      _open_std( @err_handles );
      push @pids, system(1, @cmd, $flag_files[1]);
    }
    else { # use fork
      push @pids, _fork_exec($tees[1] => @out_handles, @cmd, $flag_files[0] );
      push @pids, _fork_exec($tees[2] => @err_handles, @cmd, $flag_files[1] );
    }
    _open_std( $copy_of_std[0], @tees[1,2] );
    # wait for the OS get the processes set up
    1 until -f $flag_files[0] && -f $flag_files[1];
    unlink $_ for @flag_files;
    close $_ for @readers[1,2];
  }
  # if not teeing, redirect output to capture file
  else {
    _open_std( $copy_of_std[0], @captures[1,2] );
  }

  # run code block
  $code->();
  
  # restore original handles
  _open_std( @copy_of_std );
  
  # shut down kids
  if ( $tee ) {
    close $_ for @tees[1,2];   # kids should stop when input closes
    if ( $use_system ) {
      kill 1, $_ for @pids; # tell them to hang up if they haven't stopped
    }
    else {
      waitpid $_, 0 for @pids;
    }
  }

  # read back capture output
  my ($got_out, $got_err) = 
    map { do { seek $_,0,0; local $/; scalar <$_> } } @captures[1,2];

  return wantarray ? ($got_out, $got_err) : $got_out;
}

#--------------------------------------------------------------------------#
# capture()
#--------------------------------------------------------------------------#

sub capture(&) { ## no critic
  $_[1] = 0; # no tee
  goto \&_capture_tee;
}

#--------------------------------------------------------------------------#
# tee()
#--------------------------------------------------------------------------#

sub tee(&) { ## no critic
  $_[1] = 1; # tee
  goto \&_capture_tee;
}

1;

__END__

=begin wikidoc

= NAME

Capture::Tiny - Capture STDOUT and STDERR from Perl, XS or external programs

= VERSION

This documentation describes version %%VERSION%%.

= SYNOPSIS

    use Capture::Tiny qw/capture tee/;
    
    ($stdout, $stderr) = capture {
      # your code here
    };

    ($stdout, $stderr) = tee {
      # your code here 
    };

= DESCRIPTION

Capture::Tiny provides a simple, portable way to capture anything sent to
STDOUT or STDERR, regardless of whether it comes from Perl, from XS code or
from an external program.  Optionally, output can be teed so that it is
captured while being passed through to the original handles.  Yes, it even
works on Windows.  Stop guessing which of a dozen capturing modules to use in
any particular situation and just use this one.

This module was heavily inspired by [IO::CaptureOutput], which provides 
similar functionality without the ability to tee output and with more
complicated code and API.

= USAGE

The following functions are available.  None are exported by default.

== capture

  ($stdout, $stderr) = capture \&code;
  $stdout = capture \&code;

The {capture} function takes a code reference and returns what is sent to
STDOUT and STDERR.  In scalar context, it returns only STDOUT.  If no output
was received, returns an empty string.  Regardless of context, all output is
captured -- nothing is passed to the existing handles.

It is prototyped to take a subroutine reference as an argument. Thus, it
can be called in block form:

  ($stdout, $stderr) = capture {
    # your code here ...
  };

== tee

  ($stdout, $stderr) = tee \&code;
  $stdout = tee \&code;

The {tee} function works just like {capture}, except that output is captured
as well as passed on to the original STDOUT and STDERR.  As with {capture} it
may be called in block form.

= LIMITATIONS

Portability is a goal, not a guarantee.  {tee} requires fork, except on 
Windows where {system(1, @cmd)} is used instead.  Not tested on any
esoteric platforms yet.  Minimal test suite so far.

No support for merging STDERR with STDOUT.  This may be added in the future.

= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted through the web interface at 
[http://rt.cpan.org/Dist/Display.html?Queue=Capture-Tiny]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= SEE ALSO

This is a selection of CPAN modules that provide some sort of output capture,
albeit with various limitations that make them appropriate only in particular
circumstances.  I'm probably missing some.  The long list is provided to show
why I felt Capture::Tiny was necessary. 

* [IO::Capture]
* [IO::Capture::Extended]
* [IO::CaptureOutput]
* [IPC::Capture]
* [IPC::Cmd]
* [IPC::Open2]
* [IPC::Open3]
* [IPC::Open3::Simple]
* [IPC::Open3::Utils]
* [IPC::Run]
* [IPC::Run::SafeHandles]
* [IPC::Run::Simple]
* [IPC::Run3]
* [IPC::System::Simple]
* [Tee]
* [IO::Tee]
* [File::Tee]
* [Filter::Handle]
* [Tie::STDERR]
* [Tie::STDOUT]
* [Test::Output]

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

