package Utils;
use strict;
use warnings;
use File::Spec;
use Config;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw/save_std restore_std next_fd sig_num/;

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
  no warnings 'io';
  open my $fh, ">", File::Spec->devnull;
  my $fileno = fileno $fh;
  close $fh;
  return $fileno;
}

#--------------------------------------------------------------------------#

my %sig_num;
my @sig_name;
unless($Config{sig_name} && $Config{sig_num}) {
  die "No sigs?";
} else {
  my @names = split ' ', $Config{sig_name};
  @sig_num{@names} = split ' ', $Config{sig_num};
  foreach (@names) {
    $sig_name[$sig_num{$_}] ||= $_;
  }
}

sub sig_num {
  my $name = shift;
  return exists $sig_num{$name} ? $sig_num{$name} : '';
}

1;
