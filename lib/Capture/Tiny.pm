use 5.006;
use strict;
use warnings;
package Capture::Tiny;
# ABSTRACT: Capture STDOUT and STDERR from Perl, XS or external programs
use Carp ();
use Exporter ();
use IO::Handle ();
use File::Spec ();
use File::Temp qw/tempfile tmpnam/;
use Scalar::Util qw/reftype/;
# Get PerlIO or fake it
BEGIN {
  local $@;
  eval { require PerlIO; PerlIO->can('get_layers') }
    or *PerlIO::get_layers = sub { return () };
}

#--------------------------------------------------------------------------#
# create API subroutines and export them
# [do STDOUT flag, do STDERR flag, do merge flag, do tee flag]
#--------------------------------------------------------------------------#

my %api = (
  capture         => [1,1,0,0],
  capture_stdout  => [1,0,0,0],
  capture_stderr  => [0,1,0,0],
  capture_merged  => [1,0,1,0], # don't do STDERR since merging
  tee             => [1,1,0,1],
  tee_stdout      => [1,0,0,1],
  tee_stderr      => [0,1,0,1],
  tee_merged      => [1,0,1,1], # don't do STDERR since merging
);

for my $sub ( keys %api ) {
  my $args = join q{, }, @{$api{$sub}};
  eval "sub $sub(&) {unshift \@_, $args; goto \\&_capture_tee;}"; ## no critic
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = keys %api;
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

#--------------------------------------------------------------------------#
# constants and fixtures
#--------------------------------------------------------------------------#

my $IS_WIN32 = $^O eq 'MSWin32';

our $DEBUG = $ENV{PERL_CAPTURE_TINY_DEBUG};

my $DEBUGFH;
open $DEBUGFH, "> DEBUG" if $DEBUG;

*_debug = $DEBUG ? sub(@) { print {$DEBUGFH} @_ } : sub(){0};

our $TIMEOUT = 30;

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
  _debug("# requested layers (@{$layers}) for @{[fileno $fh]}\n");
  my %seen = ( unix => 1, perlio => 1 ); # filter these out
  my @unique = grep { !$seen{$_}++ } @$layers;
  _debug("# applying unique layers (@unique) to @{[fileno $fh]}\n");
  binmode($fh, join(":", ":raw", @unique));
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
    local $@;
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

my $have_usleep = eval "use Time::HiRes 'usleep'; 1";
sub _files_exist {
  return 1 if @_ == grep { -f } @_;
  Time::HiRes::usleep(1000) if $have_usleep;
  return 0;
}

sub _wait_for_tees {
  my ($stash) = @_;
  my $start = time;
  my @files = values %{$stash->{flag_files}};
  my $timeout = defined $ENV{PERL_CAPTURE_TINY_TIMEOUT}
              ? $ENV{PERL_CAPTURE_TINY_TIMEOUT} : $TIMEOUT;
  1 until _files_exist(@files) || ($timeout && (time - $start > $timeout));
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
  my ($name, $fh) = @_;
  _debug( "# slurping captured $name with layers: @{[PerlIO::get_layers($fh)]}\n");
  seek $fh,0,0; local $/; return scalar readline $fh
}

#--------------------------------------------------------------------------#
# _capture_tee() -- generic main sub for capturing or teeing
#--------------------------------------------------------------------------#

sub _capture_tee {
  _debug( "# starting _capture_tee with (@_)...\n" );
  my ($do_stdout, $do_stderr, $do_merge, $do_tee, $code) = @_;
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
  # get layers from underlying glob of tied filehandles if we can
  # (this only works for things that work like Tie::StdHandle)
  $layers{stdout} = [PerlIO::get_layers(tied *STDOUT)]
    if tied(*STDOUT) && (reftype tied *STDOUT eq 'GLOB');
  $layers{stderr} = [PerlIO::get_layers(tied *STDERR)]
    if tied(*STDERR) && (reftype tied *STDERR eq 'GLOB');
  _debug( "# tied object corrected layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # bypass scalar filehandles and tied handles
  my %localize;
  $localize{stdin}++,  local(*STDIN)
    if grep { $_ eq 'scalar' } @{$layers{stdin}};
  $localize{stdout}++, local(*STDOUT)
    if $do_stdout && grep { $_ eq 'scalar' } @{$layers{stdout}};
  $localize{stderr}++, local(*STDERR)
    if ($do_stderr || $do_merge) && grep { $_ eq 'scalar' } @{$layers{stderr}};
  $localize{stdout}++, local(*STDOUT), _open( \*STDOUT, ">&=1")
    if $do_stdout && tied *STDOUT && $] >= 5.008;
  $localize{stderr}++, local(*STDERR), _open( \*STDERR, ">&=2")
    if ($do_stderr || $do_merge) && tied *STDERR && $] >= 5.008;
  _debug( "# localized $_\n" ) for keys %localize;
  # proxy any closed/localized handles so we don't use fds 0, 1 or 2
  my %proxy_std = _proxy_std();
  _debug( "# proxy std: @{ [%proxy_std] }\n" );
  # update layers after any proxying
  $layers{stdin}  = [PerlIO::get_layers(\*STDIN)]  if $proxy_std{stdin};
  $layers{stdout} = [PerlIO::get_layers(\*STDOUT)] if $proxy_std{stdout};
  $layers{stderr} = [PerlIO::get_layers(\*STDERR)] if $proxy_std{stderr};
  _debug( "# post-proxy layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # store old handles and setup handles for capture
  my $stash = { old => _copy_std() };
  $stash->{new} = { %{$stash->{old}} }; # default to originals
  $stash->{new}{stdout} = $stash->{capture}{stdout} = File::Temp->new if $do_stdout;
  $stash->{new}{stderr} = $stash->{capture}{stderr} = File::Temp->new if $do_stderr;
  _debug("# will capture stdout on " . fileno($stash->{capture}{stdout})."\n" ) if $do_stdout;
  _debug("# will capture stderr on " . fileno($stash->{capture}{stderr})."\n" ) if $do_stderr;
  # get handles for capture and apply existing IO layers
  # tees may change $stash->{new}
  _start_tee( stdout => $stash ) if $do_stdout && $do_tee;
  _start_tee( stderr => $stash ) if $do_stderr && $do_tee;
  _wait_for_tees( $stash ) if $do_tee;
  # finalize redirection
  $stash->{new}{stderr} = $stash->{new}{stdout} if $do_merge;
  _debug( "# redirecting in parent ...\n" );
  _open_std( $stash->{new} );
  # execute user provided code
  my ($exit_code, $inner_error, $outer_error, @result);
  {
    local *STDIN = *CT_ORIG_STDIN if $localize{stdin}; # get original, not proxy STDIN
    local *STDERR = *STDOUT if $do_merge; # minimize buffer mixups during $code
    _debug( "# finalizing layers ...\n" );
    _relayer(\*STDOUT, $layers{stdout}) if $do_stdout;
    _relayer(\*STDERR, $layers{stderr}) if $do_stderr;
    _debug( "# running code $code ...\n" );
    local $@;
    eval { @result = $code->(); $inner_error = $@ };
    $exit_code = $?; # save this for later
    $outer_error = $@; # save this for later
  }
  # restore prior filehandles and shut down tees
  _debug( "# restoring filehandles ...\n" );
  _open_std( $stash->{old} );
  _close( $_ ) for values %{$stash->{old}}; # don't leak fds
  _unproxy( %proxy_std );
  _debug( "# killing tee subprocesses ...\n" ) if $do_tee;
  _kill_tees( $stash ) if $do_tee;
  # return captured output
  _relayer($stash->{capture}{stdout}, $layers{stdout}) if $do_stdout;
  _relayer($stash->{capture}{stderr}, $layers{stderr}) if $do_stderr;
  my $got_out = $do_stdout ? _slurp('stdout' => $stash->{capture}{stdout}) : q();
  my $got_err = $do_stderr ? _slurp('stderr' => $stash->{capture}{stderr}) : q();
  _debug("# slurped " . length($got_out) . " bytes from stdout\n");
  _debug("# slurped " . length($got_err) . " bytes from stderr\n");
  print CT_ORIG_STDOUT $got_out
    if $do_stdout && $do_tee && $localize{stdout};
  print CT_ORIG_STDERR $got_err
    if $do_stderr && $do_tee && $localize{stderr};
  $? = $exit_code;
  $@ = $inner_error if $inner_error;
  die $outer_error if $outer_error;
  _debug( "# ending _capture_tee with (@_)...\n" );
  my @return;
  push @return, $got_out if $do_stdout;
  push @return, $got_err if $do_stderr;
  push @return, @result;
  return wantarray ? @return : $return[0];
}

1;

__END__

=begin wikidoc

= SYNOPSIS

  use Capture::Tiny ':all';

  ($stdout, $stderr, @result) = capture {
    # your code here
  };

  $stdout = capture_stdout { ... };
  $stderr = capture_stderr { ... };
  $merged = capture_merged { ... };

  ($stdout, $stderr) = tee {
    # your code here
  };

  $stdout = tee_stdout { ... };
  $stderr = tee_stderr { ... };
  $merged = tee_merged { ... };

= DESCRIPTION

Capture::Tiny provides a simple, portable way to capture almost anything sent
to STDOUT or STDERR, regardless of whether it comes from Perl, from XS code or
from an external program.  Optionally, output can be teed so that it is
captured while being passed through to the original handles.  Yes, it even
works on Windows (usually).  Stop guessing which of a dozen capturing modules
to use in any particular situation and just use this one.

= USAGE

The following functions are available.  None are exported by default.

== capture

  ($stdout, $stderr, @result) = capture \&code;
  $stdout = capture \&code;

The {capture} function takes a code reference and returns what is sent to
STDOUT and STDERR as well as any return values from the code reference.  In
scalar context, it returns only STDOUT.  If no output was received for a
handle, it returns an empty string for that handle.  Regardless of calling
context, all output is captured -- nothing is passed to the existing handles.

It is prototyped to take a subroutine reference as an argument. Thus, it
can be called in block form:

  ($stdout, $stderr) = capture {
    # your code here ...
  };

Note that the coderef is evaluated in list context.  If you wish to force
scalar context on the return value, you must use the {scalar} keyword.

  ($stdout, $stderr, $count) = capture {
    my @list = qw/one two three/;
    return scalar @list; # $count will be 3
  };

== capture_stdout

  ($stdout, @result) = capture_stdout \&code;
  $stdout = capture_stdout \&code;

The {capture_stdout} function works just like {capture} except only
STDOUT is captured.  STDERR is not captured.

== capture_stderr

  ($stderr, @result) = capture_stderr \&code;
  $stderr = capture_stderr \&code;

The {capture_stderr} function works just like {capture} except only
STDERR is captured.  STDOUT is not captured.

== capture_merged

  ($merged, @result) = capture_merged \&code;
  $merged = capture_merged \&code;

The {capture_merged} function works just like {capture} except STDOUT and
STDERR are merged. (Technically, STDERR is redirected to STDOUT before
executing the function.)

Caution: STDOUT and STDERR output in the merged result are not guaranteed to be
properly ordered due to buffering.

== tee

  ($stdout, $stderr, @result) = tee \&code;
  $stdout = tee \&code;

The {tee} function works just like {capture}, except that output is captured
as well as passed on to the original STDOUT and STDERR.

== tee_stdout

  ($stdout, @result) = tee_stdout \&code;
  $stdout = tee_stdout \&code;

The {tee_stdout} function works just like {tee} except only
STDOUT is teed.  STDERR is not teed (output goes to STDERR as usual).

== tee_stderr

  ($stderr, @result) = tee_stderr \&code;
  $stderr = tee_stderr \&code;

The {tee_stderr} function works just like {tee} except only
STDERR is teed.  STDOUT is not teed (output goes to STDOUT as usual).

== tee_merged

  ($merged, @result) = tee_merged \&code;
  $merged = tee_merged \&code;

The {tee_merged} function works just like {capture_merged} except that output
is captured as well as passed on to STDOUT.

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
the call to {capture} or {tee}.  This may not work for tied handles (see below).

== Modifying filehandles before capturing

Generally speaking, you should do little or no manipulation of the standard IO
handles prior to using Capture::Tiny.  In particular, closing, reopening,
localizing or tying standard handles prior to capture may cause a variety of
unexpected, undesireable and/or unreliable behaviors, as described below.
Capture::Tiny does its best to compensate for these situations, but the
results may not be what you desire.

*Closed filehandles*

Capture::Tiny will work even if STDIN, STDOUT or STDERR have been previously
closed.  However, since they will be reopened to capture or tee output, any
code within the captured block that depends on finding them closed will, of
course, not find them to be closed.  If they started closed, Capture::Tiny will
reclose them again when the capture block finishes.

Note that this reopening will happen even for STDIN or a handle not being
captured to ensure that the filehandle used for capture is not opened to file
descriptor 0, as this causes problems on various platforms.

*Localized filehandles*

If code localizes any of Perl's standard handles before capturing, the capture
will affect the localized handles and not the original ones.  External system
calls are not affected by localizing a handle in Perl and will continue
to send output to the original handles (which will thus not be captured).

*Scalar filehandles*

If STDOUT or STDERR are reopened to scalar filehandles prior to the call to
{capture} or {tee}, then Capture::Tiny will override the output handle for the
duration of the {capture} or {tee} call and then send captured output to the
output handle after the capture is complete.  (Requires Perl 5.8)

Capture::Tiny attempts to preserve the semantics of STDIN opened to a scalar
reference.

*Tied handles*

If STDOUT or STDERR are tied prior to the call to {capture} or {tee}, then
Capture::Tiny will attempt to override the tie for the duration of the
{capture} or {tee} call and then send captured output to the tied handle after
the capture is complete.  (Requires Perl 5.8)

Capture::Tiny may not succeed resending utf8 encoded data to a tied
STDOUT or STDERR handle.  Characters may appear as bytes.  If the tied handle
is based on [Tie::StdHandle], then Capture::Tiny will attempt to determine
appropriate layers like {:utf8} from the underlying handle and do the right
thing.

Capture::Tiny attempts to preserve the semantics of tied STDIN, but capturing
or teeing when STDIN is tied is currently broken on Windows.

== Modifiying handles during a capture

Attempting to modify STDIN, STDOUT or STDERR ~during~ {capture} or {tee} is
almost certainly going to cause problems.  Don't do that.

== No support for Perl 5.8.0

It's just too buggy when it comes to layers and UTF8.

= ENVIRONMENT

== PERL_CAPTURE_TINY_TIMEOUT

Capture::Tiny uses subprocesses for {tee}.  By default, Capture::Tiny will
timeout with an error if the subprocesses are not ready to receive data within
30 seconds (or whatever is the value of {$Capture::Tiny::TIMEOUT}).  An
alternate timeout may be specified by setting the {PERL_CAPTURE_TINY_TIMEOUT}
environment variable.  Setting it to zero will disable timeouts.

= BUGS

Please report any bugs or feature requests using the CPAN Request Tracker.
Bugs can be submitted through the web interface at
[http://rt.cpan.org/Dist/Display.html?Queue=Capture-Tiny]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= SEE ALSO

This module was, inspired by [IO::CaptureOutput], which provides
similar functionality without the ability to tee output and with more
complicated code and API.  [IO::CaptureOutput] does not handle layers
or most of the unusual cases described in the [/Limitations] section and
I no longer recommend it.

There are many other CPAN modules that provide some sort of output capture,
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

=end wikidoc

=cut

