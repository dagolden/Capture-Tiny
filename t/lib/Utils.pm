package t::lib::Utils;
use strict;
use warnings;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw/save_std restore_std/;

sub _open {
  open $_[0], $_[1] or die "Error from open( " . join(q{, }, @_) . "): $!";
}

sub save_std {
  my @std = map { IO::Handle->new } 0 .. 2;
  _open $std[0], "<&STDIN";
  _open $std[1], ">&STDOUT";
  _open $std[2], ">&STDERR";
  return @std;
}

sub restore_std {
  _open \*STDIN , "<&" . fileno( $_[0] );
  _open \*STDOUT, ">&" . fileno( $_[1] );
  _open \*STDERR, ">&" . fileno( $_[2] );
}

