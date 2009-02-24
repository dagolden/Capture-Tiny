package t::lib::Utils;
use strict;
use warnings;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw/save_std restore_std/;

sub _open {
  open $_[0], $_[1] or die "Error from open( " . join(q{, }, @_) . "): $!";
}

my @saved;
sub save_std {
  for my $h ( @_ ) {
    my $fh;
    _open $fh, ($h eq 'stdin' ? "<&" : ">&") . uc $h;
    push @saved, $fh;
  }
}

sub restore_std {
  for my $h ( @_ ) {
    no strict 'refs';
    my $fh = shift @saved;
    _open \*{uc $h}, ($h eq 'stdin' ? "<&" : ">&") . fileno( $fh );
    close $fh;
  }
}

1;
