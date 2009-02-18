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
our @EXPORT_OK = qw/capture capture_merged tee tee_merged/;

my $use_system = $^O eq 'MSWin32';

#--------------------------------------------------------------------------#
# filehandle manipulation
#--------------------------------------------------------------------------#

sub _open {
  open $_[0], $_[1] or die "Error from open( " . join(q{, }, @_) . "): $!";
}

sub _copy_std {
  my @std = map { IO::Handle->new } 0 .. 2;
  _open $std[0], "<&STDIN";
  _open $std[1], ">&STDOUT";
  _open $std[2], ">&STDERR";
  return @std;
}

sub _open_std {
  _open \*STDIN , "<&" . fileno( $_[0] );
  _open \*STDOUT, ">&" . fileno( $_[1] );
  _open \*STDERR, ">&" . fileno( $_[2] );
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
  my ($tee, $merge, $code) = @_;
  
  my @copy_of_std = _copy_std();
  my @captures    = ( undef, scalar tempfile(), scalar tempfile() );
  my @readers     = ( undef, IO::Handle->new, IO::Handle->new );
  my @tees        = ( undef, IO::Handle->new, IO::Handle->new );
  my (@pids, @flag_files);

  # if teeing, redirect output to teeing subprocesses
  if ($tee) {
    pipe $readers[1], $tees[1];
    pipe $readers[2], $tees[2];
    _autoflush( @tees[1,2] );
    my @out_handles = ($readers[1], $copy_of_std[1], $captures[1]);
    my @err_handles = ($readers[2], $copy_of_std[2], $captures[2]);
    if ( $use_system ) {
      _open_std( @out_handles );
      push @flag_files, scalar tmpnam();
      push @pids, system(1, @cmd, $flag_files[-1]);
      if ( ! $merge ) {
        _open_std( @err_handles );
        push @flag_files, scalar tmpnam();
        push @pids, system(1, @cmd, $flag_files[-1]);
      }
    }
    else { # use fork
      push @flag_files, scalar tmpnam();
      push @pids, _fork_exec($tees[1] => @out_handles, @cmd, $flag_files[-1] );
      if ( ! $merge ) {
        push @flag_files, scalar tmpnam();
        push @pids, _fork_exec($tees[2] => @err_handles, @cmd, $flag_files[-1]);
      }
    }
    _open_std( $copy_of_std[0], $tees[1], $tees[ $merge ? 1 : 2 ] );
    # wait for the OS get the processes set up
    1 until do { my $f = 0; $f += -f $_ ? 1 : 0 for @flag_files; $f };
    unlink $_ for @flag_files;
    close $_ for ($readers[1], ($merge ? ($readers[2]) : () ) );
  }
  # if not teeing, redirect output to capture file
  else {
    _open_std( $copy_of_std[0], $captures[1], $captures[ $merge ? 1 : 2 ] );
  }

  # run code block
  $code->();
  
  # restore original handles
  _open_std( @copy_of_std );
  
  # shut down kids
  if ( $tee ) {
    close $tees[1];
    close $tees[2] if ! $merge;
    if ( $use_system ) {
      kill 1, $_ for @pids; # tell them to hang up if they haven't stopped
    }
    else {
      waitpid $_, 0 for @pids;
    }
  }

  # read back capture output
  my ($got_out, $got_err) = (q(), q());
  $got_out = do { seek $captures[1],0,0; local $/; scalar readline $captures[1] }; 
  $got_err = do { seek $captures[2],0,0; local $/; scalar readline $captures[2] } 
    if ! $merge;

  if ( $merge ) {
    return $got_out;
  }
  else {
    return wantarray ? ($got_out, $got_err) : $got_out;
  }
}

#--------------------------------------------------------------------------#
# create API subroutines from [tee flag, merge flag]               
#--------------------------------------------------------------------------#

my %api = (
  capture         => [0,0],
  capture_merged  => [0,1],
  tee             => [1,0],
  tee_merged      => [1,1],
);

for my $sub ( keys %api ) {
  my $args = join q{, }, @{$api{$sub}}; 
  eval "sub $sub(&) {unshift \@_, $ars; goto \\&_capture_tee;}"; ## no critic
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

    $merged = capture_merged {
      # your code here
    };

    $merged = tee_merged {
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

== capture_merged

  $merged = capture_merged \&code;

The {capture_merged} function works just like {capture} except STDOUT and
STDERR are merged. (Technically, STDERR is redirected to STDOUT before
executing the function.)  If no output was received, returns an empty string.
As with {capture} it may be called in block form.

Caution: STDOUT and STDERR output in the merged result are not guaranteed to be
properly ordered due to buffering

== tee

  ($stdout, $stderr) = tee \&code;
  $stdout = tee \&code;

The {tee} function works just like {capture}, except that output is captured
as well as passed on to the original STDOUT and STDERR.  As with {capture} it
may be called in block form.

== tee_merged

  $merged = tee_merged \&code;

The {tee_merged} function works just like {capture_merged} except that output
is captured as well as passed on to STDOUT.  As with {capture} it may be called
in block form.

Caution: STDOUT and STDERR output in the merged result are not guaranteed to be
properly ordered due to buffering

= LIMITATIONS

Portability is a goal, not a guarantee.  {tee} requires fork, except on 
Windows where {system(1, @cmd)} is used instead.  Not tested on any
esoteric platforms yet.  Minimal test suite so far.

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

