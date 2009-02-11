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
use IO::Handle;
use IPC::Open3;
use Symbol qw/qualify_to_ref/;

our $VERSION = '0.01';
$VERSION = eval $VERSION; ## no critic
our @ISA = qw/Exporter/;
our @EXPORT = qw/capture tee/;


#--------------------------------------------------------------------------#
# _capture()
#--------------------------------------------------------------------------#

# command to tee output
my @cmd = ($^X, '-e', 
  'select STDERR;$|++;select STDOUT;$|++; $SIG{HUP}=sub{exit};' .
  'while (<>) { print STDOUT $_; print STDERR $_}' 
);

my @outputs = qw/STDOUT STDERR/;

sub _capture_tee {
  my ($code, $tee) = @_;

  my ( %saved_fh, %capturing_fh, %kid_input, %kid_pid, %output );

  # copy STDOUT and STDERR and open files for replacement in binary mode
  for my $handle ( @outputs ) {
    open $saved_fh{$handle}, ">&" . fileno(qualify_to_ref($handle)) 
      or die "Couldn't save a copy for $handle";
    my $temp_fh = File::Temp::tempfile()
      or die "Couldn't get temporary file for capturing $handle\n";
    binmode( $temp_fh );
    $capturing_fh{$handle} = $temp_fh; 
  }

  # if teeing, direct output to teeing subprocesses
  if ($tee) {
    # create filehandles for kids to listen on
    %kid_input = ( stdout => IO::Handle->new, stderr => IO::Handle->new );

    # open listeners for each of STDOUT and STDERR;
    for my $handle ( @outputs ) {
        # autoflush everything -- XXX needed?
#        $kid_input{$handle}->autoflush(1);
#        $capturing_fh{$handle}->autoflush(1);
#        $saved_fh{$handle}->autoflush(1);

        # XXX this is a hack -- using STDERR temporarily to manage fds 
        open STDERR, ">&".$capturing_fh{$handle}->fileno;

        $kid_pid{$handle} = open3( 
            $kid_input{$handle}, 
            ">&".$saved_fh{$handle}->fileno,
            ">&STDERR",
            @cmd
        ) or do {
            open STDERR, ">&".$saved_fh{STDERR}->fileno;
            die "Couldn't open3 for $handle\n";
        };
    }
    # now that kids are running, redirect output to kids
    open STDOUT, ">&".$kid_input{STDOUT}->fileno or die "Couldn't redirect STDOUT";
    open STDERR, ">&".$kid_input{STDERR}->fileno or die "Couldn't redirect STDERR";
  }
  else {
    # redirect output to capture file
    open STDOUT, ">&".$capturing_fh{STDOUT}->fileno or die "Couldn't redirect STDOUT";
    open STDERR, ">&".$capturing_fh{STDERR}->fileno or die "Couldn't redirect STDERR";
  }

  # run code block
  $code->();

  # shut down kids -- or signal them to stop
  if ( $tee ) {
    for my $handle ( @outputs ) {
      close qualify_to_ref($handle);
      close $kid_input{$handle};
      if ( $^O eq 'MSWin32' ) {
        kill 1, $kid_pid{$handle};
      }
      else {
        waitpid $kid_pid{$handle}, 0;
      }
    }
  }

  # restore and read back output (STDERR first)
  for my $handle ( reverse @outputs ) {
    open qualify_to_ref($handle), ">&".$saved_fh{$handle}->fileno 
      or die "Couldn't restore $handle";
    seek $capturing_fh{$handle}, 0, 0;
    $output{$handle} = do { local $/; readline $capturing_fh{$handle} };
  }

  return wantarray ? ($output{STDOUT}, $output{STDERR}) : $output{STDOUT};
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

