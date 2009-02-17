require 5.006;
use Config;
if ( $^O ne 'MSWin32' && ! $Config{d_fork} ) {
  die "OS unsupported: requires working fork()\n";
}
use ExtUtils::MakeMaker;
WriteMakefile
(
          'INSTALLDIRS' => 'site',
          'NAME' => 'Capture::Tiny',
          'EXE_FILES' => [],
          'VERSION_FROM' => 'lib/Capture/Tiny.pm',
          'PREREQ_PM' => {
                           'Test::More' => '0.47',
                           'IO::Handle' => 0,
                           'File::Temp' => '0.14',
                           'Exporter' => 0
                         }
        )
;
