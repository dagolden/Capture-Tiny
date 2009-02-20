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
# command to tee output -- the argument is a filename that must
# be opened to signal that the process is ready to receive input.
# This is annoying, but seems to be the best that can be done
# as a simple, portable IPC technique
#--------------------------------------------------------------------------#
my @cmd = ($^X, '-e', '$SIG{HUP}=sub{exit}; ' 
  . 'if( my $fn=shift ){ open my $fh, qq{>$fn}; print {$fh} $$; close $fh;} '
  . 'my $buf; while (sysread(STDIN, $buf, 2048)) { '
  . 'syswrite(STDOUT, $buf); syswrite(STDERR, $buf)}' 
);

#--------------------------------------------------------------------------#
# filehandle manipulation
#--------------------------------------------------------------------------#

sub _open {
  open $_[0], $_[1] or die "Error from open(" . join(q{, }, @_) . "): $!";
}

sub _copy_std {
  my %handles = map { $_, IO::Handle->new } qw/stdin stdout stderr/;
  _open $handles{stdin},   "<&STDIN";
  _open $handles{stdout},  ">&STDOUT";
  _open $handles{stderr},  ">&STDERR";
  return \%handles;
}

sub _open_std {
  my ($handles) = @_;
  _open \*STDIN , "<&" . fileno( $handles->{stdin} );
  _open \*STDOUT, ">&" . fileno( $handles->{stdout} );
  _open \*STDERR, ">&" . fileno( $handles->{stderr} );
}

#--------------------------------------------------------------------------#
# private subs
#--------------------------------------------------------------------------#

sub _start_tee {
  my ($which, $stash) = @_;
  # setup pipes
  $stash->{$_}{$which} = IO::Handle->new for qw/tee reader/;
  pipe $stash->{reader}{$which}, $stash->{tee}{$which};
  select((select($stash->{tee}{$which}), $|=1)[0]); # autoflush
  # setup desired redirection for parent and child
  $stash->{new}{$which} = $stash->{tee}{$which};
  $stash->{child}{$which} = {
    stdin   => $stash->{reader}{$which},
    stdout  => $stash->{old}{$which},
    stderr  => $stash->{capture}{$which},
  };
  # flag file is used to signal the child is ready
  $stash->{flag_files}{$which} = scalar tmpnam();
  # execute @cmd as a separate process
  if ( $use_system ) {
    _open_std( $stash->{child}{$which} );
    $stash->{pid}{$which} = system(1, @cmd, $stash->{flag_files}{$which});
    # not restoring std here as it all gets redirected again shortly anyway
  }
  else { # use fork
    _fork_exec( $which, $stash );
  }
}

sub _fork_exec {
  my ($which, $stash) = @_;
  my $pid = fork; 
  if ( not defined $pid ) {
    die "Couldn't fork(): $!";
  }
  elsif ($pid == 0) { # child
    untie *STDIN; untie *STDOUT; untie *STDERR;
    close $stash->{tee}{$which};
    _open_std( $stash->{child}{$which} );
    exec @cmd, $stash->{flag_files}{$which};
  }
  $stash->{pid}{$which} = $pid
}

sub _wait_for_tees { 
  my ($stash) = @_;
  for my $file ( values %{$stash->{flag_files}} ) { 
    1 until -f $file; # XXX should add alarm and timeout 
    unlink $file
  };
}

sub _kill_tees {
  my ($stash) = @_;
  close $_ for values %{ $stash->{tee} };
  if ( $use_system ) {
    eval { Win32::Sleep(25) }; # 25 ms pause for output to get flushed, I hope
    kill 1, $_ for values %{ $stash->{pid} }; # shut them down hard
  }
  else {
    waitpid $_, 0 for values %{ $stash->{pid} };
  }
}

sub _slurp { 
  seek $_[0],0,0; local $/; scalar readline $_[0]; 
}

#--------------------------------------------------------------------------#
# _capture_tee() -- generic main sub for capturing or teeing
#--------------------------------------------------------------------------#

sub _capture_tee {
  my ($tee_stdout, $tee_stderr, $merge, $code) = @_;
  # save existing filehandles and setup captures
  my $stash = { old => _copy_std() };
  $stash->{new}{$_} = $stash->{capture}{$_} = tempfile() for qw/stdout stderr/;
  # tees may change $stash->{new}
  _start_tee( stdout => $stash ) if $tee_stdout;
  _start_tee( stderr => $stash ) if $tee_stderr;
  _wait_for_tees( $stash ) if $tee_stdout || $tee_stderr;
  # finalize redirection
  $stash->{new}{stderr} = $stash->{new}{stdout} if $merge;
  $stash->{new}{stdin} = $stash->{old}{stdin};
  _open_std( $stash->{new} );
  # execute user provided code
  $code->();
  # restore prior filehandles and shut down tees
  _open_std( $stash->{old} );
  _kill_tees( $stash ) if $tee_stdout || $tee_stderr;
  # return captured output
  my $got_out = _slurp($stash->{capture}{stdout});
  my $got_err = $merge ? q() : _slurp($stash->{capture}{stderr});
  return $got_out if $merge;
  return wantarray ? ($got_out, $got_err) : $got_out;
}

#--------------------------------------------------------------------------#
# create API subroutines from [tee STDOUT flag, tee STDERR, merge flag]               
#--------------------------------------------------------------------------#

my %api = (
  capture         => [0,0,0],
  capture_merged  => [0,0,1],
  tee             => [1,1,0],
  tee_merged      => [1,0,1], # don't tee STDOUT since merging
);

for my $sub ( keys %api ) {
  my $args = join q{, }, @{$api{$sub}}; 
  eval "sub $sub(&) {unshift \@_, $args; goto \\&_capture_tee;}"; ## no critic
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

Please report any bugs or feature requests using the CPAN Request Tracker.  
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

