# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

package Capture::Tiny;
use 5.006;
use strict;
use warnings;
use Carp ();
use Exporter ();
use IO::Handle ();
use File::Spec ();
use File::Temp qw/tempfile tmpnam/;
# Get PerlIO or fake it
BEGIN {
  eval { require PerlIO; PerlIO->can('get_layers') }
    or *PerlIO::get_layers = sub { return () };
}

our $VERSION = '0.07';
$VERSION = eval $VERSION; ## no critic
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/capture capture_merged tee tee_merged/;
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

my $IS_WIN32 = $^O eq 'MSWin32';

our $DEBUG = $ENV{PERL_CAPTURE_TINY_DEBUG};
my $DEBUGFH;
open $DEBUGFH, ">&STDERR" if $DEBUG;

*_debug = $DEBUG ? sub(@) { print {$DEBUGFH} @_ } : sub(){0};

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

sub _relayer {
  my ($fh, $layers) = @_;
  _debug("# requested layers (@{$layers}) to $fh\n");
  my %seen;
  my @unique = grep { $_ ne 'unix' and $_ ne 'perlio' and !$seen{$_}++ } @$layers;
  _debug("# applying unique layers (@unique) to $fh\n");
  binmode($fh, join(":", "", "raw", @unique));
}

sub _name {
  my $glob = shift;
  no strict 'refs'; ## no critic
  return *{$glob}{NAME};
}

sub _open {
  open $_[0], $_[1] or Carp::confess "Error from open(" . join(q{, }, @_) . "): $!";
  _debug( "# open " . join( ", " , map { defined $_ ? _name($_) : 'undef' } @_ ) . " as " . fileno( $_[0] ) . "\n" );
}

sub _close {
  close $_[0] or Carp::confess "Error from close(" . join(q{, }, @_) . "): $!";
  _debug( "# closed " . ( defined $_[0] ? _name($_[0]) : 'undef' ) . "\n" );
}

my %dup; # cache this so STDIN stays fd0
my %proxy_count;
sub _proxy_std {
  my %proxies;
  if ( ! defined fileno STDIN ) {
    $proxy_count{stdin}++;
    if (defined $dup{stdin}) {
      _open \*STDIN, "<&=" . fileno($dup{stdin});
      _debug( "# restored proxy STDIN as " . (defined fileno STDIN ? fileno STDIN : 'undef' ) . "\n" );
    }
    else {
      _open \*STDIN, "<" . File::Spec->devnull;
      _debug( "# proxied STDIN as " . (defined fileno STDIN ? fileno STDIN : 'undef' ) . "\n" );
      _open $dup{stdin} = IO::Handle->new, "<&=STDIN";
    }
    $proxies{stdin} = \*STDIN;
    binmode(STDIN, ':utf8') if $] >= 5.008;
  }
  if ( ! defined fileno STDOUT ) {
    $proxy_count{stdout}++;
    if (defined $dup{stdout}) {
      _open \*STDOUT, ">&=" . fileno($dup{stdout});
      _debug( "# restored proxy STDOUT as " . (defined fileno STDOUT ? fileno STDOUT : 'undef' ) . "\n" );
    }
    else {
      _open \*STDOUT, ">" . File::Spec->devnull;
      _debug( "# proxied STDOUT as " . (defined fileno STDOUT ? fileno STDOUT : 'undef' ) . "\n" );
      _open $dup{stdout} = IO::Handle->new, ">&=STDOUT";
    }
    $proxies{stdout} = \*STDOUT;
    binmode(STDOUT, ':utf8') if $] >= 5.008;
  }
  if ( ! defined fileno STDERR ) {
    $proxy_count{stderr}++;
    if (defined $dup{stderr}) {
      _open \*STDERR, ">&=" . fileno($dup{stderr});
      _debug( "# restored proxy STDERR as " . (defined fileno STDERR ? fileno STDERR : 'undef' ) . "\n" );
    }
    else {
      _open \*STDERR, ">" . File::Spec->devnull;
      _debug( "# proxied STDERR as " . (defined fileno STDERR ? fileno STDERR : 'undef' ) . "\n" );
      _open $dup{stderr} = IO::Handle->new, ">&=STDERR";
    }
    $proxies{stderr} = \*STDERR;
    binmode(STDERR, ':utf8') if $] >= 5.008;
  }
  return %proxies;
}

sub _unproxy {
  my (%proxies) = @_;
  _debug( "# unproxing " . join(" ", keys %proxies) . "\n" );
  for my $p ( keys %proxies ) {
    $proxy_count{$p}--;
    _debug( "# unproxied " . uc($p) . " ($proxy_count{$p} left)\n" );
    if ( ! $proxy_count{$p} ) {
      _close $proxies{$p};
      _close $dup{$p} unless $] < 5.008; # 5.6 will have already closed this as dup
      delete $dup{$p};
    }
  }
}

sub _copy_std {
  my %handles = map { $_, IO::Handle->new } qw/stdin stdout stderr/;
  _debug( "# copying std handles ...\n" );
  _open $handles{stdin},   "<&STDIN";
  _open $handles{stdout},  ">&STDOUT";
  _open $handles{stderr},  ">&STDERR";
  return \%handles;
}

sub _open_std {
  my ($handles) = @_;
  _open \*STDIN, "<&" . fileno $handles->{stdin};
  _open \*STDOUT, ">&" . fileno $handles->{stdout};
  _open \*STDERR, ">&" . fileno $handles->{stderr};
}

#--------------------------------------------------------------------------#
# private subs
#--------------------------------------------------------------------------#

sub _start_tee {
  my ($which, $stash) = @_;
  # setup pipes
  $stash->{$_}{$which} = IO::Handle->new for qw/tee reader/;
  pipe $stash->{reader}{$which}, $stash->{tee}{$which};
  _debug( "# pipe for $which\: " .  _name($stash->{tee}{$which}) . " "
    . fileno( $stash->{tee}{$which} ) . " => " . _name($stash->{reader}{$which})
    . " " . fileno( $stash->{reader}{$which}) . "\n" );
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
  if ( $IS_WIN32 ) {
    eval "use Win32API::File qw/CloseHandle GetOsFHandle SetHandleInformation fileLastError HANDLE_FLAG_INHERIT INVALID_HANDLE_VALUE/ ";
    _debug( "# Win32API::File loaded\n") unless $@;
    my $os_fhandle = GetOsFHandle( $stash->{tee}{$which} );
    _debug( "# Couldn't get OS handle: " . fileLastError() . "\n") if ! defined $os_fhandle || $os_fhandle == INVALID_HANDLE_VALUE();
    if ( SetHandleInformation( $os_fhandle, HANDLE_FLAG_INHERIT(), 0) ) {
      _debug( "# set no-inherit flag on $which tee\n" );
    }
    else {
      _debug( "# can't disable tee handle flag inherit: " . fileLastError() . "\n");
    }
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
    Carp::confess "Couldn't fork(): $!";
  }
  elsif ($pid == 0) { # child
    _debug( "# in child process ...\n" );
    untie *STDIN; untie *STDOUT; untie *STDERR;
    _close $stash->{tee}{$which};
    _debug( "# redirecting handles in child ...\n" );
    _open_std( $stash->{child}{$which} );
    _debug( "# calling exec on command ...\n" );
    exec @cmd, $stash->{flag_files}{$which};
  }
  $stash->{pid}{$which} = $pid
}

sub _files_exist { -f $_ || return 0 for @_; return 1 }

sub _wait_for_tees {
  my ($stash) = @_;
  my $start = time;
  my @files = values %{$stash->{flag_files}};
  1 until _files_exist(@files) || (time - $start > 30);
  Carp::confess "Timed out waiting for subprocesses to start" if ! _files_exist(@files);
  unlink $_ for @files;
}

sub _kill_tees {
  my ($stash) = @_;
  if ( $IS_WIN32 ) {
    _debug( "# closing handles with CloseHandle\n");
    CloseHandle( GetOsFHandle($_) ) for values %{ $stash->{tee} };
    _debug( "# waiting for subprocesses to finish\n");
    my $start = time;
    1 until wait == -1 || (time - $start > 30);
  }
  else {
    _close $_ for values %{ $stash->{tee} };
    waitpid $_, 0 for values %{ $stash->{pid} };
  }
}

sub _slurp {
  seek $_[0],0,0; local $/; return scalar readline $_[0];
}

#--------------------------------------------------------------------------#
# _capture_tee() -- generic main sub for capturing or teeing
#--------------------------------------------------------------------------#

sub _capture_tee {
  _debug( "# starting _capture_tee with (@_)...\n" );
  my ($tee_stdout, $tee_stderr, $merge, $code) = @_;
  # save existing filehandles and setup captures
  local *CT_ORIG_STDIN  = *STDIN ;
  local *CT_ORIG_STDOUT = *STDOUT;
  local *CT_ORIG_STDERR = *STDERR;
  # find initial layers
  my %layers = (
    stdin   => [PerlIO::get_layers(\*STDIN) ],
    stdout  => [PerlIO::get_layers(\*STDOUT)],
    stderr  => [PerlIO::get_layers(\*STDERR)],
  );
  _debug( "# existing layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # bypass scalar filehandles and tied handles
  my %localize;
  $localize{stdin}++,  local(*STDIN)  if grep { $_ eq 'scalar' } @{$layers{stdin}};
  $localize{stdout}++, local(*STDOUT) if grep { $_ eq 'scalar' } @{$layers{stdout}};
  $localize{stderr}++, local(*STDERR) if grep { $_ eq 'scalar' } @{$layers{stderr}};
  $localize{stdout}++, local(*STDOUT), _open( \*STDOUT, ">&=1") if tied *STDOUT && $] >= 5.008;
  $localize{stderr}++, local(*STDERR), _open( \*STDERR, ">&=2") if tied *STDERR && $] >= 5.008;
  _debug( "# localized $_\n" ) for keys %localize;
  my %proxy_std = _proxy_std();
  _debug( "# proxy std is @{ [%proxy_std] }\n" );
  my $stash = { old => _copy_std() };
  # update layers after any proxying
  %layers = (
    stdin   => [PerlIO::get_layers(\*STDIN) ],
    stdout  => [PerlIO::get_layers(\*STDOUT)],
    stderr  => [PerlIO::get_layers(\*STDERR)],
  );
  _debug( "# post-proxy layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # get handles for capture and apply existing IO layers
  $stash->{new}{$_} = $stash->{capture}{$_} = File::Temp->new for qw/stdout stderr/;
  _debug("# will capture $_ on " .fileno($stash->{capture}{$_})."\n" ) for qw/stdout stderr/;
  # tees may change $stash->{new}
  _start_tee( stdout => $stash ) if $tee_stdout;
  _start_tee( stderr => $stash ) if $tee_stderr;
  _wait_for_tees( $stash ) if $tee_stdout || $tee_stderr;
  # finalize redirection
  $stash->{new}{stderr} = $stash->{new}{stdout} if $merge;
  $stash->{new}{stdin} = $stash->{old}{stdin};
  _debug( "# redirecting in parent ...\n" );
  _open_std( $stash->{new} );
  # execute user provided code
  my $exit_code;
  {
    local *STDIN = *CT_ORIG_STDIN if $localize{stdin}; # get original, not proxy STDIN
    local *STDERR = *STDOUT if $merge; # minimize buffer mixups during $code
    _debug( "# finalizing layers ...\n" );
    _relayer(\*STDOUT, $layers{stdout});
    _relayer(\*STDERR, $layers{stderr}) unless $merge;
    _debug( "# running code $code ...\n" );
    $code->();
    $exit_code = $?; # save this for later
  }
  # restore prior filehandles and shut down tees
  _debug( "# restoring ...\n" );
  _open_std( $stash->{old} );
  _close( $_ ) for values %{$stash->{old}}; # don't leak fds
  _unproxy( %proxy_std );
  _kill_tees( $stash ) if $tee_stdout || $tee_stderr;
  # return captured output
  _relayer($stash->{capture}{stdout}, $layers{stdout});
  _relayer($stash->{capture}{stderr}, $layers{stderr}) unless $merge;
  _debug( "# slurping captured $_ with layers: @{[PerlIO::get_layers($stash->{capture}{$_})]}\n") for qw/stdout stderr/;
  my $got_out = _slurp($stash->{capture}{stdout});
  my $got_err = $merge ? q() : _slurp($stash->{capture}{stderr});
  print CT_ORIG_STDOUT $got_out if $localize{stdout} && $tee_stdout;
  print CT_ORIG_STDERR $got_err if !$merge && $localize{stderr} && $tee_stdout;
  $? = $exit_code;
  _debug( "# ending _capture_tee with (@_)...\n" );
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

    use Capture::Tiny qw/capture tee capture_merged tee_merged/;

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
properly ordered due to buffering.

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
properly ordered due to buffering.

= LIMITATIONS

== Portability

Portability is a goal, not a guarantee.  {tee} requires fork, except on
Windows where {system(1, @cmd)} is used instead.  Not tested on any
particularly esoteric platforms yet.

== PerlIO layers

Capture::Tiny does it's best to preserve PerlIO layers such as ':utf8' or
':crlf' when capturing.   Layers should be applied to STDOUT or STDERR ~before~
the call to {capture} or {tee}.

== Closed STDIN, STDOUT or STDERR

Capture::Tiny will work even if STDIN, STDOUT or STDERR have been previously
closed.  However, since they may be reopened to capture or tee output, any code
within the captured block that depends on finding them closed will, of course,
not find them to be closed.  If they started closed, Capture::Tiny will reclose
them again when the capture block finishes.

==  Scalar filehandles and STDIN, STDOUT or STDERR

If STDOUT or STDERR are reopened to scalar filehandles prior to the call to
{capture} or {tee}, then Capture::Tiny will override the output handle for the
duration of the {capture} or {tee} call and then send captured output to the
output handle after the capture is complete.  (Requires Perl 5.8)

Capture::Tiny attempts to preserve the semantics of STDIN opened to a scalar
reference.

==  Tied STDIN, STDOUT or STDERR

If STDOUT or STDERR are tied prior to the call to {capture} or {tee}, then
Capture::Tiny will attempt to override the tie for the duration of the
{capture} or {tee} call and then send captured output to the tied handle after
the capture is complete.  (Requires Perl 5.8)

Capture::Tiny does not (yet) support resending utf8 encoded data to a tied
STDOUT or STDERR handle.  Characters will appear as bytes.

Capture::Tiny attempts to preserve the semantics of tied STDIN, but capturing
or teeing when STDIN is tied is currently broken on Windows.

== Modifiying STDIN, STDOUT or STDERR during a capture

Attempting to modify STDIN, STDOUT or STDERR ~during~ {capture} or {tee} is
almost certainly going to cause problems.  Don't do that.

== No support for Perl 5.8.0

It's just too buggy when it comes to layers and UTF8.

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

Licensed under Apache License, Version 2.0 (the "License").  You may not use
this file except in compliance with the License.  A copy of the License was
distributed with this file or you may obtain a copy of the License from
http://www.apache.org/licenses/LICENSE-2.0

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

