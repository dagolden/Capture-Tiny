package t::lib::Utils;
use strict;
use warnings;
use File::Spec;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw/save_std restore_std next_fd/;

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

sub next_fd {
  open my $fh, ">", File::Spec->devnull;
  my $fileno = fileno $fh;
  close $fh;
  return $fileno;
}

1;
